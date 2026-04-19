-- server/components/utils.lua
ServerUtils = {}

function ServerUtils.getPlayerIP(source)
    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local id = GetPlayerIdentifier(source, i)
        if string.find(id, "ip:") then
            return string.gsub(id, "ip:", "")
        end
    end
    return nil
end

function ServerUtils.getIdentifier(source, idType)
    if idType == "license" then
        return GetPlayerIdentifierByType(source, "license")
    elseif idType == "discord" then
        return GetPlayerIdentifierByType(source, "discord")
    elseif idType == "fivem" then
        return GetPlayerIdentifierByType(source, "fivem")
    else
        -- Return all identifiers
        return GetPlayerIdentifiers(source)[1]
    end
end

function ServerUtils.getPlayerName(source)
    return GetPlayerName(source) or "Unknown"
end

function ServerUtils.generateUniqueId(length)
    local CHARSET = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local id = ''
    for i = 1, length or 12 do
        local rand = math.random(#CHARSET)
        id = id .. CHARSET:sub(rand, rand)
    end
    return id
end

function ServerUtils.validateEmail(email)
    if not email then return false end
    return email:match("^[^@]+@[^@]+%.%w+$") ~= nil
end

function ServerUtils.validateDate(date)
    if not date then return false end
    local year, month, day = date:match("(%d+)-(%d+)-(%d+)")
    if not year or not month or not day then return false end
    return true
end

function ServerUtils.notifyPlayer(source, message, type, duration)
    type = type or "info"
    duration = duration or 3000
    TriggerClientEvent("union:notify", source, message, type, duration)
end

function ServerUtils.notifyAll(message, type, duration)
    type = type or "info"
    duration = duration or 3000
    TriggerClientEvent("union:notify", -1, message, type, duration)
end

function ServerUtils.sendDiscordWebhook(webhookUrl, embed)
    if not webhookUrl or webhookUrl == "" then
        return false
    end
    
    local content = {
        username = embed.username or "Union Framework",
        embeds = {embed}
    }
    
    PerformHttpRequest(webhookUrl, function(err, text, headers)
        if err ~= 200 then
            Logger:error("Failed to send Discord webhook: " .. tostring(err))
        end
    end, 'POST', json.encode(content), {['Content-Type'] = 'application/json'})
    
    return true
end

return ServerUtils