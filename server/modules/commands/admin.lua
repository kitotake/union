-- server/modules/commands/admin.lua
-- FIXES:
--   #1 : /revivezone et /dvzone calculent la distance côté SERVEUR
--        (avec GetEntityCoords) au lieu de déléguer au client.
--        Un client malveillant ne peut plus falsifier la zone.
--   #2 : permissions inchangées (conservées du fichier original).

local function hasPermHeal(src)
    if src == 0 then return true end
    local player = PlayerManager.get(src)
    return player and player:hasPermission("admin.healrevive")
end

local function hasPermKick(src)
    if src == 0 then return true end
    local player = PlayerManager.get(src)
    return player and player:hasPermission("admin.kick")
end

local function hasPermVehicle(src)
    if src == 0 then return true end
    local player = PlayerManager.get(src)
    return player and player:hasPermission("admin.all")
end

local function hasPermTP(src)
    if src == 0 then return true end
    local player = PlayerManager.get(src)
    return player and player:hasPermission("admin.all")
end

local function notify(src, msg)
    if src == 0 then
        print("[ADMIN] " .. msg)
    else
        TriggerClientEvent("chat:addMessage", src, { args = { "^3ADMIN", msg } })
    end
end

local function getPlayers()
    return GetPlayers()
end

-----------------------------------------
-- HEAL
-----------------------------------------
RegisterCommand("heal", function(source, args)
    local src = source
    if not hasPermHeal(src) then notify(src, "Permission refusée.") return end

    local target = args[1]
    if target == "all" then
        for _, id in ipairs(getPlayers()) do
            TriggerClientEvent("admin:heal:client", tonumber(id))
        end
        notify(src, "Tout le monde a été heal.")
        return
    end

    local t = tonumber(target) or src
    TriggerClientEvent("admin:heal:client", t)
    notify(src, ("Heal sur %s"):format(t))
end)

-----------------------------------------
-- REVIVE
-----------------------------------------
RegisterCommand("revive", function(source, args)
    local src = source
    if not hasPermHeal(src) then notify(src, "Permission refusée.") return end

    local target = args[1]
    if target == "all" then
        for _, id in ipairs(getPlayers()) do
            TriggerClientEvent("admin:revive:client", tonumber(id))
        end
        notify(src, "Tout le monde a été revive.")
        return
    end

    local t = tonumber(target) or src
    TriggerClientEvent("admin:revive:client", t)
    notify(src, ("Revive sur %s"):format(t))
end)

-----------------------------------------
-- REVIVE ZONE — FIX #1 : calcul serveur
-----------------------------------------
RegisterCommand("revivezone", function(source, args)
    local src = source
    if not hasPermHeal(src) then notify(src, "Permission refusée.") return end

    local radius = tonumber(args[1]) or 10.0

    -- Récupérer la position de l'admin côté serveur
    local adminPed    = GetPlayerPed(src)
    local adminCoords = GetEntityCoords(adminPed)

    if not adminCoords then
        notify(src, "Impossible de récupérer votre position.")
        return
    end

    local revived = 0
    for _, playerId in ipairs(getPlayers()) do
        local pid = tonumber(playerId)
        if pid ~= src then
            local ped    = GetPlayerPed(pid)
            local coords = GetEntityCoords(ped)
            if coords then
                local dist = #(adminCoords - coords)
                if dist <= radius then
                    TriggerClientEvent("admin:revive:client", pid)
                    revived = revived + 1
                end
            end
        end
    end

    notify(src, ("Revive zone (rayon: %.1fm) — %d joueur(s) revivés."):format(radius, revived))
end)

-----------------------------------------
-- BRING
-----------------------------------------
RegisterCommand("bring", function(source, args)
    local src = source
    if not hasPermKick(src) then notify(src, "Permission refusée.") return end

    local target = tonumber(args[1])
    if not target then return end

    TriggerClientEvent("admin:bring:client", target, src)
    notify(src, ("Bring joueur %s"):format(target))
end)

