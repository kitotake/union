-- server/modules/spawn/persistence/position.lua
SpawnPosition        = {}
SpawnPosition.logger = Logger:child("SPAWN:POSITION")

local _lastSave    = {}
local MIN_INTERVAL = 3000

-- SEC-1 : limites de la carte GTA V
local MAP_LIMIT_XY = 5000
local MAP_LIMIT_Z_MIN = -200
local MAP_LIMIT_Z_MAX = 2000

local function validateCoords(position)
    if not position then return false end
    if math.abs(position.x) > MAP_LIMIT_XY then return false end
    if math.abs(position.y) > MAP_LIMIT_XY then return false end
    if position.z < MAP_LIMIT_Z_MIN or position.z > MAP_LIMIT_Z_MAX then return false end
    return true
end

function SpawnPosition.save(player, position, heading, health, armor, isDead)
    if not player or not player.currentCharacter then return false end
    if not position then
        SpawnPosition.logger:warn("Position nil pour " .. (player.name or "?")); return false
    end
    -- SEC-1 : validation des coordonnées
    if not validateCoords(position) then
        SpawnPosition.logger:warn(("Coords hors-limites ignorées pour %s : x=%.1f y=%.1f z=%.1f"):format(
            player.name or "?", position.x or 0, position.y or 0, position.z or 0))
        return false
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
    return true
end

function SpawnPosition.load(uniqueId, callback)
    Database.fetchOne("SELECT position FROM characters WHERE unique_id = ?", { uniqueId }, function(result)
        if result and result.position then
            local ok, p = pcall(json.decode, result.position)
            if ok and p and p.x then
                if callback then callback(vector3(p.x, p.y, p.z), p.heading or Config.spawn.defaultHeading) end
                return
            end
        end
        if callback then callback(Config.spawn.defaultPosition, Config.spawn.defaultHeading) end
    end)
end

function SpawnPosition.isValid(position)
    if not position then return false end
    if position.x == 0 and position.y == 0 and position.z == 0 then return false end
    return validateCoords(position)
end

RegisterNetEvent("union:position:save", function(position, heading, health, armor, isDead)
    local src = source
    -- SEC-1 : validation immédiate avant tout traitement
    if not position or not validateCoords(position) then
        SpawnPosition.logger:warn(("Coords invalides/hors-limites reçues de src=%d"):format(src))
        return
    end
    local now = GetGameTimer()
    if _lastSave[src] and (now - _lastSave[src]) < MIN_INTERVAL then return end
    _lastSave[src] = now
    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter then return end
    -- BUG-2 : stocker heading dans la table position (pas perdu si vector3 ailleurs)
    player.currentCharacter.position = {
        x       = position.x,
        y       = position.y,
        z       = position.z,
        heading = heading or 0.0,
    }
    player.currentCharacter.heading = heading or 0.0
    SpawnPosition.save(player, position, heading, health, armor, isDead)
    TriggerClientEvent("union:position:loaded", src, position, heading)
end)

AddEventHandler("union:player:dropping", function(src)
    _lastSave[src] = nil
end)

return SpawnPosition
