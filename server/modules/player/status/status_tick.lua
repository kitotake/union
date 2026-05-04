-- server/modules/player/status/status_tick.lua
-- FIXES:
--   #1 : Decay passe par StatusManager.set() (qui ne flush plus directement).
--        Un seul TriggerClientEvent groupé par joueur via StatusManager.flushPendingSends().
--   #2 : Vérification player.isSpawned — pas de decay en écran de chargement.
--   #3 : Save loop unique ici (retirée de manager.lua).
--   #4 : Les events stress sont envoyés conditionnellement, en dehors du flush groupé.
--   #5 : StatusManager récupéré via _G avec guard de chargement.

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
-- FIX #1 : decay via set() (pas de flush direct), puis flushPendingSends() une fois.
-- FIX #2 : skip si player.isSpawned == false.
-- ─────────────────────────────────────────────
CreateThread(function()
    while true do
        Wait(StatusConfig.tickInterval or 5000)

        for src, status in pairs(StatusManager.cache) do
            if status then
                local player = PlayerManager.get(src)

                -- FIX #2 : skip joueur non encore spawné
                if not player or not player.currentCharacter or not player.isSpawned then
                    goto continue
                end

                -- FIX #1 : set() marque _pendingSend, ne flush pas encore
                StatusManager.set(src, "hunger", status.hunger - (StatusConfig.decay.hunger or 0.8))
                StatusManager.set(src, "thirst", status.thirst - (StatusConfig.decay.thirst or 1.2))

                if status.stress > 0 then
                    StatusManager.set(src, "stress", status.stress - (StatusConfig.stressDecay or 0.5))
                end

                -- Dégâts si faim ou soif à 0
                if status.hunger <= 0 or status.thirst <= 0 then
                    TriggerClientEvent("union:status:applyDamage", src, StatusConfig.effects.damageAmount or 5)
                end

                -- FIX #4 : effets stress conditionnels (envoyés séparément, pas dans le flush groupé)
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

                debug(("tick src=%s | h=%d t=%d s=%d"):format(tostring(src), status.hunger, status.thirst, status.stress))

                ::continue::
            end
        end

        -- FIX #1 : un seul updateAll groupé par joueur après tous les sets du cycle
        StatusManager.flushPendingSends()
    end
end)

-- ─────────────────────────────────────────────
-- SAVE LOOP — FIX #3 : unique ici
-- ─────────────────────────────────────────────
CreateThread(function()
    while not Server.isReady do Wait(1000) end

    while true do
        Wait(StatusConfig.saveInterval or 60000)

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
