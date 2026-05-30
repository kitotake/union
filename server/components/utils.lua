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
        return GetPlayerIdentifiers(source)[1]
    end
end

function ServerUtils.generateUniqueId(length)
    length = length or 12
    local chars = "0123456789"
    local maxAttempts = 10
    for attempt = 1, maxAttempts do
        local id = "chr_"
        for _ = 1, length do
            local rand = math.random(#chars)
            id = id .. chars:sub(rand, rand)
        end
        local exists = MySQL.scalar.await(
            "SELECT COUNT(*) FROM characters WHERE unique_id = ?",
            { id }
        )
        if not exists or exists == 0 then
            return id
        end
        Logger:warn(("generateUniqueId: collision sur %s (tentative %d/%d)"):format(id, attempt, maxAttempts))
    end
    local fallback = "chr_" .. tostring(os.time()) .. tostring(math.random(1000, 9999))
    Logger:error("generateUniqueId: fallback utilisé — " .. fallback)
    return fallback
end

exports("generateUniqueId", function(len)
    return ServerUtils.generateUniqueId(len)
end)

function ServerUtils.validateEmail(email)
    if not email then return false end
    return email:match("^[%w._%+-]+@[%w.-]+%.%a+$") ~= nil
end

function ServerUtils.validateDate(date)
    if not date then return false end
    local year, month, day = date:match("(%d+)-(%d+)-(%d+)")
    if not year or not month or not day then return false end
    return true
end

function ServerUtils.notifyPlayer(src, message, type, duration)
    type     = type     or "info"
    duration = duration or 3000
    if not src or src == 0 then
        print(("[NOTIFY→console][%s] %s"):format(type:upper(), tostring(message)))
        return
    end
    TriggerClientEvent("union:notify", src, message, type, duration)
end

function ServerUtils.notifyAll(message, type, duration)
    type     = type     or "info"
    duration = duration or 3000
    TriggerClientEvent("union:notify", -1, message, type, duration)
end

function ServerUtils.sendDiscordWebhook(webhookUrl, embed)
    if not webhookUrl or webhookUrl == "" then return false end
    local content = {
        username = embed.username or "Union Framework",
        embeds   = { embed }
    }
    PerformHttpRequest(webhookUrl, function(err)
        if err ~= 200 and err ~= 204 then
            Logger:error("Discord webhook failed: " .. tostring(err))
        end
    end, "POST", json.encode(content), {
        ["Content-Type"] = "application/json"
    })
    return true
end

return ServerUtils
