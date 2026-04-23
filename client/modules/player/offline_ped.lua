---- client/modules/player/offline_ped.lua
---- Gestion-- côté-- client-- des-- peds-- persistants-- hors-ligne.
---- Chaque-- client-- peut-- recevoir-- l'ordre-- de-- spawner/supprimer-- un-- ped.
---- Un-- seul-- client-- "owner"-- gère-- réellement-- le-- ped-- réseau.

--OfflinePeds-- =-- -{}
--local-- logger-- -- =-- Logger:child("OFFLINE_PED")

---- ──-- Animations-- ────────────────────────────────────────────────────────────
--local-- ANIM_SLEEP-- =-- {
-- -- -- -- dict-- =-- "timetable@tracy@sleep@",
-- -- -- -- clip-- =-- "base",
--}

--local-- ANIM_GETUP-- =-- {
-- -- -- -- dict-- =-- "get_up@directional@transition@prone_to_knees@mp_female",
-- -- -- -- clip-- =-- "back",
--}

---- ──-- Helpers-- ───────────────────────────────────────────────────────────────
--local-- function-- loadAnimDict(dict)
-- -- -- -- if-- not-- HasAnimDictLoaded(dict)-- then
-- -- -- -- -- -- -- -- RequestAnimDict(dict)
-- -- -- -- -- -- -- -- local-- t-- =-- GetGameTimer()
-- -- -- -- -- -- -- -- while-- not-- HasAnimDictLoaded(dict)-- do
-- -- -- -- -- -- -- -- -- -- -- -- Wait(10)
-- -- -- -- -- -- -- -- -- -- -- -- if-- GetGameTimer()-- --- t-- >-- 5000-- then
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- logger:warn("Timeout-- chargement-- anim-- dict:-- "-- ..-- dict)
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- return-- false
-- -- -- -- -- -- -- -- -- -- -- -- end
-- -- -- -- -- -- -- -- end
-- -- -- -- end
-- -- -- -- return-- true
--end

--local-- function-- loadModel(modelHash)
-- -- -- -- if-- not-- HasModelLoaded(modelHash)-- then
-- -- -- -- -- -- -- -- RequestModel(modelHash)
-- -- -- -- -- -- -- -- local-- t-- =-- GetGameTimer()
-- -- -- -- -- -- -- -- while-- not-- HasModelLoaded(modelHash)-- do
-- -- -- -- -- -- -- -- -- -- -- -- Wait(50)
-- -- -- -- -- -- -- -- -- -- -- -- if-- GetGameTimer()-- --- t-- >-- 10000-- then
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- logger:warn("Timeout-- chargement-- modèle")
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- return-- false
-- -- -- -- -- -- -- -- -- -- -- -- end
-- -- -- -- -- -- -- -- end
-- -- -- -- end
-- -- -- -- return-- true
--end

---- ──-- Jouer-- l'animation-- de-- sommeil-- sur-- un-- ped-- ───────────────────────────────
--local-- function-- applySleepAnim(ped)
-- -- -- -- if-- not-- DoesEntityExist(ped)-- then-- return-- end

-- -- -- -- if-- loadAnimDict(ANIM_SLEEP.dict)-- then
-- -- -- -- -- -- -- -- ---- Mettre-- le-- ped-- à-- plat-- sur-- le-- sol
-- -- -- -- -- -- -- -- SetEntityCollision(ped,-- true,-- true)
-- -- -- -- -- -- -- -- TaskPlayAnim(ped,-- ANIM_SLEEP.dict,-- ANIM_SLEEP.clip,
-- -- -- -- -- -- -- -- -- -- -- -- 8.0,-- -8.0,-- -1,-- 1,-- 0.0,-- false,-- false,-- false)
-- -- -- -- end
--end

---- ──-- Spawner-- un-- ped-- hors-ligne-- ──────────────────────────────────────────────
--local-- function-- spawnOfflinePed(data)
-- -- -- -- if-- OfflinePeds[data.uniqueId]-- then-- return-- end-- ---- déjà-- spawné

-- -- -- -- local-- modelHash-- =-- GetHashKey(data.model)
-- -- -- -- if-- not-- loadModel(modelHash)-- then-- return-- end

-- -- -- -- local-- ped-- =-- CreatePed(
-- -- -- -- -- -- -- -- 4,-- modelHash,
-- -- -- -- -- -- -- -- data.x,-- data.y,-- data.z,
-- -- -- -- -- -- -- -- data.heading,
-- -- -- -- -- -- -- -- true,-- true-- -- -- ---- network-- =-- true,-- mission-- =-- true
-- -- -- -- )

-- -- -- -- SetModelAsNoLongerNeeded(modelHash)

-- -- -- -- if-- not-- DoesEntityExist(ped)-- then
-- -- -- -- -- -- -- -- logger:warn("Impossible-- de-- créer-- le-- ped-- offline-- pour-- "-- ..-- data.uniqueId)
-- -- -- -- -- -- -- -- return
-- -- -- -- end

