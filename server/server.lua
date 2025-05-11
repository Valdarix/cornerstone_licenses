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

lib.callback.register('cornerstone_licenses:server:getCopCount', function(source, jobType)
    local copCount = 0
    copCount = exports.qbx_core:GetDutyCountType(jobType)

    return copCount
   
end)

local function checkCriminalRecord(citizenID)
    print(citizenID)
    local result = MySQL.query.await("SELECT * FROM `mdt_criminal_record` WHERE input LIKE '%Felony%' AND TYPE = 'Arrest' and  identifier = ?", { citizenID })
    if result[1] then
        return true
    else
         return false
    end
end

local function hasFelonies(citizenID)
    local felon = false    
    felon = checkCriminalRecord(citizenID)          
    return felon
end


lib.callback.register('cornerstone_licenses:server:inquire', function(source, license)
    local src = source
    if not src then return end
  
    local player =  exports.qbx_core:GetPlayer(src)
    if not player then return end
   
    local playerId = player.PlayerData.citizenid
    if not playerId then return end
   
    local isFelon = hasFelonies(playerId)
   
    if isFelon then
       TriggerClientEvent('cornerstone_sellshop:client:sendNotify', src, 'error', 'You have a felony and cannot purchase this license.')
    else        
        if player then
            local canPay = false
            
            local hasCash = false

            hasCash = exports.ox_inventory:GetItemCount(src, 'money')

            canPay = hasCash > 5000

            if canPay then
                
                local success = exports.ox_inventory:RemoveItem(src, 'money', 5000)
                if success then
                    local licenses = player.PlayerData.metadata['licences']
                    licenses[license] = true

                    player.Functions.SetMetaData('licences', licenses)
                    TriggerClientEvent('cornerstone_sellshop:client:sendNotify', src, 'success', 'You have been granted a ' ..  license .. ', you can pick up your paper copy at city hall.')
                end
            end
        end
    end
end)