-- client/modules/vehicle/main.lua
-- FIX WARN-5 : Vehicle.spawn() envoyait un objet {plate, position, heading}
--              mais le serveur attend uniquement la plate en string.
--              On aligne le client sur le contrat serveur.
-- FIX NOTE-2 : suppression du handler union:vehicle:listReceived ici —
--              il était dupliqué avec client/modules/commands/vehicle.lua.
--              La version dans commands/vehicle.lua est complète (affichage console
--              + notifications). Ce fichier ne garde que l'API programmatique.

Vehicle = {}
Vehicle.logger = Logger:child("VEHICLE")
Vehicle.owned = {}
Vehicle.currentVehicle = nil

function Vehicle.list()
    Vehicle.logger:info("Requesting vehicle list")
    TriggerServerEvent("union:vehicle:list")
end

-- FIX WARN-5 : plate uniquement, aligné sur le handler serveur
function Vehicle.spawn(plate)
    if not plate then return end
    Vehicle.logger:info("Spawning vehicle: " .. plate)
    TriggerServerEvent("union:vehicle:spawn", plate)
end

function Vehicle.store(plate)
    if not plate then return end
    Vehicle.logger:info("Storing vehicle: " .. plate)
    TriggerServerEvent("union:vehicle:store", plate)
end

RegisterNetEvent("union:vehicle:given", function(success)
    if success then
        Notifications.send("Vehicle given successfully", "success")
        Vehicle.list()
    else
        Notifications.send("Failed to give vehicle", "error")
    end
end)

-- FIX NOTE-2 : handler union:vehicle:listReceived retiré de ce fichier.
-- Le handler canonique est dans client/modules/commands/vehicle.lua.

return Vehicle