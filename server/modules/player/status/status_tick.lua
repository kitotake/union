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
        
        for src, status in pairs(StatusManager.cache) do
            if status then
                
                -- Decay
                status.hunger = StatusManager.clamp(status.hunger - StatusConfig.decay.hunger)
                status.thirst = StatusManager.clamp(status.thirst - StatusConfig.decay.thirst)
                
                if status.stress > 0 then
                    status.stress = StatusManager.clamp(status.stress - StatusConfig.stressDecay)
                end
                
                -- Damage
                if status.hunger <= 0 or status.thirst <= 0 then
                    TriggerClientEvent("union:status:applyDamage", src, StatusConfig.effects.damageAmount or 5)
                end
                
                -- Stress effects
                if status.stress >= 90 then
                    TriggerClientEvent("union:status:stress:max", src)
                    TriggerClientEvent("union:status:blur:max", src)
                    TriggerClientEvent("union:status:heartbeat", src)
                elseif status.stress >= 75 then
                    TriggerClientEvent("union:status:stress:high", src)
                    TriggerClientEvent("union:status:blur:medium", src)
                elseif status.stress >= 50 then
                    TriggerClientEvent("union:status:stress:low", src)
                end
                
                status._dirty = true
                TriggerClientEvent("union:status:updateAll", src, status)
                
                debug(("tick src=%s | h=%d t=%d s=%d"):format(src, status.hunger, status.thirst, status.stress))
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
        for src, player in pairs(PlayerManager.getAll() or {}) do
            local status = StatusManager.get(src)
            if status and status._dirty and player.currentCharacter then
                StatusManager.save(src, status)
                saved = saved + 1
            end
            Wait(25)
        end
        
        if saved > 0 then
            StatusManager.logger:debug(("[STATUS] %d status sauvegardés"):format(saved))
        end
    end
end)
