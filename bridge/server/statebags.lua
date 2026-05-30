-- bridge/server/statebags.lua
StateBags = {}
StateBags.logger = Logger:child("STATEBAGS")

local function normalizePed(pedModel)
    local model = pedModel
    if model ~= "mp_m_freemode_01" and model ~= "mp_f_freemode_01" then
        model = "mp_m_freemode_01"
    end
    local gender = (model == "mp_f_freemode_01") and "f" or "m"
    return model, gender
end

function StateBags.setCharacter(src, charData)
    if not src or not charData then return end
    local model, gender = normalizePed(charData.ped_model)
    local ok, err = pcall(function()
        local player = Player(src)
        if not player then return end
        local state = player.state
        local character = {
            unique_id = charData.unique_id,
            firstname = charData.firstname or "",
            lastname  = charData.lastname or "",
            gender    = gender,
            ped_model = model,
            job       = charData.job or "unemployed",
            job_grade = charData.job_grade or 0,
        }
        state:set("character", character, true)
        state:set("job", {
            name  = character.job,
            grade = character.job_grade,
        }, true)
        state:set("unique_id", character.unique_id, false)
    end)
    if not ok then
        StateBags.logger:warn("setCharacter erreur src=" .. tostring(src) .. " : " .. tostring(err))
    else
        StateBags.logger:debug(("StateBag OK src=%s uid=%s"):format(
            tostring(src), tostring(charData.unique_id)
        ))
    end
end

function StateBags.clearCharacter(src)
    if not src then return end
    local ok, err = pcall(function()
        local player = Player(src)
        if not player then return end
        local state = player.state
        state:set("character", nil, true)
        state:set("job", nil, true)
        state:set("unique_id", nil, false)
    end)
    if not ok then
        StateBags.logger:warn("clearCharacter erreur src=" .. tostring(src) .. " : " .. tostring(err))
    end
end

function StateBags.getCharacter(src)
    if not src then return nil end
    local ok, result = pcall(function()
        return Player(src).state.character
    end)
    return ok and result or nil
end

function StateBags.getJob(src)
    if not src then return "unemployed", 0 end
    local ok, result = pcall(function()
        return Player(src).state.job
    end)
    if ok and result then
        return result.name or "unemployed", result.grade or 0
    end
    return "unemployed", 0
end

function StateBags.getUniqueId(src)
    if not src then return nil end
    local ok, result = pcall(function()
        return Player(src).state.unique_id
    end)
    return ok and result or nil
end

AddEventHandler("union:player:spawned", function(src, character)
    if not src or not character then return end
    StateBags.setCharacter(src, character)
end)

AddEventHandler("union:job:updated", function(src, job, grade)
    if not src then return end
    local ok, err = pcall(function()
        local state = Player(src).state
        state:set("job", { name = job, grade = grade }, true)
        local char = state.character
        if char then
            char.job       = job
            char.job_grade = grade
            state:set("character", char, true)
        end
    end)
    if not ok then
        StateBags.logger:warn("job:updated erreur src=" .. tostring(src) .. " : " .. tostring(err))
    end
end)

AddEventHandler("playerDropped", function()
    StateBags.clearCharacter(source)
end)

exports("GetCharacterState", StateBags.getCharacter)
exports("GetJobState",       StateBags.getJob)
exports("GetUniqueIdState",  StateBags.getUniqueId)

return StateBags
