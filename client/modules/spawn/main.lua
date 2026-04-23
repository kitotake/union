-- client/modules/spawn/main.lua
-- FIX #14 : OfflinePeds[unique_id] corrigé en OfflinePeds.list[unique_id]
--            car la table imbriquée s'appelle OfflinePeds.list (définie dans offline_ped.lua).

Spawn = {}
local logger = Logger:child("SPAWN")

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SAFE PED (anti-invisible global)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function SafePed()
    local ped = PlayerPedId()
    SetEntityVisible(ped, true, false)
    SetEntityAlpha(ped, 255, false)
    return ped
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- INIT
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function Spawn.initialize()
    logger:info("Initializing spawn system")
    TriggerServerEvent("union:spawn:requestInitial")
end

function Spawn.respawn(model)
    logger:info("Requesting respawn with model: " .. (model or "default"))
    TriggerServerEvent("union:spawn:requestRespawn", model)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- APPLY SPAWN
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RegisterNetEvent("union:spawn:apply", function(characterData)
    if not characterData then
        logger:error("characterData nil")
        return
    end

    local model = characterData.model
    if not model or model == "" then
        logger:error("model manquant")
        return
    end

    logger:info("Applying character model: " .. model)

    Citizen.CreateThread(function()

        -- ── LOAD MODEL ─────────────────────
        local modelHash = GetHashKey(model)

        if not IsModelInCdimage(modelHash) or not IsModelValid(modelHash) then
            logger:error("Invalid model: " .. model)
            TriggerServerEvent("union:spawn:error", "MODEL_INVALID")
            return
        end

        RequestModel(modelHash)

        local timeout = GetGameTimer() + 10000
        while not HasModelLoaded(modelHash) do
            Wait(50)
            if GetGameTimer() > timeout then
                logger:error("Timeout model: " .. model)
                TriggerServerEvent("union:spawn:error", "MODEL_LOAD_FAILED")
                return
            end
        end

        -- ── SET MODEL ──────────────────────
        SetPlayerModel(PlayerId(), modelHash)
        SetModelAsNoLongerNeeded(modelHash)

        Wait(0)
        local ped = SafePed()

        FreezeEntityPosition(ped, true)

        -- ── DATA ───────────────────────────
        local pos     = characterData.position or Config.spawn.defaultPosition
        local heading = characterData.heading  or Config.spawn.defaultHeading
        local health  = characterData.health   or Config.character.defaultHealth
        local armor   = characterData.armor    or 0

        -- ── COLLISION SAFE ─────────────────
        RequestCollisionAtCoord(pos.x, pos.y, pos.z)

        for i = 1, 50 do
            if HasCollisionLoadedAroundEntity(ped) then break end
            Wait(100)
        end

        -- ── RESPAWN ────────────────────────
        NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, heading, true, true)

        Wait(200)
        ped = SafePed()

        SetEntityHealth(ped, health)
        SetPedArmour(ped, armor)
        SetEntityHeading(ped, heading)
        ClearPedTasksImmediately(ped)

        -- ── DELETE OFFLINE PED ─────────────
        -- FIX #14 : accès via OfflinePeds.list (et non OfflinePeds directement)
        if OfflinePeds and OfflinePeds.list and characterData.unique_id then
            local offlinePed = OfflinePeds.list[characterData.unique_id]
            if offlinePed and DoesEntityExist(offlinePed) then
                DeleteEntity(offlinePed)
                OfflinePeds.list[characterData.unique_id] = nil
            end
        end

        -- ── APPARENCE ──────────────────────
        if ApplyFullAppearance then
            Wait(300)
            ApplyFullAppearance(characterData)

            Wait(150)
            ped = SafePed()
        else
            logger:warn("ApplyFullAppearance non disponible")
        end

        -- ── FINAL FIX INVISIBLE ────────────
        SetEntityVisible(ped, true, false)
        SetEntityAlpha(ped, 255, false)

        FreezeEntityPosition(ped, false)

        Client.currentCharacter = characterData

        logger:info("Character spawned successfully")

        -- Confirmer au serveur
        TriggerServerEvent("union:spawn:confirm", characterData.unique_id)

        -- Wake up anim
        Wait(300)
        if OfflinePeds and OfflinePeds.playWakeUpAnim then
            OfflinePeds.playWakeUpAnim(PlayerPedId())
        end
    end)
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ERROR
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RegisterNetEvent("union:spawn:error", function(errorType)
    logger:error("Spawn error: " .. tostring(errorType))
    Spawn.respawn(Config.spawn.defaultModel)
end)