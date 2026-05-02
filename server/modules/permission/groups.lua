-- server/modules/permission/groups.lua
-- FIX #8 : ajout de "admin.vehicle" dans les groupes admin/founder
--           pour les nouvelles vérifications granulaires dans commands/admin.lua

PermissionGroups = {}
PermissionGroups.logger = Logger:child("PERMISSION:GROUPS")

PermissionGroups.defaults = {
    founder = {
        displayName = "Founder",
        level = 3,
        permissions = {"admin.all"}
    },
    admin = {
        displayName = "Administrator",
        level = 2,
        permissions = {
            "admin.kick",
            "admin.ban",
            "admin.healrevive",
            "admin.vehicle",   -- FIX #8 : permission véhicules admin
            "character.delete",
            "job.set",
        }
    },
    moderator = {
        displayName = "Moderator",
        level = 1,
        permissions = {
            "admin.healrevive",
            "admin.kick",
            -- FIX #8 : les modérateurs n'ont PAS admin.vehicle ni admin.all
        }
    },
    user = {
        displayName = "User",
        level = 0,
        permissions = {}
    }
}

function PermissionGroups.getGroupInfo(groupName)
    return PermissionGroups.defaults[groupName] or PermissionGroups.defaults.user
end

function PermissionGroups.getAllGroups()
    return PermissionGroups.defaults
end

function PermissionGroups.getGroupLevel(groupName)
    local info = PermissionGroups.getGroupInfo(groupName)
    return info.level
end

function PermissionGroups.getGroupPermissions(groupName)
    local info = PermissionGroups.getGroupInfo(groupName)
    return info.permissions or {}
end

function PermissionGroups.hasGroupPermission(groupName, permission)
    local perms = PermissionGroups.getGroupPermissions(groupName)
    for _, perm in ipairs(perms) do
        if perm == permission or perm == "admin.all" then
            return true
        end
    end
    return false
end

return PermissionGroups