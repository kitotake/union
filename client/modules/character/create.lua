-- client/modules/character/create.lua
-- FIX CCC-1 : gender retiré de la validation (colonne inexistante).
-- FIX WARN-3 : CharacterCreate.open() envoyait juste une notification "coming soon"
--              alors qu'elle est appelée dans des flows critiques (pas de personnage).
--              Elle déclenche maintenant kt_character:openCreator via TriggerServerEvent
--              pour que le serveur transmette l'ouverture à ce client.
--              Si kt_character n'est pas disponible, une notification claire est affichée.

CharacterCreate = {}
local logger = Logger:child("CHARACTER:CREATE")

function CharacterCreate.open()
    logger:info("Opening character creation interface via kt_character")
    -- Demande au serveur d'ouvrir kt_character pour ce client
    -- (le serveur fait TriggerClientEvent("kt_character:openCreator", src))
    TriggerServerEvent("union:character:requestCreation")
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

    -- FIX CCC-1 : ped_model, pas gender
    if not data.ped_model or
       (data.ped_model ~= "mp_m_freemode_01" and data.ped_model ~= "mp_f_freemode_01") then
        return false, "Please select a valid model (male or female)"
    end

    return true, nil
end

function CharacterCreate.submit(data)
    logger:info("Submitting character creation: " .. (data.firstname or "?") .. " " .. (data.lastname or "?"))

    local valid, err = CharacterCreate.validate(data)
    if not valid then
        Notifications.send(err, "error")
        return
    end

    Character.create(data)
end

return CharacterCreate