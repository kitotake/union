-- server/modules/character/characterManager.lua
-- FIXES:
--   #1 : Double spawn — characters:selectCharacter appelait Character.select()
--        (qui déclenche union:spawn:apply) ET ensuite envoyait characters:doSpawn
--        au client (qui ne fait rien de plus, mais le commentaire était trompeur).
--        Le flow est clarifié : Character.select() gère tout le spawn,
--        characters:doSpawn sert uniquement à fermer la NUI proprement.
--   #2 : Vérification que le joueur n'est pas déjà spawné avant de re-sélectionner.

RegisterNetEvent("characters:selectCharacter", function(charId)
    local src    = source
    local player = PlayerManager.get(src)

    if not player then
        Logger:warn("[charManager] selectCharacter : joueur introuvable src=" .. src)
        TriggerClientEvent("characters:error", src, "Session expirée. Reconnectez-vous.")
        return
    end

    -- FIX #2 : éviter un double spawn si déjà spawné
    if player.isSpawned then
        Logger:warn("[charManager] Joueur déjà spawné, sélection ignorée src=" .. src)
        return
    end

    local characterId = tonumber(charId)
    if not characterId or characterId <= 0 then
        TriggerClientEvent("characters:error", src, "ID de personnage invalide.")
        return
    end

    local owned = false
    for _, char in ipairs(player.characters or {}) do
        if char.id == characterId then
            owned = true
            break
        end
    end

    if not owned then
        Logger:warn("[charManager] Tentative de sélection d'un personnage non possédé — src=" .. src)
        TriggerClientEvent("characters:error", src, "Personnage introuvable.")
        return
    end

    -- FIX #1 : Character.select() déclenche union:spawn:apply côté client.
    -- characters:doSpawn est envoyé UNIQUEMENT pour fermer la NUI —
    -- il ne doit PAS déclencher un spawn supplémentaire côté client.
    Character.select(player, characterId, function(success, character)
        if not success then
            TriggerClientEvent("characters:error", src, "Erreur lors de la sélection du personnage.")
            return
        end

        Logger:info(("[charManager] Personnage sélectionné : %s %s pour %s"):format(
            character.firstname or "?",
            character.lastname  or "?",
            player.name
        ))

        -- Fermeture de la NUI uniquement (pas de spawn ici, union:spawn:apply déjà envoyé)
        TriggerClientEvent("characters:doSpawn", src, character)
    end)
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CRÉATION DEPUIS kt_character
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RegisterNetEvent("kt_character:characterCreated", function(data)
    local src    = source
    local player = PlayerManager.get(src)

    if not player then
        Logger:warn("[charManager] kt_character:characterCreated — joueur introuvable src=" .. src)
        return
    end

    if not data then
        TriggerClientEvent("characters:error", src, "Données de personnage manquantes.")
        return
    end

    Logger:info(("[charManager] Création depuis kt_character pour %s"):format(player.name))

    Character.create(player, data, function(success, characterId, uniqueId)
        if success then
            Logger:info(("[charManager] Personnage créé ID=%s UID=%s"):format(
                tostring(characterId),
                tostring(uniqueId)
            ))
            player:loadCharacters(function()
                Character.select(player, characterId, function(selSuccess)
                    if not selSuccess then
                        TriggerClientEvent("characters:error", src, "Spawn après création échoué.")
                    end
                end)
            end)
        else
            TriggerClientEvent("characters:error", src, "Création du personnage échouée.")
        end
    end)
end)