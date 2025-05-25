Spawn = {}

function Spawn.initialize()
    print("^2[SPAWN] Initialisation du système de spawn")
    TriggerServerEvent("spawn:server:requestInitialSpawn")
end

RegisterNetEvent("spawn:client:applyCharacter", function(model, pos, heading, outfitStyle)
    print("^2[SPAWN] Application du personnage: " .. model)
    
    -- Vérifier si on a une position sauvegardée
    if Position and Position.getLast then
        local lastPos, lastHeading, hasSaved = Position.getLast()
        if hasSaved and lastPos then
            pos = lastPos
            heading = lastHeading or heading
            print("^3[SPAWN] Utilisation position sauvegardée")
        end
    end
    
    local modelHash = GetHashKey(model)
    if not IsModelValid(modelHash) then
        print("^1[SPAWN] Modèle invalide: " .. model)
        return
    end
    
    -- Charger le modèle
    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 100 do
        Wait(50)
        timeout = timeout + 1
    end
    
    if not HasModelLoaded(modelHash) then
        print("^1[SPAWN] Échec chargement modèle")
        return
    end
    
    -- Charger les collisions
    RequestCollisionAtCoord(pos.x, pos.y, pos.z)
    timeout = 0
    while not HasCollisionLoadedAroundEntity(PlayerPedId()) and timeout < 100 do
        Wait(50)
        timeout = timeout + 1
    end
    
    -- Appliquer le modèle
    SetPlayerModel(PlayerId(), modelHash)
    SetModelAsNoLongerNeeded(modelHash)
    
    -- Positionner le joueur
    local ped = PlayerPedId()
    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, heading, true, true)
    SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false, true)
    SetEntityHeading(ped, heading)
    SetEntityVisible(ped, true, false)
    
    -- Sauvegarder position
    if Position and Position.save then
        Position.save()
    end
    
    print("^2[SPAWN] Personnage spawné avec succès")
    TriggerServerEvent("spawn:server:confirmComplete")
end)