--[[
    Every rule lives here. The client only draws peds and menus; nothing it sends
    is trusted. A purchase must pass, in order: known license at a known
    location, player close to that location, few enough police on duty, license
    not already held, no felony (when enabled), enough cash.
]]

local RESOURCE = GetCurrentResourceName()

local SUPPORTED_MDT = { ['al_mdt'] = true, ['lb-tablet'] = true }

local copCount = 0
local refreshPending = false
local inquiring = {} -- players with a purchase in progress, keyed by source

-- ---------------------------------------------------------------------------
-- Config lookups
-- ---------------------------------------------------------------------------

local function findLocation(name)
    for i = 1, #Config.Locations do
        if Config.Locations[i].name == name then
            return Config.Locations[i]
        end
    end
end

local function findLicense(locationName, licenseName)
    local list = SVConfig.AvailableLicenses[locationName]
    if not list then return end
    for i = 1, #list do
        if list[i].name == licenseName then
            return list[i]
        end
    end
end

local function isSellable(license, count)
    return count <= (license.cop_count or 0)
end

-- ---------------------------------------------------------------------------
-- Police count: event driven with a debounce, plus a slow reconciling poll
-- ---------------------------------------------------------------------------

local function readCopCount()
    local count = exports.qbx_core:GetDutyCountType(SVConfig.CopJobType)
    return tonumber(count) or 0
end

local function broadcastIfChanged()
    local current = readCopCount()
    if current ~= copCount then
        copCount = current
        TriggerClientEvent('cornerstone_licenses:client:updateCopCount', -1, copCount)
    end
end

local function scheduleRefresh()
    if refreshPending then return end
    refreshPending = true
    SetTimeout(1000, function()
        refreshPending = false
        broadcastIfChanged()
    end)
end

for _, eventName in ipairs({
    'QBCore:Server:SetDuty', 'qbx_core:server:onSetDuty',
    'QBCore:Server:OnJobUpdate', 'qbx_core:server:onJobUpdate',
    'QBCore:Server:PlayerLoaded', 'qbx_core:server:playerLoaded',
    'QBCore:Server:OnPlayerUnload', 'qbx_core:server:onPlayerUnload',
    'playerDropped',
}) do
    AddEventHandler(eventName, scheduleRefresh)
end

AddEventHandler('playerDropped', function()
    inquiring[source] = nil
end)

CreateThread(function()
    Wait(1000)
    copCount = readCopCount()
    while true do
        Wait(60000)
        broadcastIfChanged()
    end
end)

-- ---------------------------------------------------------------------------
-- Felony check
-- ---------------------------------------------------------------------------

local function hasFelony(citizenId)
    if SVConfig.MDT == 'al_mdt' then
        return MySQL.scalar.await(
            "SELECT 1 FROM `mdt_criminal_record` WHERE `identifier` = ? AND `type` = 'Arrest' AND `input` LIKE '%Felony%' LIMIT 1",
            { citizenId }) ~= nil
    elseif SVConfig.MDT == 'lb-tablet' then
        return MySQL.scalar.await(
            "SELECT 1 FROM `lbtablet_police_cases_charges` c JOIN `lbtablet_police_offences` o ON o.`id` = c.`offence_id` WHERE c.`criminal` = ? AND o.`class` = 'felony' LIMIT 1",
            { citizenId }) ~= nil
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Callbacks
-- ---------------------------------------------------------------------------

lib.callback.register('cornerstone_licenses:server:getLicenseTypes', function(_, location)
    return SVConfig.AvailableLicenses[location] or {}
end)

lib.callback.register('cornerstone_licenses:server:getCopCount', function()
    return copCount
end)

local function hasLicense(player, license)
    local licences = player.PlayerData.metadata and player.PlayerData.metadata.licences
    return licences ~= nil and licences[license] == true
end

lib.callback.register('cornerstone_licenses:server:hasLicense', function(source, license)
    local player = exports.qbx_core:GetPlayer(source)
    return player ~= nil and hasLicense(player, license)
end)

local function deny(message)
    return { ok = false, message = message }
end

local function inquire(src, locationName, licenseName)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return deny('Player not found.') end

    local location = findLocation(locationName)
    local license = location and findLicense(locationName, licenseName)
    if not license then
        return deny('That license is not available here.')
    end

    local ped = GetPlayerPed(src)
    local pos = location.location
    if ped == 0 or #(GetEntityCoords(ped) - vector3(pos.x, pos.y, pos.z)) > SVConfig.MaxDistance then
        return deny('You need to be at the licensing desk.')
    end

    -- Read fresh rather than trusting the cached broadcast value
    copCount = readCopCount()
    if not isSellable(license, copCount) then
        return deny('Licensing is unavailable while police are on duty.')
    end

    if hasLicense(player, license.name) then
        return deny('You already have this license, you can purchase your paper copy at city hall.')
    end

    if SVConfig.CheckFelony then
        if not SUPPORTED_MDT[SVConfig.MDT] then
            print(('[%s] SVConfig.MDT "%s" is not supported; set it to al_mdt or lb-tablet, or set SVConfig.CheckFelony = false'):format(RESOURCE, tostring(SVConfig.MDT)))
            return deny('Licensing is unavailable right now, please contact an admin.')
        end
        if hasFelony(player.PlayerData.citizenid) then
            return deny('You have a felony and cannot purchase this license.')
        end
    end

    local price = tonumber(license.cost) or 0
    if price > 0 then
        local cash = exports.ox_inventory:GetItemCount(src, 'money') or 0
        if cash < price or not exports.ox_inventory:RemoveItem(src, 'money', price) then
            return deny(('You need $%s in cash for this license.'):format(price))
        end
    end

    local licences = player.PlayerData.metadata.licences or {}
    licences[license.name] = true
    player.Functions.SetMetaData('licences', licences)

    return { ok = true, message = ('You have been granted a %s, you can pick up your paper copy at city hall.'):format(license.label or license.name) }
end

lib.callback.register('cornerstone_licenses:server:inquire', function(source, locationName, licenseName)
    if inquiring[source] then
        return deny('Your background check is still running.')
    end
    inquiring[source] = true
    local ok, result = pcall(inquire, source, locationName, licenseName)
    inquiring[source] = nil
    if not ok then
        print(('[%s] inquire failed for %s: %s'):format(RESOURCE, source, tostring(result)))
        return deny('Licensing is unavailable right now, please contact an admin.')
    end
    return result
end)

-- ---------------------------------------------------------------------------
-- Startup checks
-- ---------------------------------------------------------------------------

CreateThread(function()
    if SVConfig.CheckFelony and not SUPPORTED_MDT[SVConfig.MDT] then
        print(('[%s] WARNING: SVConfig.MDT "%s" is not supported. Purchases will be refused until it is set to al_mdt or lb-tablet, or SVConfig.CheckFelony is set to false.'):format(RESOURCE, tostring(SVConfig.MDT)))
    end
    for name in pairs(SVConfig.AvailableLicenses) do
        if not findLocation(name) then
            print(('[%s] WARNING: SVConfig.AvailableLicenses has licenses for "%s" but client/cl_config.lua has no location with that name.'):format(RESOURCE, name))
        end
    end
    for i = 1, #Config.Locations do
        if not SVConfig.AvailableLicenses[Config.Locations[i].name] then
            print(('[%s] WARNING: location "%s" has no licenses in SVConfig.AvailableLicenses; its ped will never appear.'):format(RESOURCE, Config.Locations[i].name))
        end
    end
end)
