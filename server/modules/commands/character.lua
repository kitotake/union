-- server/modules/commands/character.lua

-- /givechar <id> <model> — donner un personnage à un joueur (debug admin)
RegisterCommand("givechar", function(source, args)
    local src = source
    local admin = PlayerManager.get(src)
    if not admin or not admin:hasPermission("admin.kick") then
        ServerUtils.notifyPlayer(src, "Permission refusée.", "error")
        return
    end

    local targetId = tonumber(args[1])
    local model    = args[2]

    if not targetId or not model then
        ServerUtils.notifyPlayer(src, "Usage: /givechar <id> <model>", "error")
        return
    end

    local target = PlayerManager.get(targetId)
    if not target then
        ServerUtils.notifyPlayer(src, "Joueur introuvable.", "error")
        return
    end

    ServerUtils.notifyPlayer(src, "Modèle appliqué à " .. target.name, "success")
    TriggerClientEvent("union:spawn:apply", targetId, {
        model    = model,
        position = Config.spawn.defaultPosition,
        heading  = Config.spawn.defaultHeading,
        health   = Config.character.defaultHealth,
        armor    = 0,
    })
end, false)


-- /charinfo <id> — affiche les infos du personnage actif d'un joueur
RegisterCommand("charinfo", function(source, args)
    local src   = source
    local admin = PlayerManager.get(src)
    if not admin or not admin:hasPermission("admin.kick") then
        ServerUtils.notifyPlayer(src, "Permission refusée.", "error")
        return
    end

    local targetId = tonumber(args[1])
    if not targetId then
        ServerUtils.notifyPlayer(src, "Usage: /charinfo <id>", "error")
        return
    end

    local target = PlayerManager.get(targetId)
    if not target then
        ServerUtils.notifyPlayer(src, "Joueur introuvable.", "error")
        return
    end

    local char = target.currentCharacter
    if not char then
        ServerUtils.notifyPlayer(src, target.name .. " n'a pas de personnage actif.", "warning")
        return
    end

    local msg = string.format(
        "[CHARINFO] %s | Perso: %s %s | UID: %s | Job: %s (%s) | HP: %s | Armor: %s",
        target.name,
        char.firstname or "?",
        char.lastname  or "?",
        char.unique_id or "?",
        char.job       or "unemployed",
        char.job_grade or 0,
        char.health    or 0,
        char.armor     or 0
    )

    print("^3" .. msg .. "^7")
    ServerUtils.notifyPlayer(src, msg, "info")
end, false)

-- /deletechar <id> <characterId> — supprimer un personnage (admin)
RegisterCommand("deletechar", function(source, args)
    local src   = source
    local admin = PlayerManager.get(src)
    if not admin or not admin:hasPermission("character.delete") then
        ServerUtils.notifyPlayer(src, "Permission refusée.", "error")
        return
    end

    local targetId    = tonumber(args[1])
    local characterId = tonumber(args[2])

    if not targetId or not characterId then
        ServerUtils.notifyPlayer(src, "Usage: /deletechar <id> <characterId>", "error")
        return
    end

    local target = PlayerManager.get(targetId)
    if not target then
        ServerUtils.notifyPlayer(src, "Joueur introuvable.", "error")
        return
    end

    Character.delete(target, characterId, function(success)
        if success then
            ServerUtils.notifyPlayer(src, "Personnage " .. characterId .. " supprimé.", "success")
            ServerUtils.notifyPlayer(targetId, "Un de vos personnages a été supprimé par un admin.", "warning")
        else
            ServerUtils.notifyPlayer(src, "Échec de la suppression.", "error")
        end
    end)
end, false)