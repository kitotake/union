-- server/modules/player/status/status_tick.lua
-- FIXES:
--   #1 : PlayerManager.getAll() retourne une table indexée par source (number),
--        pas par index numérique. La boucle `for src, player` est correcte,
--        mais on doit vérifier que StatusManager.cache[src] correspond bien
--        à un joueur encore connecté.
--   #2 : Les events stress (blur, heartbeat) sont envoyés conditionnellement
--        seulement si le joueur a un personnage actif.

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
-- ─────────────────────────────────────────────
CreateThread(function()
    while true do
        Wait(StatusConfig.tickInterval or 5000)

        -- FIX #1 : itération correcte — StatusManager.cache est indexé par src (number)
        for src, status in pairs(StatusManager.cache) do
            if status then
                -- Vérification que le joueur est encore connecté
                local player = PlayerManager.get(src)
                if not player or not player.currentCharacter then
                    -- Joueur déconnecté ou sans personnage, on saute
                    goto continue
                end

                -- Decay
                status.hunger = StatusManager.clamp(status.hunger - (StatusConfig.decay.hunger or 0.8))
                status.thirst = StatusManager.clamp(status.thirst - (StatusConfig.decay.thirst or 1.2))

                if status.stress > 0 then
                    status.stress = StatusManager.clamp(status.stress - (StatusConfig.stressDecay or 0.5))
                end

                -- Dégâts si faim ou soif à 0
                if status.hunger <= 0 or status.thirst <= 0 then
                    TriggerClientEvent("union:status:applyDamage", src, StatusConfig.effects.damageAmount or 5)
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

                status._dirty = true

                TriggerClientEvent("union:status:updateAll", src, {
                    hunger = status.hunger,
                    thirst = status.thirst,
                    stress = status.stress,
                })

                debug(("tick src=%s | h=%d t=%d s=%d"):format(tostring(src), status.hunger, status.thirst, status.stress))

                ::continue::
            end
        end
    end
end)

-- ─────────────────────────────────────────────
-- SAVE LOOP
-- ─────────────────────────────────────────────
CreateThread(function()
    while not Server.isReady do Wait(1000) end

    while true do
        Wait(StatusConfig.saveInterval or 60000)

        local saved = 0
        -- FIX #1 : itération correcte sur PlayerManager (indexé par source)
        for src, player in pairs(PlayerManager.getAll() or {}) do
            if player and player.currentCharacter then
                local status = StatusManager.get(src)
                if status and status._dirty then
                    StatusManager.save(src, status)
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
