-- server/modules/permission/main.lua
PermissionSystem = {}
PermissionSystem.logger = Logger:child("PERMISSION")
PermissionSystem.cache = {}

-- Permission groups with their permissions
PermissionSystem.groups = {
    user = {},
    moderator = {
        "admin.healrevive",
        "admin.kick",
        "character.delete",
    },
    admin = {
        "admin.all",
        "admin.healrevive",
        "admin.kick",
        "admin.ban",
        "character.delete",
        "job.set",
    },
    founder = {
        "admin.all",
    }
}

function PermissionSystem.hasPermission(source, permission)
    local player = PlayerManager.get(source)
    if not player then return false end
    
    -- Check if player is a founder
    if player.permission >= 3 then
        return true
    end
    
    -- Get player's group permissions
    local groupPerms = PermissionSystem.groups[player.group] or {}
    
    -- Check if permission exists in group
    for _, perm in ipairs(groupPerms) do
        if perm == permission or perm == "admin.all" then
            return true
        end
    end
    
    return false
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
    
    if not PermissionSystem.groups[group] then
        PermissionSystem.logger:warn("Invalid group: " .. group)
        return false
    end
    
    Database.execute(
        "UPDATE users SET `group` = ? WHERE id = ?",
        {group, player.userId},
        function(result)
            if result then
                player.group = group
                PermissionSystem.logger:info("Group set for " .. player.name .. ": " .. group)
                return true
            end
        end
    )
    
    return false
end

function PermissionSystem.addPermissionToGroup(group, permission)
    if not PermissionSystem.groups[group] then
        PermissionSystem.groups[group] = {}
    end
    
    table.insert(PermissionSystem.groups[group], permission)
    PermissionSystem.logger:info("Permission added to group " .. group .. ": " .. permission)
end

function PermissionSystem.removePermissionFromGroup(group, permission)
    if not PermissionSystem.groups[group] then return end
    
    for i, perm in ipairs(PermissionSystem.groups[group]) do
        if perm == permission then
            table.remove(PermissionSystem.groups[group], i)
            PermissionSystem.logger:info("Permission removed from group " .. group .. ": " .. permission)
            return
        end
    end
end

-- Network event for permission check
RegisterNetEvent("union:permission:check", function(permission, requestId)
    local source = source
    local hasPermission = PermissionSystem.hasPermission(source, permission)
    TriggerClientEvent("union:permission:checkResponse", source, requestId, hasPermission)
end)

-- Commands
RegisterCommand("checkperm", function(source, args)
    if not args[1] then
        TriggerClientEvent("chat:addMessage", source, {
            color = {255, 50, 50},
            multiline = true,
            args = {"[PERMISSION]", "Usage: /checkperm [permission]"}
        })
        return
    end
    
    local perm = args[1]
    local hasIt = PermissionSystem.hasPermission(source, perm)
    
    local msg = hasIt and "✓ You have permission: " .. perm or "✗ You don't have permission: " .. perm
    local color = hasIt and {50, 255, 50} or {255, 50, 50}
    
    TriggerClientEvent("chat:addMessage", source, {
        color = color,
        multiline = true,
        args = {"[PERMISSION]", msg}
    })
end)

RegisterCommand("mygroup", function(source)
    local player = PlayerManager.get(source)
    if not player then return end
    
    TriggerClientEvent("chat:addMessage", source, {
        color = {100, 255, 100},
        multiline = true,
        args = {"[GROUP]", "Your group: " .. player.group}
    })
end)

return PermissionSystem