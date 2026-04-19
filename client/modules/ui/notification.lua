-- client/modules/ui/notification.lua
Notifications = {}

function Notifications.send(message, type, duration)
    type = type or "info"
    duration = duration or 3000
    
    -- Send to chat first
    local color = {
        info = {157, 255, 157},
        success = {100, 255, 100},
        error = {255, 100, 100},
        warning = {255, 200, 50},
    }
    
    TriggerEvent("chat:addMessage", {
        color = color[type] or color.info,
        multiline = true,
        args = {"[Union]", message}
    })
    
    if Config.debug then
        Logger:info(message)
    end
end

-- Register network event
RegisterNetEvent("union:notify", function(message, type, duration)
    Notifications.send(message, type, duration)
end)

-- Export notification function
exports("Notify", Notifications.send)