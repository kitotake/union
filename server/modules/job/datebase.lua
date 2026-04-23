-- server/modules/job/database.lua
-- FIX #13 : fichier renommé de "datebase.lua" en "database.lua" (faute de frappe)

JobDB = {}
JobDB.logger = Logger:child("JOB:DATABASE")

function JobDB.getAllJobs(callback)
    Database.fetch("SELECT * FROM jobs", {}, callback)
end

function JobDB.getJob(jobName, callback)
    Database.fetchOne(
        "SELECT * FROM jobs WHERE name = ?",
        {jobName},
        callback
    )
end

function JobDB.getGrade(jobName, grade, callback)
    Database.fetchOne(
        "SELECT * FROM job_grades WHERE job_name = ? AND grade = ?",
        {jobName, grade},
        callback
    )
end

function JobDB.getEmployees(jobName, callback)
    Database.fetch(
        "SELECT * FROM characters WHERE job = ?",
        {jobName},
        callback
    )
end

function JobDB.getSalary(jobName, grade, callback)
    JobDB.getGrade(jobName, grade, function(result)
        if result then
            if callback then callback(result.salary or 0) end
        else
            if callback then callback(0) end
        end
    end)
end

return JobDB