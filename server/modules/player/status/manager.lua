-- server/modules/player/status/manager.lua
-- FIX #4 : clamp() définie en LOCAL pour éviter la pollution de l'espace global Lua
-- VERSION PRODUCTION : 100% server-authoritative

StatusManager        = {}
StatusManager.logger = Logger:child("STATUS:MANAGER")
StatusManager.cache  = {}

-- ────────────────────────────────────────────────────────────────────────────
-- CONSTANTES
-- ────────────────────────────────────────────────────────────────────────────

local ALLOWED_STATS = {
    hunger = true,
    thirst = true,
    stress = true,
}

-- FIX #4 : local function (était global, polluait l'espace Lua)
local function clamp(value)
    return math.max(StatusConfig.min, math.min(StatusConfig.max, math.floor(value + 0.5)))
end

-- Exposer clamp pour status_tick.lua (même scope de chargement)
StatusManager.clamp = clamp

local ACTION_EFFECTS = {
    eat       = function(s) s.hunger = clamp(s.hunger + 25); s.stress = clamp(s.stress - 5)  end,
    drink     = function(s) s.thirst = clamp(s.thirst + 25) end,
    shoot     = function(s) s.stress = clamp(s.stress + StatusConfig.stressGain.shooting)    end,
    sprint    = function(s) s.stress = clamp(s.stress + StatusConfig.stressGain.sprinting)   end,
    fistfight = function(s) s.stress = clamp(s.stress + StatusConfig.stressGain.fistFight)   end,
}

local actionCooldowns = {}

local ACTION_COOLDOWN_MS = {
    eat       = 1000,
    drink     = 1000,
    shoot     = 600,
    sprint    = 2500,
    fistfight = 1200,
}

-- ────────────────────────────────────────────────────────────────────────────
-- HELPERS
-- ────────────────────────────────────────────────────────────────────────────

local function defaultStatus()
    return {
        hunger    = StatusConfig.defaults.hunger,
        thirst    = StatusConfig.defaults.thirst,
        stress    = StatusConfig.defaults.stress,
        _dirty    = false,
        _uniqueId = nil,
    }
end

local function isActionOnCooldown(src, action)
    local now = GetGameTimer()
    actionCooldowns[src] = actionCooldowns[src] or {}

    local last     = actionCooldowns[src][action] or 0
    local cooldown = ACTION_COOLDOWN_MS[action]   or 1000

    if now - last < cooldown then return true end

    actionCooldowns[src][action] = now
    return false
end

-- ────────────────────────────────────────────────────────────────────────────
-- CHARGEMENT / SAUVEGARDE
-- ────────────────────────────────────────────────────────────────────────────

function StatusManager.load(src, uniqueId, callback)
    exports.oxmysql:fetch(
        "SELECT hunger, thirst, stress FROM player_status WHERE unique_id = ?",
        { uniqueId },
        function(rows)
            local status

            if rows and rows[1] then
                local r = rows[1]
                status = {
                    hunger    = clamp(r.hunger),
                    thirst    = clamp(r.thirst),
                    stress    = clamp(r.stress),
                    _dirty    = false,
                    _uniqueId = uniqueId,
                }
            else
                status            = defaultStatus()
                status._uniqueId  = uniqueId
            end

            StatusManager.cache[src] = status
            StatusManager.logger:debug(("Status chargés src=%d uid=%s"):format(src, uniqueId))

            if callback then callback(status) end
        end
    )
end

function StatusManager.save(src, status)
    if not status or not status._dirty or not status._uniqueId then return end

    local player = PlayerManager.get(src)
    if not player then return end

    exports.oxmysql:execute([[
        INSERT INTO player_status (identifier, unique_id, hunger, thirst, stress)
        VALUES (?, ?, ?, ?, ?)
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
        clamp(status.stress),
    })

    status._dirty = false
    StatusManager.logger:debug(("Status sauvegardés src=%d uid=%s"):format(src, status._uniqueId))
end

-- ────────────────────────────────────────────────────────────────────────────
-- GETTERS / SETTERS
-- ────────────────────────────────────────────────────────────────────────────

function StatusManager.get(src)
    return StatusManager.cache[src]
end

function StatusManager.set(src, stat, value)
    if not ALLOWED_STATS[stat] then
        StatusManager.logger:warn(("Stat inconnue '%s' pour src=%d"):format(tostring(stat), src))
        return
    end

    local status = StatusManager.cache[src]
    if not status then return end

    status[stat]  = clamp(value)
    status._dirty = true

    TriggerClientEvent("union:status:update", src, stat, status[stat])
end

function StatusManager.add(src, stat, delta)
    local status = StatusManager.cache[src]
    if not status or not ALLOWED_STATS[stat] then return end

    StatusManager.set(src, stat, (status[stat] or 0) + delta)
end

function StatusManager.cleanup(src)
    StatusManager.cache[src]  = nil
    actionCooldowns[src]      = nil
end

-- ────────────────────────────────────────────────────────────────────────────
-- ACTIONS ENVOYÉES PAR LE CLIENT
-- ────────────────────────────────────────────────────────────────────────────

RegisterNetEvent("union:status:action", function(action)
    local src    = source
    local effect = ACTION_EFFECTS[action]

    if not effect then return end
    if isActionOnCooldown(src, action) then return end

    local status = StatusManager.cache[src]
    if not status then return end

    effect(status)
    status._dirty = true

    if action == "eat" or action == "drink" then
        TriggerClientEvent("union:status:update", src, "hunger", status.hunger)
        TriggerClientEvent("union:status:update", src, "thirst", status.thirst)
        TriggerClientEvent("union:status:update", src, "stress", status.stress)
    end
end)

-- ────────────────────────────────────────────────────────────────────────────
-- ÉVÉNEMENTS UNION
-- ────────────────────────────────────────────────────────────────────────────

AddEventHandler("union:player:spawned", function(src, character)
    if not src or not character or not character.unique_id then return end

    StatusManager.load(src, character.unique_id, function(status)
        TriggerClientEvent("union:status:init", src, {
            hunger = status.hunger,
            thirst = status.thirst,
            stress = status.stress,
        })
    end)
end)

AddEventHandler("playerDropped", function()
    local src    = source
    local status = StatusManager.cache[src]

    if status then
        status._dirty = true
        StatusManager.save(src, status)
    end

    StatusManager.cleanup(src)
end)

-- ────────────────────────────────────────────────────────────────────────────
-- EXPORTS PUBLICS
-- ────────────────────────────────────────────────────────────────────────────

exports("GetPlayerStatus", function(src) return StatusManager.get(src) end)
exports("SetPlayerStat",   function(src, stat, v) StatusManager.set(src, stat, v) end)
exports("AddPlayerStat",   function(src, stat, d) StatusManager.add(src, stat, d) end)

return StatusManager