-- Récupération correcte de la configuration
local Config = exports.union:GetConfig()
local spawnInProgress = false
local spawnAttempts = 0
local fallbackTriggered = false

-- Lancer le spawn après chargement complet
CreateThread(function()
    -- 1. Attente du réseau actif
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(500)
        print("^6[SPAWN] En attente de NetworkIsPlayerActive...")
    end

    print("^6[SPAWN] Network actif. Attente du ped valide...")

    -- 2. Attente que le ped existe
    while not DoesEntityExist(PlayerPedId()) do
        Wait(500)
        print("^6[SPAWN] En attente du Ped...")
    end

    -- 3. Charger une position de collision "sûre"
    local safeCoords = vector3(-268.5, -957.8, 31.2) -- coordonnée fiable en ville
    RequestCollisionAtCoord(safeCoords.x, safeCoords.y, safeCoords.z)

    print("^6[SPAWN] Chargement de la collision autour d'une position sûre...")

    local maxWait = 10000 -- 10s de timeout au cas où
    local timer = 0
    while not HasCollisionLoadedAroundEntity(PlayerPedId()) and timer < maxWait do
        Wait(500)
        timer += 500
    end

    if timer >= maxWait then
        print("^1[SPAWN] Avertissement : Collision non totalement chargée après 10s.")
    else
        print("^6[SPAWN] Collision chargée. Fermeture de l'écran de chargement...")
    end

    TriggerServerEvent("spawn:server:requestInitialSpawn")

    
    -- 4. Shutdown écran de chargement SEULEMENT maintenant
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()

    -- 5. Petit délai pour transition visuelle
    Wait(1000)

    print("^6[SPAWN] Écran fermé. Déclenchement de spawn:server:requestInitialSpawn")

    if Config.debugMode then
        print("^3[SPAWN] Debug actif. Déclenchement du spawn initial")
    end

    DoScreenFadeIn(500)

end)

-- Appliquer le modèle et la position
RegisterNetEvent("spawn:client:applyCharacter")
AddEventHandler("spawn:client:applyCharacter", function(model, position, heading, outfitStyle)
    spawnInProgress = true
    spawnAttempts = spawnAttempts + 1

    print("^6[MODEL] Tentative de spawn #" .. spawnAttempts)
    print("^6[MODEL] Modèle reçu:", model)
    print("^6[MODEL] Position:", position.x, position.y, position.z)
    print("^6[MODEL] Heading:", heading)
    print("^6[MODEL] Style de tenue:", outfitStyle)

    -- Validation du modèle
    if not IsModelValid(GetHashKey(model)) then
        print("^1[ERROR] Modèle non valide:", model)
        fallbackTriggered = true
        TriggerServerEvent("spawn:server:reportError", "MODEL_INVALID")
        return
    end

    print("^6[MODEL] Modèle valide. Chargement...")

    -- Demande de chargement du modèle avec timeout
    RequestModel(GetHashKey(model))
    local startTime = GetGameTimer()
    
    while not HasModelLoaded(GetHashKey(model)) do
        Wait(50)
        if GetGameTimer() - startTime > Config.timeouts.modelLoad then
            print("^1[ERROR] Échec du chargement du modèle:", model)
            fallbackTriggered = true
            TriggerServerEvent("spawn:server:reportError", "MODEL_LOAD_FAILED")
            return
        end
    end

    print("^6[MODEL] Modèle chargé avec succès. Application...")

    -- Application du modèle au joueur
    SetPlayerModel(PlayerId(), GetHashKey(model))
    SetModelAsNoLongerNeeded(GetHashKey(model))

    local ped = PlayerPedId()

    -- Réinitialisation des vêtements et apparence de base
    print("^6[CLOTHES] Application des vêtements par défaut...")
    SetDefaultClothes(ped)
    SetPedDefaultComponentVariation(ped)

    -- Placement du joueur dans le monde
    print("^6[POS] Résurrection et placement du joueur...")
    NetworkResurrectLocalPlayer(position.x, position.y, position.z, heading or Config.heading, true, true)
    SetEntityCoordsNoOffset(ped, position.x, position.y, position.z, false, false, false, true)
    SetEntityHeading(ped, heading or Config.heading)

    -- Paramètres supplémentaires du joueur
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    SetPlayerInvincible(PlayerId(), false)

    -- Application de la santé et armure
    print("^6[HEALTH] Application de la santé et armure...")
    SetEntityHealth(ped, Config.defaultHealth)
    SetPedArmour(ped, Config.defaultArmor)

    -- Contrôles temporairement désactivés pour éviter les actions involontaires
    DisableControlAction(0, 24, true)
    DisableControlAction(0, 25, true)
    Wait(500)
    EnableAllControlActions(0)

    -- Debug de position
    if Config.debugMode then
        print("^5[POS] Position appliquée:", position.x, position.y, position.z, "heading:", heading)
    end

    -- Affichage d'un blip temporaire sur la carte
    if Config.showSpawnBlip then
        print("^6[BLIP] Affichage d'un blip temporaire au point de spawn.")
        local blip = AddBlipForCoord(position.x, position.y, position.z)
        SetBlipSprite(blip, 1)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 1.0)
        SetBlipColour(blip, 2)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Spawn Point")
        EndTextCommandSetBlipName(blip)
        SetTimeout(Config.blipDuration, function()
            RemoveBlip(blip)
            print("^6[BLIP] Blip supprimé après délai.")
        end)
    end
    
    -- Application de la tenue
    print("^6[CLOTHES] Application de la tenue...")
    SetDefaultClothes(ped)
    TriggerEvent("spawn:client:setOutfit", outfitStyle)

    -- Confirmation du spawn au serveur et sauvegarde de la position
    print("^6[SERVER] Confirmation du spawn et sauvegarde de la position.")
    fallbackTriggered = false
    TriggerServerEvent("spawn:server:confirmComplete")
    TriggerServerEvent("spawn:server:savePosition", position, heading)
