-- client/notification.lua
local Notify = {}

function Notify.send(message, type, duration)
    type = type or "info"
    duration = duration or 3000
    
    -- Send notification to UI
    SendNUIMessage({
        action = "notification",
        message = message,
        type = type,
        duration = duration
    })
    
    -- Also output to console if debugging is enabled
    if Config.debugMode then
        print(("^3[NOTIFY:%s]^0 %s"):format(type:upper(), message))
    end
end

-- Register event handler
RegisterNetEvent("union:notify")
AddEventHandler("union:notify", function(message, type, duration)
    Notify.send(message, type, duration)
end)

-- Export function
exports("notify", Notify.send)