-- server/modules/spawn/main.lua
-- FIX #1 : les handlers union:spawn:requestInitial, requestRespawn, confirm et error
--           étaient dupliqués ici ET dans handler.lua.
--           Ce fichier ne contient plus que les helpers — toute la logique
--           d'events est dans handler.lua pour éviter que le second handler
--           écrase le premier (et casse le redirect vers la sélection de perso).

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

function Spawn.removeState(player)
    if player then
        SpawnHandler.removeCharacterState(player)
    end
end

function Spawn.getModel(player)
    if not player then return nil end
    return SpawnHandler.getCharacterModel(player)
end

return Spawn