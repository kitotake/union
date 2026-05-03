-- server/modules/spawn/handler.lua
-- FIXES:
--   #1 : union:spawn:confirm déclenche TriggerEvent("union:player:spawned")
--        UNIQUEMENT depuis le serveur — c'est ce TriggerEvent qui notifie
--        manager.lua (StatusManager.load) et offline_ped (OfflinePed.remove).
--   #2 : Guard ajouté pour éviter un double confirm du même joueur.

SpawnHandler        = {}
SpawnHandler.logger = Logger:child("SPAWN:HANDLER")

-- FIX #2 : guard anti-double confirm
SpawnHandler._confirming = {}

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- INITIAL SPAWN
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

    local chars = player.characters or {}

    if #chars == 0 then
        SpawnHandler.logger:info(("Joueur %s : 0 personnage → création"):format(player.name))
        TriggerClientEvent("union:spawn:noCharacters", src)
        TriggerClientEvent("kt_character:openCreator", src)
        return
    end

    if #chars == 1 then
        SpawnHandler.logger:info(("Joueur %s : 1 personnage → spawn automatique"):format(player.name))
        Character.select(player, chars[1].id, function(success)
            if not success then
                SpawnHandler.logger:error("Auto-select échoué pour " .. player.name)
                TriggerClientEvent("union:spawn:apply", src, SpawnHandler._buildCharData(chars[1]))
            end
        end)
        return
    end

    SpawnHandler.logger:info(("Joueur %s : %d personnages → sélection NUI"):format(player.name, #chars))
    TriggerClientEvent("union:spawn:selectCharacter", src, chars)
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

    local model = char.model or ""
    if model ~= "mp_m_freemode_01" and model ~= "mp_f_freemode_01" then
        model = (char.gender == "f") and Config.spawn.femaleModel or Config.spawn.defaultModel
    end

    return {
        id          = char.id,
        unique_id   = char.unique_id,
        firstname   = char.firstname,
        lastname    = char.lastname,
        gender      = char.gender,
        model       = model,
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
-- FIX #1 : TriggerEvent serveur-local pour notifier manager.lua et offline_ped
-- FIX #2 : guard anti-double confirm
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RegisterNetEvent("union:spawn:confirm", function(uniqueId)
    local src    = source
    local player = PlayerManager.get(src)
    if not player then return end

    -- FIX #2 : éviter le double traitement
    if SpawnHandler._confirming[src] then
        SpawnHandler.logger:warn("Double confirm ignoré pour src=" .. src)
        return
    end
    SpawnHandler._confirming[src] = true

    player.isSpawned = true
    SpawnHandler.logger:info("Spawn confirmé pour " .. player.name)

    -- Supprimer le ped offline si présent
    if player.currentCharacter and player.currentCharacter.unique_id then
        OfflinePed.remove(player.currentCharacter.unique_id)
    end

    -- FIX #1 : TriggerEvent LOCAL (serveur → serveur) pour déclencher
    -- manager.lua (StatusManager.load via "union:player:spawned" handler)
    TriggerEvent("union:player:spawned", src, player.currentCharacter)

    -- Notifier le client (HUD, StateBags, etc.)
    TriggerClientEvent("union:player:spawned", src, player.currentCharacter)

    -- Reset du guard après 2 secondes
    SetTimeout(2000, function()
        SpawnHandler._confirming[src] = nil
    end)
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ERREUR CÔTÉ CLIENT
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RegisterNetEvent("union:spawn:error", function(errorType)
    local src = source
    SpawnHandler.logger:error(("Erreur spawn [%s]: %s"):format(src, tostring(errorType)))
    SpawnHandler._confirming[src] = nil
end)

-- Nettoyage à la déconnexion
AddEventHandler("playerDropped", function()
    SpawnHandler._confirming[source] = nil
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- HELPERS PUBLICS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function SpawnHandler.applyCharacter(player, characterData)
    if not player or not characterData then return false end
    TriggerClientEvent("union:spawn:apply", player.source, characterData)
    return true
end

AddEventHandler("union:player:spawned", function(src, character)
    SpawnHandler.logger:info(("union:player:spawned confirmé src=%s"):format(tostring(src)))
end)

return SpawnHandler
