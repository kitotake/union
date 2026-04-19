-- server/modules/character/database.lua
CharacterDB = {}
CharacterDB.logger = Logger:child("CHARACTER:DATABASE")

function CharacterDB.getCharacterCount(license, callback)
    Database.scalar(
        "SELECT COUNT(*) FROM characters WHERE identifier = ?",
        {license},
        function(count)
            if callback then callback(count or 0) end
        end
    )
end

function CharacterDB.getCharacterByUniqueId(uniqueId, callback)
    Database.fetchOne(
        "SELECT * FROM characters WHERE unique_id = ?",
        {uniqueId},
        function(result)
            if callback then callback(result) end
        end
    )
end

function CharacterDB.isUniqueName(firstname, lastname, excludeId, callback)
    Database.scalar(
        "SELECT COUNT(*) FROM characters WHERE firstname = ? AND lastname = ? AND id != ?",
        {firstname, lastname, excludeId or 0},
        function(count)
            if callback then callback(count == 0) end
        end
    )
end

function CharacterDB.getLastPlayedCharacter(license, callback)
    Database.fetchOne(
        "SELECT * FROM characters WHERE identifier = ? ORDER BY last_played DESC LIMIT 1",
        {license},
        function(result)
            if callback then callback(result) end
        end
    )
end

function CharacterDB.canCreateCharacter(license, callback)
    CharacterDB.getCharacterCount(license, function(count)
        local maxChars = Config.character.maxCharactersPerPlayer or 5
        if callback then callback(count < maxChars) end
    end)
end

return CharacterDB