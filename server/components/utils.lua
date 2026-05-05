-- server/components/utils.lua
-- FIXES:
--   #1 : generateUniqueId() vérifie l'unicité en base avant de retourner l'ID.
--        Évite (certes rare mais catastrophique) la collision de unique_id.
--   #2 : Version async avec callback pour usage dans Character.create().
--   #3 : Version sync conservée pour compatibilité (sans vérification DB — usage interne uniquement).

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

-- FIX #3 : version sync sans vérification DB (usage interne / non-critique)
function ServerUtils.generateUniqueId(length)
    length = length or 12
    local chars = "0123456789"
    local id = ""
    for i = 1, length do
        local rand = math.random(#chars)
        id = id .. chars:sub(rand, rand)
    end
    return "chr_" .. id
end

-- FIX #1 + #2 : version async avec vérification d'unicité en base
-- Callback reçoit l'ID unique garanti, ou nil si trop de tentatives échouent.
function ServerUtils.generateUniqueIdSafe(callback, length, _attempt)
    length   = length or 12
    _attempt = _attempt or 1

    if _attempt > 10 then
        print("^1[ServerUtils] generateUniqueIdSafe: impossible de générer un ID unique après 10 tentatives^0")
        if callback then callback(nil) end
        return
    end

    local id = ServerUtils.generateUniqueId(length)

    exports.oxmysql:scalar(
        "SELECT unique_id FROM characters WHERE unique_id = ? LIMIT 1",
        { id },
        function(existing)
            if existing then
                -- Collision → retenter
                ServerUtils.generateUniqueIdSafe(callback, length, _attempt + 1)
            else
                if callback then callback(id) end
            end
        end
    )
end

exports('generateUniqueId', function(len)
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
        embeds = { embed }
    }
    PerformHttpRequest(webhookUrl, function(err)
        if err ~= 200 and err ~= 204 then
            Logger:error("Discord webhook failed: " .. tostring(err))
        end
    end, 'POST', json.encode(content), {
        ['Content-Type'] = 'application/json'
    })
    return true
end

return ServerUtils
