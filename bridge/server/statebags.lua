-- bridge/server/statebags.lua
-- FIXES:
--   #1 : Player(src).state — accès protégé par pcall (crash si src invalide).
--   #2 : clearCharacter — vérification que src est un joueur encore connecté.

StateBags = {}
StateBags.logger = Logger:child("STATEBAGS")

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- DONNÉES PARTAGÉES AU SPAWN
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function StateBags.setCharacter(src, charData)
    if not src or not charData then return end

    -- FIX #1 : guard pcall sur Player(src).state
    local ok, err = pcall(function()
        local state = Player(src).state

        state:set("character", {
            unique_id   = charData.unique_id,
            firstname   = charData.firstname,
            lastname    = charData.lastname,
            gender      = charData.gender,
            job         = charData.job or "unemployed",
            job_grade   = charData.job_grade or 0,
        }, true)

        state:set("job", {
            name  = charData.job or "unemployed",
            grade = charData.job_grade or 0,
        }, true)

        state:set("unique_id", charData.unique_id, false)
    end)

    if not ok then
        StateBags.logger:warn("setCharacter erreur src=" .. tostring(src) .. " : " .. tostring(err))
    else
        StateBags.logger:debug(("StateBag mis à jour pour src=%s uid=%s"):format(
            tostring(src),
            tostring(charData.unique_id)
        ))
    end
end

function StateBags.clearCharacter(src)
    if not src then return end

    -- FIX #2 : vérification que le joueur est encore connecté
    local ok, err = pcall(function()
        local state = Player(src).state
        state:set("character", nil, true)
        state:set("job",       nil, true)
        state:set("unique_id", nil, false)
    end)

    if not ok then
        StateBags.logger:warn("clearCharacter erreur src=" .. tostring(src) .. " : " .. tostring(err))
    end
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- LECTURE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- LIAISON AUX EVENTS UNION
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- EXPORTS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
exports("GetCharacterState", StateBags.getCharacter)
exports("GetJobState",       StateBags.getJob)
exports("GetUniqueIdState",  StateBags.getUniqueId)

return StateBags
