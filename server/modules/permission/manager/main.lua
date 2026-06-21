-- server/modules/permission/manager/main.lua
PermissionSystem        = {}
PermissionSystem.logger = Logger:child("PERMISSION")
PermissionSystem.cache  = {}

function PermissionSystem.hasPermission(source, permission)
    local player = PlayerManager.get(source)
    if not player then return false end
    if player.group == "founder" then return true end
    return PermissionGroups.hasGroupPermission(player.group, permission)
end

function PermissionSystem.canExecute(source, permission)
    return PermissionSystem.hasPermission(source, permission)
end

function PermissionSystem.getPlayerGroup(source)
    local player = PlayerManager.get(source)
    if not player then return "user" end
    return player.group
end

-- FIX: ajout du paramètre callback pour obtenir le vrai résultat de la DB
-- L'ancienne version retournait true immédiatement avant que la DB réponde
function PermissionSystem.setPlayerGroup(source, group, callback)
    local player = PlayerManager.get(source)
    if not player then
        if callback then callback(false) end
        return
    end
    if not PermissionGroups.defaults[group] then
        PermissionSystem.logger:warn("Groupe invalide : " .. tostring(group))
        if callback then callback(false) end
        return
    end
    Database.execute(
        "UPDATE users SET `group` = ? WHERE id = ?",
        { group, player.userId },
        function(result)
            if result then
                player.group = group
                PermissionSystem.logger:info(("Groupe mis à jour pour %s : %s"):format(player.name, group))
                if callback then callback(true) end
            else
                PermissionSystem.logger:error(("Échec mise à jour groupe pour %s"):format(player.name))
                if callback then callback(false) end
            end
        end
    )
end

function PermissionSystem.addPermissionToGroup(group, permission)
    local info = PermissionGroups.defaults[group]
    if not info then
        PermissionGroups.defaults[group] = { displayName = group, level = 0, permissions = {} }
        info = PermissionGroups.defaults[group]
    end
    table.insert(info.permissions, permission)
end

function PermissionSystem.removePermissionFromGroup(group, permission)
    local info = PermissionGroups.defaults[group]
    if not info then return end
    for i, perm in ipairs(info.permissions) do
        if perm == permission then
            table.remove(info.permissions, i)
            return
        end
    end
end

RegisterNetEvent("union:permission:check", function(permission, requestId)
    local src           = source
    local hasPermission = PermissionSystem.hasPermission(src, permission)
    TriggerClientEvent("union:permission:checkResponse", src, requestId, hasPermission)
end)

RegisterCommand("mygroup", function(source)
    local player = PlayerManager.get(source)
    if not player then return end
    TriggerClientEvent("chat:addMessage", source, {
        color     = { 100, 255, 100 },
        multiline = true,
        args      = { "[GROUP]", "Votre groupe : " .. player.group },
    })
end)

return PermissionSystem
