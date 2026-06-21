-- server/modules/commands/manager/permission.lua
RegisterCommand("setgroup", function(source, args)
    local src       = source
    local isConsole = src == 0

    if not isConsole then
        local admin = PlayerManager.get(src)
        if not admin or not admin:hasPermission("admin.all") then
            ServerUtils.notifyPlayer(src, "Permission refusée.", "error")
            return
        end
    end

    local targetId  = tonumber(args[1])
    local groupName = args[2]

    if not targetId or not groupName then
        if isConsole then print("Usage: setgroup <id> <group>")
        else ServerUtils.notifyPlayer(src, "Usage: /setgroup <id> <group>", "error") end
        return
    end

    if not PermissionGroups.defaults[groupName] then
        local valid = {}
        for k in pairs(PermissionGroups.defaults) do table.insert(valid, k) end
        table.sort(valid)
        local msg = "Groupe invalide. Disponibles : " .. table.concat(valid, ", ")
        if isConsole then print(msg)
        else ServerUtils.notifyPlayer(src, msg, "error") end
        return
    end

    local target = PlayerManager.get(targetId)
    if not target then
        if isConsole then print("Joueur introuvable.")
        else ServerUtils.notifyPlayer(src, "Joueur introuvable.", "error") end
        return
    end

    -- FIX: callback async — le résultat reflète maintenant la vraie réponse DB
    -- L'ancienne version retournait true avant même que la DB réponde
    PermissionSystem.setPlayerGroup(targetId, groupName, function(success)
        if success then
            local msg = string.format("Groupe de %s défini sur '%s'.", target.name, groupName)
            if isConsole then print("[PERMISSION] " .. msg)
            else ServerUtils.notifyPlayer(src, msg, "success") end
            ServerUtils.notifyPlayer(targetId,
                string.format("Votre groupe a été changé : %s.", groupName), "info")
        else
            if isConsole then print("[PERMISSION] Échec — erreur DB ou groupe invalide.")
            else ServerUtils.notifyPlayer(src, "Échec de la mise à jour.", "error") end
        end
    end)
end, false)
