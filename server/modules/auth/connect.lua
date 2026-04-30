-- server/modules/auth/connect.lua

Auth = Auth or {}
Auth.logger = Logger:child("AUTH")

-- Store player identifiers temporarily
Auth.tempIdentifiers = {}

AddEventHandler("playerConnecting", function(sName, setKickReason, deferrals)
    local src = source
    deferrals.defer()

    Auth.logger:info("Player connecting: " .. sName .. " (" .. src .. ")")

    Wait(100)
    deferrals.update("Checking identifiers...")

    -- Get identifiers
    local license = GetPlayerIdentifierByType(src, "license")
    local discord = GetPlayerIdentifierByType(src, "discord")
    local fivem = GetPlayerIdentifierByType(src, "fivem")
    local ip = ServerUtils.getPlayerIP(src)

    -- Store temporarily
    Auth.tempIdentifiers[src] = {
        license = license,
        discord = discord,
        fivem = fivem,
        ip = ip,
        name = sName,
    }

    -- Validate required identifiers
    local missing = {}

    if not license or license == "" then
        table.insert(missing, "FiveM License")
    end

    if not discord or discord == "" then
        table.insert(missing, "Join us on Discord or on Discord servers")
    end

    if #missing > 0 then
        local msg = "Missing: " .. table.concat(missing, ", ")

        Auth.logger:warn("Connection rejected for " .. sName .. ": " .. msg)

        Auth.sendRejectionWebhook(
            sName,
            license,
            discord,
            ip,
            table.concat(missing, ", ")
        )

        deferrals.done(msg)
        return
    end

    -- =========================
    -- WHITELIST CHECK (ASYNC)
    -- =========================
    deferrals.update("Checking whitelist...")

    Whitelist.check(src, license, sName, deferrals, function(allowed)
        if not allowed then
            Auth.logger:warn("Whitelist refused for " .. sName)

            Auth.sendRejectionWebhook(
                sName,
                license,
                discord,
                ip,
                "Not whitelisted"
            )

            deferrals.done("You are not whitelisted on this server.")
            return
        end

        -- ACCEPTED
        Auth.logger:info("Connection accepted for " .. sName)

        Auth.sendAcceptanceWebhook(sName, license, discord, ip)

        deferrals.done()
    end)
end)

AddEventHandler("playerDropped", function(reason)
    local src = source

    local name = GetPlayerName(src) or "Unknown"

    Auth.tempIdentifiers[src] = nil

    Auth.logger:info("Player dropped: " .. name .. " (" .. reason .. ")")
end)

-- =========================
-- UTILS
-- =========================

function Auth.getId(source, idType)
    local identifiers = Auth.tempIdentifiers[source]
    if not identifiers then return nil end

    if idType then
        return identifiers[idType]
    end

    return identifiers
end

-- =========================
-- WEBHOOKS
-- =========================

function Auth.sendRejectionWebhook(name, license, discord, ip, reason)
    local embed = {
        title = "❌ Connection Rejected",
        description = ("**Player**: %s\n**Reason**: %s\n**License**: `%s`\n**Discord**: `%s`\n**IP**: `%s`"):format(
            name or "Unknown",
            reason or "Unknown",
            license or "N/A",
            discord or "N/A",
            ip or "N/A"
        ),
        color = 16711680,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }

    ServerUtils.sendDiscordWebhook(Config.webhooks.connectionRejected, embed)
end

function Auth.sendAcceptanceWebhook(name, license, discord, ip)
    local embed = {
        title = "✅ Connection Accepted",
        description = ("**Player**: %s\n**License**: `%s`\n**Discord**: `%s`\n**IP**: `%s`"):format(
            name or "Unknown",
            license or "N/A",
            discord or "N/A",
            ip or "N/A"
        ),
        color = 3066993,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }

    ServerUtils.sendDiscordWebhook(Config.webhooks.connectionAccepted, embed)
end