end)

RegisterNetEvent("spawn:client:prepareSpawn")
AddEventHandler("spawn:client:prepareSpawn", function()
    print("^6[SPAWN] Préparation du spawn...")
    DoScreenFadeOut(500)
    Wait(750) -- Assurer que l'écran est bien noir avant de continuer
end)

RegisterNetEvent("spawn:client:setOutfit")
AddEventHandler("spawn:client:setOutfit", function(outfitStyle)
    local ped = PlayerPedId()
    local model = GetEntityModel(ped)
    local outfitData

    print("^6[CLOTHES] Chargement de la tenue pour le modèle: " .. model)

    if model == GetHashKey(Config.defaultModel) then
        outfitData = Config.outfits.male[outfitStyle]
    elseif model == GetHashKey(Config.femaleModel) then
        outfitData = Config.outfits.female[outfitStyle]
    end

    if not outfitData then
        print("^1[ERROR] Tenue introuvable pour le style:", tostring(outfitStyle))
        return
    end

    for componentId, data in pairs(outfitData) do
        SetPedComponentVariation(ped, componentId, data[1], data[2], data[3] or 2)
    end

    print("^6[CLOTHES] Tenue appliquée avec succès:", outfitStyle)
end)

RegisterNetEvent("spawn:client:confirmed")
AddEventHandler("spawn:client:confirmed", function()
    if Config.debugMode then
        print("^2[SPAWN] Spawn confirmé par le serveur")
    end
    spawnInProgress = false
    spawnAttempts = 0

    -- Apparition progressive
    DoScreenFadeIn(500)

    -- Animation d'arrivée
    local ped = PlayerPedId()
    if not IsEntityDead(ped) then
        print("^6[ANIM] Lecture animation de spawn...")
        LoadAnimDict("amb@world_human_stand_mobile@male@text@base")
        TaskPlayAnim(ped, "amb@world_human_stand_mobile@male@text@base", "base", 8.0, -8.0, -1, 0, 0, false, false, false)
        Wait(1000)
        StopAnimTask(ped, "amb@world_human_stand_mobile@male@text@base", "base", 1.0)
    end

    -- Notification du spawn complet
    print("^2[SPAWN] Joueur entièrement chargé. Événement playerSpawned émis.")
    TriggerEvent("playerSpawned")
end)

