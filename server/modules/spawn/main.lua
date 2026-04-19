-- server/modules/spawn/main.lua
Spawn = {}
Spawn.logger = Logger:child("SPAWN")

function Spawn.requestInitial(player)
    if not player or not player.source then
        Spawn.logger:error("Invalid player for initial spawn")
        return
    end
    
    if #player.characters == 0 then
        -- No characters, request character creation
        TriggerClientEvent("union:spawn:noCharacters", player.source)
    else
        -- Has characters, show selection
        TriggerClientEvent("union:spawn:selectCharacter", player.source, player.characters)
    end
end

function Spawn.requestRespawn(player, model)
    if not player or not player.currentCharacter then
        Spawn.logger:error("Cannot respawn: invalid player or no character selected")
        return
    end
    
    local pos, heading = Spawn.getSpawnPosition(player)
    local charData = {
        model = model or player.currentCharacter.model or Config.spawn.defaultModel,
        position = pos,
        heading = heading,
    }
    
    TriggerClientEvent("union:spawn:apply", player.source, charData)
end

function Spawn.getSpawnPosition(player)
    if not player or not player.currentCharacter then
        return Config.spawn.defaultPosition, Config.spawn.defaultHeading
    end
    
    local char = player.currentCharacter
    
    -- If character has saved position and it's not (0,0,0), use it
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
    else
        Spawn.logger:warn("Respawn requested by invalid player: " .. source)
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
        -- Respawn with fallback model
        Spawn.requestRespawn(player, "a_m_y_beach_01")
    end
end)

return Spawn