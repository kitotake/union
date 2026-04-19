-- server/modules/character/select.lua
CharacterSelect = {}
CharacterSelect.logger = Logger:child("CHARACTER:SELECT")

function CharacterSelect.isAvailable(characterId)
    -- Check if character is not already in use
    for _, player in pairs(PlayerManager.getAll()) do
        if player.currentCharacter and player.currentCharacter.id == characterId then
            return false
        end
    end
    return true
end

function CharacterSelect.getLoadPosition(character)
    if character.position_x and character.position_y and character.position_z then
        return vector3(character.position_x, character.position_y, character.position_z)
    end
    return Config.spawn.defaultPosition
end

return CharacterSelect