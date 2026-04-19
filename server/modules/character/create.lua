-- server/modules/character/create.lua
CharacterCreate = {}
CharacterCreate.logger = Logger:child("CHARACTER:CREATE")

-- Validation rules
CharacterCreate.rules = {
    firstname = {
        minLength = 2,
        maxLength = 50,
        pattern = "^[a-zA-Z'-]+$"
    },
    lastname = {
        minLength = 2,
        maxLength = 50,
        pattern = "^[a-zA-Z'-]+$"
    },
    dateofbirth = {
        pattern = "^%d{4}-%d{2}-%d{2}$"
    }
}

function CharacterCreate.validate(data)
    if not data.firstname or data.firstname:len() < CharacterCreate.rules.firstname.minLength then
        return false, "First name too short"
    end
    
    if data.firstname:len() > CharacterCreate.rules.firstname.maxLength then
        return false, "First name too long"
    end
    
    if not data.lastname or data.lastname:len() < CharacterCreate.rules.lastname.minLength then
        return false, "Last name too short"
    end
    
    if data.lastname:len() > CharacterCreate.rules.lastname.maxLength then
        return false, "Last name too long"
    end
    
    if not Utils.validateDate(data.dateofbirth) then
        return false, "Invalid date format"
    end
    
    if data.gender ~= "m" and data.gender ~= "f" then
        return false, "Invalid gender"
    end
    
    return true, nil
end

function CharacterCreate.getDefaultAppearance(gender)
    -- This will be expanded later for full appearance customization
    return {
        gender = gender,
        components = {},
        props = {},
        tattoos = {},
    }
end

return CharacterCreate