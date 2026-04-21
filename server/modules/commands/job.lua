-- /setjob <id> <job> <grade> — changer le job d'un joueur
RegisterCommand("setjob", function(source, args)
    local src   = source
    local admin = PlayerManager.get(src)
    if not admin or not admin:hasPermission("job.set") then
        ServerUtils.notifyPlayer(src, "Permission refusée.", "error")
        return
    end

    local targetId = tonumber(args[1])
    local jobName  = args[2]
    local grade    = tonumber(args[3]) or 0

    if not targetId or not jobName then
        ServerUtils.notifyPlayer(src, "Usage: /setjob <id> <job> <grade>", "error")
        return
    end

    local target = PlayerManager.get(targetId)
    if not target or not target.currentCharacter then
        ServerUtils.notifyPlayer(src, "Joueur ou personnage introuvable.", "error")
        return
    end

    Job.setPlayerJob(target, jobName, grade, function(success)
        if success then
            ServerUtils.notifyPlayer(src,    "Job mis à jour : " .. jobName .. " (" .. grade .. ")", "success")
            ServerUtils.notifyPlayer(targetId, "Votre job a été changé : " .. jobName, "info")
        else
            ServerUtils.notifyPlayer(src, "Échec de la mise à jour du job.", "error")
        end
    end)
end, false)