-- -- -- -- ---- Configuration-- du-- ped
-- -- -- -- SetEntityInvincible(ped,-- true)
-- -- -- -- SetBlockingOfNonTemporaryEvents(ped,-- true)
-- -- -- -- SetPedCanRagdoll(ped,-- false)
-- -- -- -- SetPedFleeAttributes(ped,-- 0,-- false)
-- -- -- -- SetPedCombatAttributes(ped,-- 17,-- true)
-- -- -- -- FreezeEntityPosition(ped,-- false)
-- -- -- -- PlaceObjectOnGroundProperly(ped)

-- -- -- -- ---- Animation-- de-- sommeil
-- -- -- -- Wait(300)
-- -- -- -- applySleepAnim(ped)

-- -- -- -- ---- Stocker-- le-- ped
-- -- -- -- OfflinePeds[data.uniqueId]-- =-- ped

-- -- -- -- ---- Informer-- le-- serveur-- du-- netId-- si-- on-- est-- le-- propriétaire-- réseau
-- -- -- -- if-- NetworkHasControlOfEntity(ped)-- then
-- -- -- -- -- -- -- -- local-- netId-- =-- NetworkGetNetworkIdFromEntity(ped)
-- -- -- -- -- -- -- -- TriggerServerEvent("union:offlineped:spawned",-- data.uniqueId,-- netId)
-- -- -- -- end

-- -- -- -- logger:info-(("Ped-- offline-- spawné-- pour-- uid=%s"):format(data.uniqueId))
--end

---- ──-- Supprimer-- un-- ped-- hors-ligne-- ───────────────────────────────────────────
--local-- function-- removeOfflinePed(uniqueId)
-- -- -- -- local-- ped-- =-- OfflinePeds[uniqueId]
-- -- -- -- if-- not-- ped-- then-- return-- end

-- -- -- -- if-- DoesEntityExist-(ped)-- then
-- -- -- -- -- -- -- -- SetEntityAsMissionEntity(ped,-- false,-- true)
-- -- -- -- -- -- -- -- DeleteEntity-(ped)
-- -- -- -- end

-- -- -- -- OfflinePeds-[uniqueId]-- =-- nil
-- -- -- -- logger:info-(("Ped-- offline-- supprimé-- pour-- uid=%s"):format(uniqueId))
--end

---- ──────────────────────────────────────────────────────────────────────────
---- Events-- reçus-- du-- serveur
---- ──────────────────────────────────────────────────────────────────────────

--RegisterNetEvent("union:offlineped:create",-- function(data)
-- -- -- -- if-- not-- data-- or-- not-- data.uniqueId-- then-- return-- end

-- -- -- -- ---- Éviter-- de-- spawner-- son-- propre-- ped-- si-- c'est-- notre-- personnage-- actuel
-- -- -- -- local-- myChar-- =-- Client.currentCharacter
-- -- -- -- if-- myChar-- and-- myChar.unique_id-- ==-- data.uniqueId-- then-- return-- end

-- -- -- -- ---- Attendre-- un-- court-- délai-- pour-- que-- le-- monde-- soit-- chargé
-- -- -- -- Wait(500)
-- -- -- -- spawnOfflinePed(data)
--end-)

--RegisterNetEvent("union:offlineped:remove",-- function(uniqueId)
-- -- -- -- removeOfflinePed(uniqueId)
--end-)

---- ──────────────────────────────────────────────────────────────────────────
---- Animation-- de-- réveil-- pour-- le-- joueur-- LOCAL-- quand-- il-- spawn
---- Appelé-- depuis-- spawn/main.lua-- après-- que-- le-- modèle-- soit-- appliqué
---- ──────────────────────────────────────────────────────────────────────────
--function-- OfflinePeds.playWakeUpAnim-(ped)
-- -- -- -- if-- not-- ped-- or-- not-- DoesEntityExist-(ped)-- then
-- -- -- -- -- -- -- -- ped-- =-- PlayerPedId-()
-- -- -- -- end

