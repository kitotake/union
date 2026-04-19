-- client/modules/commands/character.lua

-- Create character command
RegisterCommand("createchar", function(source, args)
    local data = {
        firstname = args[1] or "Jean",
        lastname = args[2] or "Dupont",
        dateofbirth = args[3] or "1990-01-01",
        gender = args[4] or "m"
    }
    
    Character.create(data)
end, false)

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
RegisterCommand("charinfo", function()
    if Character.current then
        local char = Character.current
        Notifications.send(
            ("Current: %s %s | DOB: %s | Gender: %s"):format(
                char.firstname, char.lastname, char.dateofbirth, char.gender
            ), 
            "info"
        )
    else
        Notifications.send("No character selected", "warning")
    end
end, false)