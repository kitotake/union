-- client/modules/player/offline_ped.lua
-- FIX #1 : applyDeadAnim — Wait(0) dans la boucle pour éviter le freeze.
-- FIX #2 : spawnOfflinePed défensif si OfflinePeds.list est nil.
-- FIX #3 : nettoyage propre à union:character:unloaded.
-- FIX #4 : dict "dead" inexistant remplacé par SetPedToRagdoll (plus fiable,
--          aucun timeout, comportement identique visuellement).
-- FIX #5 : guard DoesEntityExist avant DeleteEntity dans union:player:spawned
--          pour éviter le double-delete avec spawn/main.lua (étape 6).

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

-- FIX #4 : "dead" n'est pas un anim dict valide dans GTA V.
-- RequestAnimDict("dead") ne se résout jamais → timeout de 3s garanti à chaque appel.
-- On utilise SetPedToRagdoll + FreezeEntityPosition pour le même effet visuel
-- sans aucun chargement d'asset.
local function applyDeadPose(ped)
    SetPedToRagdoll(ped, 1, 1, 0, false, false, false)
    -- Laisse le ragdoll se stabiliser une frame avant de freeze
    CreateThread(function()
        Wait(500)
        if DoesEntityExist(ped) then
            FreezeEntityPosition(ped, true)
        end
    end)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CRÉER UN PED OFFLINE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local function spawnOfflinePed(data)
    if not data or not data.uniqueId then return end
    if not OfflinePeds.list then OfflinePeds.list = {} end

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
        false,
        false
    )

    SetModelAsNoLongerNeeded(modelHash)

    if not DoesEntityExist(ped) then
        OfflinePeds.logger:warn("Impossible de créer le ped offline pour " .. data.uniqueId)
        return
    end

    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityVisible(ped, true, false)

    -- FIX #4 : pose morte sans anim dict
    applyDeadPose(ped)

    OfflinePeds.list[data.uniqueId] = ped
    OfflinePeds.logger:info("Ped offline créé pour uid=" .. data.uniqueId)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- HELPERS INTERNES DE SUPPRESSION
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local function deletePed(uniqueId)
    if not OfflinePeds.list then return end
    local ped = OfflinePeds.list[uniqueId]
    -- FIX #5 : guard avant delete pour éviter le double-delete
    if ped and DoesEntityExist(ped) then
        SetEntityAsMissionEntity(ped, false, true)
        DeleteEntity(ped)
    end
    OfflinePeds.list[uniqueId] = nil
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- EVENTS RÉSEAU
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RegisterNetEvent("union:offlineped:create", function(data)
    spawnOfflinePed(data)
end)

RegisterNetEvent("union:offlineped:loadAll", function(peds)
    if type(peds) ~= "table" then return end
    for _, data in ipairs(peds) do
        spawnOfflinePed(data)
    end
    OfflinePeds.logger:info(("Chargement initial : %d ped(s) offline"):format(#peds))
end)

RegisterNetEvent("union:offlineped:remove", function(uniqueId)
    if not uniqueId then return end
    deletePed(uniqueId)
    OfflinePeds.logger:info("Ped offline supprimé pour uid=" .. uniqueId)
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- NETTOYAGE AU SPAWN DU PERSONNAGE ACTIF
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RegisterNetEvent("union:player:spawned", function(character)
    if not character or not character.unique_id then return end
    -- FIX #5 : deletePed contient déjà le guard DoesEntityExist
    -- spawn/main.lua (étape 6) peut avoir déjà supprimé ce ped — pas de crash
    deletePed(character.unique_id)
    OfflinePeds.logger:info("Ped offline nettoyé après spawn uid=" .. character.unique_id)
end)

-- FIX #3 : nettoyage complet au déchargement du personnage
AddEventHandler("union:character:unloaded", function()
    if not OfflinePeds.list then return end
    for uniqueId in pairs(OfflinePeds.list) do
        deletePed(uniqueId)
    end
    OfflinePeds.logger:info("Tous les peds offline supprimés (character unloaded)")
end)