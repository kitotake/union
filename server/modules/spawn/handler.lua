-- server/modules/spawn/handler.lua
SpawnHandler = {}
SpawnHandler.logger = Logger:child("SPAWN:HANDLER")

function SpawnHandler.applyCharacter(player, characterData)
    if not player or not characterData then
        SpawnHandler.logger:error("Invalid spawn parameters")
        return false
    end
    
    -- Ensure model is valid
    if not characterData.model then
        characterData.model = Config.spawn.defaultModel
    end
    
    -- Ensure position is valid
    if not characterData.position then
        characterData.position = Config.spawn.defaultPosition
    end
    
    -- Ensure heading is valid
    if not characterData.heading then
        characterData.heading = Config.spawn.defaultHeading
    end
    
    TriggerClientEvent("union:spawn:apply", player.source, characterData)
    
    return true
end

function SpawnHandler.removeCharacterState(player)
    if player then
        player.currentCharacter = nil
        player.isSpawned = false
    end
end

function SpawnHandler.getCharacterModel(player)
    if player and player.currentCharacter then
        return player.currentCharacter.model or Config.spawn.defaultModel
    end
    return Config.spawn.defaultModel
end

return SpawnHandler