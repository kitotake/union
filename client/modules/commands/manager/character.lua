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