-- -- -- -- CreateThread(function()
-- -- -- -- -- -- -- ---- if-- not-- loadAnimDict(ANIM_GETUP.dict)-- then-- return-- end

-- -- -- -- -- -- -- -- ---- Freezer-- le-- joueur-- pendant-- l'anim
-- -- -- -- -- -- -- -- FreezeEntityPosition(ped,-- true)

-- -- -- -- -- -- -- -- ---- D'abord-- jouer-- la-- pose-- couchée-- une-- frame-- pour-- transition-- propre
-- -- -- -- -- -- -- -- ---- if-- loadAnimDict(ANIM_SLEEP.dict)-- then
-- -- -- -- -- -- -- -- -- -- -- -- ---- TaskPlayAnim(ped,-- ANIM_SLEEP.dict,-- ANIM_SLEEP.clip,
-- -- -- -- -- -- -- -- -- -- -- -- -- -- ---- -- -- 8.0,-- -8.0,-- 1000,-- 1,-- 0.0,-- false,-- false,-- false)
-- -- -- -- -- -- -- -- -- -- -- ---- -- Wait(800)
-- -- -- -- -- -- -- -- ---- end

-- -- -- -- -- -- -- -- ---- Puis-- jouer-- le-- lever
-- -- -- -- -- -- -- -- ---- TaskPlayAnim(ped,-- ANIM_GETUP.dict,-- ANIM_GETUP.clip,
-- -- -- -- -- -- -- -- -- -- -- ---- -- 4.0,-- -4.0,-- -1,-- 0,-- 0.0,-- false,-- false,-- false)

-- -- -- -- -- -- -- -- ---- Attendre-- la-- fin-- de-- l'animation-- (environ-- 3s)
-- -- -- -- -- -- -- -- ---- local-- timer-- =-- GetGameTimer()
-- -- -- -- -- -- -- -- ---- while-- IsEntityPlayingAnim(ped,-- ANIM_GETUP.dict,-- ANIM_GETUP.clip,-- 3)-- do
-- -- -- -- -- -- -- -- -- -- -- ---- -- Wait(100)
-- -- -- -- -- -- -- -- ---- -- -- -- -- if-- GetGameTimer()-- --- timer-- >-- 6000-- then-- break-- end
-- -- -- -- -- -- -- -- ---- end

-- -- -- -- -- -- -- -- ---- Libérer-- le-- joueur
-- -- -- -- -- -- -- -- ---- ClearPedTasks(ped)
-- -- -- -- -- -- -- ---- -- FreezeEntityPosition(ped,-- false)

-- -- -- -- -- -- ---- -- -- logger:info("Animation-- de-- réveil-- terminée")
-- -- -- ---- -- end-)
---- end

---- ──────────────────────────────────────────────────────────────────────────
---- Animation-- de-- coucher-- pour-- le-- joueur-- LOCAL-- quand-- il-- se-- déconnecte
---- NOTE-- :-- FiveM-- ne-- permet-- pas-- de-- jouer-- une-- anim-- juste-- avant-- la-- déco,
---- donc-- on-- la-- joue-- côté-- serveur-- sur-- le-- ped-- persistant-- créé-- après-- la-- déco.
---- ──────────────────────────────────────────────────────────────────────────
---- function-- OfflinePeds.playSleepAnim-()
-- -- -- -- ---- local-- ped-- =-- PlayerPedId()
-- -- -- -- ---- if-- not-- DoesEntityExist-(ped)-- then-- return-- end

-- -- -- -- ---- if-- loadAnimDict-(ANIM_SLEEP.dict)-- then
-- -- -- -- -- -- -- -- ---- TaskPlayAnim(ped,-- ANIM_SLEEP.dict,-- ANIM_SLEEP.clip,
-- -- -- -- -- -- -- -- -- ---- -- -- -- 8.0,-- -8.0,-- 3000,-- 1,-- 0.0,-- false,-- false,-- false)
-- -- -- -- -- -- ---- -- -- Wait(3000)
-- -- -- ---- -- end
---- end

---- ──────────────────────────────────────────────────────────────────────────
---- Nettoyage-- à-- la-- sélection-- d'un-- personnage-- (supprime-- notre-- propre-- ped-- offline
---- si-- quelqu'un-- d'autre-- l'avait-- spawné-- entre-- temps)
---- ──────────────────────────────────────────────────────────────────────────
--RegisterNetEvent("union:character:selected",-- function(success,-- character)
-- -- -- -- ---- if-- success-- and-- character-- and-- character.unique_id-- then
-- -- -- -- -- -- -- -- ---- Si-- un-- ped-- offline-- existait-- pour-- ce-- personnage,-- le-- retirer-- localement
-- -- -- -- -- ---- -- -- removeOfflinePed(character.unique_id)
-- -- -- ---- end
---- end)

---- return-- OfflinePeds

OfflinePeds = {}
OfflinePeds.logger = Logger:child("OFFLINE_PED")

OfflinePeds.list = {}

-- CREATE PED
RegisterNetEvent("union:offlineped:create", function(data)
    if not data or not data.uniqueId then return end

    local modelHash = GetHashKey(data.model)

    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do Wait(50) end

    local ped = CreatePed(4, modelHash, data.x, data.y, data.z - 1.0, data.heading, true, true)

    -- 🔥 NETWORK SAFE
    NetworkRegisterEntityAsNetworked(ped)
    local netId = NetworkGetNetworkIdFromEntity(ped)

    SetNetworkIdExistsOnAllMachines(netId, true)
    SetNetworkIdCanMigrate(netId, true)

    -- CONFIG PED
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)

    -- ANIM DODO (optionnel)
    TaskStartScenarioInPlace(ped, "WORLD_HUMAN_SUNBATHE_BACK", 0, true)

    OfflinePeds.list[data.uniqueId] = ped

    -- 🔁 SYNC AU SERVEUR
    TriggerServerEvent("union:offlineped:spawned", data.uniqueId, netId)

    OfflinePeds.logger:info("Ped créé " .. data.uniqueId)
end)

-- REMOVE
RegisterNetEvent("union:offlineped:remove", function(uniqueId)
    local ped = OfflinePeds.list[uniqueId]

    if ped and DoesEntityExist(ped) then
        DeleteEntity(ped)
    end

    OfflinePeds.list[uniqueId] = nil

    OfflinePeds.logger:info("Ped supprimé " .. uniqueId)
end)