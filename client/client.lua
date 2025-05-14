-- Récupération correcte de la configuration
local Config = exports.union:GetConfig()
local spawnInProgress = false
local spawnAttempts = 0

-- Appliquer le modèle et la position
RegisterNetEvent("spawn:client:applyCharacter")
AddEventHandler("spawn:client:applyCharacter", function(model, position, heading, outfitStyle)
    spawnInProgress = true
    spawnAttempts = spawnAttempts + 1

    if Config.debugMode then
        print("^5[Client] Application du modèle:", model, "tentative:", spawnAttempts)
    end

    -- Vérification que le modèle est valide
    if not IsModelValid(GetHashKey(model)) then
        print("^1[Client] Modèle non valide:", model)
        TriggerServerEvent("spawn:server:reportError", "MODEL_INVALID")
        return
    end

    -- Demande du modèle
    RequestModel(GetHashKey(model))
    local startTime = GetGameTimer()
    while not HasModelLoaded(GetHashKey(model)) do
        Wait(50)
        if GetGameTimer() - startTime > Config.timeouts.modelLoad then
            print("^1[Client] Échec du chargement du modèle")
            TriggerServerEvent("spawn:server:reportError", "MODEL_LOAD_FAILED")
            return
        end
    end

    -- Application du modèle
    SetPlayerModel(PlayerId(), GetHashKey(model))
    SetModelAsNoLongerNeeded(GetHashKey(model))

    -- Récupération du ped après le changement de modèle
    local ped = PlayerPedId()
    
    -- Appliquer les composants par défaut
    SetDefaultClothes(ped)
    SetPedDefaultComponentVariation(ped)
    
    -- S'assurer que le joueur est complètement chargé
    NetworkResurrectLocalPlayer(position.x, position.y, position.z, heading or Config.heading, true, true)
    
    -- Positionnement
    SetEntityCoordsNoOffset(ped, position.x, position.y, position.z, false, false, false, true)
    SetEntityHeading(ped, heading or Config.heading)
    
    -- Réglages supplémentaires
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    SetPlayerInvincible(PlayerId(), false)
    
    -- Santé et armure
    SetEntityHealth(ped, Config.defaultHealth)
    SetPedArmour(ped, Config.defaultArmor)
    
    -- Désactiver les contrôles pendant un court moment
    DisableControlAction(0, 24, true)
    DisableControlAction(0, 25, true)
    Wait(500)
    EnableAllControlActions(0)

    -- Forcer l'écran de chargement à se fermer
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    
    if Config.debugMode then
        print("^5[Client] Position appliquée:", position.x, position.y, position.z, "heading:", heading)
    end

    -- Affichage d'un blip temporaire sur la position
    if Config.showSpawnBlip then
        local blip = AddBlipForCoord(position.x, position.y, position.z)
        SetBlipSprite(blip, 1)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 1.0)
        SetBlipColour(blip, 2)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Spawn Point")
        EndTextCommandSetBlipName(blip)
        
        -- Supprimer le blip après un délai
        SetTimeout(Config.blipDuration, function()
            RemoveBlip(blip)
        end)
    end

    -- Appliquer la tenue par défaut d'abord
    SetDefaultClothes(ped)
    
    -- Puis appliquer la tenue configurée
    TriggerEvent("spawn:client:setOutfit", outfitStyle)
    
    -- Confirmer la fin du processus
    TriggerServerEvent("spawn:server:confirmComplete")
    
    -- Sauvegarder la position actuelle
    TriggerServerEvent("spawn:server:savePosition", position, heading)
end)

-- Définir la tenue
RegisterNetEvent("spawn:client:setOutfit")
AddEventHandler("spawn:client:setOutfit", function(outfitStyle)
    local ped = PlayerPedId()
    local model = GetEntityModel(ped)

    local outfitData
    if model == GetHashKey(Config.defaultModel) then
        outfitData = Config.outfits.male[outfitStyle]
    elseif model == GetHashKey(Config.femaleModel) then
        outfitData = Config.outfits.female[outfitStyle]
    end

    if not outfitData then
        print("^1[Client] Aucune tenue trouvée pour ce style: " .. tostring(outfitStyle))
        return
    end

    for componentId, data in pairs(outfitData) do
        SetPedComponentVariation(ped, componentId, data[1], data[2], data[3] or 2)
    end

    if Config.debugMode then
        print("^5[Client] Tenue appliquée:", outfitStyle)
    end
end)

