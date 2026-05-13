-- server/modules/character/select.lua
-- FIX NOTE-1 : getLoadPosition() utilisait character.position_x/y/z (colonnes
--              inexistantes — la position est stockée en JSON dans la colonne
--              "position"). Fonction supprimée car dead code : jamais appelée
--              dans le flow principal (Character.select dans main.lua gère
--              lui-même le décodage de la position JSON).
-- La seule fonction utile, isAvailable(), est conservée et utilisée maintenant
-- dans characterManager.lua (FIX CRIT-6).

CharacterSelect = {}
CharacterSelect.logger = Logger:child("CHARACTER:SELECT")

-- Vérifie qu'aucun joueur connecté n'a déjà ce personnage actif.
-- Appelée dans characters:selectCharacter (characterManager.lua).
function CharacterSelect.isAvailable(characterId)
    for _, player in pairs(PlayerManager.getAll()) do
        if player.currentCharacter and player.currentCharacter.id == characterId then
            return false
        end
    end
    return true
end

return CharacterSelect