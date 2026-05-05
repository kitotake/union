-- client/modules/player/offline_ped.lua
-- FIX #1 : applyDeadAnim — ajout de Wait(0) dans la boucle pour éviter le freeze.
-- FIX #2 : spawnOfflinePed ne crashe plus si OfflinePeds.list est nil.
-- FIX #3 : nettoyage propre à union:character:unloaded.

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

-- FIX #1 : Wait(0) ajouté pour éviter le blocage si HasAnimDictLoaded ne se résout jamais
local function applyDeadAnim(ped)
    local dict = "dead"
    RequestAnimDict(dict)
    local t = GetGameTimer()
    while not HasAnimDictLoaded(dict) do
        Wait(0)   -- FIX #1 : évite le freeze
        if GetGameTimer() - t > 3000 then
            OfflinePeds.logger:warn("Timeout chargement anim dict 'dead'")
            return
        end
    end
    TaskPlayAnim(ped, dict, "dead_d", 8.0, -8.0, -1, 1, 0, false, false, false)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CRÉER UN PED OFFLINE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local function spawnOfflinePed(data)
    -- FIX #2 : vérifications défensives
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
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, true, false)

    applyDeadAnim(ped)

    OfflinePeds.list[data.uniqueId] = ped
    OfflinePeds.logger:info("Ped offline créé pour uid=" .. data.uniqueId)
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

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SUPPRIMER UN PED OFFLINE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RegisterNetEvent("union:offlineped:remove", function(uniqueId)
    if not uniqueId then return end
    if not OfflinePeds.list then return end

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
    if not OfflinePeds.list then return end

    local ped = OfflinePeds.list[character.unique_id]
    if ped and DoesEntityExist(ped) then
        SetEntityAsMissionEntity(ped, false, true)
        DeleteEntity(ped)
        OfflinePeds.list[character.unique_id] = nil
        OfflinePeds.logger:info("Ped offline propre supprimé après spawn uid=" .. character.unique_id)
    end
end)

-- FIX #3 : nettoyage complet au déchargement du personnage
AddEventHandler("union:character:unloaded", function()
    if not OfflinePeds.list then return end
    for uniqueId, ped in pairs(OfflinePeds.list) do
        if ped and DoesEntityExist(ped) then
            SetEntityAsMissionEntity(ped, false, true)
            DeleteEntity(ped)
        end
        OfflinePeds.list[uniqueId] = nil
    end
    OfflinePeds.logger:info("Tous les peds offline supprimés (character unloaded)")
end)
