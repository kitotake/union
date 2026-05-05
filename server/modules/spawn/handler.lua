-- server/modules/spawn/handler.lua
-- FIXES:
--   #1 : _confirming[src] nettoyé dans playerDropped → plus de blocage si crash entre
--        union:spawn:apply et union:spawn:confirm.
--   #2 : SpawnHandler._confirming reset correctement sans dépendre du SetTimeout seul.
--   #3 : requestInitial — guard si joueur déjà spawné (double-connect ou reconnect rapide).

SpawnHandler        = {}
SpawnHandler.logger = Logger:child("SPAWN:HANDLER")

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

    -- FIX #3 : si déjà spawné (reconnect rapide / double event), ignorer
    if player.isSpawned then
        SpawnHandler.logger:warn(("requestInitial ignoré — joueur déjà spawné src=%d"):format(src))
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
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RegisterNetEvent("union:spawn:confirm", function(uniqueId)
    local src    = source
    local player = PlayerManager.get(src)
    if not player then return end

    if SpawnHandler._confirming[src] then
        SpawnHandler.logger:warn("Double confirm ignoré pour src=" .. src)
        return
    end
    SpawnHandler._confirming[src] = true

    player.isSpawned = true
    SpawnHandler.logger:info("Spawn confirmé pour " .. player.name)

    if player.currentCharacter and player.currentCharacter.unique_id then
        if OfflinePed then
            OfflinePed.remove(player.currentCharacter.unique_id)
        end
    end

    TriggerEvent("union:player:spawned", src, player.currentCharacter)
    TriggerClientEvent("union:player:spawned", src, player.currentCharacter)

    -- FIX #2 : reset après 2s mais playerDropped nettoie aussi (voir ci-dessous)
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

-- FIX #1 : nettoyage complet à la déconnexion
-- Couvre le cas où le joueur crashe entre union:spawn:apply et union:spawn:confirm
AddEventHandler("playerDropped", function()
    local src = source
    SpawnHandler._confirming[src] = nil
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
