-- server/modules/commands/permission.lua
RegisterCommand("setgroup", function(source, args)
    local src = source
    if src ~= 0 then
        local admin = PlayerManager.get(src)
        if not admin or not admin:hasPermission("admin.all") then
            ServerUtils.notifyPlayer(src, "Permission refusée.", "error"); return
        end
    end
    local targetId  = tonumber(args[1])
    local groupName = args[2]
    if not targetId or not groupName then
        if src == 0 then print("Usage: setgroup <id> <group>")
        else ServerUtils.notifyPlayer(src, "Usage: /setgroup <id> <group>", "error") end
        return
    end
    if not PermissionGroups.defaults[groupName] then
        local valid = {}
        for k in pairs(PermissionGroups.defaults) do table.insert(valid, k) end
        local msg = "Groupe invalide. Disponibles : " .. table.concat(valid, ", ")
        if src == 0 then print(msg) else ServerUtils.notifyPlayer(src, msg, "error") end
        return
    end
    local target = PlayerManager.get(targetId)
    if not target then
        if src == 0 then print("Joueur introuvable.") else ServerUtils.notifyPlayer(src, "Joueur introuvable.", "error") end
        return
    end
    local success = PermissionSystem.setPlayerGroup(targetId, groupName)
    if success then
        local msg = string.format("Groupe de %s défini sur '%s'.", target.name, groupName)
        if src == 0 then print("[PERMISSION] " .. msg) else ServerUtils.notifyPlayer(src, msg, "success") end
        ServerUtils.notifyPlayer(targetId, string.format("Votre groupe a été changé : %s.", groupName), "info")
    else
        if src == 0 then print("Échec.") else ServerUtils.notifyPlayer(src, "Échec.", "error") end
    end
end, false)
