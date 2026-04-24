-- client/modules/admin/client.lua

-----------------------------------------
-- HEAL
-----------------------------------------
RegisterNetEvent("admin:heal:client", function()
    local ped = PlayerPedId()

    SetEntityHealth(ped, 200)
    ClearPedBloodDamage(ped)
end)

-----------------------------------------
-- REVIVE
-----------------------------------------
RegisterNetEvent("admin:revive:client", function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    SetEntityHealth(ped, 200)
end)

RegisterNetEvent("admin:revivezone:client", function(radius)
    local adminPed = PlayerPedId()
    local adminCoords = GetEntityCoords(adminPed)

    local players = GetActivePlayers()

    for _, player in ipairs(players) do
        local ped = GetPlayerPed(player)
        local coords = GetEntityCoords(ped)

        local dist = #(adminCoords - coords)

        if dist <= radius then
            -- revive local player
            NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
            SetEntityHealth(PlayerPedId(), 200)
        end
    end
end)

-----------------------------------------
-- /id (affiche l'id joueur dans F8)
-----------------------------------------
RegisterCommand("id", function()
    local playerId = GetPlayerServerId(PlayerId())

    print(("[INFO] Votre ID serveur est : %s"):format(playerId))
end, false)

-----------------------------------------
-- BRING (target -> admin)
-----------------------------------------
RegisterNetEvent("admin:bring:client", function(adminId)
    local adminPed = GetPlayerPed(GetPlayerFromServerId(adminId))
    if not adminPed then return end

    local coords = GetEntityCoords(adminPed)
    SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z)
end)

-----------------------------------------
-- GOTO (admin -> target)
-----------------------------------------
RegisterNetEvent("admin:goto:client", function(targetId)
    local targetPed = GetPlayerPed(GetPlayerFromServerId(targetId))
    if not targetPed then return end

    local coords = GetEntityCoords(targetPed)
    SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z)
end)

-----------------------------------------
-- SPECTATE
-----------------------------------------
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

-----------------------------------------
-- TP
-----------------------------------------
RegisterNetEvent("admin:tp:client", function(coords)
    SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z)
end)

RegisterNetEvent("admin:tpa:client", function()
    local ped = PlayerPedId()

    -- Check waypoint blip
    local blip = GetFirstBlipInfoId(8) -- 8 = waypoint
    if DoesBlipExist(blip) then

        local coord = GetBlipInfoIdCoord(blip)

        -- Ground Z detection
        local foundGround, z = GetGroundZFor_3dCoord(coord.x, coord.y, 1000.0, false)

        if foundGround then
            SetEntityCoords(ped, coord.x, coord.y, z + 1.0, false, false, false, true)
        else
            SetEntityCoords(ped, coord.x, coord.y, coord.z + 1.0, false, false, false, true)
        end

        SetPedToRagdoll(ped, 1000, 1000, 0, false, false, false)

    else
        TriggerEvent("chat:addMessage", {
            args = { "^3ADMIN", "Aucun GPS actif (waypoint requis)" }
        })
    end
end)

RegisterNetEvent("admin:car:client", function(model)
    local modelHash = GetHashKey(model)

    if not IsModelInCdimage(modelHash) or not IsModelAVehicle(modelHash) then
        TriggerEvent("chat:addMessage", {
            args = { "^3ADMIN", "Modèle invalide" }
        })
        return
    end

    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Wait(0)
    end

    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)

    local vehicle = CreateVehicle(modelHash, coords.x, coords.y, coords.z, true, false)
    SetPedIntoVehicle(playerPed, vehicle, -1)
    SetModelAsNoLongerNeeded(modelHash)
end)