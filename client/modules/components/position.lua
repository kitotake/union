-- client/modules/components/position.lua

Position = {}
local lastSavedPos     = nil
local lastSavedHeading = nil
local positionSaved    = false

function Position.save()
   

    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then
        return
    end

    if IsEntityDead(ped) then
        Logger:debug("Position skip: joueur mort")
        return
    end

    local coords  = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    Logger:debug("Position save called: " .. tostring(coords) .. ", heading: " .. tostring(heading))

    if math.abs(coords.x) < 1.0 and math.abs(coords.y) < 1.0 then
        Logger:debug("Position skip: coords nulles (spawn en cours)")
        return
    end

    lastSavedPos     = coords
    lastSavedHeading = heading
    positionSaved    = true

    print("^2[POSITION]^7 position sauvegardée localement")
    Logger:debug("Position saved locally: " .. tostring(lastSavedPos))

    print("^5[POSITION]^7 TriggerServerEvent -> union:position:save")
    TriggerServerEvent("union:position:save", lastSavedPos, lastSavedHeading)
end

function Position.get()
    return lastSavedPos, lastSavedHeading, positionSaved
end

function Position.setLast(position, heading)
    
    if position and position.x ~= 0 then
        lastSavedPos     = position
        lastSavedHeading = heading or 0.0
        positionSaved    = true

        Logger:debug("Position received from server: " .. tostring(position))
    else
        positionSaved = false
        Logger:debug("Invalid position received from server")
    end
end

RegisterNetEvent("union:position:loaded", function(position, heading)
    Position.setLast(position, heading)
end)

CreateThread(function()
    while true do
        Wait(Config.spawn.saveInterval)

        if Client.isReady and Client.currentCharacter then
            Position.save()
        else
            Logger:debug("Position auto-save skipped: client not ready or no character")
        end
    end
end)