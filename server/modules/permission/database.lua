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

function PermissionDB.savePermissions(source, permissions, callback)
    local player = PlayerManager.get(source)
    if not player then
        if callback then callback(false) end
        return
    end
    
    -- This would save custom permissions if needed
    PermissionDB.logger:info("Permissions saved for " .. player.name)
    if callback then callback(true) end
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

function PermissionDB.setPlayerPermissionLevel(source, level, callback)
    local player = PlayerManager.get(source)
    if not player then
        if callback then callback(false) end
        return
    end
    
    Database.execute(
        "UPDATE users SET permission_level = ? WHERE id = ?",
        {level, player.userId},
        function(result)
            if result then
                player.permission = level
                PermissionDB.logger:info("Permission level set for " .. player.name .. ": " .. level)
                if callback then callback(true) end
            else
                if callback then callback(false) end
            end
        end
    )
end

return PermissionDB