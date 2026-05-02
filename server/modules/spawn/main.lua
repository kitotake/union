-- server/modules/spawn/main.lua
-- FIX #12 : suppression des appels vers SpawnHandler.removeCharacterState()
--           et SpawnHandler.getCharacterModel() qui n'existent pas dans handler.lua
-- Ce fichier ne contient que des helpers — toute la logique est dans handler.lua

Spawn        = {}
Spawn.logger = Logger:child("SPAWN")

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- HELPERS (utilisés par d'autres modules)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function Spawn.applyToPlayer(player, characterData)
    if not player or not characterData then
        Spawn.logger:error("applyToPlayer: paramètres invalides")
        return false
    end
    return SpawnHandler.applyCharacter(player, characterData)
end

-- FIX #12 : removeState et getModel supprimés — fonctions inexistantes dans handler.lua
-- Si ces fonctionnalités sont nécessaires à l'avenir, les implémenter dans handler.lua d'abord.

return Spawn