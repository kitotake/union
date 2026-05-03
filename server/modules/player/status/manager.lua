-- server/modules/player/status/manager.lua
-- FIXES:
--   #1 : Ajout du handler "union:status:sync" — sans ce handler, les appels
--        client AddStat/SetStat ne remontaient jamais au serveur, les statuts
--        étaient donc figés côté serveur et ne se sauvegardaient pas.
--   #2 : Export "SetStat" ajouté (déclaré dans fxmanifest mais absent).
--   #3 : Nettoyage + sauvegarde du cache à la déconnexion.

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

function StatusManager.save(src, status)
    if not status or not status._dirty or not status._uniqueId then return end

    local player = PlayerManager.get(src)
    if not player or not player.license then return end

    exports.oxmysql:execute([[
        INSERT INTO player_status (identifier, unique_id, hunger, thirst, stress, last_update)
        VALUES (?, ?, ?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE
            hunger      = VALUES(hunger),
            thirst      = VALUES(thirst),
            stress      = VALUES(stress),
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
-- Reçoit les mises à jour initiées côté client (AddStat / SetStat)
-- Sans ce handler, les statuts ne remontaient JAMAIS au serveur.
-- ─────────────────────────────────────────────
RegisterNetEvent("union:status:sync", function(clientStatus)
    local src = source
    if not clientStatus then return end

    local s = StatusManager.cache[src]
    if not s then return end

    -- On applique seulement les stats autorisées et on clamp
    for stat, _ in pairs(ALLOWED_STATS) do
        if clientStatus[stat] ~= nil then
            s[stat] = clamp(clientStatus[stat])
        end
    end
    s._dirty = true

    -- Pas de TriggerClientEvent ici pour éviter la boucle infinie
    -- (le client a déjà la valeur à jour localement)
end)

-- ─────────────────────────────────────────────
-- FIX #3 : nettoyage du cache à la déconnexion
-- ─────────────────────────────────────────────
AddEventHandler("playerDropped", function()
    local src = source
    if StatusManager.cache[src] then
        StatusManager.save(src, StatusManager.cache[src])
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

-- FIX #2 : exports SetStat / AddStat (déclarés dans fxmanifest, absents ici)
exports("SetStat", function(stat, value)
    local src = source
    StatusManager.set(src, stat, value)
end)

exports("AddStat", function(stat, value)
    local src = source
    StatusManager.add(src, stat, value)
end)