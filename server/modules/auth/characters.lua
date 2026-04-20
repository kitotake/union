Auth.Characters = {}
Auth.Characters.logger = Logger:child("AUTH:CHARACTERS")

-----------------------------------------
-- SEND CHARACTER SELECT WEBHOOK
-----------------------------------------
function Auth.Characters.sendCharacterSelected(source, character)
    local identifiers = Auth.Identifier.get(source)
    if not identifiers then
        Auth.Characters.logger:error("No identifiers for source: " .. source)
        return
    end

    if not character then
        Auth.Characters.logger:error("No character data provided")
        return
    end

    local webhookUrl = Config.webhooks.characterSelected or Config.webhooks.default

    local embed = {
        title = "🎭 Character Selected du joueur",
        description = table.concat({
            "**License**: `" .. (identifiers.license or "N/A") .. "`",
            "**Nom**: `" .. (character.lastname or "N/A") .. "`",
            "**Prénom**: `" .. (character.firstname or "N/A") .. "`",
            "**Unique ID**: `" .. (character.id or "N/A") .. "`",
            "**Discord**: `" .. (identifiers.discord or "N/A") .. "`",
        }, "\n"),
        color = 3447003, -- Blue
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }

    ServerUtils.sendDiscordWebhook(webhookUrl, embed)

    Auth.Characters.logger:info(
        ("Character selected: %s %s (%s)"):format(
            character.firstname,
            character.lastname,
            character.id
        )
    )
end

-----------------------------------------
-- EVENT: CHARACTER SELECTED
-----------------------------------------
RegisterNetEvent("union:character:selected", function(character)
    local src = source

    if not character then
        Auth.Characters.logger:error("Character selection failed (nil)")
        return
    end

    Auth.Characters.sendCharacterSelected(src, character)
end)

return Auth.Characters