-- server/modules/spawn/main.lua  (Union Framework)
-- FIX: Character.select charge le skin AVANT TriggerClientEvent union:spawn:apply
--      (déjà fait dans character/main.lua, ici on s'assure que le flow est propre)
-- FIX: last_login supprimé (ping inutile à chaque chargement joueur)

Spawn = {}
Spawn.logger = Logger:child("SPAWN")

function Spawn.requestInitial(player)
    if not player or not player.source then
        Spawn.logger:error("Invalid player for initial spawn")
        return
    end

    if #player.characters == 0 then
        Spawn.logger:info("No characters for " .. player.name .. " → opening kt_character creator")
        TriggerClientEvent("kt_character:openCreator", player.source)
    else
        if #player.characters == 1 then
            Spawn.logger:info("1 character found, auto-selecting for " .. player.name)
            Character.select(player, player.characters[1].id, function() end)
        else
            TriggerClientEvent("union:spawn:selectCharacter", player.source, player.characters)
        end
    end
end

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

function Spawn.getSpawnPosition(player)
    if not player or not player.currentCharacter then
        return Config.spawn.defaultPosition, Config.spawn.defaultHeading
    end

    local char = player.currentCharacter

    if char.position_x and char.position_x ~= 0 then
        return vector3(char.position_x, char.position_y, char.position_z),
               char.heading or Config.spawn.defaultHeading
    end

    return Config.spawn.defaultPosition, Config.spawn.defaultHeading
end

-- Network events
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
        Spawn.logger:error("Spawn error for " .. player.name .. ": " .. errorType)
        Spawn.requestRespawn(player, "a_m_y_beach_01")
    end
end)

return Spawn