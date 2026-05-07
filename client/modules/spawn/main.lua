-- client/modules/spawn/main.lua
-- FIX SP-1 : charData.model → charData.ped_model (colonne réelle côté serveur).
-- FIX SP-2 : position reçue comme table { x, y, z } (plus vector3 brut).
-- FIX SP-3 : guard spawnInProgress par session.

Spawn = {}
local logger = Logger:child("SPAWN")

local function SafePed()
    local ped = PlayerPedId()
    SetEntityVisible(ped, true, false)
    SetEntityAlpha(ped, 255, false)
    return ped
end

function Spawn.initialize()
    logger:info("Initialisation du système de spawn")
    TriggerServerEvent("union:spawn:requestInitial")
end

function Spawn.respawn(model)
    logger:info("Demande de respawn avec modèle : " .. (model or "default"))
    TriggerServerEvent("union:spawn:requestRespawn", model)
end

local spawnInProgress    = false
local currentSpawnSession = 0

local function resetSpawnGuard()
    spawnInProgress = false
end

local function startSpawnTimeout(seconds, sessionId)
    CreateThread(function()
        local limit = GetGameTimer() + (seconds * 1000)
        while GetGameTimer() < limit do
            Wait(500)
            if currentSpawnSession ~= sessionId then return end
        end
        if currentSpawnSession == sessionId and spawnInProgress then
            logger:warn(("Spawn timeout (%ds) — réinitialisation du guard [session %d]"):format(seconds, sessionId))
            resetSpawnGuard()
        end
    end)
end

RegisterNetEvent("union:spawn:apply", function(characterData)
    if not characterData then
        logger:error("characterData nil")
        return
    end

    if spawnInProgress then
        logger:warn("Spawn déjà en cours — événement dupliqué ignoré")
        return
    end
    spawnInProgress = true

    currentSpawnSession = currentSpawnSession + 1
    local mySession = currentSpawnSession
    startSpawnTimeout(30, mySession)

    -- FIX SP-1 : le serveur envoie ped_model (colonne réelle), plus "model"
    local model = characterData.ped_model
    if not model or model == "" then
        logger:error("ped_model manquant dans characterData")
        resetSpawnGuard()
        return
    end

    logger:info("Application du modèle personnage : " .. model)

    Citizen.CreateThread(function()

        -- ── 1. LOAD MODEL ─────────────────────────────
        local modelHash = GetHashKey(model)

        if not IsModelInCdimage(modelHash) or not IsModelValid(modelHash) then
            logger:error("Modèle invalide : " .. model)
            TriggerServerEvent("union:spawn:error", "MODEL_INVALID")
            resetSpawnGuard()
            return
        end

        RequestModel(modelHash)
        local timeout = GetGameTimer() + 8000
        while not HasModelLoaded(modelHash) do
            Wait(0)
            if GetGameTimer() > timeout then
                logger:error("Timeout chargement modèle : " .. model)
                TriggerServerEvent("union:spawn:error", "MODEL_LOAD_FAILED")
                resetSpawnGuard()
                return
            end
            if currentSpawnSession ~= mySession then
                logger:warn("Session spawn invalidée pendant chargement modèle")
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
        -- FIX SP-2 : position peut être une table { x, y, z } ou vector3
        local rawPos  = characterData.position or Config.spawn.defaultPosition
        local posX    = rawPos.x or Config.spawn.defaultPosition.x
        local posY    = rawPos.y or Config.spawn.defaultPosition.y
        local posZ    = rawPos.z or Config.spawn.defaultPosition.z
        local heading = characterData.heading or Config.spawn.defaultHeading
        local health  = characterData.health  or Config.character.defaultHealth
        local armor   = characterData.armor   or 0

        -- ── 4. APPARENCE via Bridge ───────────────────
        Bridge.Character.applyAppearance(characterData)

        -- ── 5. COLLISION + RESPAWN ───────────────────
        RequestCollisionAtCoord(posX, posY, posZ)
        local collTimeout = GetGameTimer() + 6000
        while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < collTimeout do
            Wait(50)
        end

        NetworkResurrectLocalPlayer(posX, posY, posZ, heading, true, true)
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
        resetSpawnGuard()

        -- ── 9. SERVER CONFIRM ─────────────────────────
        TriggerServerEvent("union:spawn:confirm", characterData.unique_id)

        -- ── 10. EVENT LOCAL (HUD, Target, etc.) ───────
        TriggerEvent("union:player:spawned", characterData)
    end)
end)

RegisterNetEvent("union:spawn:error", function(errorType)
    logger:error("Erreur spawn : " .. tostring(errorType))
    resetSpawnGuard()
    Spawn.respawn(Config.spawn.defaultModel)
end)
