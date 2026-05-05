-- server/modules/permission/groups.lua
-- FIX : suppression de la double définition entre groups.lua et main.lua.
--       Ce fichier est la SOURCE UNIQUE des groupes et permissions.
--       main.lua lit PermissionGroups.defaults au lieu de redéfinir PermissionSystem.groups.

PermissionGroups = {}
PermissionGroups.logger = Logger:child("PERMISSION:GROUPS")

PermissionGroups.defaults = {
    founder = {
        displayName = "Founder",
        level = 3,
        permissions = { "admin.all" }
    },
    admin = {
        displayName = "Administrator",
        level = 2,
        permissions = {
            "admin.all",
            "admin.kick",
            "admin.ban",
            "admin.healrevive",
            "admin.vehicle",
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
            -- Les modérateurs n'ont PAS admin.vehicle ni admin.all
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
    return PermissionGroups.getGroupInfo(groupName).level
end

function PermissionGroups.getGroupPermissions(groupName)
    return PermissionGroups.getGroupInfo(groupName).permissions or {}
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
