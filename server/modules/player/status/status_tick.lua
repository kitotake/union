-- server/modules/player/status/status_tick.lua
-- FIXES:
--   #1 : Decay groupé — on calcule les 3 stats puis UN SEUL TriggerClientEvent
--         au lieu de 3 (un par StatusManager.set)
--   #2 : Effets stress conditionnels
--   #3 : Une seule save loop (manager.lua n'en a plus)
--   #4 : Save loop passe player.license directement pour éviter race condition

print("[STATUS] Tick loaded")

local StatusManager = _G.StatusManager
if not StatusManager then
    print("^1[STATUS][FATAL] StatusManager introuvable (ordre de chargement incorrect)^0")
    return
end

local function debug(msg)
    if StatusConfig.debug then
        print("^3[STATUS][TICK]^0 " .. msg)
    end
end

-- ─────────────────────────────────────────────
-- MAIN TICK
-- FIX #1 : on modifie le cache directement pour les 3 stats
-- puis un seul TriggerClientEvent("union:status:updateAll")
-- Avant : 3 appels StatusManager.set = 3 TriggerClientEvent par joueur par tick
-- ─────────────────────────────────────────────
CreateThread(function()
    while true do
        Wait(StatusConfig.tickInterval or 5000)

        for src, status in pairs(StatusManager.cache) do
            if status then
                local player = PlayerManager.get(src)
                if not player or not player.currentCharacter then
                    goto continue
                end

                -- Decay direct sur le cache (pas via set pour éviter 3x TriggerClientEvent)
                status.hunger = StatusManager.clamp(status.hunger - (StatusConfig.decay.hunger or 0.8))
                status.thirst = StatusManager.clamp(status.thirst - (StatusConfig.decay.thirst or 1.2))

                if status.stress > 0 then
                    status.stress = StatusManager.clamp(status.stress - (StatusConfig.stressDecay or 0.5))
                end

                status._dirty = true

                -- FIX #1 : UN SEUL TriggerClientEvent pour les 3 stats
                TriggerClientEvent("union:status:updateAll", src, {
                    hunger = status.hunger,
                    thirst = status.thirst,
                    stress = status.stress,
                })

                -- Dégâts si faim ou soif à 0
                if status.hunger <= 0 or status.thirst <= 0 then
                    TriggerClientEvent("union:status:applyDamage", src,
                        StatusConfig.effects.damageAmount or 5)
                end

                -- FIX #2 : effets stress conditionnels
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

                debug(("tick src=%s | h=%d t=%d s=%d"):format(
                    tostring(src), status.hunger, status.thirst, status.stress))

                ::continue::
            end
        end
    end
end)

-- ─────────────────────────────────────────────
-- SAVE LOOP — unique ici (plus de save loop dans manager.lua)
-- FIX #4 : passe player.license directement à save()
-- ─────────────────────────────────────────────
CreateThread(function()
    while not Server.isReady do Wait(1000) end

    while true do
        Wait(StatusConfig.saveInterval or 60000)

        local saved = 0
        for src, player in pairs(PlayerManager.getAll() or {}) do
            if player and player.currentCharacter and player.license then
                local status = StatusManager.get(src)
                if status and status._dirty then
                    -- FIX #4 : license déjà disponible ici, pas de risque de nil
                    StatusManager.save(src, status, player.license)
                    saved = saved + 1
                end
            end
            Wait(25) -- ne pas bloquer le thread
        end

        if saved > 0 then
            StatusManager.logger:debug(("[STATUS] %d status sauvegardés"):format(saved))
        end
    end
end)