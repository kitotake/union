union = union or {}
union.tPlayerLicenses = union.tPlayerLicenses or {}

local function getPlayerIP(src)
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if string.find(id, "ip:") then
            return string.gsub(id, "ip:", "")
        end
    end
    return nil
end

AddEventHandler("playerConnecting", function(sName, setKickReason, deferrals)
    local src = source
    deferrals.defer()
    
    Wait(100)
    deferrals.update("Vérification des identifiants...")
    
    local license = GetPlayerIdentifierByType(src, "license")
    local discord = GetPlayerIdentifierByType(src, "discord")
    local fivem = GetPlayerIdentifierByType(src, "fivem")
    local ip = getPlayerIP(src)
    
    -- Stockage temporaire
    union.tPlayerLicenses[src] = {
        license = license,
        discord = discord,
        fivem = fivem,
        ip = ip
    }
    
    -- Vérifications
    local missing = {}
    if not license or license == "" then table.insert(missing, "License FiveM") end
    if not discord or discord == "" then table.insert(missing, "Compte Discord") end
    if not fivem or fivem == "" then table.insert(missing, "Identifiant FiveM") end
    
    if #missing > 0 then
        local msg = "Connexion refusée - Services manquants: " .. table.concat(missing, ", ")
        deferrals.done(msg)
        return
    end
    
    deferrals.done()
end)

AddEventHandler("playerDropped", function()
    local src = source
    union.tPlayerLicenses[src] = nil
end)

function union:GetId(pPlayer, idType)
    local t = union.tPlayerLicenses[pPlayer or source]
    if not t then return nil end
    return idType and t[idType] or t
end

-- 🔁 Réinitialisation manuelle (optionnelle)
function union:SyncIdentifier(pPlayer)
    local license = GetPlayerIdentifierByType(pPlayer, "license")
    local discord = GetPlayerIdentifierByType(pPlayer, "discord")
    local fivem = GetPlayerIdentifierByType(pPlayer, "fivem")
    local ip = getPlayerIP(pPlayer)

    union.tPlayerLicenses[pPlayer] = {
        license   = license,
        discord   = discord,
        fivem     = fivem,
        ip        = ip
    }
end



function sendLogToDiscord(name, license, ip, discord, fivem)
    if not Config.webhooks or not Config.webhooks.connectionRejected then
        print("^1[ERROR] Webhook configuration missing")
        return
    end

    local content = {
        username = "Union Logs",
        embeds = {{
            title = "❌ Connexion refusée",
            description = ("Nom: **%s**\nDiscord: `%s`\nLicense: `%s`\nIP: `%s`\nFiveM: `%s`")
                :format(name, discord or "N/A", license or "N/A", ip or "N/A", fivem or "N/A"),
            color = 16711680
        }}
    }
    
    PerformHttpRequest(Config.webhooks.connectionRejected, function(err, text, headers)
        if err ~= 200 then
            print("^1[ERROR] Failed to send Discord webhook: " .. tostring(err))
        end
    end, 'POST', json.encode(content), {['Content-Type'] = 'application/json'})
end


function sendSuccessLogToDiscord(name, license, ip, discord, fivem)
    local content = {
        username = "Union Logs",
        embeds = {{
            title = "✅ Connexion autorisée",
            description = table.concat({
                "**Nom**: `" .. (name or "Inconnu") .. "`",
                "**License**: `" .. (license or "N/A") .. "`",
                "**Discord**: `" .. (discord or "N/A") .. "`",
                "**FiveM**: `" .. (fivem or "N/A") .. "`",
                "**IP**: `" .. (ip or "N/A") .. "`"
            }, "\n"),
            color = 3066993,
            footer = { text = "Système de connexion Union" },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }

    PerformHttpRequest(Config.webhooks.connectionRejected, function(err, text, headers)
        if err ~= 200 then
            print("^1[ERROR] Failed to send Discord webhook: " .. tostring(err))
        end
    end, 'POST', json.encode(content), {['Content-Type'] = 'application/json'})
end