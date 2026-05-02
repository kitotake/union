-- server/modules/vehicle/main.lua
-- FIX #14 : remplacement de "local source = source" par "local src = source"
--           dans tous les RegisterNetEvent pour éviter le shadowing de la globale FiveM

Vehicle = {}
Vehicle.logger = Logger:child("VEHICLE")
Vehicle.owned = {}

function Vehicle.giveToPlayer(player, model, props, callback)
    if not player or not model then
        if callback then callback(false) end
        return
    end

    local plate = "UNI" .. math.random(100, 999) .. math.random(10, 99)

    Database.insert([[
        INSERT INTO owned_vehicles
        (plate, unique_id, vehicle_model, vehicle_props)
        VALUES (?, ?, ?, ?)
    ]], {
        plate,
        player.currentCharacter.unique_id,
        model,
        json.encode(props or {})
    }, function(result)
        if result then
            Vehicle.logger:info("Vehicle given to " .. player.name .. ": " .. plate)
            player:notify("Vehicle given: " .. plate, "success")
            if callback then callback(true) end
        else
            if callback then callback(false) end
        end
    end)
end

function Vehicle.getPlayerVehicles(uniqueId, callback)
    Database.fetch(
        "SELECT * FROM owned_vehicles WHERE unique_id = ?",
        {uniqueId},
        callback
    )
end

function Vehicle.remove(plate, callback)
    Database.execute(
        "DELETE FROM owned_vehicles WHERE plate = ?",
        {plate},
        callback
    )
end

-- FIX #14 : src au lieu de local source = source
RegisterNetEvent("union:vehicle:give", function(model)
    local src    = source
    local player = PlayerManager.get(src)

    if not player then return end

    Vehicle.giveToPlayer(player, model, {}, function(success)
        TriggerClientEvent("union:vehicle:given", src, success)
    end)
end)

RegisterNetEvent("union:vehicle:list", function()
    local src    = source
    local player = PlayerManager.get(src)

    if not player or not player.currentCharacter then return end

    Vehicle.getPlayerVehicles(player.currentCharacter.unique_id, function(vehicles)
        TriggerClientEvent("union:vehicle:listReceived", src, vehicles or {})
    end)
end)

RegisterNetEvent("union:vehicle:spawn", function(plate)
    local src    = source
    local player = PlayerManager.get(src)

    -- FIX #16 : vérification de currentCharacter avant accès
    if not player or not player.currentCharacter then return end

    Database.fetchOne(
        "SELECT * FROM owned_vehicles WHERE plate = ? AND unique_id = ?",
        { plate, player.currentCharacter.unique_id },
        function(vehicle)
            if not vehicle then
                TriggerClientEvent("union:vehicle:spawnResult", src, false, plate)
                return
            end

            Database.execute(
                "UPDATE owned_vehicles SET stored = 0 WHERE plate = ?",
                { plate },
                function()
                    TriggerClientEvent("union:vehicle:spawnResult", src, true, plate)
                end
            )
        end
    )
end)

RegisterNetEvent("union:vehicle:store", function(plate)
    local src    = source
    local player = PlayerManager.get(src)

    if not player or not player.currentCharacter then return end

    Database.fetchOne(
        "SELECT * FROM owned_vehicles WHERE plate = ? AND unique_id = ?",
        { plate, player.currentCharacter.unique_id },
        function(vehicle)
            if not vehicle then
                TriggerClientEvent("union:vehicle:storeResult", src, false, plate)
                return
            end

            Database.execute(
                "UPDATE owned_vehicles SET stored = 1 WHERE plate = ?",
                { plate },
                function()
                    TriggerClientEvent("union:vehicle:storeResult", src, true, plate)
                end
            )
        end
    )
end)

return Vehicle