print("[STATUS] Manager loaded")

StatusManager        = {}
StatusManager.logger = Logger:child("STATUS:MANAGER")
StatusManager.cache  = {}

_G.StatusManager = StatusManager

-- ─────────────────────────────────────────────
-- CONFIG (fallback si StatusConfig pas chargé)
-- ─────────────────────────────────────────────

local ALLOWED_STATS = { hunger = true, thirst = true, stress = true }

local function clamp(v)
    v = tonumber(v) or 0
    return math.max(StatusConfig.min or 0, math.min(StatusConfig.max or 100, math.floor(v + 0.5)))
end

StatusManager.clamp = clamp

-- ─────────────────────────────────────────────
-- DEFAULT
-- ─────────────────────────────────────────────

local function defaultStatus()
    return {
        hunger = StatusConfig.defaults.hunger or 100,
        thirst = StatusConfig.defaults.thirst or 100,
        stress = StatusConfig.defaults.stress or 0,
        _dirty = false,
        _uniqueId = nil,
    }
end

-- ─────────────────────────────────────────────
-- LOAD / SAVE
-- ─────────────────────────────────────────────

function StatusManager.load(src, uniqueId, callback)
    exports.oxmysql:fetch(
        "SELECT hunger, thirst, stress FROM player_status WHERE unique_id = ?",
        { uniqueId },
        function(rows)
            local status = defaultStatus()
            status._uniqueId = uniqueId

            if rows and rows[1] then
                local r = rows[1]
                status.hunger = clamp(r.hunger)
                status.thirst = clamp(r.thirst)
                status.stress = clamp(r.stress)
            end

            StatusManager.cache[src] = status
            StatusManager.logger:debug(("Status chargés src=%d uid=%s"):format(src, uniqueId))

            TriggerClientEvent("union:status:init", src, status)

            if callback then callback(status) end
        end
    )
end

function StatusManager.save(src, status)
    if not status or not status._dirty or not status._uniqueId then return end

    local player = PlayerManager.get(src)
    if not player or not player.license then return end

    exports.oxmysql:execute([[ 
        INSERT INTO player_status (identifier, unique_id, hunger, thirst, stress, last_update)
        VALUES (?, ?, ?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE 
            hunger = VALUES(hunger),
            thirst = VALUES(thirst),
            stress = VALUES(stress),
            last_update = NOW()
    ]], {
        player.license,
        status._uniqueId,
        clamp(status.hunger),
        clamp(status.thirst),
        clamp(status.stress)
    })

    status._dirty = false
end

function StatusManager.get(src)
    return StatusManager.cache[src]
end

-- ─────────────────────────────────────────────
-- SET / ADD
-- ─────────────────────────────────────────────

function StatusManager.set(src, stat, value)
    if not ALLOWED_STATS[stat] then return end
    local s = StatusManager.cache[src]
    if not s then return end

    s[stat] = clamp(value)
    s._dirty = true

    TriggerClientEvent("union:status:updateAll", src, s)
end

function StatusManager.add(src, stat, value)
    local s = StatusManager.cache[src]
    if not s then return end
    StatusManager.set(src, stat, (s[stat] or 0) + (value or 0))
end

-- ─────────────────────────────────────────────
-- EXPORTS
-- ─────────────────────────────────────────────

exports("GetPlayerStatus", StatusManager.get)
exports("SetPlayerStat", StatusManager.set)
exports("AddPlayerStat", StatusManager.add)

-- Pour compatibilité client
exports("AddStat", function(stat, value)
    local src = source
    StatusManager.add(src, stat, value)
end)