-- server/modules/spawn/main.lua
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- FIX: getSpawnPosition lit la colonne `position` JSON
-- FIX: patch kt_character pour ouvrir le creator si aucun personnage
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Spawn = {}
Spawn.logger = Logger:child("SPAWN")

-- ─── Décode un champ position JSON ────────────────────────────────────────
local function decodePosition(raw)
    if not raw then
        return Config.spawn.defaultPosition, Config.spawn.defaultHeading
    end
    local ok, p = pcall(json.decode, tostring(raw))
    if ok and p and p.x then
        return vector3(p.x, p.y, p.z), (p.heading or Config.spawn.defaultHeading)
    end
    return Config.spawn.defaultPosition, Config.spawn.defaultHeading
end

-- ─── Spawn initial ────────────────────────────────────────────────────────
function Spawn.requestInitial(player)
    if not player or not player.source then
        Spawn.logger:error("Invalid player for initial spawn")
        return
    end

    if #player.characters == 0 then
        -- Aucun personnage → ouvrir le creator kt_character
        Spawn.logger:info("No characters for " .. player.name .. " → opening kt_character creator")
        TriggerClientEvent("kt_character:openCreator", player.source)
    elseif #player.characters == 1 then
        -- Un seul personnage → auto-select
        Spawn.logger:info("1 character found, auto-selecting for " .. player.name)
        Character.select(player, player.characters[1].id, function() end)
    else
        -- Plusieurs personnages → menu de sélection
        TriggerClientEvent("union:spawn:selectCharacter", player.source, player.characters)
    end
end

-- ─── Respawn ──────────────────────────────────────────────────────────────
function Spawn.requestRespawn(player, model)
    if not player or not player.currentCharacter then
        Spawn.logger:error("Cannot respawn: invalid player or no character selected")
        return
    end

    local pos, heading = Spawn.getSpawnPosition(player)
    local charData = {
        unique_id = player.currentCharacter.unique_id,
        model     = model or player.currentCharacter.model or Config.spawn.defaultModel,
        position  = pos,
        heading   = heading,
        health    = player.currentCharacter.health or Config.character.defaultHealth,
        armor     = player.currentCharacter.armor  or 0,
    }

    TriggerClientEvent("union:spawn:apply", player.source, charData)
end

-- ─── Récupération de la position depuis la colonne JSON ───────────────────
-- FIX: ne lit plus position_x/y/z (colonnes supprimées après migration SQL)
function Spawn.getSpawnPosition(player)
    if not player or not player.currentCharacter then
        return Config.spawn.defaultPosition, Config.spawn.defaultHeading
    end

    local char = player.currentCharacter

    -- Nouvelle colonne JSON
    if char.position then
        local pos, hdg = decodePosition(char.position)
        return pos, hdg
    end

    -- Fallback : anciennes colonnes séparées (avant migration)
    if char.position_x and char.position_x ~= 0 then
        return vector3(char.position_x, char.position_y, char.position_z),
               char.heading or Config.spawn.defaultHeading
    end

    return Config.spawn.defaultPosition, Config.spawn.defaultHeading
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- NET EVENTS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RegisterNetEvent("union:spawn:requestInitial", function()
    local source = source
    local player = PlayerManager.get(source)
    if player then
        Spawn.requestInitial(player)
    else
        Spawn.logger:warn("Initial spawn requested by invalid player: " .. source)
    end
end)

RegisterNetEvent("union:spawn:requestRespawn", function(model)
    local source = source
    local player = PlayerManager.get(source)
    if player then
        Spawn.requestRespawn(player, model)
    end
end)

RegisterNetEvent("union:spawn:confirm", function()
    local source = source
    local player = PlayerManager.get(source)
    if player then
        player.isSpawned = true
        Spawn.logger:info("Player " .. player.name .. " spawn confirmed")
        TriggerEvent("union:player:spawned", source, player.currentCharacter)
    end
end)

RegisterNetEvent("union:spawn:error", function(errorType)
    local source = source
    local player = PlayerManager.get(source)
    if player then
        Spawn.logger:error("Spawn error for " .. player.name .. ": " .. tostring(errorType))
        -- Fallback : respawn avec modèle de base
        Spawn.requestRespawn(player, Config.spawn.defaultModel)
    end
end)

return Spawn