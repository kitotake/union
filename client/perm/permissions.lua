-- client/perm/permissions.lua
Permissions = Permissions or {}

local pendingCallbacks = {}

-- Vérifie les permissions côté serveur
function HasPermissionClient(perm, cb)
    local requestId = math.random(100000,999999)
    pendingCallbacks[requestId] = cb
    TriggerServerEvent('permissions:HasPermission', perm, requestId)
end

-- Réponse serveur
RegisterNetEvent('permissions:HasPermission:Response')
AddEventHandler('permissions:HasPermission:Response', function(requestId, result)
    if pendingCallbacks[requestId] then
        pendingCallbacks[requestId](result)
        pendingCallbacks[requestId] = nil
    end
end)

-- Notification simple
function Notify(msg, type)
    type = type or "info"
    TriggerEvent('chat:addMessage', { args = { ("^%s%s"):format(type=="error" and "1" or "2", msg) } })
end

-- Exemple de commande
RegisterCommand("checkkick", function()
    HasPermissionClient("admin.kick", function(hasPerm)
        if hasPerm then
            Notify("✔ Vous avez la permission de kick.", "success")
        else
            Notify("✖ Vous n'avez pas la permission de kick.", "error")
        end
    end)
end)
