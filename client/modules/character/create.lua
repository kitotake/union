-- client/modules/character/create.lua
CharacterCreate = {}
local logger = Logger:child("CHARACTER:CREATE")

function CharacterCreate.open()
    logger:info("Opening character creation interface")
    -- This will open a UI for character creation
    -- For now, just show a notification
    Notifications.send("Character creation UI coming soon", "info")
end

function CharacterCreate.validate(data)
    if not data.firstname or data.firstname == "" then
        return false, "First name is required"
    end
    
    if not data.lastname or data.lastname == "" then
        return false, "Last name is required"
    end
    
    if not data.dateofbirth or data.dateofbirth == "" then
        return false, "Date of birth is required"
    end
    
    if not data.ped_model or (data.ped_model ~= "mp_m_freemode_01" and data.ped_model ~= "mp_f_freemode_01") then
        return false, "Please select a valid model"
    end
    
    return true, nil
end

function CharacterCreate.submit(data)
    logger:info("Submitting character creation: " .. data.firstname .. " " .. data.lastname)
    
    local valid, error = CharacterCreate.validate(data)
    if not valid then
        Notifications.send(error, "error")
        return
    end
    
    Character.create(data)
end

return CharacterCreate