-- server/connect.lua
union = union or {}

-- ⛓️ Initialisation de la table temporaire des licences
union.tPlayerLicenses = union.tPlayerLicenses or {}

-- 📡 Récupération IP du joueur
local function getPlayerIP(src)
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if string.find(id, "ip:") then
            return string.gsub(id, "ip:", "")
        end
    end
    return nil
end

-- 📥 Gestion de la connexion du joueur
AddEventHandler("playerConnecting", function(sName, setKickReason, deferrals)
    local src = source
    deferrals.defer()

    print("^2[DEBUG] Identifiants détectés pour " .. sName)
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        print("^2[IDENTIFIER] " .. i .. ": " .. GetPlayerIdentifier(src, i))
    end

    Wait(0)
    deferrals.update("Vérification de vos identifiants...")

    -- 🔍 Extraction des identifiants
    local license = GetPlayerIdentifierByType(src, "license")
    local discord = GetPlayerIdentifierByType(src, "discord")
    local xbl     = GetPlayerIdentifierByType(src, "xbl")
    local live    = GetPlayerIdentifierByType(src, "live")
    local fivem   = GetPlayerIdentifierByType(src, "fivem")
    local ip      = getPlayerIP(src)

    union.tPlayerLicenses[src] = {
        license   = license,
        discord   = discord,
        fivem     = fivem,
        ip        = ip
    }

    local checks = {
        { key = license, label = "License FiveM" },
        { key = discord, label = "Compte Discord" },
        { key = fivem,   label = "Identifiant FiveM" },
        { key = ip,      label = "Adresse IP détectable" }
    }

    local missing = {}
    for _, check in ipairs(checks) do
        if not check.key or check.key == "" then
            table.insert(missing, check.label)
        end
    end

    if #missing > 0 then
        local msg = ("Connexion refusée : services manquants – %s."):format(table.concat(missing, ", "))
        sendLogToDiscord(sName, license, ip, discord, fivem)
        deferrals.done(msg)
        return
    end

    sendSuccessLogToDiscord(sName, license, ip, discord, fivem)
    deferrals.done()
end)

-- 🧹 Nettoyage des identifiants à la déconnexion
AddEventHandler("playerDropped", function(reason)
    local src = source
    union.tPlayerLicenses[src] = nil
end)

-- 🔧 Fonction d'accès aux identifiants synchronisés
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