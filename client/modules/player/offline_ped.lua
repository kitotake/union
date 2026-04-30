-- fixes/client/modules/player/offline_ped.lua
-- VERSION CORRIGÉE : supprime tout le code commenté de l'ancienne version
-- Logique propre et fonctionnelle uniquement

OfflinePeds        = {}
OfflinePeds.logger = Logger:child("OFFLINE_PED")
OfflinePeds.list   = {}

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- HELPERS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local function loadModel(modelHash)
    if HasModelLoaded(modelHash) then return true end

    RequestModel(modelHash)
    local t = GetGameTimer()
    while not HasModelLoaded(modelHash) do
        Wait(50)
        if GetGameTimer() - t > 8000 then
            OfflinePeds.logger:warn("Timeout chargement modèle")
            return false
        end
    end
    return true
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CRÉER UN PED OFFLINE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RegisterNetEvent("union:offlineped:create", function(data)
    if not data or not data.uniqueId then return end

    -- Ne pas spawner son propre ped offline
    if Client.currentCharacter and Client.currentCharacter.unique_id == data.uniqueId then
        return
    end

    -- Déjà spawné
    if OfflinePeds.list[data.uniqueId] then return end

    local modelHash = GetHashKey(data.model or "mp_m_freemode_01")
    if not loadModel(modelHash) then return end

    local ped = CreatePed(
        4,
        modelHash,
        data.x,
        data.y,
        data.z - 1.0,
        data.heading or 0.0,
        true,
        true
    )

    SetModelAsNoLongerNeeded(modelHash)

    if not DoesEntityExist(ped) then
        OfflinePeds.logger:warn("Impossible de créer le ped offline pour " .. data.uniqueId)
        return
    end

    -- Configuration réseau
    NetworkRegisterEntityAsNetworked(ped)
    local netId = NetworkGetNetworkIdFromEntity(ped)
    SetNetworkIdExistsOnAllMachines(netId, true)
    SetNetworkIdCanMigrate(netId, true)

    -- Configuration ped
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)

    -- Animation couché
    TaskStartScenarioInPlace(ped, "WORLD_HUMAN_SUNBATHE_BACK", 0, true)

    OfflinePeds.list[data.uniqueId] = ped

    -- Sync netId au serveur
    TriggerServerEvent("union:offlineped:spawned", data.uniqueId, netId)

    OfflinePeds.logger:info("Ped offline créé pour uid=" .. data.uniqueId)
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SUPPRIMER UN PED OFFLINE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RegisterNetEvent("union:offlineped:remove", function(uniqueId)
    if not uniqueId then return end

    local ped = OfflinePeds.list[uniqueId]
    if ped and DoesEntityExist(ped) then
        SetEntityAsMissionEntity(ped, false, true)
        DeleteEntity(ped)
    end

    OfflinePeds.list[uniqueId] = nil
    OfflinePeds.logger:info("Ped offline supprimé pour uid=" .. uniqueId)
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- NETTOYAGE AU CHARGEMENT DE PERSONNAGE
-- Supprime le ped offline de notre propre personnage
-- si un autre client l'avait spawné entre-temps
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RegisterNetEvent("union:player:spawned", function(character)
    if not character or not character.unique_id then return end

    local ped = OfflinePeds.list[character.unique_id]
    if ped and DoesEntityExist(ped) then
        SetEntityAsMissionEntity(ped, false, true)
        DeleteEntity(ped)
        OfflinePeds.list[character.unique_id] = nil
        OfflinePeds.logger:info("Ped offline propre supprimé après spawn uid=" .. character.unique_id)
    end
end)
