-- client/modules/commands/manager/admin.lua
RegisterNetEvent("admin:heal:client", function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, 200)
    ClearPedBloodDamage(ped)
end)

RegisterNetEvent("admin:revive:client", function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    SetEntityHealth(ped, 200)
end)

RegisterNetEvent("admin:revivezone:client", function(radius)
    -- FIX: calcul maintenant côté serveur dans server/modules/commands/admin.lua
    -- Ce handler n'est plus utilisé mais conservé pour compatibilité
    local adminPed = PlayerPedId()
    local adminCoords = GetEntityCoords(adminPed)
    local players = GetActivePlayers()
    for _, player in ipairs(players) do
        local ped = GetPlayerPed(player)
        local coords = GetEntityCoords(ped)
        local dist = #(adminCoords - coords)
        if dist <= radius then
            NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
            SetEntityHealth(PlayerPedId(), 200)
        end
    end
end)

RegisterCommand("id", function()
    local playerId = GetPlayerServerId(PlayerId())
    print(("[INFO] Votre ID serveur est : %s"):format(playerId))
end, false)

-- RegisterCommand('me', function(source, args)
--     local message = table.concat(args, " ")

--     TriggerClientEvent('chat:addMessage', -1, {
--         color = {255, 0, 255},
--         multiline = true,
--         args = {"ME", message}
--     })
-- end)


RegisterNetEvent("admin:bring:client", function(adminId)
    local adminPed = GetPlayerPed(GetPlayerFromServerId(adminId))
    if not adminPed then return end
    local coords = GetEntityCoords(adminPed)
    SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z)
end)

RegisterNetEvent("admin:goto:client", function(targetId)
    local targetPed = GetPlayerPed(GetPlayerFromServerId(targetId))
    if not targetPed then return end
    local coords = GetEntityCoords(targetPed)
    SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z)
end)

local spectating = false
RegisterNetEvent("admin:spectate:client", function(targetId)
    local targetPed = GetPlayerPed(GetPlayerFromServerId(targetId))
    if not targetPed then return end
    spectating = not spectating
    if spectating then
        NetworkSetInSpectatorMode(true, targetPed)
    else
        NetworkSetInSpectatorMode(false, targetPed)
    end
end)

RegisterNetEvent("admin:tp:client", function(coords)
    SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z)
end)

RegisterNetEvent("admin:tpm:client", function()
    local ped = PlayerPedId()
    local blip = GetFirstBlipInfoId(8)
    if DoesBlipExist(blip) then
        local coord = GetBlipInfoIdCoord(blip)
        local foundGround, z = GetGroundZFor_3dCoord(coord.x, coord.y, 1000.0, false)
        if foundGround then
            SetEntityCoords(ped, coord.x, coord.y, z + 1.0, false, false, false, true)
        else
            SetEntityCoords(ped, coord.x, coord.y, coord.z + 1.0, false, false, false, true)
        end
        SetPedToRagdoll(ped, 1000, 1000, 0, false, false, false)
    else
        TriggerEvent("chat:addMessage", { args = { "^3ADMIN", "Aucun GPS actif (waypoint requis)" } })
    end
end)

RegisterNetEvent("admin:car:client", function(model)
    local modelHash = GetHashKey(model)
    if not IsModelInCdimage(modelHash) or not IsModelAVehicle(modelHash) then
        TriggerEvent("chat:addMessage", { args = { "^3ADMIN", "Modèle invalide" } })
        return
    end
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do Wait(0) end
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local vehicle = CreateVehicle(modelHash, coords.x, coords.y, coords.z, true, false)
    SetPedIntoVehicle(playerPed, vehicle, -1)
    SetModelAsNoLongerNeeded(modelHash)
end)

RegisterNetEvent("admin:dv:client", function()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    if vehicle and vehicle ~= 0 then
        DeleteVehicle(vehicle)
    else
        TriggerEvent("chat:addMessage", { args = { "^3ADMIN", "Vous n'êtes pas dans un véhicule" } })
    end
end)

RegisterNetEvent("admin:dvzone:client", function(radius)
    -- FIX: calcul maintenant côté serveur
    -- Ce handler n'est plus utilisé mais conservé pour compatibilité
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local vehicles = GetGamePool("CVehicle")
    for _, vehicle in ipairs(vehicles) do
        local vCoords = GetEntityCoords(vehicle)
        local dist = #(coords - vCoords)
        if dist <= radius then DeleteVehicle(vehicle) end
    end
end)

RegisterNetEvent("admin:fix:client", function()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    if vehicle and vehicle ~= 0 then
        SetVehicleFixed(vehicle)
        SetVehicleDeformationFixed(vehicle)
        SetVehicleUndriveable(vehicle, false)
        SetVehicleEngineOn(vehicle, true, true, false)
    else
        TriggerEvent("chat:addMessage", { args = { "^3ADMIN", "Vous n'êtes pas dans un véhicule" } })
    end
end)

RegisterNetEvent("admin:boost:client", function()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    if vehicle and vehicle ~= 0 then
        SetVehicleModKit(vehicle, 0)
        for modType = 0, 50 do
            local modCount = GetNumVehicleMods(vehicle, modType)
            if modCount > 0 then
                SetVehicleMod(vehicle, modType, modCount - 1, false)
            end
        end
    else
        TriggerEvent("chat:addMessage", { args = { "^3ADMIN", "Vous n'êtes pas dans un véhicule" } })
    end
end)

RegisterNetEvent('admin:spawnnpc:client', function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local forward = GetEntityForwardVector(playerPed)
    local spawnPos = coords + (forward * 2.0)
    local model = `a_m_m_business_01`
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end
    local ped = CreatePed(0, model, spawnPos.x, spawnPos.y, spawnPos.z, GetEntityHeading(playerPed), true, false)
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetModelAsNoLongerNeeded(model)
    print("NPC spawn:", ped)
end)
