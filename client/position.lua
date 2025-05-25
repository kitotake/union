local Config = exports.union:GetConfig()

Position = {}
local lastSavedPos, lastSavedHeading
local positionSaved = false

function Position.save()
    local ped = PlayerPedId()
    if DoesEntityExist(ped) then
        lastSavedPos = GetEntityCoords(ped)
        lastSavedHeading = GetEntityHeading(ped)
        positionSaved = true
        Utils.log("POSITION", "Position locale sauvegardée: " .. tostring(lastSavedPos))
        TriggerServerEvent("spawn:server:savePosition", lastSavedPos, lastSavedHeading)
    end
end

function Position.getLast()
    return lastSavedPos, lastSavedHeading, positionSaved
end

RegisterNetEvent("spawn:client:receiveLastPosition", function(position, heading)
    if position and position.x ~= 0 then
        lastSavedPos = position
        lastSavedHeading = heading or 0.0
        positionSaved = true
        Utils.log("POSITION", "Position reçue du serveur: " .. tostring(position))
    else
        positionSaved = false
        Utils.log("POSITION", "Aucune position valide reçue du serveur")
    end
end)

CreateThread(function()
    while true do
        Wait(60000)
        if not IsEntityDead(PlayerPedId()) then
            Position.save()
        end
        Wait(Config.saveInterval or 30000)
    end
end)
