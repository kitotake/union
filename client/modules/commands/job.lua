-- client/modules/commands/job.lua

-- /myjob — affiche le job actuel du personnage
RegisterCommand("myjob", function()
    if not Character.current then
        Notifications.send("Aucun personnage actif.", "warning")
        return
    end

    local char = Character.current
    local job   = char.job       or "unemployed"
    local grade = char.job_grade or 0

    Notifications.send(
        string.format("Job: %s | Grade: %s", job, grade),
        "info"
    )
end, false)


-- /joblist — liste tous les jobs disponibles
RegisterCommand("joblist", function()
    TriggerServerEvent("union:job:list:request")
end, false)


-- /employees <job> — liste les employés d'un job (admin)
RegisterCommand("employees", function(source, args)
    local job = args[1]
    if not job then
        Notifications.send("Usage: /employees <job>", "error")
        return
    end

    TriggerServerEvent("union:job:employees:request", job)
end, false)


-- Réception de la liste des jobs
RegisterNetEvent("union:job:list:received", function(jobs)
    if not jobs or #jobs == 0 then
        Notifications.send("Aucun job disponible.", "warning")
        return
    end

    print("^2[JOBS] Liste des jobs disponibles :")
    for _, j in ipairs(jobs) do
        local wl = j.whitelisted == 1 and "^1[WL]^7" or "^2[OPEN]^7"
        print(string.format("  %s ^3%s^7 — %s", wl, j.name, j.label))
    end

    Notifications.send(#jobs .. " job(s) disponible(s). (voir console)", "info")
end)


-- Réception de la liste des employés
RegisterNetEvent("union:job:employees:received", function(job, employees)
    if not employees or #employees == 0 then
        Notifications.send("Aucun employé pour le job : " .. job, "warning")
        return
    end

    print(string.format("^2[EMPLOYEES] %s (%d employé(s)) :", job, #employees))
    for _, e in ipairs(employees) do
        print(string.format(
            "  ^3%s %s^7 | Grade: %s | UID: %s",
            e.firstname or "?",
            e.lastname  or "?",
            e.job_grade or 0,
            e.unique_id or "?"
        ))
    end

    Notifications.send(#employees .. " employé(s) pour " .. job .. ". (voir console)", "info")
end)


-- Réception après changement de job (si un admin change ton job)
RegisterNetEvent("union:job:updated", function(job, grade)
    if Character.current then
        Character.current.job       = job
        Character.current.job_grade = grade
    end

    Notifications.send(
        string.format("Votre job a été mis à jour : %s (grade %s)", job, grade),
        "success"
    )
end)