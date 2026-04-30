StatusTick = {}

local function clamp(value)
    return math.max(StatusConfig.min, math.min(StatusConfig.max, value))
end

CreateThread(function()
    while not Server.isReady do Wait(1000) end

    while true do
        Wait(StatusConfig.tickInterval)

        for src, status in pairs(StatusManager.cache) do
            local player = PlayerManager.get(src)
            if not player or not player.currentCharacter then goto continue end

            -- DECAY
            status.hunger = clamp(status.hunger - StatusConfig.decay.hunger)
            status.thirst = clamp(status.thirst - StatusConfig.decay.thirst)

            if status.stress > 0 then
                status.stress = clamp(status.stress - StatusConfig.stressDecay)
            end

            -- DAMAGE
            if StatusConfig.effects.damageOnEmpty then
                if status.hunger <= 0 or status.thirst <= 0 then
                    local ped = GetPlayerPed(src)
                    if ped and ped ~= 0 then
                        ApplyDamageToPed(ped, StatusConfig.effects.damageAmount, false)
                    end
                end
            end

            status._dirty = true

            -- SYNC CLIENT
            TriggerClientEvent("union:status:updateAll", src, status)

            ::continue::
            Wait(50) -- anti spike
        end
    end
end)

-- SAVE LOOP
CreateThread(function()
    while true do
        Wait(StatusConfig.saveInterval)

        for src, player in pairs(PlayerManager.getAll()) do
            local status = StatusManager.get(src)
            if status and player.currentCharacter then
                StatusManager.save(src, status, player.currentCharacter.unique_id)
            end
            Wait(50)
        end
    end
end)

return StatusTick