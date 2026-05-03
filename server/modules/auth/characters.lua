-- server/modules/auth/characters.lua
-- FIXES:
--   #1 : Webhook — character.id remplacé par character.unique_id
--        (character.id est l'ID SQL interne, unique_id est l'identifiant métier).

Auth.Characters = {}
Auth.Characters.logger = Logger:child("AUTH:CHARACTERS")

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
        title = "🎭 Personnage sélectionné",
        description = table.concat({
            "**License**: `" .. (identifiers.license or "N/A") .. "`",
            "**Nom**: `" .. (character.lastname or "N/A") .. "`",
            "**Prénom**: `" .. (character.firstname or "N/A") .. "`",
            -- FIX #1 : unique_id au lieu de id (l'ID SQL interne n'est pas utile ici)
            "**Unique ID**: `" .. (character.unique_id or "N/A") .. "`",
            "**Discord**: `" .. (identifiers.discord or "N/A") .. "`",
        }, "\n"),
        color = 3447003,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }

    ServerUtils.sendDiscordWebhook(webhookUrl, embed)

    Auth.Characters.logger:info(
        ("Character selected: %s %s (uid=%s)"):format(
            character.firstname or "?",
            character.lastname  or "?",
            character.unique_id or "N/A"
        )
    )
end

RegisterNetEvent("union:character:selected", function(character)
    local src = source

    if not character then
        Auth.Characters.logger:error("Character selection failed (nil)")
        return
    end

    Auth.Characters.sendCharacterSelected(src, character)
end)

return Auth.Characters
