-- server/modules/player/status/status_tick.lua

print("[STATUS] Tick loaded")

local StatusManager = _G.StatusManager
if not StatusManager then
    print("^1[STATUS][FATAL] StatusManager introuvable (ordre de chargement incorrect)^0")
    return
end

local function debug(msg)
    if StatusConfig and StatusConfig.debug then
        print("^3[STATUS][TICK]^0 " .. msg)
    end
end

-- ─────────────────────────────────────────────
-- MAIN TICK
-- ─────────────────────────────────────────────
CreateThread(function()
    -- Guard : attendre que StatusConfig soit chargé
    while not StatusConfig or not StatusConfig.tickInterval do
        print("^3[STATUS][TICK] En attente de StatusConfig...^0")
        Wait(1000)
    end

    print(("^2[STATUS][TICK] Démarrage — interval=%dms decay h=%.1f t=%.1f^0"):format(
        StatusConfig.tickInterval,
        StatusConfig.decay.hunger,
        StatusConfig.decay.thirst
    ))

    while true do
        Wait(StatusConfig.tickInterval)

        for src, status in pairs(StatusManager.cache) do
            if status then
                local player = PlayerManager.get(src)

                if not player or not player.currentCharacter or not player.isSpawned then
                    goto continue
                end

                local newHunger = status.hunger - (StatusConfig.decay.hunger or 0.8)
                local newThirst = status.thirst - (StatusConfig.decay.thirst or 1.2)

                StatusManager.set(src, "hunger", newHunger)
                StatusManager.set(src, "thirst", newThirst)

                if status.stress > 0 then
                    StatusManager.set(src, "stress", status.stress - (StatusConfig.stressDecay or 0.5))
                end

                if status.hunger <= 0 or status.thirst <= 0 then
                    TriggerClientEvent("union:status:applyDamage", src, StatusConfig.effects.damageAmount or 5)
                end

                if status.stress >= 90 then
                    TriggerClientEvent("union:status:stress:max",  src)
                    TriggerClientEvent("union:status:blur:max",    src)
                    TriggerClientEvent("union:status:heartbeat",   src)
                elseif status.stress >= 75 then
                    TriggerClientEvent("union:status:stress:high", src)
                    TriggerClientEvent("union:status:blur:medium", src)
                elseif status.stress >= 50 then
                    TriggerClientEvent("union:status:stress:low",  src)
                end

                debug(("tick src=%s | h=%d t=%d s=%d [%s]"):format(
                    tostring(src),
                    status.hunger,
                    status.thirst,
                    status.stress,
                    os.date("%H:%M:%S")
                ))

                ::continue::
            end
        end

        StatusManager.flushPendingSends()
    end
end)

-- ─────────────────────────────────────────────
-- SAVE LOOP
-- ─────────────────────────────────────────────
CreateThread(function()
    while not StatusConfig or not StatusConfig.saveInterval do
        Wait(1000)
    end

    while not Server.isReady do
        Wait(1000)
    end

    while true do
        Wait(StatusConfig.saveInterval)

        local saved = 0
        for src, player in pairs(PlayerManager.getAll() or {}) do
            if player and player.currentCharacter and player.isSpawned then
                local status = StatusManager.get(src)
                if status and status._dirty then
                    StatusManager.save(src, status, player.license)
                    saved = saved + 1
                end
            end
            Wait(25)
        end

        if saved > 0 then
            StatusManager.logger:debug(("[STATUS] %d status sauvegardés"):format(saved))
        end
    end
end)