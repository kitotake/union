-- client/modules/spawn/main.lua
-- FIXES:
--   #1 : clearTimeout() n'existe pas en Lua FiveM (c'est du JS).
--        Remplacé par un flag booléen + thread de timeout manuel.
--   #2 : unique_id transmis dans union:spawn:confirm.

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

local spawnInProgress  = false
local spawnTimeoutActive = false

-- FIX #1 : reset du guard sans clearTimeout
local function resetSpawnGuard()
    spawnInProgress      = false
    spawnTimeoutActive   = false
end

-- FIX #1 : timeout manuel via thread Lua
local function startSpawnTimeout(seconds)
    spawnTimeoutActive = true
    CreateThread(function()
        local limit = GetGameTimer() + (seconds * 1000)
        while spawnTimeoutActive do
            Wait(500)
            if GetGameTimer() > limit then
                if spawnInProgress then
                    logger:warn("Spawn timeout (" .. seconds .. "s) — réinitialisation du guard")
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
        logger:warn("Spawn already in progress — ignoring duplicate event")
        return
    end
    spawnInProgress = true

    -- FIX #1 : timeout de sécurité 30s via thread Lua
    startSpawnTimeout(30)

    local model = characterData.model
    if not model or model == "" then
        logger:error("model manquant dans characterData")
        resetSpawnGuard()
        return
    end

    logger:info("Applying character model: " .. model)

    Citizen.CreateThread(function()

        -- ── 1. LOAD MODEL ─────────────────────────────
        local modelHash = GetHashKey(model)

        if not IsModelInCdimage(modelHash) or not IsModelValid(modelHash) then
            logger:error("Invalid model: " .. model)
            TriggerServerEvent("union:spawn:error", "MODEL_INVALID")
            resetSpawnGuard()
            return
        end

        RequestModel(modelHash)
        local timeout = GetGameTimer() + 8000
        while not HasModelLoaded(modelHash) do
            Wait(0)
            if GetGameTimer() > timeout then
                logger:error("Timeout model: " .. model)
                TriggerServerEvent("union:spawn:error", "MODEL_LOAD_FAILED")
                resetSpawnGuard()
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
        Bridge.Character.applyAppearance(characterData)

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

        logger:info("Character spawned successfully")
        resetSpawnGuard()

        -- ── 9. SERVER CONFIRM ─────────────────────────
        -- FIX #2 : unique_id transmis pour identification côté serveur
        TriggerServerEvent("union:spawn:confirm", characterData.unique_id)

        -- ── 10. EVENT LOCAL (HUD, Target, etc.) ───────
        TriggerEvent("union:player:spawned", characterData)
    end)
end)

RegisterNetEvent("union:spawn:error", function(errorType)
    logger:error("Spawn error: " .. tostring(errorType))
    resetSpawnGuard()
    Spawn.respawn(Config.spawn.defaultModel)
end)