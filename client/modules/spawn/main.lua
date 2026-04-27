-- client/modules/spawn/main.lua
-- FIX : suppression du double ApplyFullAppearance (était aussi appelé depuis kt_character/client/main.lua)
--       On est maintenant la SEULE source d'application du skin.
--       ApplyFullAppearance est appelé UNE SEULE FOIS, juste après SetPlayerModel.

Spawn = {}
local logger = Logger:child("SPAWN")

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SAFE PED (anti-invisible global)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function SafePed()
    local ped = PlayerPedId()
    SetEntityVisible(ped, true, false)
    SetEntityAlpha(ped, 255, false)
    return ped
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- INIT
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function Spawn.initialize()
    logger:info("Initializing spawn system")
    TriggerServerEvent("union:spawn:requestInitial")
end

function Spawn.respawn(model)
    logger:info("Requesting respawn with model: " .. (model or "default"))
    TriggerServerEvent("union:spawn:requestRespawn", model)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- APPLY SPAWN — point d'entrée unique
-- FIX vitesse : on charge le modèle ET les collisions en parallèle
--               et on applique le skin IMMÉDIATEMENT après SetPlayerModel
--               sans Wait() inutiles.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local spawnInProgress = false   -- guard anti-double-spawn

RegisterNetEvent("union:spawn:apply", function(characterData)
    if not characterData then
        logger:error("characterData nil")
        return
    end

    -- Guard : si un spawn est déjà en cours on l'ignore
    if spawnInProgress then
        logger:warn("Spawn already in progress — ignoring duplicate event")
        return
    end
    spawnInProgress = true

    local model = characterData.model
    if not model or model == "" then
        logger:error("model manquant")
        spawnInProgress = false
        return
    end

    logger:info("Applying character model: " .. model)

    Citizen.CreateThread(function()

        -- ── 1. CHARGER LE MODÈLE ──────────────────────────────────────
        local modelHash = GetHashKey(model)

        if not IsModelInCdimage(modelHash) or not IsModelValid(modelHash) then
            logger:error("Invalid model: " .. model)
            TriggerServerEvent("union:spawn:error", "MODEL_INVALID")
            spawnInProgress = false
            return
        end

        RequestModel(modelHash)

        local timeout = GetGameTimer() + 8000
        while not HasModelLoaded(modelHash) do
            Wait(0)
            if GetGameTimer() > timeout then
                logger:error("Timeout model: " .. model)
                TriggerServerEvent("union:spawn:error", "MODEL_LOAD_FAILED")
                spawnInProgress = false
                return
            end
        end

        -- ── 2. SET MODEL ──────────────────────────────────────────────
        SetPlayerModel(PlayerId(), modelHash)
        SetModelAsNoLongerNeeded(modelHash)

        -- Un seul Wait(0) pour laisser le moteur initialiser le ped
        Wait(0)
        local ped = SafePed()
        FreezeEntityPosition(ped, true)

        -- ── 3. DONNÉES POSITION / STATS ───────────────────────────────
        local pos     = characterData.position or Config.spawn.defaultPosition
        local heading = characterData.heading  or Config.spawn.defaultHeading
        local health  = characterData.health   or Config.character.defaultHealth
        local armor   = characterData.armor    or 0

        -- ── 4. APPLIQUER L'APPARENCE IMMÉDIATEMENT ────────────────────
        -- FIX VITESSE : on applique le skin AVANT NetworkResurrect
        --               pour éviter le flash "skin de base" visible
        if ApplyFullAppearance then
            ApplyFullAppearance(characterData)
         else
            logger:warn("ApplyFullAppearance non disponible")
            print("WARNING: ApplyFullAppearance function not found! Character may appear with default skin.")
            
              -- DEBUG : appliquer un skin par défaut pour éviter de etre invisible
                local defaultModel = "a_m_m_skater_01"
             RequestModel(GetHashKey(defaultModel))
             print("DEBUG: Loading default model for fallback skin: " .. defaultModel)
             while not HasModelLoaded(GetHashKey(defaultModel)) do Wait(0) end
             SetPlayerModel(PlayerId(), GetHashKey(defaultModel))
             SetModelAsNoLongerNeeded(GetHashKey(defaultModel))
             print("ERROR: ApplyFullAppearance function not found start default model.")
        end

        -- ── 5. COLLISION + RESPAWN ────────────────────────────────────
        RequestCollisionAtCoord(pos.x, pos.y, pos.z)

        local collTimeout = GetGameTimer() + 6000
        while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < collTimeout do
            Wait(50)
        end

        NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, heading, true, true)
        Wait(0)

        ped = SafePed()
        SetEntityHealth(ped, health)
        SetPedArmour(ped, armor)
        SetEntityHeading(ped, heading)
        ClearPedTasksImmediately(ped)

        -- ── 6. SUPPRIMER LE PED OFFLINE ───────────────────────────────
        if OfflinePeds and OfflinePeds.list and characterData.unique_id then
            local offlinePed = OfflinePeds.list[characterData.unique_id]
            if offlinePed and DoesEntityExist(offlinePed) then
                DeleteEntity(offlinePed)
                OfflinePeds.list[characterData.unique_id] = nil
            end
        end

        -- ── 7. FIX INVISIBLE FINAL ────────────────────────────────────
        SetEntityVisible(ped, true, false)
        SetEntityAlpha(ped, 255, false)
        FreezeEntityPosition(ped, false)

        -- ── 8. STOCKER LE PERSONNAGE ──────────────────────────────────
        Client.currentCharacter = characterData

        logger:info("Character spawned successfully")
        spawnInProgress = false

        -- ── 9. CONFIRMER AU SERVEUR ───────────────────────────────────
        TriggerServerEvent("union:spawn:confirm", characterData.unique_id)
    end)
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ERROR
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RegisterNetEvent("union:spawn:error", function(errorType)
    logger:error("Spawn error: " .. tostring(errorType))
    spawnInProgress = false
    Spawn.respawn(Config.spawn.defaultModel)
end)