-- server/modules/commands/admin.lua
-- FIX: toutes les commandes testent maintenant si src == 0 (console)
--      → bypass de la vérification de permission pour la console
--      → ServerUtils.notifyPlayer(0) remplacé par print() via le fix dans utils.lua

local function isConsole(src)
    return src == 0
end

local function requirePerm(src, perm)
    if isConsole(src) then return true end
    local admin = PlayerManager.get(src)
    return admin and admin:hasPermission(perm)
end

-- /kick <id> <raison>
RegisterCommand("kick", function(source, args)
    local src = source
    if not requirePerm(src, "admin.kick") then
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

    Logger:warn("[ADMIN] kick " .. target.name .. " : " .. reason)
    target:kick(reason)
    ServerUtils.notifyPlayer(src, target.name .. " a été kické.", "success")
end, false)


-- /ban <id> <raison>
RegisterCommand("ban", function(source, args)
    local src = source
    if not requirePerm(src, "admin.ban") then
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

    Logger:warn("[ADMIN] ban " .. target.name .. " : " .. reason)
    target:ban(reason)
    ServerUtils.notifyPlayer(src, target.name .. " a été banni.", "success")
end, false)


-- /heal <id?>
RegisterCommand("heal", function(source, args)
    local src = source
    if not requirePerm(src, "admin.healrevive") then
        ServerUtils.notifyPlayer(src, "Permission refusée.", "error")
        return
    end

    local targetId = tonumber(args[1]) or src
    TriggerClientEvent("admin:heal:client", targetId)
    ServerUtils.notifyPlayer(src, "Joueur soigné.", "success")
end, false)


-- /revive <id?>
RegisterCommand("revive", function(source, args)
    local src = source
    if not requirePerm(src, "admin.healrevive") then
        ServerUtils.notifyPlayer(src, "Permission refusée.", "error")
        return
    end

    local targetId = tonumber(args[1]) or src
    TriggerClientEvent("admin:respawn:client", targetId)
    ServerUtils.notifyPlayer(src, "Joueur revivifié.", "success")
end, false)


-- /setgroup <id> <groupe>
-- FIX: supporte source=0 (console) → notifyPlayer(0) ne crash plus
RegisterCommand("setgroup", function(source, args)
    local src = source
    if not requirePerm(src, "admin.all") then
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
        ServerUtils.notifyPlayer(src, "Joueur introuvable (id: " .. targetId .. ").", "error")
        return
    end

    PermissionSystem.setPlayerGroup(targetId, group)
    ServerUtils.notifyPlayer(src,      "Groupe de " .. target.name .. " → " .. group, "success")
    ServerUtils.notifyPlayer(targetId, "Votre groupe a été changé : " .. group, "info")
end, false)


-- /players
RegisterCommand("players", function(source)
    local src = source
    if not requirePerm(src, "admin.kick") then
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