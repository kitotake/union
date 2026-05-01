-- server/modules/player/status/status_tick.lua
-- VERSION PRODUCTION : tick serveur unique et autoritaire
-- Plus de double decay (client + serveur), plus de sync depuis le client.

StatusTick = {}

-- ────────────────────────────────────────────────────────────────────────────
-- HELPERS
-- ────────────────────────────────────────────────────────────────────────────

local function clampLocal(value)
    return math.max(StatusConfig.min, math.min(StatusConfig.max, value))
end

local function applyDecay(status)
    status.hunger = clampLocal(status.hunger - StatusConfig.decay.hunger)
    status.thirst = clampLocal(status.thirst - StatusConfig.decay.thirst)

    if status.stress > 0 then
        status.stress = clampLocal(status.stress - StatusConfig.stressDecay)
    end
end

local function applyDamage(src, status)
    if not StatusConfig.effects.damageOnEmpty then return end
    if status.hunger > 0 and status.thirst > 0 then return end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end

    -- Ne pas tuer en dessous du seuil GTA (100 = 0 HP joueur)
    local health = GetEntityHealth(ped)
    if health > 101 then
        ApplyDamageToPed(ped, StatusConfig.effects.damageAmount, false)
    end
end

-- ────────────────────────────────────────────────────────────────────────────
-- TICK PRINCIPAL — decay + dégâts + sync client
-- Anti-spike : Wait(10) entre chaque joueur pour ne pas spiker la frame
-- ────────────────────────────────────────────────────────────────────────────

CreateThread(function()
    -- Attendre que le serveur soit prêt
    while not Server.isReady do Wait(1000) end

    StatusTick.logger = Logger:child("STATUS:TICK")
    StatusTick.logger:info("Tick serveur démarré")

    while true do
        Wait(StatusConfig.tickInterval)

        local players = PlayerManager.getAll()

        for src, player in pairs(players) do
            local status = StatusManager.get(src)

            if status and player.currentCharacter then
                -- 1. Decay
                applyDecay(status)

                -- 2. Dégâts si stat critique
                applyDamage(src, status)

                -- 3. Marquer dirty pour save loop
                status._dirty = true

                -- 4. Sync vers le client (updateAll = full refresh)
                TriggerClientEvent("union:status:updateAll", src, {
                    hunger = status.hunger,
                    thirst = status.thirst,
                    stress = status.stress,
                })
            end

            -- Anti-spike : cède la main entre chaque joueur
            Wait(10)
        end
    end
end)

-- ────────────────────────────────────────────────────────────────────────────
-- SAVE LOOP — sauvegarde périodique uniquement les entrées dirty
-- Séparée du tick pour ne pas coupler decay et I/O DB
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

            -- Anti-spike DB : pause entre chaque save
            Wait(25)
        end

        if saved > 0 then
            Logger:debug(("[STATUS] %d status sauvegardés"):format(saved))
        end
    end
end)

return StatusTick