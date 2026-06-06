-- server/modules/spawn/position.lua
SpawnPosition        = {}
SpawnPosition.logger = Logger:child("SPAWN:POSITION")

local _lastSave    = {}
local MIN_INTERVAL = 3000
print("SpawnPosition module loaded") -- Debug initial load

function SpawnPosition.save(player, position, heading, health, armor, isDead)
    print("Saving position for " .. (player.name or "?") .. " at " .. json.encode(position))
    if not player or not player.currentCharacter then return false end
    if not position then
        SpawnPosition.logger:warn("Position nil pour " .. (player.name or "?")); return false
    end
    local posJson = json.encode({ x = position.x, y = position.y, z = position.z, heading = heading or 0.0 })
    player.currentCharacter.position = { x = position.x, y = position.y, z = position.z, heading = heading or 0.0 }
    player.currentCharacter.heading  = heading or 0.0
    if health ~= nil then player.currentCharacter.health  = health end
    if armor  ~= nil then player.currentCharacter.armor   = armor  end
    if isDead ~= nil then player.currentCharacter.is_dead = isDead and 1 or 0 end
    local hp   = player.currentCharacter.health  or 200
    local arm  = player.currentCharacter.armor   or 0
    local dead = player.currentCharacter.is_dead or 0
    Database.execute([[
        UPDATE characters SET position = ?, health = ?, armor = ?, is_dead = ?, last_played = NOW()
        WHERE unique_id = ?
    ]], { posJson, hp, arm, dead, player.currentCharacter.unique_id }, function(result)
        if result then
            SpawnPosition.logger:debug(("Saved %s | pos=%.1f,%.1f | HP=%d Armor=%d Dead=%d"):format(
                player.name, position.x, position.y, hp, arm, dead))
        else
            SpawnPosition.logger:error("Échec save pour " .. player.name)
        end
    end)
    print("Position save initiated for " .. (player.name or "?"))
    return true
end

function SpawnPosition.load(uniqueId, callback)
    print("Loading position for uid=" .. tostring(uniqueId))
    Database.fetchOne("SELECT position FROM characters WHERE unique_id = ?", { uniqueId }, function(result)
        if result and result.position then
            local ok, p = pcall(json.decode, result.position)
            if ok and p and p.x then
                if callback then callback(vector3(p.x, p.y, p.z), p.heading or Config.spawn.defaultHeading) end
                return
            end
        end
        if callback then callback(Config.spawn.defaultPosition, Config.spawn.defaultHeading) end
    print("Position load initiated for uid=" .. tostring(uniqueId))
    end)
end

function SpawnPosition.isValid(position)
    print("Validating position: " .. tostring(position))

    if not position then
        return false
    end

    if position.x == 0 and position.y == 0 and position.z == 0 then
        return false
    end

    print("Position validation completed for: " .. tostring(position))
    return true
end

-- Remplacer le RegisterNetEvent("union:position:save") existant par :
RegisterNetEvent("union:position:save", function(position, heading, health, armor, isDead)
    print("Received position save event from src=" .. tostring(source) .. " pos=" .. json.encode(position) .. " heading=" .. tostring(heading))
    local src = source
    local now = GetGameTimer()
    if _lastSave[src] and (now - _lastSave[src]) < MIN_INTERVAL then return end
    _lastSave[src] = now
    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter or not position then return end

    -- FIX: stocker heading dans la table position pour que playerDropped l'encode correctement
    player.currentCharacter.position = {
        x       = position.x,
        y       = position.y,
        z       = position.z,
        heading = heading or 0.0,
    }
    player.currentCharacter.heading = heading or 0.0

    SpawnPosition.save(player, position, heading, health, armor, isDead)
    TriggerClientEvent("union:position:loaded", src, position, heading)
    print("Position save event processed for src=" .. tostring(src))
end)

AddEventHandler("union:player:dropping", function(src)
    _lastSave[src] = nil
    print("Player dropping event processed for src=" .. tostring(src))
end)

return SpawnPosition
