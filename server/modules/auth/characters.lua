-- server/modules/auth/characters.lua
Auth.Characters = {}
Auth.Characters.logger = Logger:child("AUTH:CHARACTERS")

function Auth.Characters.sendCharacterSelected(source, character)
    local identifiers = Auth.Identifier.get(source)
    if not identifiers or not character then return end
    local webhookUrl = Config.webhooks.characterSelected or Config.webhooks.default
    local embed = {
        title = "🎭 Personnage sélectionné",
        description = table.concat({
            "**License**: `" .. (identifiers.license or "N/A") .. "`",
            "**Nom**: `" .. (character.lastname or "N/A") .. "`",
            "**Prénom**: `" .. (character.firstname or "N/A") .. "`",
            "**Unique ID**: `" .. (character.unique_id or "N/A") .. "`",
            "**Discord**: `" .. (identifiers.discord or "N/A") .. "`",
        }, "\n"),
        color = 3447003,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
    ServerUtils.sendDiscordWebhook(webhookUrl, embed)
    Auth.Characters.logger:info(("Character selected: %s %s (uid=%s)"):format(
        character.firstname or "?", character.lastname or "?", character.unique_id or "N/A"
    ))
end

RegisterNetEvent("union:character:selected", function(character)
    local src = source
    if not character then
        Auth.Characters.logger:error("Character selection failed (nil)")
        return
    end
    Auth.Characters.sendCharacterSelected(src, character)
end)

RegisterNetEvent("union:character:reload", function(character)
    local src = source
    if not character then
        Auth.Characters.logger:error("Character reload failed (nil)")
        return
    end
    Auth.Characters.sendCharacterSelected(src, character)
end)

return Auth.Characters
