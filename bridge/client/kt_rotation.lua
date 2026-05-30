-- bridge/client/kt_rotation.lua
Bridge.Rotation = Bridge.create("kt_rotation")
Bridge.register("kt_rotation", Bridge.Rotation)

Bridge.Rotation._sessions = {}

function Bridge.Rotation.start(entity, options)
    if not entity or not DoesEntityExist(entity) then
        print("^1[BRIDGE:kt_rotation] start : entité invalide ou inexistante^7")
        return false
    end
    if not Bridge.Rotation:isAvailable() then
        print("^3[BRIDGE:kt_rotation] start ignoré — ressource non disponible^7")
        return false
    end
    options = options or {}
    local ok, sessionId = pcall(function()
        return exports["kt_rotation"]:StartRotation(entity, options)
    end)
    if not ok then
        print(("^1[BRIDGE:kt_rotation] start erreur : %s^7"):format(tostring(sessionId)))
        return false
    end
    if sessionId then
        Bridge.Rotation._sessions[entity] = sessionId
    end
    return sessionId or true
end

function Bridge.Rotation.stop(entity)
    if not entity then return false end
    if not Bridge.Rotation:isAvailable() then return false end
    local sessionId = Bridge.Rotation._sessions[entity]
    local ok, err = pcall(function()
        if sessionId then
            exports["kt_rotation"]:StopRotation(sessionId)
        else
            exports["kt_rotation"]:StopRotation(entity)
        end
    end)
    if not ok then
        print(("^1[BRIDGE:kt_rotation] stop erreur : %s^7"):format(tostring(err)))
        return false
    end
    Bridge.Rotation._sessions[entity] = nil
    return true
end

function Bridge.Rotation.stopAll()
    if not Bridge.Rotation:isAvailable() then return end
    for entity, _ in pairs(Bridge.Rotation._sessions) do
        Bridge.Rotation.stop(entity)
    end
    Bridge.Rotation._sessions = {}
end

function Bridge.Rotation.pause(entity)
    if not Bridge.Rotation:isAvailable() then return false end
    local sessionId = Bridge.Rotation._sessions[entity]
    if not sessionId then return false end
    local ok, err = pcall(function()
        exports["kt_rotation"]:PauseRotation(sessionId)
    end)
    if not ok then
        print(("^1[BRIDGE:kt_rotation] pause erreur : %s^7"):format(tostring(err)))
        return false
    end
    return true
end

function Bridge.Rotation.resume(entity)
    if not Bridge.Rotation:isAvailable() then return false end
    local sessionId = Bridge.Rotation._sessions[entity]
    if not sessionId then return false end
    local ok, err = pcall(function()
        exports["kt_rotation"]:ResumeRotation(sessionId)
    end)
    if not ok then
        print(("^1[BRIDGE:kt_rotation] resume erreur : %s^7"):format(tostring(err)))
        return false
    end
    return true
end

AddEventHandler("union:character:unloaded", function()
    Bridge.Rotation.stopAll()
end)

AddEventHandler("onResourceStop", function(r)
    if r == "kt_rotation" then
        Bridge.Rotation._sessions = {}
    end
end)
