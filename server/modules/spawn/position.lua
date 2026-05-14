-- server/modules/spawn/position.lua
-- FIX SAVE-4 : health, armor, is_dead reçus et sauvegardés avec la position.
-- FIX SAVE-5 : UPDATE immédiat en BDD à chaque réception (plus de lazy save).
-- FIX NOTE-4 : anti-flood 3s minimum entre deux saves par joueur.

SpawnPosition        = {}
SpawnPosition.logger = Logger:child("SPAWN:POSITION")

local _lastSave    = {}
local MIN_INTERVAL = 3000  -- 3 secondes minimum entre deux saves

function SpawnPosition.save(player, position, heading, health, armor, isDead)
    if not player or not player.currentCharacter then return false end
    if not position then
        SpawnPosition.logger:warn("Position nil pour " .. (player.name or "?"))
        return false
    end

    local posJson = json.encode({
        x       = position.x,
        y       = position.y,
        z       = position.z,
        heading = heading or 0.0,
    })

    -- Mise à jour en mémoire (utilisée par Persistence et manager à la déco)
    player.currentCharacter.position = {
        x       = position.x,
        y       = position.y,
        z       = position.z,
        heading = heading or 0.0,
    }
    player.currentCharacter.heading = heading or 0.0

    if health ~= nil then player.currentCharacter.health  = health        end
    if armor  ~= nil then player.currentCharacter.armor   = armor         end
    if isDead ~= nil then player.currentCharacter.is_dead = isDead and 1 or 0 end

    local hp   = player.currentCharacter.health  or 200
    local arm  = player.currentCharacter.armor   or 0
    local dead = player.currentCharacter.is_dead or 0

    -- UPDATE immédiat en BDD
    Database.execute([[
        UPDATE characters
        SET position = ?, health = ?, armor = ?, is_dead = ?, last_played = NOW()
        WHERE unique_id = ?
    ]], {
        posJson, hp, arm, dead,
        player.currentCharacter.unique_id
    }, function(result)
        if result then
            SpawnPosition.logger:debug(("Saved %s | pos=%.1f,%.1f | HP=%d Armor=%d Dead=%d"):format(
                player.name, position.x, position.y, hp, arm, dead
            ))
        else
            SpawnPosition.logger:error("Échec save pour " .. player.name)
        end
    end)

    return true
end

function SpawnPosition.load(uniqueId, callback)
    Database.fetchOne(
        "SELECT position FROM characters WHERE unique_id = ?",
        { uniqueId },
        function(result)
            if result and result.position then
                local ok, p = pcall(json.decode, result.position)
                if ok and p and p.x then
                    if callback then callback(vector3(p.x, p.y, p.z), p.heading or Config.spawn.defaultHeading) end
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

-- ─── Handler réseau ────────────────────────────────────────────────────────

RegisterNetEvent("union:position:save", function(position, heading, health, armor, isDead)
    local src = source

    -- Anti-flood
    local now = GetGameTimer()
    if _lastSave[src] and (now - _lastSave[src]) < MIN_INTERVAL then return end
    _lastSave[src] = now

    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter or not position then return end

    SpawnPosition.save(player, position, heading, health, armor, isDead)
    TriggerClientEvent("union:position:loaded", src, position, heading)
end)

AddEventHandler("union:player:dropping", function(src)
    _lastSave[src] = nil
end)

return SpawnPosition