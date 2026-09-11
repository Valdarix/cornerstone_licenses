--[[
    The client draws peds, blips and menus from the police count the server
    broadcasts. Every rule is checked again on the server before a purchase.
]]

local peds = {}          -- location index -> ped handle (or true while spawning)
local blips = {}         -- location index -> blip handle
local licenseCache = {}  -- location name -> license list from the server
local copCount = 0
local updateSeq = 0      -- bumps on every update so a stale update stops itself

local function notify(notifyType, message)
    lib.notify({
        title = locale('notify_title'),
        description = message,
        type = notifyType,
        duration = 5000,
        position = 'center-right',
    })
end

local function getLicenses(locationName)
    if not licenseCache[locationName] then
        licenseCache[locationName] = lib.callback.await('cornerstone_licenses:server:getLicenseTypes', false, locationName) or {}
    end
    return licenseCache[locationName]
end

local function sellableLicenses(locationName, count)
    local out = {}
    for _, license in ipairs(getLicenses(locationName)) do
        if count <= (license.cop_count or 0) then
            out[#out + 1] = license
        end
    end
    return out
end

local function loadModel(model)
    local hash = joaat(model)
    RequestModel(hash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        Wait(0)
        if GetGameTimer() > deadline then
            print(('[%s] model "%s" did not load'):format(GetCurrentResourceName(), model))
            return false
        end
    end
    return true
end

-- ---------------------------------------------------------------------------
-- Buying
-- ---------------------------------------------------------------------------

local function purchase(loc, license)
    local finished = lib.progressBar({
        duration = 2000,
        label = locale('progress_label'),
        useWhileDead = false,
        canCancel = true,
    })
    if not finished then return end

    local result = lib.callback.await('cornerstone_licenses:server:inquire', false, loc.name, license.name)
    if not result then
        notify('error', locale('no_answer'))
        return
    end
    notify(result.ok and 'success' or 'error', result.message)
end

local function menuId(loc)
    return 'cornerstone_licenses_' .. loc.name
end

function OpenBuyMenu(loc)
    local licenses = sellableLicenses(loc.name, copCount)
    if #licenses == 0 then
        notify('inform', locale('none_available'))
        return
    end

    local options = {}
    for _, license in ipairs(licenses) do
        options[#options + 1] = {
            title = license.label,
            description = locale('menu_price', license.description or '', license.cost or 0),
            icon = license.icon,
            onSelect = function()
                purchase(loc, license)
            end,
        }
    end

    local id = menuId(loc)
    lib.registerContext({
        id = id,
        title = locale('menu_title'),
        options = options,
    })
    lib.showContext(id)
end

-- ---------------------------------------------------------------------------
-- Peds and blips
-- ---------------------------------------------------------------------------

local function despawn(i)
    local loc = Config.Locations[i]
    if loc and lib.getOpenContextMenu() == menuId(loc) then
        lib.hideContext(true) -- the desk just closed under the player's menu
    end

    local ped = peds[i]
    if type(ped) == 'number' then
        exports.ox_target:removeLocalEntity(ped)
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    peds[i] = nil

    if blips[i] and DoesBlipExist(blips[i]) then
        RemoveBlip(blips[i])
    end
    blips[i] = nil
end

local function spawn(i, loc)
    peds[i] = true -- reserve the slot before yielding so a second update cannot double-spawn

    if not loadModel(loc.pedModel) then
        peds[i] = nil
        return
    end

    local hash = joaat(loc.pedModel)
    local ped = CreatePed(1, hash, loc.location.x, loc.location.y, loc.location.z - 1.0, loc.location.w, false, true)
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(ped) then
        peds[i] = nil
        return
    end

    SetEntityHeading(ped, loc.location.w)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_CLIPBOARD', 0, true)
    peds[i] = ped

    exports.ox_target:addLocalEntity(ped, {
        {
            label = loc.label,
            name = loc.name,
            icon = loc.icon,
            description = loc.description,
            iconColor = 'green',
            distance = 2.0,
            canInteract = function()
                return not IsPedDeadOrDying(cache.ped, true)
            end,
            onSelect = function()
                OpenBuyMenu(loc)
            end,
        },
    })

    if loc.useBlip and loc.blip then
        local blip = AddBlipForCoord(loc.location.x, loc.location.y, loc.location.z)
        SetBlipSprite(blip, loc.blip.sprite or 110)
        SetBlipColour(blip, loc.blip.color or 1)
        SetBlipScale(blip, loc.blip.scale or 0.8)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(loc.blip.name or loc.label)
        EndTextCommandSetBlipName(blip)
        blips[i] = blip
    end
end

local function despawnAll()
    for i in pairs(peds) do despawn(i) end
end

local function applyCopCount(count)
    copCount = tonumber(count) or 0
    updateSeq = updateSeq + 1
    local seq = updateSeq

    for i = 1, #Config.Locations do
        local loc = Config.Locations[i]
        local canSell = #sellableLicenses(loc.name, copCount) > 0
        if seq ~= updateSeq then return end -- a newer count arrived while we waited on the server

        if canSell and not peds[i] then
            spawn(i, loc)
        elseif not canSell and peds[i] then
            despawn(i)
        end
    end
end

local function resync()
    local count = lib.callback.await('cornerstone_licenses:server:getCopCount', false)
    applyCopCount(count)
end

RegisterNetEvent('cornerstone_licenses:client:updateCopCount', function(count)
    applyCopCount(count)
end)

-- Character selected (also fires after a relog); the server count may have moved meanwhile
AddEventHandler('QBCore:Client:OnPlayerLoaded', resync)

-- Back to character selection: nothing should be left in the world
RegisterNetEvent('qbx_core:client:playerLoggedOut', despawnAll)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    despawnAll()
end)

-- Resource (re)started while already in game
CreateThread(function()
    if LocalPlayer.state.isLoggedIn then
        resync()
    end
end)
