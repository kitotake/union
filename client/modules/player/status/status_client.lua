StatusClient = {}
StatusClient.status = { hunger = 100, thirst = 100, stress = 0 }
StatusClient.isActive = false

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

    -- Notification à la HUD
    TriggerEvent("union:status:ready", StatusClient.status)
end)

RegisterNetEvent("union:status:updateAll", function(status)
    if not status then return end

    StatusClient.status.hunger = status.hunger
    StatusClient.status.thirst = status.thirst
    StatusClient.status.stress = status.stress

    TriggerEvent("union:status:tick", StatusClient.status)
    TriggerEvent("union:status:changed", nil, nil) -- ou tu peux émettre par stat si besoin
end)

-- Partial update (au cas où)
RegisterNetEvent("union:status:update", function(stat, value)
    if not stat or StatusClient.status[stat] == nil then return end
    StatusClient.status[stat] = value

    TriggerEvent("union:status:tick", StatusClient.status)
    TriggerEvent("union:status:changed", stat, value)
end)

-- ─────────────────────────────────────────────
-- DAMAGE FROM SERVER
-- ─────────────────────────────────────────────

RegisterNetEvent("union:status:applyDamage", function(amount)
    local ped = PlayerPedId()
    local hp = GetEntityHealth(ped)

    if hp > 101 then
        SetEntityHealth(ped, hp - amount)
    end
end)

-- ─────────────────────────────────────────────
-- EXPORTS
-- ─────────────────────────────────────────────

exports("GetStatus", function()
    return StatusClient.status
end)

exports("AddStat", function(stat, value)
    if not StatusClient.status[stat] then return end
    StatusClient.status[stat] = math.max(0, math.min(100, StatusClient.status[stat] + value))

    TriggerServerEvent("union:status:sync", StatusClient.status)
    TriggerEvent("union:status:changed", stat, StatusClient.status[stat])
end)

-- Compatibilité avec l'ancien nom
exports("AddPlayerStat", function(stat, value) -- pour les scripts qui l'utilisent
    exports['union']:AddStat(stat, value)
end)

return StatusClient