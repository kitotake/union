-- server/modules/player/status/manager.lua
-- FIXES:
--   #1 : Ajout du handler "union:status:sync"
--   #2 : Export "SetStat" ajouté
--   #3 : Nettoyage + sauvegarde du cache à la déconnexion
--   #4 : Suppression de la save loop dupliquée (gérée dans status_tick.lua)
--   #5 : Fix playerDropped — sauvegarde directe sans PlayerManager.get()
--        pour éviter la race condition à la déconnexion

print("[STATUS] Manager loaded")

StatusManager        = {}
StatusManager.logger = Logger:child("STATUS:MANAGER")
StatusManager.cache  = {}

_G.StatusManager = StatusManager

local ALLOWED_STATS = { hunger = true, thirst = true, stress = true }

local function clamp(v)
    v = tonumber(v) or 0
    return math.max(StatusConfig.min or 0, math.min(StatusConfig.max or 100, math.floor(v + 0.5)))
end

StatusManager.clamp = clamp

local function defaultStatus()
    return {
        hunger    = StatusConfig.defaults.hunger or 100,
        thirst    = StatusConfig.defaults.thirst or 100,
        stress    = StatusConfig.defaults.stress or 0,
        _dirty    = false,
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
            StatusManager.logger:debug(("Statuts chargés src=%d uid=%s"):format(src, uniqueId))

            TriggerClientEvent("union:status:init", src, {
                hunger = status.hunger,
                thirst = status.thirst,
                stress = status.stress,
            })

            if callback then callback(status) end
        end
    )
end

-- FIX #5 : save accepte un identifier optionnel pour éviter
-- la dépendance à PlayerManager.get() lors du playerDropped
function StatusManager.save(src, status, identifier)
    if not status or not status._dirty or not status._uniqueId then return end

    local license = identifier

    if not license then
        local player = PlayerManager.get(src)
        if not player or not player.license then return end
        license = player.license
    end

    exports.oxmysql:execute([[
        INSERT INTO player_status (identifier, unique_id, hunger, thirst, stress, last_update)
        VALUES (?, ?, ?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE
            hunger      = VALUES(hunger),
            thirst      = VALUES(thirst),
            stress      = VALUES(stress),
            last_update = NOW()
    ]], {
        license,
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

    s[stat]  = clamp(value)
    s._dirty = true

    TriggerClientEvent("union:status:updateAll", src, {
        hunger = s.hunger,
        thirst = s.thirst,
        stress = s.stress,
    })
end

function StatusManager.add(src, stat, value)
    local s = StatusManager.cache[src]
    if not s then return end
    StatusManager.set(src, stat, (s[stat] or 0) + (value or 0))
end

-- ─────────────────────────────────────────────
-- FIX #1 : handler union:status:sync
-- ─────────────────────────────────────────────
RegisterNetEvent("union:status:sync", function(clientStatus)
    local src = source
    if not clientStatus then return end

    local s = StatusManager.cache[src]
    if not s then return end

    for stat, _ in pairs(ALLOWED_STATS) do
        if clientStatus[stat] ~= nil then
            s[stat] = clamp(clientStatus[stat])
        end
    end
    s._dirty = true
end)

-- ─────────────────────────────────────────────
-- FIX #3 + #5 : playerDropped avec license capturée avant déco
-- ─────────────────────────────────────────────
AddEventHandler("playerDropped", function()
    local src = source

    -- On récupère la license AVANT que PlayerManager la libère
    local license = nil
    local player  = PlayerManager.get(src)
    if player then license = player.license end

    local status = StatusManager.cache[src]
    if status then
        StatusManager.save(src, status, license)
        StatusManager.cache[src] = nil
        StatusManager.logger:debug("Cache statut nettoyé pour src=" .. tostring(src))
    end
end)

-- ─────────────────────────────────────────────
-- EXPORTS
-- ─────────────────────────────────────────────

exports("GetPlayerStatus", StatusManager.get)
exports("SetPlayerStat",   StatusManager.set)
exports("AddPlayerStat",   StatusManager.add)

-- FIX #2 : exports SetStat / AddStat
exports("SetStat", function(stat, value)
    local src = source
    StatusManager.set(src, stat, value)
end)

exports("AddStat", function(stat, value)
    local src = source
    StatusManager.add(src, stat, value)
end)