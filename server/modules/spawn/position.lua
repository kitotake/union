-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- PATCH server/modules/spawn/position.lua (Union)
-- Fix : [WARN|SPAWN:POSITION] Cannot save position: invalid parameters
-- Cause : player.currentCharacter est nil quand la position est reçue
--         (ex : la sauvegarde auto se déclenche avant la sélection de perso)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SpawnPosition = {}
SpawnPosition.logger = Logger:child("SPAWN:POSITION")

function SpawnPosition.save(player, position, heading)
    if not player then
        -- Silencieux : joueur pas encore chargé, normal en début de session
        return false
    end

    if not player.currentCharacter then
        -- Pas d'avertissement si le joueur n'a simplement pas encore sélectionné
        -- un personnage (état normal après connexion)
        SpawnPosition.logger:debug("Position non sauvegardée : aucun personnage sélectionné pour " .. (player.name or "?"))
        return false
    end

    if not position then
        SpawnPosition.logger:warn("Position nil pour " .. player.name)
        return false
    end

    Database.execute([[
        UPDATE characters SET
        position_x = ?, position_y = ?, position_z = ?, heading = ?
        WHERE unique_id = ?
    ]], {
        position.x, position.y, position.z, heading or 0.0,
        player.currentCharacter.unique_id
    }, function(result)
        if result then
            SpawnPosition.logger:debug("Position saved for " .. player.name)
        else
            SpawnPosition.logger:error("Failed to save position for " .. player.name)
        end
    end)

    return true
end

function SpawnPosition.load(uniqueId, callback)
    Database.fetchOne(
        "SELECT position_x, position_y, position_z, heading FROM characters WHERE unique_id = ?",
        {uniqueId},
        function(result)
            if result then
                local position = vector3(result.position_x, result.position_y, result.position_z)
                local heading = result.heading or Config.spawn.defaultHeading
                if callback then callback(position, heading) end
            else
                if callback then callback(Config.spawn.defaultPosition, Config.spawn.defaultHeading) end
            end
        end
    )
end

function SpawnPosition.isValid(position)
    if not position then return false end
    if position.x == 0 and position.y == 0 and position.z == 0 then return false end
    return true
end

RegisterNetEvent("union:position:save", function(position, heading)
    local source = source
    local player = PlayerManager.get(source)

    -- FIX : vérification silencieuse si pas de perso, pas de WARN spam
    if not player then return end
    if not player.currentCharacter then
        -- Ignorer silencieusement, c'est normal avant la sélection
        return
    end
    if not position then return end

    SpawnPosition.save(player, position, heading)
    -- Renvoyer la position confirmée au client
    TriggerClientEvent("union:position:loaded", source, position, heading)
end)

return SpawnPosition