-----------------------------------------
-- GOTO
-----------------------------------------
RegisterCommand("goto", function(source, args)
    local src = source
    if not hasPermKick(src) then notify(src, "Permission refusée.") return end

    local target = tonumber(args[1])
    if not target then return end

    TriggerClientEvent("admin:goto:client", src, target)
    notify(src, ("Goto joueur %s"):format(target))
end)

-----------------------------------------
-- SPECTATE
-----------------------------------------
RegisterCommand("spectate", function(source, args)
    local src = source
    if not hasPermKick(src) then notify(src, "Permission refusée.") return end

    local target = tonumber(args[1])
    if not target then return end

    TriggerClientEvent("admin:spectate:client", src, target)
    notify(src, ("Spectate joueur %s"):format(target))
end)

-----------------------------------------
-- TP
-----------------------------------------
RegisterCommand("tp", function(source, args)
    local src = source

    if not hasPermTP(src) then
        notify(src, "Permission refusée.")
        return
    end

    local function parseCoord(value)
        if not value then return nil end
        value = value:gsub(",", "") -- retire les virgules
        return tonumber(value)
    end

    local x = parseCoord(args[1])
    local y = parseCoord(args[2])
    local z = parseCoord(args[3])

    if not x or not y or not z then
        notify(src, "Usage: /tp x y z")
        return
    end

    TriggerClientEvent("admin:tp:client", src, vector3(x, y, z))
end)
    
-----------------------------------------
-- TPM
-----------------------------------------
RegisterCommand("tpm", function(source)
    local src = source
    if not hasPermTP(src) then notify(src, "Permission refusée.") return end
    TriggerClientEvent("admin:tpm:client", src)
end)

-----------------------------------------
-- CAR
-----------------------------------------
RegisterCommand("car", function(source, args)
    local src = source
    if not hasPermVehicle(src) then notify(src, "Permission refusée.") return end

    local model = args[1]
    if not model then notify(src, "Usage: /car model") return end

    TriggerClientEvent("admin:car:client", src, model)
end)

-----------------------------------------
-- DV
-----------------------------------------
RegisterCommand('dv', function(source)
    local src = source
    if not hasPermVehicle(src) then notify(src, "Permission refusée.") return end
    TriggerClientEvent("admin:dv:client", src)
    notify(src, "Véhicule supprimé.")
end)

-----------------------------------------
-- DVZONE — FIX #1 : calcul serveur
-----------------------------------------
RegisterCommand('dvzone', function(source, args)
    local src = source
    if not hasPermVehicle(src) then notify(src, "Permission refusée.") return end

    local radius = tonumber(args[1]) or 10.0

    local adminPed    = GetPlayerPed(src)
    local adminCoords = GetEntityCoords(adminPed)

    if not adminCoords then
        notify(src, "Impossible de récupérer votre position.")
        return
    end

    local deleted = 0
    -- Récupérer tous les véhicules du monde
    local vehicles = GetAllVehicles()
    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle) then
            local vCoords = GetEntityCoords(vehicle)
            if vCoords then
                local dist = #(adminCoords - vCoords)
                if dist <= radius then
                    DeleteEntity(vehicle)
                    deleted = deleted + 1
                end
            end
        end
    end

    notify(src, ("DV zone (rayon: %.1fm) — %d véhicule(s) supprimé(s)."):format(radius, deleted))
end)

-----------------------------------------
-- FIX
-----------------------------------------
RegisterCommand('fix', function(source)
    local src = source
    if not hasPermVehicle(src) then notify(src, "Permission refusée.") return end
    TriggerClientEvent("admin:fix:client", src)
    notify(src, "Véhicule réparé.")
end)

RegisterCommand('boost', function(source)
    local src = source
    if not hasPermVehicle(src) then notify(src, "Permission refusée.") return end
    TriggerClientEvent("admin:boost:client", src)
    notify(src, "Véhicule boosté.")
end)

RegisterCommand('spawnnpc', function(source)
    local src = source
    if not hasPermVehicle(src) then notify(src, "Permission refusée.") return end
    TriggerClientEvent('admin:spawnnpc:client', src)
    notify(src, "Spawn NPC devant toi.")
end)
