-- server/modules/player/status/manager.lua
-- FIXES:
--   #1 : Suppression de la save loop dupliquée (dans status_tick.lua uniquement)
--   #2 : Un seul handler "union:player:spawned" → StatusManager.load
--         (suppression du handler dans player/manager.lua)
--   #3 : playerDropped — license capturée avant déco pour éviter race condition
--   #4 : Guard anti-double-chargement (_loading) pour éviter double union:status:init
--   #5 : save protégée contre les nil identifier

print("[STATUS] Manager loaded")

StatusManager        = {}
StatusManager.logger = Logger:child("STATUS:MANAGER")
StatusManager.cache  = {}

-- FIX #4 : guard pour éviter le double chargement simultané
StatusManager._loading = {}

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
    -- FIX #4 : éviter le double chargement
    if StatusManager._loading[src] then
        StatusManager.logger:warn(("Double load ignoré src=%d uid=%s"):format(src, uniqueId))
        if callback then callback(StatusManager.cache[src]) end
        return
    end
    StatusManager._loading[src] = true

    exports.oxmysql:fetch(
        "SELECT hunger, thirst, stress FROM player_status WHERE unique_id = ?",
        { uniqueId },
        function(rows)
            StatusManager._loading[src] = nil

            -- Si déjà chargé entre temps (race condition), ne pas écraser
            if StatusManager.cache[src] and StatusManager.cache[src]._uniqueId == uniqueId then
                StatusManager.logger:debug(("Statuts déjà en cache src=%d uid=%s — skip"):format(src, uniqueId))
                if callback then callback(StatusManager.cache[src]) end
                return
            end

            local status = defaultStatus()
            status._uniqueId = uniqueId

            if rows and rows[1] then
                local r = rows[1]
                status.hunger = clamp(r.hunger)
                status.thirst = clamp(r.thirst)
                status.stress = clamp(r.stress)
            end

            StatusManager.cache[src] = status
            StatusManager.logger:debug(("Statuts chargés src=%d uid=%s | h=%d t=%d s=%d"):format(
                src, uniqueId, status.hunger, status.thirst, status.stress))

            TriggerClientEvent("union:status:init", src, {
                hunger = status.hunger,
                thirst = status.thirst,
                stress = status.stress,
            })

            if callback then callback(status) end
        end
    )
end

-- FIX #5 : identifier optionnel, protection nil
function StatusManager.save(src, status, identifier)
    if not status or not status._dirty or not status._uniqueId then return end

    local license = identifier

    if not license then
        local player = PlayerManager.get(src)
        if not player or not player.license then
            StatusManager.logger:warn(("save: license nil pour src=%d — sauvegarde annulée"):format(src))
            return
        end
        license = player.license
    end

    if not license or license == "" then
        StatusManager.logger:warn(("save: license vide pour src=%d — sauvegarde annulée"):format(src))
        return
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
-- FIX #1 : handler union:status:sync (client → serveur)
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
-- FIX #2 : UN SEUL handler pour le chargement au spawn
-- Ce handler écoute l'event serveur local émis par SpawnHandler
-- NE PAS ajouter un second handler dans player/manager.lua
-- ─────────────────────────────────────────────
AddEventHandler("union:player:spawned", function(src, character)
    if not src or not character or not character.unique_id then return end

    StatusManager.load(src, character.unique_id, function(status)
        StatusManager.logger:debug(
            ("Statuts prêts src=%d uid=%s"):format(src, character.unique_id)
        )
    end)
end)

-- ─────────────────────────────────────────────
-- FIX #3 : playerDropped avec license capturée AVANT que PlayerManager libère
-- ─────────────────────────────────────────────
AddEventHandler("playerDropped", function()
    local src = source

    -- Capturer la license AVANT que PlayerManager.remove() la nil
    local license = nil
    local player  = PlayerManager.get(src)
    if player then license = player.license end

    -- Nettoyer le guard de chargement
    StatusManager._loading[src] = nil

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

exports("SetStat", function(stat, value)
    local src = source
    StatusManager.set(src, stat, value)
end)

exports("AddStat", function(stat, value)
    local src = source
    StatusManager.add(src, stat, value)
end)