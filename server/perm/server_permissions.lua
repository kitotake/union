-- server/perm/server_permissions.lua
local json = require("json")

if not Permissions then
    print("^1[ERREUR] Le module 'permissions.lua' n'est pas chargé. Vérifie ton fxmanifest.^0")
    Permissions = { Groups = {}, Players = {}, File = "permissions_data.json" }
end

-- Sauvegarde des permissions
local function SavePermissions()
    local file = io.open(Permissions.File, "w+")
    if file then
        file:write(json.encode(Permissions.Players))
        file:close()
    else
        print("^1[ERREUR] Impossible d'ouvrir le fichier de permissions pour écriture.^0")
    end
end

-- Chargement des permissions
local function LoadPermissions()
    local file = io.open(Permissions.File, "r")
    if file then
        local data = file:read("*a")
        file:close()
        if data and data ~= "" then
            Permissions.Players = json.decode(data) or {}
        end
    else
        Permissions.Players = {}
    end
end

LoadPermissions()

-- Utilitaires
function GetIdentifier(src)
    local identifiers = GetPlayerIdentifiers(src)
    return identifiers[1] or ("unknown_" .. tostring(src))
end

function GetPlayerGroup(src)
    local id = GetIdentifier(src)
    return Permissions.Players[id] or "user"
end

function SetPlayerGroup(src, group)
    local id = GetIdentifier(src)
    if Permissions.Groups[group] then
        Permissions.Players[id] = group
        SavePermissions()
        return true
    end
    return false
end

function HasPermission(src, perm)
    local group = GetPlayerGroup(src)
    local perms = Permissions.Groups[group]
    if not perms then return false end
    for _, p in ipairs(perms) do
        if p == perm or p == "admin.all" then
            return true
        end
    end
    return false
end

-- Callback serveur pour client
RegisterNetEvent('permissions:HasPermission')
AddEventHandler('permissions:HasPermission', function(perm, requestId)
    local src = source
    local result = HasPermission(src, perm)
    TriggerClientEvent('permissions:HasPermission:Response', src, requestId, result)
end)

-- /info : affiche le groupe du joueur
RegisterCommand("info", function(source, args)
    local src = source
    local group = GetPlayerGroup(src)
    TriggerClientEvent('chat:addMessage', src, { args = { "^3Info:", ("Votre groupe actuel est : %s"):format(group) } })
end)


-- Commandes Admin
RegisterCommand("setgroup", function(source, args)
    if not HasPermission(source, "admin.setgroup") then
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Erreur:", "Permission refusée." } })
        return
    end

    local target = tonumber(args[1])
    local newGroup = tostring(args[2])
    if not target or not newGroup or not Permissions.Groups[newGroup] then
        TriggerClientEvent('chat:addMessage', source, { args = { "^3Usage:", "/setgroup [id] [fondateur/admin/moderateur/user]" } })
        return
    end

    if SetPlayerGroup(target, newGroup) then
        TriggerClientEvent('chat:addMessage', source, { args = { "^2Succès:", ("Le joueur %s est maintenant %s"):format(GetPlayerName(target), newGroup) } })
        TriggerClientEvent('chat:addMessage', target, { args = { "^2Info:", ("Votre groupe a été changé en %s"):format(newGroup) } })
    else
        TriggerClientEvent('chat:addMessage', source, { args = { "^1Erreur:", "Groupe invalide." } })
    end
end)

RegisterCommand("getgroup", function(source, args)
    local target = tonumber(args[1]) or source
    local group = GetPlayerGroup(target)
    TriggerClientEvent('chat:addMessage', source, { args = { "^3Info:", ("Le joueur %s est %s"):format(GetPlayerName(target), group) } })
end)

RegisterCommand("checkperm", function(source, args)
    local perm = tostring(args[1])
    if not perm then
        TriggerClientEvent('chat:addMessage', source, { args = { "^3Usage:", "/checkperm [permission]" } })
        return
    end

    if HasPermission(source, perm) then
        TriggerClientEvent('chat:addMessage', source, { args = { "^2✔ Vous avez la permission:", perm } })
    else
        TriggerClientEvent('chat:addMessage', source, { args = { "^1✖ Vous n'avez pas la permission:", perm } })
    end
end)

-- Auto-assignation au premier join
AddEventHandler('playerJoining', function()
    local src = source
    local id = GetIdentifier(src)
    if not Permissions.Players[id] then
        Permissions.Players[id] = "user"
        SavePermissions()
    end
end)
