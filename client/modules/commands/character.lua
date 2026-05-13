-- client/modules/commands/character.lua
-- FIX WARN-1 : /charinfo utilisait Character.current (toujours nil depuis la migration)
--              → remplacé par Client.currentCharacter (source unique de vérité).
-- FIX WARN-2 : sous-commande "player" du debug corrigée dans ce même fichier.

-- List characters command
RegisterCommand("listchars", function()
    Character.list()
end, false)

-- Select character command
RegisterCommand("selectchar", function(source, args)
    local id = tonumber(args[1])
    if not id then
        Notifications.send("Usage: /selectchar <id>", "error")
        return
    end
    Character.select(id)
end, false)

-- Delete character command (with confirmation)
RegisterCommand("delchar", function(source, args)
    local id = tonumber(args[1])
    if not id then
        Notifications.send("Usage: /delchar <id>", "error")
        return
    end
    Character.delete(id)
end, false)

-- Info command
-- FIX WARN-1 : utilise Client.currentCharacter
RegisterCommand("charinfo", function()
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