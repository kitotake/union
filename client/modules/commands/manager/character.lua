-- client/modules/commands/manager/character.lua
RegisterCommand("listchars", function()
    Character.list()
end, false)

RegisterCommand("selectchar", function(source, args)
    local id = tonumber(args[1])
    if not id then
        Notifications.send("Usage: /selectchar <id>", "error")
        return
    end
    Character.select(id)
end, false)

RegisterCommand("delchar", function(source, args)
    local id = tonumber(args[1])
    if not id then
        Notifications.send("Usage: /delchar <id>", "error")
        return
    end
    Character.delete(id)
end, false)

-- FIX : renommé "charinfo" → "mycharinfo".
-- Il collisionnait avec la commande serveur "/charinfo <id>" (admin,
-- server/modules/commands/manager/character.lua). Le client intercepte
-- toujours en premier une commande de même nom : taper "/charinfo 5" dans
-- le chat exécutait systématiquement CETTE version (infos du joueur
-- lui-même), et la commande admin n'était atteignable que depuis la
-- console serveur. Avec ce renommage, "/charinfo <id>" devient enfin
-- utilisable en jeu par un admin.
RegisterCommand("mycharinfo", function()
    local char = Client.currentCharacter
    if char then
        Notifications.send(
            ("Current: %s %s | DOB: %s | Job: %s (%s)"):format(
                char.firstname   or "?",
                char.lastname    or "?",
                char.dateofbirth or "?",
                char.job         or "unemployed",
                char.job_grade   or 0
            ),
            "info"
        )
    else
        Notifications.send("No character selected", "warning")
    end
end, false)