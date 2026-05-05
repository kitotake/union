-- server/modules/permission/main.lua
-- FIX : suppression de la double définition de PermissionSystem.groups.
--       On délègue maintenant à PermissionGroups (source unique de vérité).
--       Plus de divergence entre les deux fichiers.

PermissionSystem = {}
PermissionSystem.logger = Logger:child("PERMISSION")
PermissionSystem.cache  = {}

function PermissionSystem.hasPermission(source, permission)
    local player = PlayerManager.get(source)
    if not player then return false end

    -- founder a toujours tout
    if player.group == "founder" then return true end

    -- Délègue à PermissionGroups (source unique)
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

function PermissionSystem.setPlayerGroup(source, group)
    local player = PlayerManager.get(source)
    if not player then return false end

    if not PermissionGroups.defaults[group] then
        PermissionSystem.logger:warn("Groupe invalide : " .. tostring(group))
        return false
    end

    Database.execute(
        "UPDATE users SET `group` = ? WHERE id = ?",
        { group, player.userId },
        function(result)
            if result then
                player.group = group
                PermissionSystem.logger:info("Groupe mis à jour pour " .. player.name .. " : " .. group)
            end
        end
    )

    return true
end

function PermissionSystem.addPermissionToGroup(group, permission)
    local info = PermissionGroups.defaults[group]
    if not info then
        PermissionGroups.defaults[group] = { displayName = group, level = 0, permissions = {} }
        info = PermissionGroups.defaults[group]
    end
    table.insert(info.permissions, permission)
    PermissionSystem.logger:info("Permission ajoutée au groupe " .. group .. " : " .. permission)
end

function PermissionSystem.removePermissionFromGroup(group, permission)
    local info = PermissionGroups.defaults[group]
    if not info then return end
    for i, perm in ipairs(info.permissions) do
        if perm == permission then
            table.remove(info.permissions, i)
            PermissionSystem.logger:info("Permission retirée du groupe " .. group .. " : " .. permission)
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
        args      = { "[GROUP]", "Votre groupe : " .. player.group }
    })
end)

return PermissionSystem
