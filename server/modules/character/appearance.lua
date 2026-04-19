-- server/modules/character/appearance.lua
CharacterAppearance = {}
CharacterAppearance.logger = Logger:child("CHARACTER:APPEARANCE")

function CharacterAppearance.load(uniqueId, callback)
    Database.fetchOne(
        "SELECT * FROM character_appearances WHERE unique_id = ?",
        {uniqueId},
        function(result)
            if callback then
                callback(result or {})
            end
        end
    )
end

function CharacterAppearance.save(uniqueId, skinData, faceFeatures, tattoos, callback)
    Database.execute([[
        UPDATE character_appearances SET
        skin_data = ?, face_features = ?, tattoos = ?,
        updated_at = NOW()
        WHERE unique_id = ?
    ]], {
        json.encode(skinData or {}),
        json.encode(faceFeatures or {}),
        json.encode(tattoos or {}),
        uniqueId
    }, function(result)
        CharacterAppearance.logger:info("Appearance saved for character: " .. uniqueId)
        if callback then callback(result) end
    end)
end

function CharacterAppearance.getSkinData(appearance)
    if appearance.skin_data then
        return json.decode(appearance.skin_data) or {}
    end
    return {}
end

function CharacterAppearance.getFaceFeatures(appearance)
    if appearance.face_features then
        return json.decode(appearance.face_features) or {}
    end
    return {}
end

function CharacterAppearance.getTattoos(appearance)
    if appearance.tattoos then
        return json.decode(appearance.tattoos) or {}
    end
    return {}
end

return CharacterAppearance