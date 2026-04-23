-- client/modules/spawn/main.lua
-- FIX invisibilité : après SetPlayerModel() le ped change d'entité.
--   Il faut rappeler PlayerPedId() à chaque étape critique et ne jamais
--   réutiliser une variable ped périmée.
-- FIX GetPlayerFromId nil : on retarde union:spawn:confirm pour laisser
--   le serveur finaliser currentCharacter avant que kt_inventory l'appelle.

Spawn = {}
local logger = Logger:child("SPAWN")

function Spawn.initialize()
    logger:info("Initializing spawn system")
    TriggerServerEvent("union:spawn:requestInitial")
end

function Spawn.respawn(model)
    logger:info("Requesting respawn with model: " .. (model or "default"))
    TriggerServerEvent("union:spawn:requestRespawn", model)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- EVENT : union:spawn:apply
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RegisterNetEvent("union:spawn:apply", function(characterData)
    if not characterData then
        logger:error("union:spawn:apply: characterData nil")
        return
    end

    local model = characterData.model
    if not model or model == "" then
        logger:error("union:spawn:apply: model manquant")
        return
    end

    logger:info("Applying character model: " .. model)

    Citizen.CreateThread(function()

        -- ── 1. Charger le modèle ──────────────────────────────────────
        local modelHash = GetHashKey(model)

        if not IsModelValid(modelHash) then
            logger:error("Invalid model: " .. model)
            TriggerServerEvent("union:spawn:error", "MODEL_INVALID")
            return
        end

        RequestModel(modelHash)
        local t = GetGameTimer()
        while not HasModelLoaded(modelHash) do
            Wait(50)
            if GetGameTimer() - t > 10000 then
                logger:error("Timeout chargement modèle: " .. model)
                TriggerServerEvent("union:spawn:error", "MODEL_LOAD_FAILED")
                return
            end
        end

        -- ── 2. Appliquer le modèle ────────────────────────────────────
        -- IMPORTANT : après SetPlayerModel le ped change d'handle.
        -- On récupère le nouveau ped immédiatement après.
        SetPlayerModel(PlayerId(), modelHash)
        SetModelAsNoLongerNeeded(modelHash)

        -- Attendre que le moteur crée le nouveau ped (1 frame suffit)
        Wait(0)
        local ped = PlayerPedId()

        -- ── 3. Rendre visible immédiatement ──────────────────────────
        -- C'est ici qu'on était invisible : l'ancienne variable ped
        -- pointait vers l'ancien ped. On appelle SetEntityVisible
        -- sur le NOUVEAU ped tout de suite.
        SetEntityVisible(ped, true, false)
        SetEntityAlpha(ped, 255, false)

        -- ── 4. Position et résurrection ───────────────────────────────
        local pos     = characterData.position or Config.spawn.defaultPosition
        local heading = characterData.heading  or Config.spawn.defaultHeading
        local health  = characterData.health   or Config.character.defaultHealth
        local armor   = characterData.armor    or 0

        -- Charger les collisions à la position cible
        RequestCollisionAtCoord(pos.x, pos.y, pos.z)
        local collTimeout = GetGameTimer() + 5000
        while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < collTimeout do
            Wait(0)
        end

        -- Ressusciter et positionner
        NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, heading, true, true)
        Wait(150)

        -- Rafraîchir le ped après résurrection (peut changer à nouveau)
        ped = PlayerPedId()

        SetEntityHeading(ped, heading)
        SetEntityHealth(ped, health)
        SetPedArmour(ped, armor)
        SetEntityVisible(ped, true, false)   -- re-confirmer la visibilité
        SetEntityAlpha(ped, 255, false)
        ClearPedTasksImmediately(ped)
        FreezeEntityPosition(ped, false)

        -- ── 5. Supprimer le ped offline local ────────────────────────
        if OfflinePeds and characterData.unique_id then
            local offlinePed = OfflinePeds[characterData.unique_id]
            if offlinePed and DoesEntityExist(offlinePed) then
                SetEntityAsMissionEntity(offlinePed, false, true)
                DeleteEntity(offlinePed)
                OfflinePeds[characterData.unique_id] = nil
            end
        end

        -- ── 6. Apparence ─────────────────────────────────────────────
        if ApplyFullAppearance then
            Wait(200)
            -- Rafraîchir encore (ApplyFullAppearance peut spawner un nouveau ped)
            ped = PlayerPedId()
            ApplyFullAppearance(characterData)
        else
            logger:warn("ApplyFullAppearance non disponible")
        end

        -- Dernière confirmation de visibilité après apparence
        Wait(50)
        ped = PlayerPedId()
        SetEntityVisible(ped, true, false)
        SetEntityAlpha(ped, 255, false)

        -- ── 7. Stocker le personnage courant ─────────────────────────
        Client.currentCharacter = characterData

        logger:info("Character spawned successfully")

        -- ── 8. Confirmer au serveur ───────────────────────────────────
        -- FIX GetPlayerFromId nil : on attend 1 frame supplémentaire
        -- pour que le serveur ait bien fini Character.select() et
        -- mis à jour player.currentCharacter avant que kt_inventory
        -- tente de le lire via union:player:spawned.
        Wait(100)
        TriggerServerEvent("union:spawn:confirm")

        -- ── 9. Animation de réveil ────────────────────────────────────
        Wait(300)
        if OfflinePeds and OfflinePeds.playWakeUpAnim then
            OfflinePeds.playWakeUpAnim(PlayerPedId())
        end
    end)
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- EVENT : union:spawn:error
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RegisterNetEvent("union:spawn:error", function(errorType)
    logger:error("Spawn error: " .. tostring(errorType))
    Spawn.respawn(Config.spawn.defaultModel)
end)