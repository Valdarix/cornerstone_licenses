local pedEntities = {} 
local blipEntities = {} --

local function sendNotify(notifyType, message)
    exports.qbx_core:Notify('Background Check', notifyType, 5000, message, 'center-right')
end

RegisterNetEvent('cornerstone_sellshop:client:sendNotify')
AddEventHandler('cornerstone_sellshop:client:sendNotify', function(notifyType, message)    
    sendNotify(notifyType, message)    
end)

local function LoadModel(model)
    RequestModel(model)
    local startTime = GetGameTimer()
    while not HasModelLoaded(model) do
        Wait(0)
        if GetGameTimer() - startTime > 5000 then            
            break
        end
    end
end

local function checkLicense(license)    
    local hasLicense = false
    hasLicense = lib.callback.await('cornerstone_licenses:server:hasLicense', false, license)
    if hasLicense then
        sendNotify('inform', 'You already have this license, you can purchase your paper copy at city hall.')
    else
       lib.callback.await('cornerstone_licenses:server:inquire', false, license)       
    end
    
end

function OpenBuyMenu(loc)
    local availableLicenses = lib.callback.await('cornerstone_licenses:server:getLicenseTypes', false, loc.name)
   
    local menu = {}
    for i = 1, #availableLicenses  do     
        menu[#menu + 1] = {                  
            title = availableLicenses[i].label,
            description = availableLicenses[i].description .. ' - $' .. availableLicenses[i].cost,          
            icon = availableLicenses[i].icon,
            onSelect = function()
                if lib.progressBar({
                    duration = 2000,
                    label = 'Performing background check...',
                    useWhileDead = false,
                    canCancel = true,
                }) then checkLicense(availableLicenses[i].name) end        
            end}  
            
        end

    local contextId = 'OpenBuyMenu_' .. loc.name
         
    lib.registerContext({
        id = contextId,
        title = "Purchase License",
        options = menu
    })
    lib.showContext(contextId)
end

local function UpdateLicensePeds(currentCopCount)
    if not pedEntities then pedEntities = {} end    
    
    for i = 1, #Config.Locations do
        local locationSettings = lib.callback.await('cornerstone_licenses:server:getLicenseTypes', false, Config.Locations[i].name)
        local copCount = currentCopCount
    
        local canSell = copCount <= locationSettings[i].cop_count            
        
        if canSell and not pedEntities[i] then
            local loc = Config.Locations[i]
            LoadModel(loc.pedModel)
            
            local ped = CreatePed(1, GetHashKey(loc.pedModel), loc.location.x, loc.location.y, loc.location.z - 1.0, loc.location.w, false, true)
            SetEntityHeading(ped, loc.location.w)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_CLIPBOARD', 0, true)       
            SetModelAsNoLongerNeeded(GetHashKey(loc.pedModel))
            pedEntities[i] = ped

            exports.ox_target:addLocalEntity(ped, {
                label = loc.label,
                name = loc.name,
                icon = loc.icon,
                description = loc.description,
                iconColor = 'green',
                distance = 2.0,
                onSelect = function()
                    OpenBuyMenu(loc)
                end,
            })                            

           if loc.useBlip then
            local newBlip = AddBlipForCoord(loc.location.x, loc.location.y, loc.location.z)
            SetBlipSprite(newBlip, loc.blip.sprite)
            SetBlipColour(newBlip, loc.blip.color)
            SetBlipScale(newBlip, loc.blip.scale)
            SetBlipAsMissionCreatorBlip(newBlip, true)
            SetBlipAsShortRange(newBlip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(loc.blip.name)
            EndTextCommandSetBlipName(newBlip)
            blipEntities[i] = newBlip
        end
        elseif not canSell then
            if pedEntities[i] then 
                exports.ox_target:removeLocalEntity(pedEntities[i])
                DeleteEntity(pedEntities[i])
                if blipEntities[i] and DoesBlipExist(blipEntities[i]) then
                    RemoveBlip(blipEntities[i])
                end
                pedEntities[i] = nil
                blipEntities[i] = nil
            end
        end
    end
end

RegisterNetEvent('cornerstone_licenses:client:updateCopCount')
AddEventHandler('cornerstone_licenses:client:updateCopCount', function(copCount)
    UpdateLicensePeds(copCount) -- Pass cop count to avoid callback
end)
CreateThread(function()
    Wait(1000) -- Wait for player to fully load
    local copCount = lib.callback.await('cornerstone_licenses:server:getCopCount', false, 'leo')
    UpdateLicensePeds(copCount)
end)
