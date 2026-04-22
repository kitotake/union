-- client/modules/spawn/main.lua
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Gestion du spawn côté client :
--   - Chargement du modèle
--   - Résurrection / positionnement
--   - Application de l'apparence (skin, cheveux, tatouages…)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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
-- Reçu depuis le serveur avec toutes les données du personnage
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
        -- ── 1. Charger le modèle ────────────────────────────────────────
        local modelHash = GetHashKey(model)

        if not IsModelValid(modelHash) then
            logger:error("Invalid model: " .. model)
            TriggerServerEvent("union:spawn:error", "MODEL_INVALID")
            return
        end

        RequestModel(modelHash)
        local startTime = GetGameTimer()
        while not HasModelLoaded(modelHash) and GetGameTimer() - startTime < 10000 do
            Wait(50)
        end

        if not HasModelLoaded(modelHash) then
            logger:error("Failed to load model: " .. model)
            TriggerServerEvent("union:spawn:error", "MODEL_LOAD_FAILED")
            return
        end

        -- ── 2. Appliquer le modèle ──────────────────────────────────────
        SetPlayerModel(PlayerId(), modelHash)
        SetModelAsNoLongerNeeded(modelHash)

        local ped = PlayerPedId()

        -- ── 3. Position et résurrection ─────────────────────────────────
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

        -- Ressusciter et placer le joueur
        NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, heading, true, true)

        Wait(100) -- laisser le moteur appliquer la position

        ped = PlayerPedId()
        SetEntityHeading(ped, heading)
        SetEntityHealth(ped, health)
        SetPedArmour(ped, armor)
        SetEntityVisible(ped, true, false)
        ClearPedTasksImmediately(ped)
        FreezeEntityPosition(ped, false)

        -- ── 4. Appliquer l'apparence (skin complet) ─────────────────────
        -- ApplyFullAppearance est défini dans kt_character/client/appearance.lua
        -- et disponible globalement dans l'espace de noms partagé
        if ApplyFullAppearance then
            Wait(200) -- petit délai pour que le modèle soit pleinement initialisé
            ApplyFullAppearance(characterData)
        else
            logger:warn("ApplyFullAppearance non disponible — apparence non appliquée")
        end

        -- ── 5. Stocker le personnage courant ────────────────────────────
        Client.currentCharacter = characterData

        logger:info("Character spawned successfully")

        -- ── 6. Confirmer le spawn au serveur ────────────────────────────
        TriggerServerEvent("union:spawn:confirm")
    end)
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- EVENT : union:spawn:error
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RegisterNetEvent("union:spawn:error", function(errorType)
    logger:error("Spawn error: " .. tostring(errorType))
    -- Tenter un respawn avec le modèle par défaut
    Spawn.respawn(Config.spawn.defaultModel)
end)