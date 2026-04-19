-- client/components/position.lua
Position = {}
local lastSavedPos = nil
local lastSavedHeading = nil
local positionSaved = false

function Position.save()
    local ped = PlayerPedId()
    if DoesEntityExist(ped) then
        lastSavedPos = GetEntityCoords(ped)
        lastSavedHeading = GetEntityHeading(ped)
        positionSaved = true
        Logger:debug("Position saved locally: " .. tostring(lastSavedPos))
        TriggerServerEvent("union:position:save", lastSavedPos, lastSavedHeading)
    end
end

function Position.get()
    return lastSavedPos, lastSavedHeading, positionSaved
end

function Position.setLast(position, heading)
    if position and position.x ~= 0 then
        lastSavedPos = position
        lastSavedHeading = heading or 0.0
        positionSaved = true
        Logger:debug("Position received from server: " .. tostring(position))
    else
        positionSaved = false
        Logger:debug("Invalid position received from server")
    end
end

-- Listen for position from server
RegisterNetEvent("union:position:loaded", function(position, heading)
    Position.setLast(position, heading)
end)

-- Auto-save position periodically
CreateThread(function()
    while true do
        Wait(Config.spawn.saveInterval)
        if Client.isReady and not IsEntityDead(PlayerPedId()) then
            Position.save()
        end
    end
end)