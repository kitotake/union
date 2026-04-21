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

    print("^2[CHARACTER SELECT] Available characters:")
    for i, char in ipairs(characters) do
        print(string.format("  ^3[%d]^7 %s %s (DOB: %s)",
            char.id, char.firstname, char.lastname, char.dateofbirth))
    end
    print("^2Use /selectchar <id> to select a character")
end

-- ✅ FIX : Character.list = characters écrasait la FONCTION Character.list
function CharacterSelect.display(characters)
    Character.characters = characters  -- utilise la bonne propriété
    CharacterSelect.open(characters)
end

RegisterNetEvent("union:character:listUpdated", function(characters)
    CharacterSelect.display(characters)
end)

RegisterNetEvent("union:spawn:noCharacters", function()
    logger:info("Player has no characters")
    Notifications.send("You have no characters. Create one first!", "info")
    CharacterCreate.open()
end)

RegisterNetEvent("union:spawn:selectCharacter", function(characters)
    CharacterSelect.display(characters)
end)

return CharacterSelect