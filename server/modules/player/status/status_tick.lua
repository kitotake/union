-- server/modules/player/status/status_tick.lua
-- FIX #5 : utilise StatusManager.clamp au lieu de dupliquer clampLocal
-- VERSION PRODUCTION : tick serveur unique et autoritaire

StatusTick = {}

-- ────────────────────────────────────────────────────────────────────────────
-- HELPERS
-- FIX #5 : réutilise StatusManager.clamp (défini dans manager.lua, chargé avant)
-- ────────────────────────────────────────────────────────────────────────────

local function applyDecay(status)
    local clamp = StatusManager.clamp
    status.hunger = clamp(status.hunger - StatusConfig.decay.hunger)
    status.thirst = clamp(status.thirst - StatusConfig.decay.thirst)

    if status.stress > 0 then
        status.stress = clamp(status.stress - StatusConfig.stressDecay)
    end
end

local function applyDamage(src, status)
    if not StatusConfig.effects.damageOnEmpty then return end
    if status.hunger > 0 and status.thirst > 0 then return end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end

    local health = GetEntityHealth(ped)
    if health > 101 then
        SetEntityHealth(ped, health - StatusConfig.effects.damageAmount)
    end
end

-- ────────────────────────────────────────────────────────────────────────────
-- TICK PRINCIPAL
-- ────────────────────────────────────────────────────────────────────────────

CreateThread(function()
    while not Server.isReady do Wait(1000) end

    StatusTick.logger = Logger:child("STATUS:TICK")
    StatusTick.logger:info("Tick serveur démarré")

    while true do
        Wait(StatusConfig.tickInterval)

        local players = PlayerManager.getAll()

        for src, player in pairs(players) do
            local status = StatusManager.get(src)

            if status and player.currentCharacter then
                applyDecay(status)
                applyDamage(src, status)
                status._dirty = true

                TriggerClientEvent("union:status:updateAll", src, {
                    hunger = status.hunger,
                    thirst = status.thirst,
                    stress = status.stress,
                })
            end

            Wait(10)
        end
    end
end)

-- ────────────────────────────────────────────────────────────────────────────
-- SAVE LOOP
-- ────────────────────────────────────────────────────────────────────────────

CreateThread(function()
    while not Server.isReady do Wait(1000) end

    while true do
        Wait(StatusConfig.saveInterval)

        local saved = 0

        for src, player in pairs(PlayerManager.getAll()) do
            local status = StatusManager.get(src)

            if status and status._dirty and player.currentCharacter then
                StatusManager.save(src, status)
                saved = saved + 1
            end

            Wait(25)
        end

        if saved > 0 then
            Logger:debug(("[STATUS] %d status sauvegardés"):format(saved))
        end
    end
end)

return StatusTick