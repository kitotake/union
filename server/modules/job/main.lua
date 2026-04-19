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

RegisterNetEvent("union:job:set", function(jobName, grade)
    local source = source
    local player = PlayerManager.get(source)
    
    if player and player:hasPermission("job.set") then
        Job.setPlayerJob(player, jobName, grade)
    else
        player:notify("Permission denied", "error")
    end
end)

return Job