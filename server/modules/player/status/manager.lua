-- server/modules/player/status/manager.lua
-- FIX ST1 : implémentation de StatusManager.flushPendingSends() (manquait totalement)
-- FIX ST2 : StatusManager.set() ne TriggerClientEvent plus directement —
--            il marque _pendingSend = true et laisse flushPendingSends() envoyer.
--            Cela évite la contradiction entre envoi direct et envoi groupé.
-- FIX ST3 : guard GetPlayerEndpoint déjà présent, renforcé.
-- FIX #4  : StatusManager.save protégée contre identifier nil (conservé).
-- FIX #5  : exports sans conflit source global (conservé).

print("[STATUS] Manager chargé")

StatusManager          = {}
StatusManager.logger   = Logger:child("STATUS:MANAGER")
StatusManager.cache    = {}
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
        hunger       = StatusConfig.defaults.hunger or 100,
        thirst       = StatusConfig.defaults.thirst or 100,
        stress       = StatusConfig.defaults.stress or 0,
        _dirty       = false,
        _uniqueId    = nil,
        -- FIX ST1 : flag pour l'envoi groupé
        _pendingSend = false,
    }
end

-- ─────────────────────────────────────────────
-- LOAD / SAVE
-- ─────────────────────────────────────────────

function StatusManager.load(src, uniqueId, callback)
    if StatusManager._loading[src] then
        StatusManager.logger:warn(("Double load ignoré src=%d uid=%s"):format(src, tostring(uniqueId)))
        CreateThread(function()
            local waited = 0
            while StatusManager._loading[src] and waited < 30 do
                Wait(100)
                waited = waited + 1
            end
            if callback then callback(StatusManager.cache[src]) end
        end)
        return
    end

    StatusManager._loading[src] = true

    exports.oxmysql:fetch(
        "SELECT hunger, thirst, stress FROM player_status WHERE unique_id = ?",
        { uniqueId },
        function(rows)
            StatusManager._loading[src] = nil

            if StatusManager.cache[src] and StatusManager.cache[src]._uniqueId == uniqueId then
                StatusManager.logger:debug(("Déjà en cache src=%d uid=%s"):format(src, tostring(uniqueId)))
                if callback then callback(StatusManager.cache[src]) end
                return
            end

            local status         = defaultStatus()
            status._uniqueId     = uniqueId

            if rows and rows[1] then
                local r       = rows[1]
                status.hunger = clamp(r.hunger)
                status.thirst = clamp(r.thirst)
                status.stress = clamp(r.stress)
            end

            StatusManager.cache[src] = status
            StatusManager.logger:debug(
                ("Statuts chargés src=%d uid=%s | h=%d t=%d s=%d"):format(
                    src, tostring(uniqueId), status.hunger, status.thirst, status.stress
                )
            )

            if GetPlayerEndpoint(src) then
                TriggerClientEvent("union:status:init", src, {
                    hunger = status.hunger,
                    thirst = status.thirst,
                    stress = status.stress,
                })
            end

            if callback then callback(status) end
        end
    )
end

function StatusManager.save(src, status, identifier)
    if not status or not status._dirty or not status._uniqueId then return end

    local license = identifier

    if not license then
        local player = PlayerManager.get(src)
        if not player or not player.license then
            StatusManager.logger:warn(("save: license nil src=%d — annulé"):format(src))
            return
        end
        license = player.license
    end

    if not license or license == "" then
        StatusManager.logger:warn(("save: license vide src=%d — annulé"):format(src))
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
-- FIX ST2 : set() marque _pendingSend au lieu d'envoyer directement
-- ─────────────────────────────────────────────

function StatusManager.set(src, stat, value)
    if not ALLOWED_STATS[stat] then return end
    local s = StatusManager.cache[src]
    if not s then return end

    s[stat]        = clamp(value)
    s._dirty       = true
    -- FIX ST2 : on marque juste, flushPendingSends() enverra groupé
    s._pendingSend = true
end

function StatusManager.add(src, stat, value)
    local s = StatusManager.cache[src]
    if not s then return end
    StatusManager.set(src, stat, (s[stat] or 0) + (value or 0))
end

-- ─────────────────────────────────────────────
-- SET IMMÉDIAT (pour les commandes admin qui doivent notifier tout de suite)
-- ─────────────────────────────────────────────

function StatusManager.setAndSend(src, stat, value)
    StatusManager.set(src, stat, value)
    local s = StatusManager.cache[src]
    if not s or not GetPlayerEndpoint(src) then return end
    TriggerClientEvent("union:status:updateAll", src, {
        hunger = s.hunger,
        thirst = s.thirst,
        stress = s.stress,
    })
    s._pendingSend = false
end

-- ─────────────────────────────────────────────
-- FLUSH GROUPÉ
-- FIX ST1 : cette fonction était appelée dans status_tick.lua mais n'existait pas
-- ─────────────────────────────────────────────

function StatusManager.flushPendingSends()
    for src, status in pairs(StatusManager.cache) do
        if status and status._pendingSend then
            if GetPlayerEndpoint(src) then
                TriggerClientEvent("union:status:updateAll", src, {
                    hunger = status.hunger,
                    thirst = status.thirst,
                    stress = status.stress,
                })
            end
            status._pendingSend = false
        end
    end
end

-- ─────────────────────────────────────────────
-- SYNC client → serveur
-- ─────────────────────────────────────────────

RegisterNetEvent("union:status:sync", function(clientStatus)
    local src = source
    if not clientStatus then return end

    local s = StatusManager.cache[src]
    if not s then return end

    for stat in pairs(ALLOWED_STATS) do
        if clientStatus[stat] ~= nil then
            s[stat] = clamp(clientStatus[stat])
        end
    end
    s._dirty = true
    -- Pas de pendingSend ici : le client a déjà les valeurs
end)

-- ─────────────────────────────────────────────
-- SPAWN : chargement des statuts
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
-- DÉCONNEXION
-- ─────────────────────────────────────────────

AddEventHandler("playerDropped", function()
    local src = source

    local license = nil
    local player  = PlayerManager.get(src)
    if player then license = player.license end

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
-- FIX #5 : wrappers pour éviter la confusion avec source global
-- ─────────────────────────────────────────────

exports("GetPlayerStatus", StatusManager.get)
exports("SetPlayerStat",   StatusManager.setAndSend)
exports("AddPlayerStat",   StatusManager.add)

exports("SetStat", function(stat, value)
    local src = source
    StatusManager.setAndSend(src, stat, value)
end)

exports("AddStat", function(stat, value)
    local src = source
    StatusManager.add(src, stat, value)
    -- Flush immédiat pour les exports externes
    local s = StatusManager.cache[src]
    if s and GetPlayerEndpoint(src) then
        TriggerClientEvent("union:status:updateAll", src, {
            hunger = s.hunger,
            thirst = s.thirst,
            stress = s.stress,
        })
        s._pendingSend = false
    end
end)