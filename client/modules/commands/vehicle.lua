-- client/modules/commands/vehicle.lua

-- /myvehicles — liste les véhicules du personnage
RegisterCommand("myvehicles", function()
    if not Character.current then
        Notifications.send("Aucun personnage actif.", "warning")
        return
    end
    TriggerServerEvent("union:vehicle:list")
end, false)

-- /spawncar <plaque> — spawner un de ses véhicules
RegisterCommand("spawncar", function(source, args)
    if not Character.current then
        Notifications.send("Aucun personnage actif.", "warning")
        return
    end

    local plate = args[1]
    if not plate then
        Notifications.send("Usage: /spawncar <plaque>", "error")
        return
    end

    TriggerServerEvent("union:vehicle:spawn", plate)
end, false)

-- /storecar — ranger le véhicule dans lequel tu es
RegisterCommand("storecar", function()
    if not Character.current then
        Notifications.send("Aucun personnage actif.", "warning")
        return
    end

    local ped     = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if not DoesEntityExist(vehicle) then
        Notifications.send("Vous n'êtes pas dans un véhicule.", "error")
        return
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    if not plate or plate == "" then
        Notifications.send("Plaque illisible.", "error")
        return
    end

    TriggerServerEvent("union:vehicle:store", plate)
end, false)

-- /vehinfo — infos du véhicule actuel
RegisterCommand("vehinfo", function()
    local ped     = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if not DoesEntityExist(vehicle) then
        Notifications.send("Vous n'êtes pas dans un véhicule.", "error")
        return
    end

    local plate        = GetVehicleNumberPlateText(vehicle)
    local engineHealth = math.floor(GetVehicleEngineHealth(vehicle))
    local bodyHealth   = math.floor(GetVehicleBodyHealth(vehicle))
    local fuel         = math.floor(GetVehicleFuelLevel(vehicle))

    Notifications.send(
        string.format("Plaque: %s | Moteur: %s | Carrosserie: %s | Carburant: %s%%",
            plate, engineHealth, bodyHealth, fuel),
        "info"
    )
end, false)

-- Réceptions depuis le serveur
RegisterNetEvent("union:vehicle:listReceived", function(vehicles)
    if not vehicles or #vehicles == 0 then
        Notifications.send("Vous n'avez aucun véhicule.", "warning")
        return
    end

    print("^2[VEHICLES] Vos véhicules :")
    for _, v in ipairs(vehicles) do
        local stored = v.stored == 1 and "^3[GARÉ]^7" or "^2[SORTI]^7"
        print(string.format(
            "  %s ^3%s^7 — Modèle: %s | Moteur: %.0f | Carburant: %.0f%%",
            stored, v.plate, v.vehicle_model, v.engine_health, v.fuel
        ))
    end

    Notifications.send(#vehicles .. " véhicule(s). (voir console)", "info")
end)

RegisterNetEvent("union:vehicle:spawnResult", function(success, plate)
    if success then
        Notifications.send("Véhicule " .. plate .. " spawné.", "success")
    else
        Notifications.send("Impossible de spawner ce véhicule.", "error")
    end
end)

RegisterNetEvent("union:vehicle:storeResult", function(success, plate)
    if success then
        Notifications.send("Véhicule " .. plate .. " rangé.", "success")
    else
        Notifications.send("Impossible de ranger ce véhicule.", "error")
    end
end)