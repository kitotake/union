-- client/modules/commands/debug.lua
if not Config.debug then return end

RegisterCommand("union:debug", function(source, args)
    local subcommand = args[1]
    if subcommand == "pos" then
        local pos, heading = Position.get()
        Notifications.send("Pos: " .. tostring(pos) .. ", Heading: " .. tostring(heading), "info")
    elseif subcommand == "player" then
        local char = Client.currentCharacter
        if char then
            Notifications.send(
                ("Perso actif: %s %s (uid=%s)"):format(
                    char.firstname or "?",
                    char.lastname  or "?",
                    char.unique_id or "?"
                ),
                "info"
            )
        else
            Notifications.send("Aucun personnage actif (Client.currentCharacter nil)", "warning")
        end
    elseif subcommand == "config" then
        Logger:debug("Current config:")
        Utils.dump(Config)
    else
        Notifications.send("Unknown debug command", "error")
    end
end, false)
