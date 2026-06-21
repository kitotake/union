-- server/modules/auth/manager/webhooks.lua
Auth.Webhooks = {}
Auth.Webhooks.logger = Logger:child("AUTH:WEBHOOKS")

function Auth.Webhooks.sendAction(action, playerName, license, discord, ip, details)
    local colors = { login=3066993, logout=16711680, ban=16711680, kick=16755200, admin_action=16776960 }
    local webhookUrl = Config.webhooks[action] or Config.webhooks.connectionAccepted
    local descParts = {
        "**License**: `" .. (license or "N/A") .. "`",
        "**Discord**: `" .. (discord or "N/A") .. "`",
        "**IP**: `" .. (ip or "N/A") .. "`",
    }
    if details then table.insert(descParts, "**Details**: " .. details) end
    local embed = {
        title = ("**[%s]** %s"):format(action:upper(), playerName or "Unknown Player"),
        description = table.concat(descParts, "\n"),
        color = colors[action] or 0,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
    ServerUtils.sendDiscordWebhook(webhookUrl, embed)
end

function Auth.Webhooks.playerJoined(source)
    local identifiers = Auth.Identifier.get(source)
    if not identifiers then return end
    Auth.Webhooks.sendAction("login", identifiers.name, identifiers.license, identifiers.discord, identifiers.ip, nil)
end

function Auth.Webhooks.playerLeft(source, reason)
    local identifiers = Auth.tempIdentifiers[source]
    if not identifiers then return end
    Auth.Webhooks.sendAction("logout", identifiers.name, identifiers.license, identifiers.discord, identifiers.ip, "Reason: " .. (reason or "Unknown"))
end

function Auth.Webhooks.playerKicked(source, reason)
    local identifiers = Auth.Identifier.get(source)
    if not identifiers then return end
    Auth.Webhooks.sendAction("kick", identifiers.name, identifiers.license, identifiers.discord, identifiers.ip, "Reason: " .. (reason or "No reason provided"))
end

function Auth.Webhooks.playerBanned(identifier, reason, duration)
    Auth.Webhooks.logger:info("Logging ban: " .. identifier)
    local idType = "Unknown"
    if identifier:find("license:") then idType = "License"
    elseif identifier:find("discord:") then idType = "Discord"
    elseif identifier:find("fivem:") then idType = "FiveM" end
    local embed = {
        title = "🔨 Player Banned",
        description = table.concat({
            "**ID**: `" .. identifier .. "`",
            "**Type**: " .. idType,
            "**Reason**: " .. (reason or "No reason"),
            duration and ("**Duration**: " .. duration .. " seconds") or "**Duration**: Permanent",
        }, "\n"),
        color = 16711680,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
    ServerUtils.sendDiscordWebhook(Config.webhooks.playerBanned or Config.webhooks.connectionRejected, embed)
end

return Auth.Webhooks
