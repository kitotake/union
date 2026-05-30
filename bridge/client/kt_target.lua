-- bridge/client/kt_target.lua
Bridge.Target = Bridge.create("kt_target")
Bridge.register("kt_target", Bridge.Target)

local function syncCharacterState(charData)
    if not charData then
        LocalPlayer.state:set("character", nil, false)
        LocalPlayer.state:set("job", nil, false)
        return
    end
    local model = charData.ped_model or "mp_m_freemode_01"
    if model ~= "mp_m_freemode_01" and model ~= "mp_f_freemode_01" then
        model = "mp_m_freemode_01"
    end
    local gender = (model == "mp_f_freemode_01") and "f" or "m"
    LocalPlayer.state:set("character", {
        unique_id = charData.unique_id,
        firstname = charData.firstname or "",
        lastname  = charData.lastname  or "",
        gender    = gender,
        ped_model = model,
        job       = charData.job       or "unemployed",
        job_grade = charData.job_grade or 0,
    }, false)
    LocalPlayer.state:set("job", {
        name  = charData.job       or "unemployed",
        grade = charData.job_grade or 0,
    }, false)
end

function Bridge.Target.addZone(name, coords, options)
    if not Bridge.Target:isAvailable() then
        print(("^3[BRIDGE:kt_target] addZone '%s' ignoré — ressource non disponible^7"):format(tostring(name)))
        return false
    end
    local ok, err = pcall(function()
        exports["kt_target"]:AddTargetZone(name, coords, options)
    end)
    if not ok then
        print(("^1[BRIDGE:kt_target] addZone erreur : %s^7"):format(tostring(err)))
        return false
    end
    return true
end

function Bridge.Target.removeZone(name)
    if not Bridge.Target:isAvailable() then return false end
    local ok, err = pcall(function()
        exports["kt_target"]:RemoveTargetZone(name)
    end)
    if not ok then
        print(("^1[BRIDGE:kt_target] removeZone erreur : %s^7"):format(tostring(err)))
        return false
    end
    return true
end

function Bridge.Target.addEntity(entities, options)
    if not Bridge.Target:isAvailable() then return false end
    local ok, err = pcall(function()
        exports["kt_target"]:AddTargetEntity(entities, options)
    end)
    if not ok then
        print(("^1[BRIDGE:kt_target] addEntity erreur : %s^7"):format(tostring(err)))
        return false
    end
    return true
end

function Bridge.Target.removeEntity(entities, labels)
    if not Bridge.Target:isAvailable() then return false end
    local ok, err = pcall(function()
        exports["kt_target"]:RemoveTargetEntity(entities, labels)
    end)
    if not ok then
        print(("^1[BRIDGE:kt_target] removeEntity erreur : %s^7"):format(tostring(err)))
        return false
    end
    return true
end

function Bridge.Target.addModel(models, options)
    if not Bridge.Target:isAvailable() then return false end
    local ok, err = pcall(function()
        exports["kt_target"]:AddTargetModel(models, options)
    end)
    if not ok then
        print(("^1[BRIDGE:kt_target] addModel erreur : %s^7"):format(tostring(err)))
        return false
    end
    return true
end

RegisterNetEvent("union:player:spawned", function(character)
    syncCharacterState(character or Client.currentCharacter)
end)

RegisterNetEvent("union:job:updated", function(job, grade)
    if Client.currentCharacter then
        Client.currentCharacter.job       = job
        Client.currentCharacter.job_grade = grade
        syncCharacterState(Client.currentCharacter)
    end
end)

AddEventHandler("union:character:unloaded", function()
    syncCharacterState(nil)
end)

exports("GetActiveCharacter", function()
    return Client.currentCharacter
end)

exports("GetActiveJob", function()
    if not Client.currentCharacter then return "unemployed", 0 end
    return Client.currentCharacter.job       or "unemployed",
           Client.currentCharacter.job_grade or 0
end)
