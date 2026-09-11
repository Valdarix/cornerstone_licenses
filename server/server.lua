--[[
    Every rule lives here. The client only draws peds and menus; nothing it sends
    is trusted. A purchase must pass, in order: known license at a known
    location, player close to that location, few enough police on duty, license
    not already held, no felony (when enabled), enough cash.
]]

local RESOURCE = GetCurrentResourceName()

local SUPPORTED_MDT = { ['al_mdt'] = true, ['lb-tablet'] = true }
local COOLDOWN_MS = 2000 -- matches the client's background-check progress bar

local copCount = 0
local refreshPending = false
local inquiring = {}   -- source -> true while a purchase is being processed
local lastInquiry = {} -- source -> GetGameTimer() of the last accepted request

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

-- Every qbx_core server event that can change who is on duty
-- (names verified against qbx_core server/player.lua and docs.qbox.re)
for _, eventName in ipairs({
    'QBCore:Server:SetDuty',          -- (source, onDuty)
    'QBCore:Server:OnJobUpdate',      -- (source, job)
    'qbx_core:server:onGroupUpdate',  -- (source, groupName, groupGrade)
    'QBCore:Server:PlayerLoaded',     -- (player)
    'QBCore:Server:OnPlayerUnload',   -- (source)
    'qbx_core:server:playerLoggedOut',-- (source)
    'playerDropped',
}) do
    AddEventHandler(eventName, scheduleRefresh)
end

AddEventHandler('playerDropped', function()
    inquiring[source] = nil
    lastInquiry[source] = nil
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

local function deny(key, ...)
    return { ok = false, message = locale(key, ...) }
end

local function inquire(src, locationName, licenseName)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return deny('contact_admin') end

    local location = findLocation(locationName)
    local license = location and findLicense(locationName, licenseName)
    if not license then
        return deny('unavailable_here')
    end

    local ped = GetPlayerPed(src)
    local pos = location.location
    if ped == 0 or #(GetEntityCoords(ped) - vector3(pos.x, pos.y, pos.z)) > SVConfig.MaxDistance then
        return deny('too_far')
    end

    -- Read fresh rather than trusting the cached broadcast value
    copCount = readCopCount()
    if not isSellable(license, copCount) then
        return deny('police_on_duty')
    end

    if hasLicense(player, license.name) then
        return deny('already_owned')
    end

    if SVConfig.CheckFelony then
        if not SUPPORTED_MDT[SVConfig.MDT] then
            print(('[%s] SVConfig.MDT "%s" is not supported; set it to al_mdt or lb-tablet, or set SVConfig.CheckFelony = false'):format(RESOURCE, tostring(SVConfig.MDT)))
            return deny('contact_admin')
        end
        if hasFelony(player.PlayerData.citizenid) then
            return deny('felony')
        end
    end

    local price = tonumber(license.cost) or 0
    -- qbx_core keeps cash in sync with the ox_inventory money item, refuses to
    -- go negative, and writes its own money log
    if price > 0 and not player.Functions.RemoveMoney('cash', price, 'license:' .. license.name) then
        return deny('not_enough_cash', price)
    end

    local licences = player.PlayerData.metadata.licences or {}
    licences[license.name] = true
    player.Functions.SetMetaData('licences', licences)

    lib.logger(src, 'license_granted', ('%s granted for $%s at %s'):format(license.name, price, locationName),
        'citizenid:' .. tostring(player.PlayerData.citizenid), 'license:' .. license.name, 'location:' .. locationName)

    return { ok = true, message = locale('granted', license.label or license.name) }
end

lib.callback.register('cornerstone_licenses:server:inquire', function(source, locationName, licenseName)
    if inquiring[source] then
        return deny('in_progress')
    end
    local now = GetGameTimer()
    if lastInquiry[source] and now - lastInquiry[source] < COOLDOWN_MS then
        return deny('too_soon')
    end
    lastInquiry[source] = now

    inquiring[source] = true
    local ok, result = pcall(inquire, source, locationName, licenseName)
    inquiring[source] = nil
    if not ok then
        print(('[%s] inquire failed for %s: %s'):format(RESOURCE, source, tostring(result)))
        return deny('contact_admin')
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
