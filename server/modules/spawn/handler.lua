-- server/modules/spawn/handler.lua
-- FIX #1  : ce fichier est l'unique endroit où les NetEvents spawn sont enregistrés.
--            Les doublons de spawn/main.lua ont été supprimés.
-- FIX #2  : le handler playerDropped qui créait le ped offline est SUPPRIMÉ ici.
--            La création du ped est faite UNE SEULE FOIS dans player/manager.lua.
-- FIX #3  : union:player:spawned est maintenant un AddEventHandler (local serveur)
--            et non un RegisterNetEvent (client → serveur).
-- FIX #4  : la suppression du ped offline est faite directement dans union:spawn:confirm
--            pour garantir que ça arrive APRÈS confirmation client du spawn.

SpawnHandler        = {}
SpawnHandler.logger = Logger:child("SPAWN:HANDLER")

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- INITIAL SPAWN
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RegisterNetEvent("union:spawn:requestInitial", function()
    local src    = source
    local player = PlayerManager.get(src)

    if not player then
        SpawnHandler.logger:error("requestInitial: joueur introuvable pour source " .. src)
        return
    end

    -- Aucun personnage → redirige vers création
    if not player.characters or #player.characters == 0 then
        TriggerClientEvent("union:spawn:noCharacters", src)
        return
    end

    -- A déjà un personnage sélectionné (respawn / retour de menu)
    if player.currentCharacter then
        TriggerClientEvent("union:spawn:apply", src, player.currentCharacter)
        return
    end

    -- Sinon → afficher la sélection de personnage
    TriggerClientEvent("union:spawn:selectCharacter", src, player.characters)
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- RESPAWN
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RegisterNetEvent("union:spawn:requestRespawn", function(model)
    local src    = source
    local player = PlayerManager.get(src)

    if not player or not player.currentCharacter then return end

    local char = player.currentCharacter

    local charData = {
        id        = char.id,
        unique_id = char.unique_id,
        model     = model or char.model or Config.spawn.defaultModel,
        position  = Config.spawn.defaultPosition,
        heading   = Config.spawn.defaultHeading,
        health    = Config.character.defaultHealth,
        armor     = 0,
    }

    TriggerClientEvent("union:spawn:apply", src, charData)
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CONFIRMATION CLIENT → SPAWN RÉUSSI
-- FIX #4 : suppression ped offline faite ici, après confirmation réelle du client
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RegisterNetEvent("union:spawn:confirm", function()
    local src    = source
    local player = PlayerManager.get(src)

    if not player then return end

    player.isSpawned = true
    SpawnHandler.logger:info("Spawn confirmé pour " .. player.name)

    -- FIX #4 : supprimer le ped offline ICI (après confirmation client)
    -- et non dans Character.select (trop tôt, avant que le client ait spawné)
    if player.currentCharacter and player.currentCharacter.unique_id then
        OfflinePed.remove(player.currentCharacter.unique_id)
    end

    TriggerEvent("union:player:spawned", src, player.currentCharacter)
    TriggerClientEvent("union:player:spawned", src, player.currentCharacter)
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ERREUR CÔTÉ CLIENT
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RegisterNetEvent("union:spawn:error", function(errorType)
    local src = source
    SpawnHandler.logger:error(("Erreur spawn client [%s]: %s"):format(src, tostring(errorType)))
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- FIX #3 : AddEventHandler LOCAL (pas RegisterNetEvent)
-- pour écouter l'event serveur union:player:spawned déclenché par TriggerEvent
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
AddEventHandler("union:player:spawned", function(src, character)
    -- Le ped offline est déjà supprimé dans union:spawn:confirm ci-dessus.
    -- Ce handler reste disponible pour que d'autres modules (inventory, etc.)
    -- puissent écouter l'événement de spawn.
    SpawnHandler.logger:info(("union:player:spawned déclenché pour src=%s"):format(tostring(src)))
end)

-- FIX #2 : SUPPRIMÉ — le handler playerDropped qui créait OfflinePed.create
-- est retiré ici. Il existe déjà dans player/manager.lua → une seule création.

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- HELPERS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function SpawnHandler.applyCharacter(player, characterData)
    if not player or not characterData then return false end
    TriggerClientEvent("union:spawn:apply", player.source, characterData)
    return true
end

return SpawnHandler