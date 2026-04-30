StatusManager        = {}
StatusManager.logger = Logger:child("STATUS:MANAGER")

StatusManager.cache  = {}

local lastSave = {}

local allowedStats = {
    hunger = true,
    thirst = true,
    stress = true
}

local function clamp(value)
    return math.max(StatusConfig.min, math.min(StatusConfig.max, math.floor(value + 0.5)))
end

local function defaultStatus()
    return {
        hunger = StatusConfig.defaults.hunger,
        thirst = StatusConfig.defaults.thirst,
        stress = StatusConfig.defaults.stress,
        _dirty = false
    }
end

function StatusManager.load(src, uniqueId, callback)
    exports.oxmysql:fetch(
        "SELECT hunger, thirst, stress FROM player_status WHERE unique_id = ?",
        { uniqueId },
        function(rows)
            local status

            if rows and rows[1] then
                local r = rows[1]
                status = {
                    hunger = clamp(r.hunger),
                    thirst = clamp(r.thirst),
                    stress = clamp(r.stress),
                    _dirty = false
                }
            else
                status = defaultStatus()
            end

            StatusManager.cache[src] = status
            if callback then callback(status) end
        end
    )
end

function StatusManager.save(src, status, uniqueId)
    if not status or not uniqueId then return end

    if not status._dirty then return end

    local player = PlayerManager.get(src)
    if not player then return end

    exports.oxmysql:execute([[
        INSERT INTO player_status (identifier, unique_id, hunger, thirst, stress)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
        hunger = VALUES(hunger),
        thirst = VALUES(thirst),
        stress = VALUES(stress)
    ]], {
        player.license,
        uniqueId,
        clamp(status.hunger),
        clamp(status.thirst),
        clamp(status.stress)
    })

    status._dirty = false
end

function StatusManager.get(src)
    return StatusManager.cache[src]
end

function StatusManager.set(src, stat, value)
    if not allowedStats[stat] then return end

    local status = StatusManager.cache[src]
    if not status then return end

    status[stat] = clamp(value)
    status._dirty = true

    TriggerClientEvent("union:status:update", src, stat, status[stat])
end

function StatusManager.add(src, stat, delta)
    local status = StatusManager.cache[src]
    if not status or not allowedStats[stat] then return end

    StatusManager.set(src, stat, status[stat] + delta)
end

function StatusManager.cleanup(src)
    StatusManager.cache[src] = nil
end

-- SPAWN
AddEventHandler("union:player:spawned", function(src, character)
    if not character or not character.unique_id then return end

    StatusManager.load(src, character.unique_id, function(status)
        TriggerClientEvent("union:status:init", src, status)
    end)
end)

-- ACTIONS CLIENT → SERVEUR (SAFE)
RegisterNetEvent("union:status:action", function(action, value)
    local src = source

    if action == "eat" then
        StatusManager.add(src, "hunger", value or 20)

    elseif action == "drink" then
        StatusManager.add(src, "thirst", value or 20)

    elseif action == "shoot" then
        StatusManager.add(src, "stress", StatusConfig.stressGain.shooting)

    elseif action == "sprint" then
        StatusManager.add(src, "stress", StatusConfig.stressGain.sprinting)
    end
end)

-- DECO
AddEventHandler("playerDropped", function()
    local src = source
    local player = PlayerManager.get(src)

    if player and player.currentCharacter then
        local status = StatusManager.cache[src]
        if status then
            StatusManager.save(src, status, player.currentCharacter.unique_id)
        end
    end

    StatusManager.cleanup(src)
end)

exports("GetPlayerStatus", function(src) return StatusManager.get(src) end)
exports("SetPlayerStat", function(src, stat, v) StatusManager.set(src, stat, v) end)
exports("AddPlayerStat", function(src, stat, d) StatusManager.add(src, stat, d) end)

return StatusManager