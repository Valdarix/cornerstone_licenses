local lastCopCount = 0

lib.callback.register('cornerstone_licenses:server:getLicenseTypes', function(source, location)   
     return SVConfig.AvailableLicenses[location] or {}
end)

local function hasLicense(source, license)
    local src = source
    if not src then return end

    local player =  exports.qbx_core:GetPlayer(src)
    if not player then return end

    local licenses = player.PlayerData.metadata['licences']
  
    if licenses[license] == true then
        return true
    else
        return false
    end
end

lib.callback.register('cornerstone_licenses:server:hasLicense', function(source, license)   
    return hasLicense(source, license)
end)    

local function GetCopCount(jobType) 
    return  exports.qbx_core:GetDutyCountType(jobType)
end

lib.callback.register('cornerstone_licenses:server:getCopCount', function(source, jobType)
    local copCount = 0
    copCount = GetCopCount(jobType) 
    return copCount
   
end)

local function checkCriminalRecord(src, citizenID)

    local result = nil

    if SVConfig.MDT == 'al_mdt' then
        result = MySQL.query.await("SELECT * FROM `mdt_criminal_record` WHERE input LIKE '%Felony%' AND TYPE = 'Arrest' and  identifier = ?", { citizenID })
    elseif SVConfig.MDT == 'lb-tablet' then
        result = MySQL.query.await("SELECT * from `lbtablet_police_cases_charges` where offence_id IN (select id from `lbtablet_police_offences` where class = 'felony') and criminal = ?", { citizenID })
    else
        TriggerClientEvent('cornerstone_sellshop:client:sendNotify', src, 'error', 'Your MDT is not supported, you will need to add support or disable felony check')
    end

    if result[1] then
        return true
    else
         return false
    end
end

local function hasFelonies(src, citizenID)
    local felon = false
    felon = checkCriminalRecord(src, citizenID)
    return felon
end


lib.callback.register('cornerstone_licenses:server:inquire', function(source, license)
    local src = source
    if not src then return end
  
    local player =  exports.qbx_core:GetPlayer(src)
    if not player then return end
   
    local playerId = player.PlayerData.citizenid
    if not playerId then return end

    if SVConfig.CheckFelony then
         local isFelon = hasFelonies(src, playerId)
         if isFelon then
            TriggerClientEvent('cornerstone_sellshop:client:sendNotify', src, 'error', 'You have a felony and cannot purchase this license.')
            return
        end
    end

    if player then
        local canPay = false
            
        local hasCash = false

        hasCash = exports.ox_inventory:GetItemCount(src, 'money')

        canPay = hasCash >= 5000

        if not canPay then return end
                
        local success = exports.ox_inventory:RemoveItem(src, 'money', 5000)

        if not success then return end
            local licenses = player.PlayerData.metadata['licences']
            licenses[license] = true

            player.Functions.SetMetaData('licences', licenses)
            TriggerClientEvent('cornerstone_sellshop:client:sendNotify', src, 'success', 'You have been granted a ' ..  license .. ', you can pick up your paper copy at city hall.')
        end
   
    
end)

CreateThread(function()
    while true do
        Wait(10000) -- Check every 30 seconds on server
        local currentCopCount = GetCopCount('leo') -- Your existing function
        
        if math.abs(currentCopCount - lastCopCount) >= 1 then -- Only if count changed
            TriggerClientEvent('cornerstone_licenses:client:updateCopCount', -1, currentCopCount)
            lastCopCount = currentCopCount
        end
    end
end)
