-- server/modules/commands/admin.lua
-- FIX #12 : suppression de la commande vide RegisterCommand("", ...) à la fin du fichier.

-- Remplace
local ADMIN_ACE = "admin"
local function hasPerm(src)
    return src == 0 or IsPlayerAceAllowed(src, ADMIN_ACE)
end

-- Par
local function hasPerm(src)
    if src == 0 then return true end
    local player = PlayerManager.get(src)
    return player and player:hasPermission("admin.healrevive")
end

local function notify(src, msg)
    if src == 0 then
        print("[ADMIN] " .. msg)
    else
        TriggerClientEvent("chat:addMessage", src, {
            args = { "^3ADMIN", msg }
        })
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
    if not hasPerm(src) then return end

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
    if not hasPerm(src) then return end

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
-- REVIVE ZONE
-----------------------------------------
RegisterCommand("revivezone", function(source, args)
    local src = source
    if not hasPerm(src) then return end

    local radius = tonumber(args[1]) or 10.0
    TriggerClientEvent("admin:revivezone:client", src, radius)
    notify(src, ("Revive zone activé (rayon: %.1f)"):format(radius))
end)

-----------------------------------------
-- BRING (ramener target vers admin)
-----------------------------------------
RegisterCommand("bring", function(source, args)
    local src = source
    if not hasPerm(src) then return end

    local target = tonumber(args[1])
    if not target then return end

    TriggerClientEvent("admin:bring:client", target, src)
    notify(src, ("Bring joueur %s"):format(target))
end)

-----------------------------------------
-- GOTO (admin vers joueur)
-----------------------------------------
RegisterCommand("goto", function(source, args)
    local src = source
    if not hasPerm(src) then return end

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
    if not hasPerm(src) then return end

    local target = tonumber(args[1])
    if not target then return end

    TriggerClientEvent("admin:spectate:client", src, target)
    notify(src, ("Spectate joueur %s"):format(target))
end)

-----------------------------------------
-- TP (teleport coords)
-----------------------------------------
RegisterCommand("tp", function(source, args)
    local src = source
    if not hasPerm(src) then return end

    local x = tonumber(args[1])
    local y = tonumber(args[2])
    local z = tonumber(args[3])

    if not x or not y or not z then
        notify(src, "Usage: /tp x y z")
        return
    end

    TriggerClientEvent("admin:tp:client", src, vector3(x, y, z))
end)

-----------------------------------------
-- TPM (teleport waypoint GPS)
-----------------------------------------
RegisterCommand("tpm", function(source)
    local src = source
    if not hasPerm(src) then return end

    TriggerClientEvent("admin:tpm:client", src)
end)

RegisterCommand("car", function(source, args)
    local src = source
    if not hasPerm(src) then return end

    local model = args[1]
    if not model then
        notify(src, "Usage: /car model")
        return
    end

    TriggerClientEvent("admin:car:client", src, model)
end)
    

RegisterCommand('dv', function(source)
    local src = source
    if not hasPerm(src) then return end

    TriggerClientEvent("admin:dv:client", src)
    notify(src, "Véhicule supprimé.")
end)

RegisterCommand('dvzone', function(source, args)
    local src = source
    if not hasPerm(src) then return end

    local radius = tonumber(args[1]) or 10.0
    TriggerClientEvent("admin:dvzone:client", src, radius)
    notify(src, ("DV zone activé (rayon: %.1f)"):format(radius))
end)

RegisterCommand('fix', function(source)
    local src = source
    if not hasPerm(src) then return end

    TriggerClientEvent("admin:fix:client", src)
    notify(src, "Véhicule réparé.")
end)

RegisterCommand('boost', function(source)
    local src = source
    if not hasPerm(src) then return end

    TriggerClientEvent("admin:boost:client", src)
    notify(src, "Véhicule boosté.")
end)

RegisterCommand('spawnnpc', function(source)
    local src = source
    if not hasPerm(src) then return end

    TriggerClientEvent('admin:spawnnpc:client', src)

    notify(src, "Spawn NPC devant toi.")
end)