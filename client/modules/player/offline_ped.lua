-- client/modules/player/offline_ped.lua
-- FIXES:
--   #1 : Suppression des natives réseau serveur-only appelées côté client
--        (NetworkRegisterEntityAsNetworked, SetNetworkIdExistsOnAllMachines,
--         SetNetworkIdCanMigrate) → ces appels crashaient silencieusement
--         et empêchaient le ped d'être créé correctement.
--   #2 : Remplacement de TaskStartScenarioInPlace par TaskPlayAnim
--        (le scénario SUNBATHE_BACK n'est pas compatible avec les peds réseau).
--   #3 : Réception du dump initial au spawn pour voir les peds des joueurs
--        déconnectés avant notre connexion.

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

-- FIX #2 : animation allongé au sol valide pour peds non-réseau
local function applyDeadAnim(ped)
    local dict = "dead"
    RequestAnimDict(dict)
    local t = GetGameTimer()
    while not HasAnimDictLoaded(dict) do
        Wait(50)
        if GetGameTimer() - t > 3000 then return end
    end
    TaskPlayAnim(ped, dict, "dead_d", 8.0, -8.0, -1, 1, 0, false, false, false)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CRÉER UN PED OFFLINE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local function spawnOfflinePed(data)
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
        false,  -- FIX #1 : false = ped local uniquement, pas réseau
        false
    )

    SetModelAsNoLongerNeeded(modelHash)

    if not DoesEntityExist(ped) then
        OfflinePeds.logger:warn("Impossible de créer le ped offline pour " .. data.uniqueId)
        return
    end

    -- FIX #1 : suppression des natives serveur-only
    -- NetworkRegisterEntityAsNetworked(ped)    ← SERVER ONLY, retiré
    -- SetNetworkIdExistsOnAllMachines(...)     ← SERVER ONLY, retiré
    -- SetNetworkIdCanMigrate(...)              ← SERVER ONLY, retiré

    -- Configuration ped
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, true, false)

    -- FIX #2 : animation correcte pour un ped local
    applyDeadAnim(ped)

    OfflinePeds.list[data.uniqueId] = ped

    -- FIX #1 : suppression de TriggerServerEvent("union:offlineped:spawned")
    -- Le netId n'existe plus (ped local), plus besoin de le notifier au serveur.

    OfflinePeds.logger:info("Ped offline créé pour uid=" .. data.uniqueId)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- EVENTS RÉSEAU
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RegisterNetEvent("union:offlineped:create", function(data)
    spawnOfflinePed(data)
end)

-- FIX #3 : réception du dump initial (joueurs déconnectés avant notre arrivée)
RegisterNetEvent("union:offlineped:loadAll", function(peds)
    if type(peds) ~= "table" then return end
    for _, data in ipairs(peds) do
        spawnOfflinePed(data)
    end
    OfflinePeds.logger:info(("Chargement initial : %d ped(s) offline"):format(#peds))
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
-- NETTOYAGE AU SPAWN DU PERSONNAGE ACTIF
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
