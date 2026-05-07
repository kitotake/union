-- client/modules/character/main.lua
-- FIX CM-1 : character.create() n'exige plus gender (colonne inexistante).
--            Seul ped_model est requis (détermine le genre implicitement).

Character = {}
local logger = Logger:child("CHARACTER")

Character.characters = {}
Character.current    = nil

function Character.list()
    logger:info("Requesting character list")
    TriggerServerEvent("union:character:list")
end

function Character.create(data)
    -- FIX CM-1 : validation sans gender (colonne absente de characters)
    if not data.firstname or not data.lastname or not data.dateofbirth or not data.ped_model then
        logger:error("Incomplete character data")
        Notifications.send(_t("character.create_failed"), "error")
        return
    end

    logger:info("Creating character: " .. data.firstname .. " " .. data.lastname)
    TriggerServerEvent("union:character:create", data)
end

function Character.select(id)
    if not id or id <= 0 then
        logger:error("Invalid character ID: " .. tostring(id))
        return
    end

    logger:info("Selecting character: " .. id)
    TriggerServerEvent("union:character:select", id)
end

function Character.delete(id)
    if not id or id <= 0 then
        logger:error("Invalid character ID: " .. tostring(id))
        return
    end

    logger:info("Deleting character: " .. id)
    TriggerServerEvent("union:character:delete", id)
end

RegisterNetEvent("union:character:listReceived", function(characters)
    Character.characters = characters
    logger:info("Received " .. #characters .. " characters")
    TriggerEvent("union:character:listUpdated", characters)
end)

RegisterNetEvent("union:character:created", function(success, id, uniqueId)
    if success then
        logger:info("Character created successfully - ID: " .. tostring(id) .. ", UID: " .. tostring(uniqueId))
        Notifications.send(_t("character.created", "Character", "Created"), "success")
        Character.list()
    else
        logger:error("Failed to create character")
        Notifications.send(_t("character.create_failed"), "error")
    end
end)

RegisterNetEvent("union:character:selected", function(success, character)
    if success then
        Character.current = character
        logger:info("Character selected: " .. character.firstname .. " " .. character.lastname)
        Notifications.send(_t("character.selected", character.firstname .. " " .. character.lastname), "success")
    else
        logger:error("Failed to select character")
        Notifications.send(_t("character.select_failed"), "error")
    end
end)
