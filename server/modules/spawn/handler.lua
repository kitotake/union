-- server/modules/spawn/handler.lua
-- FIX SH-1 : ped_model (colonne réelle, pas "model").
-- FIX SH-2 : position transmise comme table JSON-sérialisable (pas vector3 brut).
-- FIX SH-3 : guard anti-double confirm avec nettoyage fiable.
-- FIX SH-4 : SpawnHandler._confirming nettoyé immédiatement à playerDropped.
-- FIX CRIT-1 : union:player:spawned déclenché UNE SEULE FOIS via TriggerEvent local.
-- FIX CRIT-2 : player.isSpawned mis à true DANS le handler de confirm.
-- FIX CRIT-3 : _confirming nettoyé immédiatement après traitement.
-- FIX DOUBLE-SPAWN : guard _spawnedGuard par (src+uid) dans une fenêtre de 5s.
--   Après "ensure union", le client renvoie union:player:joined → loadFromDatabase
--   → auto-spawn → confirm : un doublon peut arriver dans la même fenêtre courte.
--   Le guard détecte ce doublon et l'absorbe silencieusement, évitant le double
--   déclenchement de union:player:spawned (et donc le double chargement d'inventaire
--   et la double application d'apparence).

SpawnHandler        = {}
SpawnHandler.logger = Logger:child("SPAWN:HANDLER")

SpawnHandler._sessions      = {}
SpawnHandler._confirming    = {}
SpawnHandler._spawnedGuard  = {}   -- FIX DOUBLE-SPAWN : guardKey → timestamp

local SPAWN_DEDUP_WINDOW = 5000   -- ms : deux spawns du même uid dans cette fenêtre = doublon

local function isConnected(src)
    return GetPlayerEndpoint(src) ~= nil
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SPAWN INITIAL
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RegisterNetEvent("union:spawn:requestInitial", function()
    local src    = source
    local player = PlayerManager.get(src)

    if not player then
        SpawnHandler.logger:error("requestInitial: joueur introuvable pour source " .. src)
        return
    end

    if player.isLoading then
        local waited = 0
        while player.isLoading and waited < 50 do
            Wait(100)
            waited = waited + 1
        end
    end

    if not isConnected(src) then
        SpawnHandler.logger:warn("requestInitial: joueur " .. src .. " déconnecté pendant l'attente")
        return
    end

    local chars = player.characters or {}

    if #chars == 0 then
        SpawnHandler.logger:info(("Joueur %s : 0 personnage → création"):format(player.name))
        TriggerClientEvent("union:spawn:noCharacters", src)
        TriggerClientEvent("kt_character:openCreator", src)
        return
    end

    if #chars == 1 then
        SpawnHandler.logger:info(("Joueur %s : 1 personnage → auto-spawn"):format(player.name))

        local spawnSent = false

        Character.select(player, chars[1].id, function(success)
            if success then
                spawnSent = true
                SpawnHandler.logger:info(("Auto-spawn OK pour %s"):format(player.name))
            else
                SpawnHandler.logger:error("Auto-select échoué pour " .. player.name)
                if not spawnSent and isConnected(src) then
                    spawnSent = true
                    TriggerClientEvent("union:spawn:apply", src, SpawnHandler._buildCharData(chars[1]))
                end
            end
        end)

        return
    end

    SpawnHandler.logger:info(("Joueur %s : %d personnages → sélection NUI"):format(player.name, #chars))

    TriggerClientEvent("characters:openSelection", src, {
        slots      = player.slots or 1,
        characters = chars,
    })
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- No-op pour characters:playerReady
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RegisterNetEvent("characters:playerReady", function()
    SpawnHandler.logger:debug("characters:playerReady reçu de src=" .. tostring(source) .. " (ignoré)")
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- HELPER : construit charData compatible client
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function SpawnHandler._buildCharData(char)
    local defPos = Config.spawn.defaultPosition
    local defHdg = Config.spawn.defaultHeading
    local px, py, pz, heading = defPos.x, defPos.y, defPos.z, defHdg

    if char.position then
        local ok, p = pcall(json.decode, tostring(char.position))
        if ok and p and p.x then
            px, py, pz = p.x, p.y, p.z
            heading    = p.heading or defHdg
        end
    end

    return {
        id          = char.id,
        unique_id   = char.unique_id,
        firstname   = char.firstname,
        lastname    = char.lastname,
        ped_model   = char.ped_model or Config.spawn.defaultModel,
        dateofbirth = char.dateofbirth,
        position    = { x = px, y = py, z = pz },
        heading     = heading,
        health      = char.health    or Config.character.defaultHealth,
        armor       = char.armor     or 0,
        job         = char.job       or "unemployed",
        job_grade   = char.job_grade or 0,
    }
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- RESPAWN
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RegisterNetEvent("union:spawn:requestRespawn", function(model)
    local src    = source
    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter then return end
    if not isConnected(src) then return end

    local char   = player.currentCharacter
    local defPos = Config.spawn.defaultPosition

    TriggerClientEvent("union:spawn:apply", src, {
        id        = char.id,
        unique_id = char.unique_id,
        ped_model = model or char.ped_model or Config.spawn.defaultModel,
        position  = { x = defPos.x, y = defPos.y, z = defPos.z },
        heading   = Config.spawn.defaultHeading,
        health    = Config.character.defaultHealth,
        armor     = 0,
    })
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CONFIRMATION CLIENT → SPAWN RÉUSSI
-- FIX DOUBLE-SPAWN : guard _spawnedGuard par (src+uid) dans une fenêtre de 5s.
--
-- Séquence problématique après "ensure union" :
--   1. Client envoie union:player:joined
--   2. Serveur : loadFromDatabase → auto-spawn → union:spawn:apply
--   3. Client : union:spawn:apply → spawn → union:spawn:confirm  ← 1er confirm OK
--   4. BUT : l'ancien CreateThread de handler.lua côté client (du chargement
--      précédent) peut aussi terminer et envoyer un 2e union:player:joined,
--      ce qui relance toute la chaîne → 2e union:spawn:confirm → double spawned.
--   Le guard _spawnedGuard bloque le 2e confirm si uid identique dans les 5s.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RegisterNetEvent("union:spawn:confirm", function(uniqueId)
    local src    = source
    local player = PlayerManager.get(src)
    if not player then return end

    -- Guard anti-double confirm (même tick)
    if SpawnHandler._confirming[src] then
        SpawnHandler.logger:warn("Double confirm ignoré pour src=" .. src)
        return
    end
    SpawnHandler._confirming[src] = true

    -- FIX DOUBLE-SPAWN : guard temporel par (src + unique_id)
    local guardKey  = tostring(src) .. "_" .. tostring(uniqueId)
    local lastSpawn = SpawnHandler._spawnedGuard[guardKey]
    local now       = GetGameTimer()

    if lastSpawn and (now - lastSpawn) < SPAWN_DEDUP_WINDOW then
        SpawnHandler.logger:warn(("Double spawn bloqué src=%d uid=%s (delta=%dms)"):format(
            src, tostring(uniqueId), now - lastSpawn
        ))
        SpawnHandler._confirming[src] = nil
        return
    end
    SpawnHandler._spawnedGuard[guardKey] = now

    -- FIX CRIT-2 : isSpawned AVANT le TriggerEvent
    player.isSpawned = true
    SpawnHandler.logger:info("Spawn confirmé pour " .. player.name)

    -- Nettoyage OfflinePed
    if player.currentCharacter and player.currentCharacter.unique_id then
        if OfflinePed then
            OfflinePed.remove(player.currentCharacter.unique_id)
        end
    end

    -- FIX CRIT-1 : UN SEUL point de déclenchement de union:player:spawned
    TriggerEvent("union:player:spawned", src, player.currentCharacter)
    if isConnected(src) then
        TriggerClientEvent("union:player:spawned", src, player.currentCharacter)
    end

    -- FIX CRIT-3 : nettoyage immédiat
    SpawnHandler._confirming[src] = nil
end)

RegisterNetEvent("union:spawn:error", function(errorType)
    local src = source
    SpawnHandler.logger:error(("Erreur spawn [%s]: %s"):format(src, tostring(errorType)))
    SpawnHandler._confirming[src] = nil
end)

-- Nettoyage complet à la déconnexion
AddEventHandler("playerDropped", function()
    local src    = source
    local srcStr = tostring(src)

    SpawnHandler._confirming[src] = nil
    SpawnHandler._sessions[src]   = nil

    -- Purge du guard pour ce src
    local toDelete = {}
    for key in pairs(SpawnHandler._spawnedGuard) do
        if key:sub(1, #srcStr + 1) == srcStr .. "_" then
            toDelete[#toDelete + 1] = key
        end
    end
    for _, key in ipairs(toDelete) do
        SpawnHandler._spawnedGuard[key] = nil
    end
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- HELPERS PUBLICS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function SpawnHandler.applyCharacter(player, characterData)
    if not player or not characterData then return false end
    if not isConnected(player.source) then return false end
    TriggerClientEvent("union:spawn:apply", player.source, characterData)
    return true
end

AddEventHandler("onResourceStart", function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Logger:info("[SPAWN] Resource restart — les clients vont envoyer union:player:joined")
end)

return SpawnHandler
