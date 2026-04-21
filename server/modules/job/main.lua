-- server/modules/job/main.lua
Job = {}
Job.logger = Logger:child("JOB")
Job.cache = {}

function Job.setPlayerJob(player, jobName, grade, callback)
    if not player or not jobName then
        if callback then callback(false) end
        return
    end
    
    Database.execute(
        "UPDATE characters SET job = ?, job_grade = ? WHERE unique_id = ?",
        {jobName, grade or 0, player.currentCharacter.unique_id},
        function(result)
            if result then
                player.currentCharacter.job = jobName
                player.currentCharacter.job_grade = grade or 0
                Job.logger:info("Job set for " .. player.name .. ": " .. jobName .. " (" .. (grade or 0) .. ")")
                if callback then callback(true) end
            else
                Job.logger:error("Failed to set job for " .. player.name)
                if callback then callback(false) end
            end
        end
    )
end

function Job.getPlayerJob(player)
    if not player or not player.currentCharacter then
        return nil, 0
    end
    
    return player.currentCharacter.job or "unemployed", player.currentCharacter.job_grade or 0
end

function Job.getJobs(callback)
    Database.fetch("SELECT * FROM jobs", {}, function(result)
        if callback then callback(result or {}) end
    end)
end

function Job.getJobGrades(jobName, callback)
    Database.fetch(
        "SELECT * FROM job_grades WHERE job_name = ? ORDER BY grade ASC",
        {jobName},
        function(result)
            if callback then callback(result or {}) end
        end
    )
end

-- ✅ Event déclenché quand un admin change le job d'un joueur en ligne
RegisterNetEvent("union:job:set", function(jobName, grade)
    local source = source
    local player = PlayerManager.get(source)

    if player and player:hasPermission("job.set") then
        Job.setPlayerJob(player, jobName, grade, function(success)
            if success then
                -- Notifier le client que son job a changé
                TriggerClientEvent("union:job:updated", source, jobName, grade)
            end
        end)
    else
        if player then
            player:notify("Permission refusée.", "error")
        end
    end
end)

-- Demande de liste des jobs
RegisterNetEvent("union:job:list:request", function()
    local source = source
    Job.getJobs(function(jobs)
        TriggerClientEvent("union:job:list:received", source, jobs)
    end)
end)


-- Demande de liste des employés d'un job
RegisterNetEvent("union:job:employees:request", function(jobName)
    local source = source
    local player = PlayerManager.get(source)

    if not player or not player:hasPermission("admin.kick") then
        ServerUtils.notifyPlayer(source, "Permission refusée.", "error")
        return
    end

    if not jobName then return end

    Database.fetch(
        "SELECT firstname, lastname, job_grade, unique_id FROM characters WHERE job = ?",
        { jobName },
        function(employees)
            TriggerClientEvent("union:job:employees:received", source, jobName, employees or {})
        end
    )
end)

return Job