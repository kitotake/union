-- client/modules/ui/notification.lua
Notifications = {}

local queue   = {}
local showing = false

local COLORS = {
    info    = { r = 52,  g = 152, b = 219 },
    success = { r = 46,  g = 204, b = 113 },
    error   = { r = 231, g = 76,  b = 60  },
    warning = { r = 241, g = 196, b = 15  },
}

local ICONS = {
    info    = "ℹ",
    success = "✓",
    error   = "✕",
    warning = "⚠",
}

local function showNext()
    if #queue == 0 then
        showing = false
        return
    end

    showing = true
    local notif = table.remove(queue, 1)

    SendNUIMessage({
        action   = "notify",
        message  = notif.message,
        type     = notif.type,
        duration = notif.duration,
        color    = COLORS[notif.type] or COLORS.info,
        icon     = ICONS[notif.type]  or ICONS.info,
    })

    SetTimeout(notif.duration + 400, function()
        showNext()
    end)
end

function Notifications.send(message, type, duration)
    type     = type     or "info"
    duration = duration or 4000

    table.insert(queue, {
        message  = message,
        type     = type,
        duration = duration,
    })

    if not showing then
        showNext()
    end
end

RegisterNetEvent("union:notify", function(message, type, duration)
    Notifications.send(message, type, duration)
end)

exports("Notify", Notifications.send)