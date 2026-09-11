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
        title = 'Background Check',
        description = message,
        type = notifyType,
        duration = 5000,
        position = 'center-right',
    })
end

RegisterNetEvent('cornerstone_licenses:client:notify', function(notifyType, message)
    notify(notifyType, message)
end)

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
        label = 'Performing background check...',
        useWhileDead = false,
        canCancel = true,
    })
    if not finished then return end

    local result = lib.callback.await('cornerstone_licenses:server:inquire', false, loc.name, license.name)
    if not result then
        notify('error', 'No answer from the server, please try again.')
        return
    end
    notify(result.ok and 'success' or 'error', result.message)
end

function OpenBuyMenu(loc)
    local licenses = sellableLicenses(loc.name, copCount)
    if #licenses == 0 then
        notify('inform', 'No licenses are available while police are on duty.')
        return
    end

    local options = {}
    for _, license in ipairs(licenses) do
        options[#options + 1] = {
            title = license.label,
            description = ('%s - $%s'):format(license.description or '', license.cost or 0),
            icon = license.icon,
            onSelect = function()
                purchase(loc, license)
            end,
        }
    end

    local contextId = 'OpenBuyMenu_' .. loc.name
    lib.registerContext({
        id = contextId,
        title = 'Purchase License',
        options = options,
    })
    lib.showContext(contextId)
end

-- ---------------------------------------------------------------------------
-- Peds and blips
-- ---------------------------------------------------------------------------

local function despawn(i)
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
        SetBlipAsMissionCreatorBlip(blip, true)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(loc.blip.name or loc.label)
        EndTextCommandSetBlipName(blip)
        blips[i] = blip
    end
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

RegisterNetEvent('cornerstone_licenses:client:updateCopCount', function(count)
    applyCopCount(count)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for i in pairs(peds) do despawn(i) end
end)

CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do
        Wait(500)
    end
    local count = lib.callback.await('cornerstone_licenses:server:getCopCount', false)
    applyCopCount(count)
end)
