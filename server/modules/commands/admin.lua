-- server/modules/commands/admin.lua

-- /kick <id> <raison>
RegisterCommand("kick", function(source, args)
    local src   = source
    local admin = PlayerManager.get(src)
    if not admin or not admin:hasPermission("admin.kick") then
        ServerUtils.notifyPlayer(src, "Permission refusée.", "error")
        return
    end

    local targetId = tonumber(args[1])
    if not targetId then
        ServerUtils.notifyPlayer(src, "Usage: /kick <id> <raison>", "error")
        return
    end

    local reason = table.concat(args, " ", 2) or "Aucune raison"
    local target = PlayerManager.get(targetId)
    if not target then
        ServerUtils.notifyPlayer(src, "Joueur introuvable.", "error")
        return
    end

    Logger:warn("[ADMIN] " .. admin.name .. " a kické " .. target.name .. " : " .. reason)
    target:kick(reason)
    ServerUtils.notifyPlayer(src, target.name .. " a été kické.", "success")
end, false)


-- /ban <id> <raison>
RegisterCommand("ban", function(source, args)
    local src   = source
    local admin = PlayerManager.get(src)
    if not admin or not admin:hasPermission("admin.ban") then
        ServerUtils.notifyPlayer(src, "Permission refusée.", "error")
        return
    end

    local targetId = tonumber(args[1])
    if not targetId then
        ServerUtils.notifyPlayer(src, "Usage: /ban <id> <raison>", "error")
        return
    end

    local reason = table.concat(args, " ", 2) or "Aucune raison"
    local target = PlayerManager.get(targetId)
    if not target then
        ServerUtils.notifyPlayer(src, "Joueur introuvable.", "error")
        return
    end

    Logger:warn("[ADMIN] " .. admin.name .. " a banni " .. target.name .. " : " .. reason)
    target:ban(reason)
    ServerUtils.notifyPlayer(src, target.name .. " a été banni.", "success")
end, false)


-- /heal <id?> — soigne soi-même ou un autre joueur
RegisterCommand("heal", function(source, args)
    local src   = source
    local admin = PlayerManager.get(src)
    if not admin or not admin:hasPermission("admin.healrevive") then
        ServerUtils.notifyPlayer(src, "Permission refusée.", "error")
        return
    end

    local targetId = tonumber(args[1]) or src
    TriggerClientEvent("admin:heal:client", targetId)
    ServerUtils.notifyPlayer(src, "Joueur soigné.", "success")
end, false)


-- /revive <id?> — revive soi-même ou un autre joueur
RegisterCommand("revive", function(source, args)
    local src   = source
    local admin = PlayerManager.get(src)
    if not admin or not admin:hasPermission("admin.healrevive") then
        ServerUtils.notifyPlayer(src, "Permission refusée.", "error")
        return
    end

    local targetId = tonumber(args[1]) or src
    TriggerClientEvent("admin:respawn:client", targetId)
    ServerUtils.notifyPlayer(src, "Joueur revivifié.", "success")
end, false)


-- /setgroup <id> <groupe>
RegisterCommand("setgroup", function(source, args)
    local src   = source
    local admin = PlayerManager.get(src)
    if not admin or not admin:hasPermission("admin.all") then
        ServerUtils.notifyPlayer(src, "Permission refusée.", "error")
        return
    end

    local targetId = tonumber(args[1])
    local group    = args[2]

    if not targetId or not group then
        ServerUtils.notifyPlayer(src, "Usage: /setgroup <id> <user|moderator|admin|founder>", "error")
        return
    end

    local target = PlayerManager.get(targetId)
    if not target then
        ServerUtils.notifyPlayer(src, "Joueur introuvable.", "error")
        return
    end

    PermissionSystem.setPlayerGroup(targetId, group)
    ServerUtils.notifyPlayer(src,      "Groupe de " .. target.name .. " → " .. group, "success")
    ServerUtils.notifyPlayer(targetId, "Votre groupe a été changé : " .. group, "info")
end, false)


-- /players — liste tous les joueurs en ligne
RegisterCommand("players", function(source)
    local src   = source
    local admin = PlayerManager.get(src)
    if not admin or not admin:hasPermission("admin.kick") then
        ServerUtils.notifyPlayer(src, "Permission refusée.", "error")
        return
    end

    local count = 0
    for _, p in pairs(PlayerManager.getAll()) do
        count = count + 1
        local charInfo = "aucun personnage"
        if p.currentCharacter then
            charInfo = p.currentCharacter.firstname .. " " .. p.currentCharacter.lastname
                    .. " [" .. p.currentCharacter.unique_id .. "]"
        end
        print(string.format("^3[%d]^7 %s — %s — groupe: %s", p.source, p.name, charInfo, p.group))
    end

    ServerUtils.notifyPlayer(src, count .. " joueur(s) en ligne. (voir console)", "info")
end, false)