-- client/modules/player/status/status_client.lua
-- FIXES:
--   #1 : exports SetStat/AddStat : debounce sur TriggerServerEvent pour éviter le spam.
--        Un seul sync envoyé toutes les 500ms maximum même si appelé en rafale.
--   #2 : export AddPlayerStat corrigé — plus d'auto-appel exports["union"] fragile.
--   #3 : Guard caractère actif conservé et renforcé.
--   #4 : RegisterCommand("feed") protégé par Config.debug.
--   #5 : Handler updateAll : comparaison avant update pour éviter les re-renders inutiles.

StatusClient = {}
StatusClient.status   = { hunger = 100, thirst = 100, stress = 0 }
StatusClient.isActive = false

-- FIX #1 : debounce pour TriggerServerEvent("union:status:sync")
local _syncPending = false
local _syncCooldown = 500  -- ms minimum entre deux syncs serveur

local function scheduleSyncToServer()
    if _syncPending then return end
    _syncPending = true
    SetTimeout(_syncCooldown, function()
        _syncPending = false
        if not Client.currentCharacter then return end
        TriggerServerEvent("union:status:sync", {
            hunger = StatusClient.status.hunger,
            thirst = StatusClient.status.thirst,
            stress = StatusClient.status.stress,
        })
    end)
end

-- ─────────────────────────────────────────────
-- INIT / UPDATE
-- ─────────────────────────────────────────────

RegisterNetEvent("union:status:init", function(status)
    if not status then return end

    StatusClient.status = {
        hunger = status.hunger or 100,
        thirst = status.thirst or 100,
        stress = status.stress or 0
    }

    StatusClient.isActive = true

    LocalPlayer.state:set("hunger", StatusClient.status.hunger, false)
    LocalPlayer.state:set("thirst", StatusClient.status.thirst, false)
    LocalPlayer.state:set("stress", StatusClient.status.stress, false)

    TriggerEvent("union:status:ready", StatusClient.status)
end)

RegisterNetEvent("union:status:updateAll", function(status)
    if not status then return end

    local changed = false

    -- FIX #5 : ne mettre à jour que si la valeur change réellement
    if status.hunger ~= nil and StatusClient.status.hunger ~= status.hunger then
        StatusClient.status.hunger = status.hunger
        LocalPlayer.state:set("hunger", status.hunger, false)
        changed = true
    end
    if status.thirst ~= nil and StatusClient.status.thirst ~= status.thirst then
        StatusClient.status.thirst = status.thirst
        LocalPlayer.state:set("thirst", status.thirst, false)
        changed = true
    end
    if status.stress ~= nil and StatusClient.status.stress ~= status.stress then
        StatusClient.status.stress = status.stress
        LocalPlayer.state:set("stress", status.stress, false)
        changed = true
    end

    if changed then
        TriggerEvent("union:status:tick", StatusClient.status)
        TriggerEvent("union:status:changed", nil, nil)
    end
end)

RegisterNetEvent("union:status:update", function(stat, value)
    if not stat or StatusClient.status[stat] == nil then return end

    if StatusClient.status[stat] == value then return end  -- FIX #5 : skip si identique

    StatusClient.status[stat] = value
    LocalPlayer.state:set(stat, value, false)

    TriggerEvent("union:status:tick", StatusClient.status)
    TriggerEvent("union:status:changed", stat, value)
end)

-- ─────────────────────────────────────────────
-- DAMAGE FROM SERVER
-- ─────────────────────────────────────────────

RegisterNetEvent("union:status:applyDamage", function(amount)
    local ped = PlayerPedId()
    local hp  = GetEntityHealth(ped)

    if hp > 101 then
        SetEntityHealth(ped, hp - amount)
    end
end)

-- FIX #4 : commande de debug protégée
if Config and Config.debug then
    RegisterCommand("feed", function()
        TriggerServerEvent("union:status:sync", {
            hunger = 100,
            thirst = 100,
            stress = 0
        })
    end, false)
end

-- ─────────────────────────────────────────────
-- RESET AU DÉCHARGEMENT DU PERSONNAGE
-- ─────────────────────────────────────────────

AddEventHandler("union:character:unloaded", function()
    StatusClient.isActive = false
    StatusClient.status = { hunger = 100, thirst = 100, stress = 0 }
    _syncPending = false
end)

-- ─────────────────────────────────────────────
-- EXPORTS
-- ─────────────────────────────────────────────

exports("GetStatus", function()
    return StatusClient.status
end)

-- FIX #1 + #3 : SetStat avec debounce et guard personnage actif
exports("SetStat", function(stat, value)
    if StatusClient.status[stat] == nil then return end
    if not Client.currentCharacter then return end

    local clamped = math.max(0, math.min(100, math.floor(value + 0.5)))
    StatusClient.status[stat] = clamped
    LocalPlayer.state:set(stat, clamped, false)

    TriggerEvent("union:status:changed", stat, clamped)

    -- FIX #1 : debounce du sync serveur
    scheduleSyncToServer()
end)

-- FIX #1 + #3 : AddStat avec debounce et guard personnage actif
exports("AddStat", function(stat, value)
    if StatusClient.status[stat] == nil then return end
    if not Client.currentCharacter then return end

    local newVal = math.max(0, math.min(100,
        math.floor(StatusClient.status[stat] + (value or 0) + 0.5)
    ))
    StatusClient.status[stat] = newVal
    LocalPlayer.state:set(stat, newVal, false)

    TriggerEvent("union:status:changed", stat, newVal)

    -- FIX #1 : debounce du sync serveur
    scheduleSyncToServer()
end)

-- FIX #2 : AddPlayerStat appelle directement la logique locale,
-- plus d'auto-appel fragile exports["union"]:AddStat
exports("AddPlayerStat", function(stat, value)
    if StatusClient.status[stat] == nil then return end
    if not Client.currentCharacter then return end

    local newVal = math.max(0, math.min(100,
        math.floor(StatusClient.status[stat] + (value or 0) + 0.5)
    ))
    StatusClient.status[stat] = newVal
    LocalPlayer.state:set(stat, newVal, false)

    TriggerEvent("union:status:changed", stat, newVal)
    scheduleSyncToServer()
end)

return StatusClient
