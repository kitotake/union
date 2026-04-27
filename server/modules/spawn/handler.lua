-- server/modules/spawn/handler.lua
-- FIX #1 : suppression du double routing.
--           characters:playerReady (characterManager.lua) ET union:spawn:requestInitial
--           faisaient la même chose. On garde UNIQUEMENT union:spawn:requestInitial ici.
--           characterManager.lua est conservé pour le flow NUI (autoSpawn, openSelection, openCreation).

SpawnHandler        = {}
SpawnHandler.logger = Logger:child("SPAWN:HANDLER")

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- INITIAL SPAWN — déclenché par le client après handler.lua
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RegisterNetEvent("union:spawn:requestInitial", function()
    local src    = source
    local player = PlayerManager.get(src)

    if not player then
        SpawnHandler.logger:error("requestInitial: joueur introuvable pour source " .. src)
        return
    end

    -- Attendre que le joueur soit chargé (cas rare de timing)
    if player.isLoading then
        local waited = 0
        while player.isLoading and waited < 50 do
            Wait(100)
            waited = waited + 1
        end
    end

    local chars = player.characters or {}

    -- ── Cas 0 : aucun personnage → création ──────────────────────────
    if #chars == 0 then
        SpawnHandler.logger:info(("Joueur %s : 0 personnage → création"):format(player.name))
        TriggerClientEvent("union:spawn:noCharacters", src)
        TriggerClientEvent("kt_character:openCreator", src)
        return
    end

    -- ── Cas 1 : un seul personnage → spawn automatique ───────────────
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

    -- ── Cas 2 : plusieurs personnages → menu de sélection NUI ────────
    SpawnHandler.logger:info(("Joueur %s : %d personnages → sélection NUI"):format(player.name, #chars))
    TriggerClientEvent("union:spawn:selectCharacter", src, chars)
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- HELPERS INTERNES
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
-- FIX : OfflinePed.remove() après confirmation réelle client
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RegisterNetEvent("union:spawn:confirm", function()
    local src    = source
    local player = PlayerManager.get(src)
    if not player then return end

    player.isSpawned = true
    SpawnHandler.logger:info("Spawn confirmé pour " .. player.name)

    if player.currentCharacter and player.currentCharacter.unique_id then
        OfflinePed.remove(player.currentCharacter.unique_id)
    end

    TriggerEvent("union:player:spawned", src, player.currentCharacter)
    TriggerClientEvent("union:player:spawned", src, player.currentCharacter)
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ERREUR CÔTÉ CLIENT
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RegisterNetEvent("union:spawn:error", function(errorType)
    local src = source
    SpawnHandler.logger:error(("Erreur spawn [%s]: %s"):format(src, tostring(errorType)))
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
    SpawnHandler.logger:info(("union:player:spawned src=%s"):format(tostring(src)))
end)

return SpawnHandler