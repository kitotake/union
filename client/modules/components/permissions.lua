-- client/components/permissions.lua
Permissions = {}
Permissions.pendingCallbacks = {}

function Permissions.check(permission, callback)
    local requestId = math.random(100000, 999999)
    Permissions.pendingCallbacks[requestId] = callback
    TriggerServerEvent("union:permission:check", permission, requestId)
end

function Permissions.hasSync(permission)
    -- Synchronous check (not ideal, but available)
    -- Returns cached result if available
    if Permissions.cachedPermissions then
        return Permissions.cachedPermissions[permission] or false
    end
    return false
end

-- Response from server
RegisterNetEvent("union:permission:checkResponse", function(requestId, hasPermission)
    if Permissions.pendingCallbacks[requestId] then
        Permissions.pendingCallbacks[requestId](hasPermission)
        Permissions.pendingCallbacks[requestId] = nil
    end
end)

-- Helper function to show permission denied
function Permissions.deny()
    TriggerEvent("union:notify", _t("permission.denied"), "error", 3000)
    Logger:warn("Permission denied for player")
end

-- Helper function to show permission granted
function Permissions.allow()
    TriggerEvent("union:notify", _t("permission.granted"), "success", 2000)
    Logger:info("Permission granted")
end