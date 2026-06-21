-- server/modules/character/selection/select.lua
CharacterSelect = {}
CharacterSelect.logger = Logger:child("CHARACTER:SELECT")

function CharacterSelect.isAvailable(characterId)
    for _, player in pairs(PlayerManager.getAll()) do
        if player.currentCharacter and player.currentCharacter.id == characterId then
            return false
        end
    end
    return true
end

return CharacterSelect
