-- server/modules/player/status/manager.lua
-- FIXES:
--   #1 : set() n'envoie plus TriggerClientEvent directement.
--        L'envoi est délégué au tick (flush différé) pour éviter le flood réseau.
--   #2 : Guard _loading renforcé avec callback queue pour éviter la race condition async.
--   #3 : save() passe par db (oxmysql) de manière cohérente avec le reste de l'archi.
--   #4 : StatusManager._dirty géré par flag sur le status, non par la fonction set.
--   #5 : clamp() exposé proprement, utilisable en externe.
--   #6 : _pendingSend : flag par joueur pour savoir si un updateAll doit être envoyé au prochain tick.

print("[STATUS] Manager loaded")

StatusManager          = {}
StatusManager.logger   = Logger:child("STATUS:MANAGER")
StatusManager.cache    = {}
StatusManager._loading = {}
StatusManager._queue   = {}  -- callbacks en attente si load déjà en cours
StatusManager._pendingSend = {}  -- FIX #1 : joueurs à notifier au prochain tick

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

-- ====================== LOAD / SAVE ======================

-- FIX #2 : si un load est déjà en cours pour ce src,
-- on met le callback en file d'attente au lieu de doubler la requête.
function StatusManager.load(src, uniqueId, callback)
    if StatusManager._loading[src] then
        StatusManager.logger:warn(("Double load — mise en queue src=%d uid=%s"):format(src, uniqueId or "nil"))
        if callback then
            StatusManager._queue[src] = StatusManager._queue[src] or {}
            table.insert(StatusManager._queue[src], callback)
        end
        return
    end

    -- Déjà en cache pour ce même uid → pas de requête DB
    if StatusManager.cache[src] and StatusManager.cache[src]._uniqueId == uniqueId then
        StatusManager.logger:debug(("Cache hit src=%d uid=%s"):format(src, uniqueId or "nil"))
        if callback then callback(StatusManager.cache[src]) end
        return
    end

    StatusManager._loading[src] = true

    exports.oxmysql:fetch(
        "SELECT hunger, thirst, stress FROM player_status WHERE unique_id = ?",
        { uniqueId },
        function(rows)
            StatusManager._loading[src] = nil

            local status = defaultStatus()
            status._uniqueId = uniqueId

            if rows and rows[1] then
                local r = rows[1]
                status.hunger = clamp(r.hunger)
                status.thirst = clamp(r.thirst)
                status.stress = clamp(r.stress)
            end

            StatusManager.cache[src] = status

            -- Envoyer l'init au client
            TriggerClientEvent("union:status:init", src, {
                hunger = status.hunger,
                thirst = status.thirst,
                stress = status.stress,
            })

            StatusManager.logger:debug(("Statuts chargés src=%d uid=%s | h=%d t=%d s=%d"):format(
                src, uniqueId, status.hunger, status.thirst, status.stress))

            if callback then callback(status) end

            -- FIX #2 : vider la file d'attente
            local queued = StatusManager._queue[src]
            StatusManager._queue[src] = nil
            if queued then
                for _, cb in ipairs(queued) do cb(status) end
            end
        end
    )
end

-- FIX #3 : save() cohérent avec l'archi (utilise exports.oxmysql comme les autres modules)
function StatusManager.save(src, status, identifier)
    if not status or not status._dirty or not status._uniqueId then return end

    local license = identifier
    if not license then
        local player = PlayerManager.get(src)
        license = player and player.license
    end

    if not license or license == "" then
        StatusManager.logger:warn(("save: license invalide pour src=%d"):format(src))
        return
    end

    local h = clamp(status.hunger)
    local t = clamp(status.thirst)
    local s = clamp(status.stress)

    exports.oxmysql:execute([[
        INSERT INTO player_status (identifier, unique_id, hunger, thirst, stress, last_update)
        VALUES (?, ?, ?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE
            hunger = VALUES(hunger),
            thirst = VALUES(thirst),
            stress = VALUES(stress),
            last_update = NOW()
    ]], {
        license,
        status._uniqueId,
        h, t, s
    })

    status._dirty = false

    StatusManager.logger:debug(("Statuts sauvegardés src=%d h=%d t=%d s=%d"):format(src, h, t, s))
end

function StatusManager.get(src)
    return StatusManager.cache[src]
end

-- ====================== SET / ADD ======================

-- FIX #1 : set() marque _dirty et _pendingSend mais n'envoie PAS directement au client.
--           Le flush est fait par le tick (status_tick.lua) une seule fois par cycle.
function StatusManager.set(src, stat, value)
    if not ALLOWED_STATS[stat] then return end
    local s = StatusManager.cache[src]
    if not s then return end

    local clamped = clamp(value)
    if s[stat] == clamped then return end  -- pas de changement → skip

    s[stat] = clamped
    s._dirty = true
    StatusManager._pendingSend[src] = true  -- FIX #1 : déléguer l'envoi au tick
end

function StatusManager.add(src, stat, value)
    local s = StatusManager.cache[src]
    if not s then return end
    StatusManager.set(src, stat, (s[stat] or 0) + (value or 0))
end

-- FIX #1 : flush appelé par status_tick.lua une fois par cycle pour tous les joueurs marqués.
function StatusManager.flushPendingSends()
    for src, _ in pairs(StatusManager._pendingSend) do
        local s = StatusManager.cache[src]
        if s then
            TriggerClientEvent("union:status:updateAll", src, {
                hunger = s.hunger,
                thirst = s.thirst,
                stress = s.stress,
            })
        end
    end
    StatusManager._pendingSend = {}
end

-- ====================== EVENTS ======================

RegisterNetEvent("union:status:sync", function(clientStatus)
    local src = source
    if not clientStatus then return end

    local s = StatusManager.cache[src]
    if not s then return end

    for stat in pairs(ALLOWED_STATS) do
        if clientStatus[stat] ~= nil then
            local clamped = clamp(clientStatus[stat])
            if s[stat] ~= clamped then
                s[stat] = clamped
                s._dirty = true
            end
        end
    end
end)

AddEventHandler("union:player:spawned", function(src, character)
    if not src or not character or not character.unique_id then return end
    StatusManager.load(src, character.unique_id)
end)

AddEventHandler("playerDropped", function()
    local src = source

    local license = nil
    local player = PlayerManager.get(src)
    if player then license = player.license end

    StatusManager._loading[src] = nil
    StatusManager._queue[src]   = nil
    StatusManager._pendingSend[src] = nil

    local status = StatusManager.cache[src]
    if status then
        StatusManager.save(src, status, license)
        StatusManager.cache[src] = nil
    end
end)

-- ====================== EXPORTS ======================

exports("GetPlayerStatus", StatusManager.get)
exports("SetPlayerStat",   StatusManager.set)
exports("AddPlayerStat",   StatusManager.add)

exports("SetStat", function(stat, value)
    StatusManager.set(source, stat, value)
end)

exports("AddStat", function(stat, value)
    StatusManager.add(source, stat, value)
end)
