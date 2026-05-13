-- server/modules/character/characterManager.lua
-- FIX #1 : Double spawn — corrigé.
-- FIX #2 : Guard isSpawned.
-- FIX CRIT-6 : CharacterSelect.isAvailable() appelée dans le flow.
-- FIX WARN-3 : handler union:character:requestCreation ajouté.
--   Le client appelle TriggerServerEvent("union:character:requestCreation")
--   et le serveur ouvre kt_character:openCreator pour lui, avec vérification
--   que la resource est bien démarrée.
-- FIX WARN-4 : guard dans union:player:joined côté serveur — si le joueur
--   existe déjà dans PlayerManager (restart resource rapide), on recharge
--   ses données sans créer de doublon.

RegisterNetEvent("characters:selectCharacter", function(charId)
    local src    = source
    local player = PlayerManager.get(src)

    if not player then
        Logger:warn("[charManager] selectCharacter : joueur introuvable src=" .. src)
        TriggerClientEvent("characters:error", src, "Session expirée. Reconnectez-vous.")
        return
    end

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

    -- FIX CRIT-6
    if not CharacterSelect.isAvailable(characterId) then
        Logger:warn(("[charManager] Personnage %d déjà utilisé — src=%d"):format(characterId, src))
        TriggerClientEvent("characters:error", src, "Ce personnage est déjà utilisé.")
        return
    end

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

        TriggerClientEvent("characters:doSpawn", src, character)
    end)
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- FIX WARN-3
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RegisterNetEvent("union:character:requestCreation", function()
    local src    = source
    local player = PlayerManager.get(src)

    if not player then
        Logger:warn("[charManager] requestCreation : joueur introuvable src=" .. src)
        return
    end

    if GetResourceState("kt_character") ~= "started" then
        Logger:warn("[charManager] kt_character non démarré — impossible d'ouvrir le créateur")
        ServerUtils.notifyPlayer(src, "L'interface de création n'est pas disponible.", "error")
        return
    end

    Logger:info(("[charManager] Ouverture créateur kt_character pour %s"):format(player.name))
    TriggerClientEvent("kt_character:openCreator", src)
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