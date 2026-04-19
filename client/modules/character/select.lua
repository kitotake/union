-- client/modules/character/select.lua
CharacterSelect = {}
local logger = Logger:child("CHARACTER:SELECT")

function CharacterSelect.open(characters)
    logger:info("Opening character selection menu")
    
    if not characters or #characters == 0 then
        Notifications.send("No characters found. Create one first!", "info")
        CharacterCreate.open()
        return
    end
    
    -- Show character selection UI
    print("^2[CHARACTER SELECT] Available characters:")
    for i, char in ipairs(characters) do
        print(string.format("  ^3[%d]^7 %s %s (DOB: %s)", 
            char.id, char.firstname, char.lastname, char.dateofbirth))
    end
    print("^2Use /selectchar <id> to select a character")
end

function CharacterSelect.display(characters)
    Character.list = characters
    CharacterSelect.open(characters)
end

-- Listen for character list to trigger selection menu
RegisterNetEvent("union:character:listUpdated", function(characters)
    CharacterSelect.display(characters)
end)

-- Listen for no characters found
RegisterNetEvent("union:spawn:noCharacters", function()
    logger:info("Player has no characters")
    Notifications.send("You have no characters. Create one first!", "info")
    CharacterCreate.open()
end)

-- Listen for character selection screen
RegisterNetEvent("union:spawn:selectCharacter", function(characters)
    CharacterSelect.display(characters)
end)

return CharacterSelect