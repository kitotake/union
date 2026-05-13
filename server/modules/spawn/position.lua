-- server/modules/spawn/position.lua
-- FIX #D : suppression de "heading" dans le SELECT (colonne inexistante).
-- FIX NOTE-4 : ajout d'un cooldown anti-flood sur union:position:save.
--   Sans protection, un client malveillant peut envoyer cet event en boucle
--   et saturer la base de données. On refuse les saves trop rapprochés
--   (< Config.spawn.saveInterval / 10, ou 3s minimum).

SpawnPosition = {}
SpawnPosition.logger = Logger:child("SPAWN:POSITION")

-- Timestamps de la dernière sauvegarde par source
local _lastSave    = {}
local MIN_INTERVAL = 3000  -- 3 secondes minimum entre deux saves position

function SpawnPosition.save(player, position, heading)
    if not player then return false end

    if not player.currentCharacter then
        SpawnPosition.logger:debug("Position non sauvegardée : aucun personnage pour " .. (player.name or "?"))
        return false
    end

    if not position then
        SpawnPosition.logger:warn("Position nil pour " .. player.name)
        return false
    end

    local posJson = json.encode({
        x       = position.x,
        y       = position.y,
        z       = position.z,
        heading = heading or 0.0
    })

    -- Mise à jour de la position en mémoire (utilisée par Persistence.savePlayer)
    player.currentCharacter.position = {
        x       = position.x,
        y       = position.y,
        z       = position.z,
        heading = heading or 0.0,
    }
    player.currentCharacter.heading = heading or 0.0

    Database.execute([[
        UPDATE characters SET position = ?
        WHERE unique_id = ?
    ]], {
        posJson,
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
    -- FIX #D : retrait de "heading" du SELECT
    Database.fetchOne(
        "SELECT position FROM characters WHERE unique_id = ?",
        { uniqueId },
        function(result)
            if result and result.position then
                local ok, p = pcall(json.decode, result.position)
                if ok and p and p.x then
                    local position = vector3(p.x, p.y, p.z)
                    local heading  = p.heading or Config.spawn.defaultHeading
                    if callback then callback(position, heading) end
                    return
                end
            end
            if callback then callback(Config.spawn.defaultPosition, Config.spawn.defaultHeading) end
        end
    )
end

function SpawnPosition.isValid(position)
    if not position then return false end
    if position.x == 0 and position.y == 0 and position.z == 0 then return false end
    return true
end

-- FIX NOTE-4 : cooldown anti-flood
RegisterNetEvent("union:position:save", function(position, heading)
    local src = source

    -- Anti-flood : ignorer si trop fréquent
    local now = GetGameTimer()
    if _lastSave[src] and (now - _lastSave[src]) < MIN_INTERVAL then
        return
    end
    _lastSave[src] = now

    local player = PlayerManager.get(src)
    if not player then return end
    if not player.currentCharacter then return end
    if not position then return end

    SpawnPosition.save(player, position, heading)
    TriggerClientEvent("union:position:loaded", src, position, heading)
end)

-- Nettoyage à la déco
AddEventHandler("union:player:dropping", function(src)
    _lastSave[src] = nil
end)

return SpawnPosition