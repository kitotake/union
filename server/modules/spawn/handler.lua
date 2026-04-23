-- server/modules/spawn/handler.lua
-- Gestion du spawn côté serveur : reçoit les events du client et orchestre
-- la sélection initiale du personnage ou le re-spawn.

SpawnHandler        = {}
SpawnHandler.logger = Logger:child("SPAWN:HANDLER")

-- ──────────────────────────────────────────────────────────────────────────
-- EVENT : union:spawn:requestInitial
-- Déclenché par le client après que union:player:loaded a été reçu.
-- ──────────────────────────────────────────────────────────────────────────
RegisterNetEvent("union:spawn:requestInitial", function()
    local src    = source
    local player = PlayerManager.get(src)

    if not player then
        SpawnHandler.logger:error("requestInitial: joueur introuvable pour " .. src)
        return
    end

    -- Si le joueur n'a aucun personnage → lui proposer d'en créer un
    if not player.characters or #player.characters == 0 then
        TriggerClientEvent("union:spawn:noCharacters", src)
        return
    end

    -- Sinon → lui envoyer la liste pour qu'il choisisse
    TriggerClientEvent("union:spawn:selectCharacter", src, player.characters)
end)

-- ──────────────────────────────────────────────────────────────────────────
-- EVENT : union:spawn:requestRespawn
-- Re-spawn demandé (mort, erreur modèle…)
-- ──────────────────────────────────────────────────────────────────────────
RegisterNetEvent("union:spawn:requestRespawn", function(model)
    local src    = source
    local player = PlayerManager.get(src)

    if not player or not player.currentCharacter then
        SpawnHandler.logger:warn("requestRespawn: pas de personnage actif pour " .. src)
        return
    end

    local charData = {
        id          = player.currentCharacter.id,
        unique_id   = player.currentCharacter.unique_id,
        firstname   = player.currentCharacter.firstname,
        lastname    = player.currentCharacter.lastname,
        gender      = player.currentCharacter.gender,
        model       = model or player.currentCharacter.model or Config.spawn.defaultModel,
        position    = Config.spawn.defaultPosition,
        heading     = Config.spawn.defaultHeading,
        health      = Config.character.defaultHealth,
        armor       = 0,
    }

    TriggerClientEvent("union:spawn:apply", src, charData)
end)

-- ──────────────────────────────────────────────────────────────────────────
-- EVENT : union:spawn:confirm
-- Le client confirme que le spawn est terminé.
-- On déclenche union:player:spawned pour que kt_inventory charge l'inventaire.
-- ──────────────────────────────────────────────────────────────────────────
RegisterNetEvent("union:spawn:confirm", function()
    local src    = source
    local player = PlayerManager.get(src)

    if not player then return end

    player.isSpawned = true
    SpawnHandler.logger:info("Spawn confirmé pour " .. player.name)

    -- Charger l'inventaire kt_inventory si disponible
    if UnionInventory and player.currentCharacter then
        UnionInventory.loadForPlayer(player)
    end

    -- Event générique pour les autres modules
    TriggerEvent("union:player:spawned", src)
    TriggerClientEvent("union:player:spawned", src)
end)

-- ──────────────────────────────────────────────────────────────────────────
-- EVENT : union:spawn:error  (reçu depuis le client)
-- ──────────────────────────────────────────────────────────────────────────
RegisterNetEvent("union:spawn:error", function(errorType)
    local src = source
    SpawnHandler.logger:error("Erreur de spawn pour " .. src .. " : " .. tostring(errorType))
end)

-- ──────────────────────────────────────────────────────────────────────────
-- Helpers publics
-- ──────────────────────────────────────────────────────────────────────────
function SpawnHandler.applyCharacter(player, characterData)
    if not player or not characterData then
        SpawnHandler.logger:error("Paramètres de spawn invalides")
        return false
    end

    characterData.model    = characterData.model    or Config.spawn.defaultModel
    characterData.position = characterData.position or Config.spawn.defaultPosition
    characterData.heading  = characterData.heading  or Config.spawn.defaultHeading

    TriggerClientEvent("union:spawn:apply", player.source, characterData)
    return true
end

function SpawnHandler.removeCharacterState(player)
    if player then
        player.currentCharacter = nil
        player.isSpawned        = false
    end
end

function SpawnHandler.getCharacterModel(player)
    if player and player.currentCharacter then
        return player.currentCharacter.model or Config.spawn.defaultModel
    end
    return Config.spawn.defaultModel
end

return SpawnHandler