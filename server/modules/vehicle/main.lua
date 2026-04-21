-- server/modules/vehicle/main.lua
Vehicle = {}
Vehicle.logger = Logger:child("VEHICLE")
Vehicle.owned = {}

-- Give vehicle to player
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

-- Get player vehicles
function Vehicle.getPlayerVehicles(uniqueId, callback)
    Database.fetch(
        "SELECT * FROM owned_vehicles WHERE unique_id = ?",
        {uniqueId},
        callback
    )
end

-- Remove vehicle
function Vehicle.remove(plate, callback)
    Database.execute(
        "DELETE FROM owned_vehicles WHERE plate = ?",
        {plate},
        callback
    )
end

-- Events
RegisterNetEvent("union:vehicle:give", function(model)
    local source = source
    local player = PlayerManager.get(source)
    
    if not player then return end
    
    Vehicle.giveToPlayer(player, model, {}, function(success)
        TriggerClientEvent("union:vehicle:given", source, success)
    end)
end)

RegisterNetEvent("union:vehicle:list", function()
    local source = source
    local player = PlayerManager.get(source)
    
    if not player or not player.currentCharacter then return end
    
    Vehicle.getPlayerVehicles(player.currentCharacter.unique_id, function(vehicles)
        TriggerClientEvent("union:vehicle:listReceived", source, vehicles or {})
    end)
end)

RegisterNetEvent("union:vehicle:spawn", function(plate)
    local source = source
    local player = PlayerManager.get(source)
    if not player or not player.currentCharacter then return end

    Database.fetchOne(
        "SELECT * FROM owned_vehicles WHERE plate = ? AND unique_id = ?",
        { plate, player.currentCharacter.unique_id },
        function(vehicle)
            if not vehicle then
                TriggerClientEvent("union:vehicle:spawnResult", source, false, plate)
                return
            end

            Database.execute(
                "UPDATE owned_vehicles SET stored = 0 WHERE plate = ?",
                { plate },
                function()
                    TriggerClientEvent("union:vehicle:spawnResult", source, true, plate)
                end
            )
        end
    )
end)

RegisterNetEvent("union:vehicle:store", function(plate)
    local source = source
    local player = PlayerManager.get(source)
    if not player or not player.currentCharacter then return end

    Database.fetchOne(
        "SELECT * FROM owned_vehicles WHERE plate = ? AND unique_id = ?",
        { plate, player.currentCharacter.unique_id },
        function(vehicle)
            if not vehicle then
                TriggerClientEvent("union:vehicle:storeResult", source, false, plate)
                return
            end

            Database.execute(
                "UPDATE owned_vehicles SET stored = 1 WHERE plate = ?",
                { plate },
                function()
                    TriggerClientEvent("union:vehicle:storeResult", source, true, plate)
                end
            )
        end
    )
end)

return Vehicle