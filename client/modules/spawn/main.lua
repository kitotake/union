-- client/modules/spawn/main.lua
-- FIXES:
--   #1 : spawnInProgress reset dans tous les chemins d'erreur, y compris
--        si union:spawn:error arrive après une coupure réseau partielle.
--   #2 : resetSpawnGuard() appelé explicitement si le modèle est invalide
--        ET que TriggerServerEvent échoue (pas de réponse serveur).
--   #3 : Timeout de sécurité réduit à 20s (30s était trop long pour l'UX)
--        et le reset est garanti même si aucun event serveur ne répond.

Spawn = {}
local logger = Logger:child("SPAWN")

local function SafePed()
    local ped = PlayerPedId()
    SetEntityVisible(ped, true, false)
    SetEntityAlpha(ped, 255, false)
    return ped
end

function Spawn.initialize()
    logger:info("Initializing spawn system")
    TriggerServerEvent("union:spawn:requestInitial")
end

function Spawn.respawn(model)
    logger:info("Requesting respawn with model: " .. (model or "default"))
    TriggerServerEvent("union:spawn:requestRespawn", model)
end

local spawnInProgress    = false
local spawnTimeoutActive = false

local function resetSpawnGuard()
    spawnInProgress      = false
    spawnTimeoutActive   = false
end

-- FIX #3 : timeout réduit à 20s
local function startSpawnTimeout(seconds)
    seconds = seconds or 20
    spawnTimeoutActive = true
    CreateThread(function()
        local limit = GetGameTimer() + (seconds * 1000)
        while spawnTimeoutActive do
            Wait(500)
            if GetGameTimer() > limit then
                if spawnInProgress then
                    logger:warn(("Spawn timeout (%ds) — reset du guard"):format(seconds))
                    resetSpawnGuard()
                end
                return
            end
        end
    end)
end

RegisterNetEvent("union:spawn:apply", function(characterData)
    if not characterData then
        logger:error("characterData nil")
        return
    end

    if spawnInProgress then
        logger:warn("Spawn déjà en cours — event ignoré")
        return
    end
    spawnInProgress = true
    startSpawnTimeout(20)

    local model = characterData.model
    if not model or model == "" then
        logger:error("model manquant dans characterData")
        -- FIX #1 : reset avant d'envoyer l'event serveur (pas de réponse garantie)
        resetSpawnGuard()
        TriggerServerEvent("union:spawn:error", "MODEL_MISSING")
        return
    end

    logger:info("Applying character model: " .. model)

    Citizen.CreateThread(function()

        -- ── 1. LOAD MODEL ─────────────────────────────
        local modelHash = GetHashKey(model)

        if not IsModelInCdimage(modelHash) or not IsModelValid(modelHash) then
            logger:error("Modèle invalide: " .. model)
            -- FIX #1 : reset garanti avant l'event serveur
            resetSpawnGuard()
            TriggerServerEvent("union:spawn:error", "MODEL_INVALID")
            return
        end

        RequestModel(modelHash)
        local timeout = GetGameTimer() + 8000
        while not HasModelLoaded(modelHash) do
            Wait(0)
            if GetGameTimer() > timeout then
                logger:error("Timeout chargement modèle: " .. model)
                resetSpawnGuard()
                TriggerServerEvent("union:spawn:error", "MODEL_LOAD_FAILED")
                return
            end
        end

        -- ── 2. SET MODEL ──────────────────────────────
        SetPlayerModel(PlayerId(), modelHash)
        SetModelAsNoLongerNeeded(modelHash)

        Wait(0)
        local ped = SafePed()
        FreezeEntityPosition(ped, true)

        -- ── 3. DATA ───────────────────────────────────
        local pos     = characterData.position or Config.spawn.defaultPosition
        local heading = characterData.heading  or Config.spawn.defaultHeading
        local health  = characterData.health   or Config.character.defaultHealth
        local armor   = characterData.armor    or 0

        -- ── 4. APPARENCE via Bridge ───────────────────
        local ok, err = pcall(Bridge.Character.applyAppearance, characterData)
        if not ok then
            logger:warn("applyAppearance erreur (non bloquant): " .. tostring(err))
        end

        -- ── 5. COLLISION + RESPAWN ───────────────────
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

        -- ── 6. OFFLINE PED CLEAN ──────────────────────
        if OfflinePeds and OfflinePeds.list and characterData.unique_id then
            local offlinePed = OfflinePeds.list[characterData.unique_id]
            if offlinePed and DoesEntityExist(offlinePed) then
                DeleteEntity(offlinePed)
                OfflinePeds.list[characterData.unique_id] = nil
            end
        end

        -- ── 7. FINAL FIX VISIBILITY ───────────────────
        SetEntityVisible(ped, true, false)
        SetEntityAlpha(ped, 255, false)
        FreezeEntityPosition(ped, false)

        -- ── 8. STORE CHARACTER ────────────────────────
        Client.currentCharacter = characterData

        logger:info("Personnage spawné avec succès")

        -- FIX #1 : reset AVANT le confirm serveur
        resetSpawnGuard()

        -- ── 9. SERVER CONFIRM ─────────────────────────
        TriggerServerEvent("union:spawn:confirm", characterData.unique_id)

        -- ── 10. EVENT LOCAL ───────────────────────────
        TriggerEvent("union:player:spawned", characterData)
    end)
end)

-- FIX #1 : reset garanti sur erreur serveur
RegisterNetEvent("union:spawn:error", function(errorType)
    logger:error("Spawn error: " .. tostring(errorType))
    resetSpawnGuard()
    -- Attendre un peu avant de retenter pour éviter une boucle infinie
    SetTimeout(2000, function()
        Spawn.respawn(Config.spawn.defaultModel)
    end)
end)