-- Fonction utilitaire pour réinitialiser les vêtements
function SetDefaultClothes(ped)
    for i = 0, 11 do
        SetPedComponentVariation(ped, i, 0, 0, 1)
    end
    for i = 0, 7 do
        ClearPedProp(ped, i)
    end
end

-- Chargement d'un dictionnaire d'animation
function LoadAnimDict(dict)
    RequestAnimDict(dict)
    local startTime = GetGameTimer()
    while not HasAnimDictLoaded(dict) do
        Wait(10)
        if GetGameTimer() - startTime > 5000 then -- 5 secondes max
            print("^1[ERROR] Échec du chargement du dictionnaire d'animation:", dict)
            break
        end
    end
end

-- Demande de respawn
RegisterNetEvent("spawn:respawn")
AddEventHandler("spawn:respawn", function()
    print("^3[SPAWN] Respawn demandé")

    spawnInProgress = false
    spawnAttempts = 0
    fallbackTriggered = false

    DoScreenFadeOut(500)
    Wait(500)

    TriggerServerEvent("spawn:server:requestRespawn")
end)

-- Mise à jour de la tenue
RegisterNetEvent("spawn:client:updateOutfit")
AddEventHandler("spawn:client:updateOutfit", function(outfitStyle)
    print("^6[CLOTHES] Mise à jour de la tenue demandée:", outfitStyle)
    TriggerEvent("spawn:client:setOutfit", outfitStyle)
end)

-- Affichage d'une notification
RegisterNetEvent("spawn:client:notification")
AddEventHandler("spawn:client:notification", function(msg)
    print("^6[NOTIFY] " .. msg)
    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandThefeedPostTicker(true, true)
end)

-- Force la fermeture de l'écran de chargement
RegisterNetEvent("spawn:client:forceCloseLoadingScreen")
AddEventHandler("spawn:client:forceCloseLoadingScreen", function()
    print("^3[SPAWN] Fermeture forcée de l'écran de chargement")
    DoScreenFadeIn(500)
    Wait(250)
    TriggerEvent("spawn:respawn") -- Tentative de respawn après fermeture
end)

-- Sauvegarde automatique de la position du joueur
CreateThread(function()
    while true do
        Wait(60000) -- Sauvegarde toutes les minutes
        if not spawnInProgress then
            local ped = PlayerPedId()
            if DoesEntityExist(ped) and not IsEntityDead(ped) then
                local coords = GetEntityCoords(ped)
                local heading = GetEntityHeading(ped)
                print("^6[POS] Sauvegarde automatique de la position...")
                TriggerServerEvent("spawn:server:savePosition", coords, heading)
            end
        end
    end
end)

-- Détection de blocage de spawn
CreateThread(function()
    while true do
        Wait(1000)
        if spawnInProgress and spawnAttempts > Config.retries.spawn then
            print("^1[ERROR] Blocage détecté. Respawn forcé...")
            spawnInProgress = false
            spawnAttempts = 0
            fallbackTriggered = true
            TriggerServerEvent("spawn:server:reportError", "SPAWN_BLOCKED")
        end
    end
end)

-- -- Vérification de visibilité du joueur
-- CreateThread(function()
--     while true do
--         Wait(2000)
--         if not spawnInProgress and not fallbackTriggered then
--             local ped = PlayerPedId()
--             if DoesEntityExist(ped) and not IsEntityVisible(ped) and not IsEntityDead(ped) and not IsScreenFadedOut() then
--                 print("^1[ERROR] Joueur invisible. Tentative de correction...")
--                 SetEntityVisible(ped, true, false)
--                 Wait(100)
--                 if not IsEntityVisible(ped) then
--                     print("^1[ERROR] Échec de la correction de visibilité. Respawn forcé...")
--                     TriggerEvent("spawn:respawn")
--                 end
--             end
--         end
--     end
-- end)