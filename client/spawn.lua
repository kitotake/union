-- client/spawn.lua
Spawn = {}  -- Global, accessible dans main.lua

function Spawn.initialize()
    TriggerServerEvent("spawn:server:requestInitialSpawn")
end

RegisterNetEvent("spawn:client:applyCharacter", function(model, pos, heading, outfitStyle)
    if (pos.x == 0 and pos.y == 0 and pos.z == 0) and Position.lastSaved then
        pos = Position.lastSavedPos
        heading = Position.lastSavedHeading
        Utils.log("SPAWN", "Utilisation de la dernière position sauvegardée.")
    end

    local modelHash = GetHashKey(model)
    if not IsModelValid(modelHash) then
        Utils.log("ERROR", "Modèle invalide : " .. model)
        return
    end

    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do Wait(50) end

    RequestCollisionAtCoord(pos.x, pos.y, pos.z)
    while not HasCollisionLoadedAroundEntity(PlayerPedId()) do Wait(50) end

    SetPlayerModel(PlayerId(), modelHash)
    SetModelAsNoLongerNeeded(modelHash)

    local ped = PlayerPedId()
    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, heading, true, true)
    SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false, true)
    SetEntityHeading(ped, heading)
    SetEntityVisible(ped, true, false)

    Position.save(pos, heading)
    TriggerServerEvent("spawn:server:confirmComplete")
end)
