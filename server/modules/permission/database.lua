-- server/modules/permission/database.lua
PermissionDB = {}
PermissionDB.logger = Logger:child("PERMISSION:DATABASE")

function PermissionDB.getPlayerPermissions(source, callback)
    local player = PlayerManager.get(source)
    if not player then
        if callback then callback({}) end
        return
    end

    local groupPerms = PermissionGroups.getGroupPermissions(player.group) or {}
    if callback then callback(groupPerms) end
end

function PermissionDB.getAllPlayerPermissions(callback)
    Database.fetch(
        "SELECT identifier, `group` FROM users",
        {},
        function(results)
            if callback then callback(results or {}) end
        end
    )
end

return PermissionDB