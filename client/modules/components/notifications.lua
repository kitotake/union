-- client/modules/components/notifications.lua
Notifications = {}

local TYPE_MAP = {
    success = "success",
    error   = "error",
    warning = "warning",
    info    = "info",
}

function Notifications.send(message, notifType, duration)
    if not message or message == "" then return end
    lib.notify({
        description = tostring(message),
        type        = TYPE_MAP[notifType] or "info",
        duration    = duration or 3000,
    })
end

-- Reçoit les notifs envoyées depuis le serveur via ServerUtils.notifyPlayer()
RegisterNetEvent("union:notify", function(message, notifType, duration)
    Notifications.send(message, notifType, duration)
end)