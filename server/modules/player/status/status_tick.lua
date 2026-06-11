-- server/modules/player/status/status_tick.lua

-- BUG-3 : ne pas capturer _G.StatusManager en top-level (peut être nil au démarrage)
-- Utiliser un getter lazy pour récupérer la référence au moment de l'utilisation
local function getSM()
    return _G.StatusManager
end

local function debug(msg)
    if StatusConfig and StatusConfig.debug then
        print("^3[STATUS][TICK]^0 " .. msg)
    end
end

CreateThread(function()
    -- BUG-3 : retry si StatusManager pas encore initialisé
    local SM = getSM()
    local waited = 0
    while not SM do
        Wait(500)
        SM = getSM()
        waited = waited + 1
        if waited >= 20 then
            Logger:error("[STATUS][TICK][FATAL] StatusManager introuvable après 10s — tick abandonné")
            return
        end
    end

    -- Attendre StatusConfig
    local waitedConfig = 0
    while not StatusConfig or not StatusConfig.tickInterval do
        Wait(1000)
        waitedConfig = waitedConfig + 1
        if waitedConfig >= 60 then
            Logger:error("[STATUS][TICK][FATAL] StatusConfig non disponible après 60s — tick abandonné")
            return
        end
    end

    Logger:info(("[STATUS][TICK] Démarrage — interval=%dms decay h=%.1f t=%.1f"):format(
        StatusConfig.tickInterval, StatusConfig.decay.hunger, StatusConfig.decay.thirst))

    while true do
        Wait(StatusConfig.tickInterval)
        -- BUG-3 : récupérer SM à chaque cycle pour être robuste à un éventuel reload
        SM = getSM()
        if not SM then
            Logger:warn("[STATUS][TICK] StatusManager perdu — attente")
            goto continue
        end

        for src, status in pairs(SM.cache) do
            if status then
                local player = PlayerManager.get(src)
                if not player or not player.currentCharacter or not player.isSpawned then
                    goto continue_inner
                end
                SM.set(src, "hunger", status.hunger - (StatusConfig.decay.hunger or 0.8))
                SM.set(src, "thirst", status.thirst - (StatusConfig.decay.thirst or 1.2))
                if status.stress > 0 then
                    SM.set(src, "stress", status.stress - (StatusConfig.stressDecay or 0.5))
                end
                -- Utiliser StatusConfig.min au lieu de 0 en dur
                local threshold = StatusConfig.min or 0
                if status.hunger <= threshold or status.thirst <= threshold then
                    TriggerClientEvent("union:status:applyDamage", src, StatusConfig.effects.damageAmount or 5)
                end
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
                ::continue_inner::
            end
        end
        SM.flushPendingSends()
        ::continue::
    end
end)

CreateThread(function()
    local waitedSave = 0
    while not StatusConfig or not StatusConfig.saveInterval do
        Wait(1000); waitedSave = waitedSave + 1
        if waitedSave >= 60 then
            Logger:error("[STATUS][SAVE][FATAL] StatusConfig non disponible après 60s")
            return
        end
    end
    local waitedServer = 0
    while not Server.isReady do
        Wait(1000); waitedServer = waitedServer + 1
        if waitedServer >= 60 then
            Logger:error("[STATUS][SAVE][FATAL] Server.isReady jamais true après 60s")
            return
        end
    end
    while true do
        Wait(StatusConfig.saveInterval)
        local SM = getSM()
        if not SM then goto save_continue end
        local saved = 0
        for src, player in pairs(PlayerManager.getAll() or {}) do
            if player and player.currentCharacter and player.isSpawned then
                local status = SM.get(src)
                if status and status._dirty then
                    SM.save(src, status, player.license)
                    saved = saved + 1
                end
            end
            Wait(25)
        end
        if saved > 0 then SM.logger:debug(("[STATUS] %d status sauvegardés"):format(saved)) end
        ::save_continue::
    end
end)