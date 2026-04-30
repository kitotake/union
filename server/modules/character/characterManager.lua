-- fixes/server/modules/character/characterManager.lua
-- VERSION CORRIGÉE : supprime les NetEvents dupliqués avec spawn/handler.lua
-- Ce fichier gère UNIQUEMENT le flow NUI (openCreator, autoSpawn, sélection multi-perso)
-- Tous les handlers union:spawn:requestInitial / confirm / error sont dans spawn/handler.lua

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SÉLECTION DE PERSONNAGE DEPUIS LA NUI
-- Reçu quand le joueur clique "Jouer" dans l'interface de sélection
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RegisterNetEvent("characters:selectCharacter", function(charId)
    local src    = source
    local player = PlayerManager.get(src)

    if not player then
        Logger:warn("[charManager] selectCharacter : joueur introuvable src=" .. src)
        TriggerClientEvent("characters:error", src, "Session expirée. Reconnectez-vous.")
        return
    end

    local characterId = tonumber(charId)
    if not characterId or characterId <= 0 then
        TriggerClientEvent("characters:error", src, "ID de personnage invalide.")
        return
    end

    -- Vérifie que le personnage appartient bien au joueur
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

    -- Délègue à Character.select qui gère le spawn
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

        -- Ferme la NUI côté client
        TriggerClientEvent("characters:doSpawn", src, character)
    end)
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CRÉATION DE PERSONNAGE COMPLÈTE (depuis kt_character)
-- Reçu quand kt_character a terminé la création
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
            -- Recharge les persos et spawn automatiquement le nouveau
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

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- NOTE : les handlers suivants sont dans spawn/handler.lua
-- NE PAS les redéclarer ici :
--   RegisterNetEvent("union:spawn:requestInitial")
--   RegisterNetEvent("union:spawn:requestRespawn")
--   RegisterNetEvent("union:spawn:confirm")
--   RegisterNetEvent("union:spawn:error")
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
