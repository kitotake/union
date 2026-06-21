-- server/modules/character/creation/create.lua
CharacterCreate = {}
CharacterCreate.logger = Logger:child("CHARACTER:CREATE")

CharacterCreate.rules = {
    firstname   = { minLength = 2, maxLength = 50, pattern = "^[a-zA-Z'-]+$" },
    lastname    = { minLength = 2, maxLength = 50, pattern = "^[a-zA-Z'-]+$" },
    dateofbirth = { pattern = "^%d%d%d%d%-%d%d%-%d%d$" }
}

function CharacterCreate.validate(data)
    if not data.firstname or data.firstname:len() < CharacterCreate.rules.firstname.minLength then return false, "First name too short" end
    if data.firstname:len() > CharacterCreate.rules.firstname.maxLength then return false, "First name too long" end
    if not data.lastname or data.lastname:len() < CharacterCreate.rules.lastname.minLength then return false, "Last name too short" end
    if data.lastname:len() > CharacterCreate.rules.lastname.maxLength then return false, "Last name too long" end
    if not Utils.validateDate(data.dateofbirth) then return false, "Invalid date format" end
    if not data.ped_model or (data.ped_model ~= "mp_m_freemode_01" and data.ped_model ~= "mp_f_freemode_01") then
        return false, "Invalid ped model"
    end
    return true, nil
end

function CharacterCreate.getDefaultAppearance(pedModel)
    return { ped_model = pedModel or "mp_m_freemode_01", components = {}, props = {}, tattoos = {} }
end

return CharacterCreate
