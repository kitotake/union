local playerCharacters = {}
CharacterData = {}
local config = exports.union:GetConfig()

function GetPlayerCharacterData(playerId)
    local identifier = GetPlayerIdentifier(playerId, 0)
    if not identifier then
        print("^1[SpawnSystem] Erreur: Aucun identifiant trouvé pour le joueur " .. tostring(playerId))
        return nil
    end

    if not playerCharacters[identifier] then
        print("^5[SpawnSystem] Création d'un personnage par défaut pour " .. identifier)
        playerCharacters[identifier] = {
            model = config.defaultModel,
            lastPosition = config.temporary,
            lastHeading = config.heading,
            outfit = "casual",
            firstSpawn = true
        }
    end

    return playerCharacters[identifier]
end

function SavePlayerCharacterData(playerId, characterData)
    local identifier = GetPlayerIdentifier(playerId, 0)
    if not identifier then
        print("^1[SpawnSystem] Erreur: Impossible de trouver l'identifiant pour " .. tostring(playerId))
        return false
    end

    playerCharacters[identifier] = characterData
    print("^2[SpawnSystem] Données sauvegardées pour " .. GetPlayerName(playerId))
    return true
end
