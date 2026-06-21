-- client/modules/player/manager/offline_ped.lua
OfflinePeds        = {}
OfflinePeds.logger = Logger:child("OFFLINE_PED")
OfflinePeds.list   = {}

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

local function applyDeadPose(ped)
    SetPedToRagdoll(ped, 1, 1, 0, false, false, false)
    CreateThread(function()
        Wait(500)
        if DoesEntityExist(ped) then
            FreezeEntityPosition(ped, true)
        end
    end)
end

local function spawnOfflinePed(data)
    if not data or not data.uniqueId then return end
    if not OfflinePeds.list then OfflinePeds.list = {} end
    if Client.currentCharacter and Client.currentCharacter.unique_id == data.uniqueId then return end
    if OfflinePeds.list[data.uniqueId] then return end

    local modelHash = GetHashKey(data.model or "mp_m_freemode_01")
    if not loadModel(modelHash) then return end

    local ped = CreatePed(4, modelHash, data.x, data.y, data.z - 1.0, data.heading or 0.0, false, false)
    SetModelAsNoLongerNeeded(modelHash)
    if not DoesEntityExist(ped) then
        OfflinePeds.logger:warn("Impossible de créer le ped offline pour " .. data.uniqueId)
        return
    end

    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityVisible(ped, true, false)
    applyDeadPose(ped)

    OfflinePeds.list[data.uniqueId] = ped
    OfflinePeds.logger:info("Ped offline créé pour uid=" .. data.uniqueId)
end

local function deletePed(uniqueId)
    if not OfflinePeds.list then return end
    local ped = OfflinePeds.list[uniqueId]
    if ped and DoesEntityExist(ped) then
        SetEntityAsMissionEntity(ped, false, true)
        DeleteEntity(ped)
    end
    OfflinePeds.list[uniqueId] = nil
end

RegisterNetEvent("union:offlineped:create", function(data) spawnOfflinePed(data) end)
RegisterNetEvent("union:offlineped:loadAll", function(peds)
    if type(peds) ~= "table" then return end
    for _, data in ipairs(peds) do spawnOfflinePed(data) end
    OfflinePeds.logger:info(("Chargement initial : %d ped(s) offline"):format(#peds))
end)
RegisterNetEvent("union:offlineped:remove", function(uniqueId)
    if not uniqueId then return end
    deletePed(uniqueId)
    OfflinePeds.logger:info("Ped offline supprimé pour uid=" .. uniqueId)
end)
RegisterNetEvent("union:player:spawned", function(character)
    if not character or not character.unique_id then return end
    if not OfflinePeds.list or not OfflinePeds.list[character.unique_id] then return end
    deletePed(character.unique_id)
    OfflinePeds.logger:info("Ped offline nettoyé après spawn uid=" .. character.unique_id)
end)
AddEventHandler("union:character:unloaded", function()
    if not OfflinePeds.list then return end
    for uniqueId in pairs(OfflinePeds.list) do deletePed(uniqueId) end
    OfflinePeds.logger:info("Tous les peds offline supprimés (character unloaded)")
end)