-- Confirmer le spawn
RegisterNetEvent("spawn:client:confirmed")
AddEventHandler("spawn:client:confirmed", function()
    if Config.debugMode then
        print("^2[Client] Spawn terminé avec succès.")
    end
    spawnInProgress = false
    spawnAttempts = 0
    
    -- S'assurer que le joueur est jouable
    DoScreenFadeIn(500)
    
    -- Animation de réveil
    local ped = PlayerPedId()
    if not IsEntityDead(ped) then
        LoadAnimDict("amb@world_human_stand_mobile@male@text@base")
        TaskPlayAnim(ped, "amb@world_human_stand_mobile@male@text@base", "base", 8.0, -8.0, -1, 0, 0, false, false, false)
        Wait(1000)
        StopAnimTask(ped, "amb@world_human_stand_mobile@male@text@base", "base", 1.0)
    end
    
    -- S'assurer que l'écran de chargement est bien fermé
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    
    -- Émettre un événement pour indiquer que le joueur est complètement chargé
    TriggerEvent("playerSpawned")
end)

---Function for setting default clothes on a ped
---@param ped number Ped ID
function SetDefaultClothes(ped)
    for i = 0, 11 do
        SetPedComponentVariation(ped, i, 0, 0, 1)
    end
    for i = 0, 7 do
        ClearPedProp(ped, i)
    end
end

-- Fonction pour charger les dictionnaires d'animation
function LoadAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

-- Lancer le spawn après chargement
CreateThread(function()
    while not NetworkIsSessionStarted() do
        Wait(100)
    end
    
    -- S'assurer que le joueur est actif dans le réseau
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(100)
    end

    -- S'assurer que l'écran de chargement est fermé
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()

    -- Attendre que le joueur soit complètement chargé
    Wait(2000)
    
    if Config.debugMode then
        print("^3[Client] Joueur actif, envoi de spawn:server:requestInitialSpawn")
    end
    
    -- Forcer une fade-in pour s'assurer que l'écran n'est pas noir
    DoScreenFadeIn(500)
    
    -- Demander le spawn initial
    TriggerServerEvent("spawn:server:requestInitialSpawn")
end)

-- Forcer le respawn
RegisterNetEvent("spawn:respawn")
AddEventHandler("spawn:respawn", function()
    if Config.debugMode then
        print("^3[Client] Demande de respawn")
    end
    
    -- Réinitialisation des compteurs
    spawnInProgress = false
    spawnAttempts = 0
    
    -- Faire un fondu avant de respawn
    DoScreenFadeOut(500)
    Wait(500)
    
    TriggerServerEvent("spawn:server:requestRespawn", Config.defaultModel)
end)

-- Mise à jour de la tenue
RegisterNetEvent("spawn:client:updateOutfit")
AddEventHandler("spawn:client:updateOutfit", function(outfitStyle)
    TriggerEvent("spawn:client:setOutfit", outfitStyle)
end)

-- Notifications (ex: erreurs, infos)
RegisterNetEvent("spawn:client:notification")
AddEventHandler("spawn:client:notification", function(msg)
    print("^6[Notification] " .. msg)
    -- Affichage visuel pour le joueur
    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandThefeedPostTicker(true, true)
end)

-- Sauvegarder la position périodiquement
CreateThread(function()
    while true do
        Wait(60000) -- Toutes les minutes
        
        if not spawnInProgress then
            local ped = PlayerPedId()
            if DoesEntityExist(ped) and not IsEntityDead(ped) then
                local coords = GetEntityCoords(ped)
                local heading = GetEntityHeading(ped)
                
                TriggerServerEvent("spawn:server:savePosition", coords, heading)
            end
        end
    end
end)

-- Monitoring des erreurs
CreateThread(function()
    while true do
        Wait(1000)
        
        -- Vérifier si le joueur est bloqué en état de spawn
        if spawnInProgress and spawnAttempts > Config.retries.spawn then
            print("^1[Client] Détection d'un blocage de spawn, tentative de récupération")
            spawnInProgress = false
            spawnAttempts = 0
            
            -- S'assurer que l'écran de chargement est fermé
            ShutdownLoadingScreen()
            ShutdownLoadingScreenNui()
            
            -- Forcer un fondu
            DoScreenFadeIn(500)
            
            -- Forcer un respawn avec le modèle par défaut
            TriggerServerEvent("spawn:server:requestRespawn", Config.defaultModel)
        end
    end
end)

-- Thread pour s'assurer que l'écran de chargement est fermé
CreateThread(function()
    Wait(10000) -- Attendre 10 secondes après le démarrage
    
    -- Forcer la fermeture de l'écran de chargement s'il est toujours présent
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    DoScreenFadeIn(500)
end)