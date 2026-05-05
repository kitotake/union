-- server/modules/job/main.lua
-- FIXES:
--   #1 : "local source = source" remplacé par "local src = source"
--        dans tous les RegisterNetEvent (shadowing de la globale FiveM).
--   #2 : Notification client après setPlayerJob (TriggerClientEvent corrigé).

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
        { jobName, grade or 0, player.currentCharacter.unique_id },
        function(result)
            if result then
                player.currentCharacter.job       = jobName
                player.currentCharacter.job_grade = grade or 0
                Job.logger:info(("Job set pour %s: %s (%d)"):format(player.name, jobName, grade or 0))
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
        { jobName },
        function(result)
            if callback then callback(result or {}) end
        end
    )
end

-- FIX #1 : src au lieu de local source = source
RegisterNetEvent("union:job:set", function(jobName, grade)
    local src    = source
    local player = PlayerManager.get(src)

    if player and player:hasPermission("job.set") then
        Job.setPlayerJob(player, jobName, grade, function(success)
            if success then
                -- FIX #2 : notifier le client avec les bons paramètres
                TriggerClientEvent("union:job:updated", src, jobName, grade)
            end
        end)
    else
        if player then
            player:notify("Permission refusée.", "error")
        end
    end
end)

-- FIX #1 : src au lieu de source
RegisterNetEvent("union:job:list:request", function()
    local src = source
    Job.getJobs(function(jobs)
        TriggerClientEvent("union:job:list:received", src, jobs)
    end)
end)

-- FIX #1 : src au lieu de source
RegisterNetEvent("union:job:employees:request", function(jobName)
    local src    = source
    local player = PlayerManager.get(src)

    if not player or not player:hasPermission("admin.kick") then
        ServerUtils.notifyPlayer(src, "Permission refusée.", "error")
        return
    end

    if not jobName then return end

    Database.fetch(
        "SELECT firstname, lastname, job_grade, unique_id FROM characters WHERE job = ?",
        { jobName },
        function(employees)
            TriggerClientEvent("union:job:employees:received", src, jobName, employees or {})
        end
    )
end)

return Job
