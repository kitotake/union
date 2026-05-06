-- server/modules/spawn/handler.lua
-- FIX #1 : guard anti-double confirm avec nettoyage fiable à la déconnexion.
-- FIX #2 : vérification que le joueur est encore connecté avant TriggerClientEvent.
-- FIX #3 : characters:playerReady — ajout d'un handler vide pour éviter les warnings.
-- FIX #4 : SpawnHandler._confirming nettoyé immédiatement à playerDropped.

SpawnHandler        = {}
SpawnHandler.logger = Logger:child("SPAWN:HANDLER")

-- Clés de session pour éviter le double confirm
-- { [src] = sessionId }
SpawnHandler._sessions    = {}
SpawnHandler._confirming  = {}

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

    -- FIX #2 : vérifier connexion après l'attente
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
        Character.select(player, chars[1].id, function(success)
            if not success then
                SpawnHandler.logger:error("Auto-select échoué pour " .. player.name)
                -- FIX #2 : re-vérifier connexion
                if isConnected(src) then
                    TriggerClientEvent("union:spawn:apply", src, SpawnHandler._buildCharData(chars[1]))
                end
            end
        end)
        return
    end

    SpawnHandler.logger:info(("Joueur %s : %d personnages → sélection NUI"):format(player.name, #chars))

    -- Ouvrir la sélection NUI (format compatible avec characterManager.lua côté client)
    TriggerClientEvent("characters:openSelection", src, {
        slots      = player.slots or 1,
        characters = chars,
    })
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- FIX #3 : handler pour characters:playerReady
-- Envoyé par le client (characterManager.lua) au démarrage.
-- Plus utilisé pour le routing du spawn mais on l'absorbe proprement.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RegisterNetEvent("characters:playerReady", function()
    -- No-op : le spawn est géré par union:spawn:requestInitial
    -- On loggue en debug pour le suivi
    SpawnHandler.logger:debug("characters:playerReady reçu de src=" .. tostring(source) .. " (ignoré)")
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- HELPER
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function SpawnHandler._buildCharData(char)
    local defPos = Config.spawn.defaultPosition
    local defHdg = Config.spawn.defaultHeading
    local position, heading = defPos, defHdg

    if char.position then
        local ok, p = pcall(json.decode, tostring(char.position))
        if ok and p and p.x then
            position = vector3(p.x, p.y, p.z)
            heading  = p.heading or defHdg
        end
    end

    return {
        id          = char.id,
        unique_id   = char.unique_id,
        firstname   = char.firstname,
        lastname    = char.lastname,
        ped_model   = char.ped_model or Config.spawn.defaultModel,
        dateofbirth = char.dateofbirth,
        position    = position,
        heading     = heading,
        health      = char.health or Config.character.defaultHealth,
        armor       = char.armor  or 0,
    }
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- RESPAWN
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RegisterNetEvent("union:spawn:requestRespawn", function(model)
    local src    = source
    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter then return end

    -- FIX #2 : vérification connexion
    if not isConnected(src) then return end

    local char = player.currentCharacter
    TriggerClientEvent("union:spawn:apply", src, {
        id        = char.id,
        unique_id = char.unique_id,
        model     = model or char.model or Config.spawn.defaultModel,
        position  = Config.spawn.defaultPosition,
        heading   = Config.spawn.defaultHeading,
        health    = Config.character.defaultHealth,
        armor     = 0,
    })
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CONFIRMATION CLIENT → SPAWN RÉUSSI
-- FIX #1 : guard anti-double avec session ID
-- FIX #4 : nettoyage immédiat à playerDropped
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RegisterNetEvent("union:spawn:confirm", function(uniqueId)
    local src    = source
    local player = PlayerManager.get(src)
    if not player then return end

    -- FIX #1 : guard strict — si déjà en cours de confirmation, ignorer
    if SpawnHandler._confirming[src] then
        SpawnHandler.logger:warn("Double confirm ignoré pour src=" .. src)
        return
    end
    SpawnHandler._confirming[src] = true

    player.isSpawned = true
    SpawnHandler.logger:info("Spawn confirmé pour " .. player.name)

    -- Supprimer le ped offline si présent
    if player.currentCharacter and player.currentCharacter.unique_id then
        if OfflinePed then
            OfflinePed.remove(player.currentCharacter.unique_id)
        end
    end

    -- Event serveur-local (écouté par status/manager.lua et offline_ped.lua)
    TriggerEvent("union:player:spawned", src, player.currentCharacter)

    -- FIX #2 : vérification connexion avant TriggerClientEvent
    if isConnected(src) then
        TriggerClientEvent("union:player:spawned", src, player.currentCharacter)
    end

    -- FIX #1 : reset du guard après 3s (SetTimeout FiveM est disponible côté serveur)
    SetTimeout(3000, function()
        SpawnHandler._confirming[src] = nil
    end)
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ERREUR CÔTÉ CLIENT
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RegisterNetEvent("union:spawn:error", function(errorType)
    local src = source
    SpawnHandler.logger:error(("Erreur spawn [%s]: %s"):format(src, tostring(errorType)))
    -- FIX #4 : nettoyage immédiat
    SpawnHandler._confirming[src] = nil
end)

-- FIX #4 : nettoyage IMMÉDIAT à la déconnexion (pas de SetTimeout)
AddEventHandler("playerDropped", function()
    local src = source
    SpawnHandler._confirming[src] = nil
    SpawnHandler._sessions[src]   = nil
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- HELPERS PUBLICS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function SpawnHandler.applyCharacter(player, characterData)
    if not player or not characterData then return false end
    -- FIX #2 : vérification connexion
    if not isConnected(player.source) then return false end
    TriggerClientEvent("union:spawn:apply", player.source, characterData)
    return true
end

AddEventHandler("union:player:spawned", function(src, character)
    SpawnHandler.logger:info(("union:player:spawned confirmé src=%s"):format(tostring(src)))
end)

return SpawnHandler
