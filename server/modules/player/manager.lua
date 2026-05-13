-- server/modules/player/manager.lua
-- FIX PM1 : snapshot complet (health, armor, position) sans accès async.
-- FIX PM2 : commentaire clarifié sur la single-thread FiveM.
-- FIX PM3 : Auth.Webhooks.playerLeft appelée seulement si player existe.
-- FIX PM4 : char.model → char.ped_model. gender supprimé.
-- FIX PM5 : position transmise à OfflinePed sous forme de string JSON.
-- FIX CRIT-5 : Race condition playerDropped supprimée.
--   Avant : manager.lua et status/manager.lua avaient chacun un AddEventHandler
--   ("playerDropped") indépendant. L'ordre d'exécution n'était pas garanti.
--   Si manager.lua retirait le joueur en premier, StatusManager ne trouvait
--   plus la licence et abandonnait la sauvegarde des statuts silencieusement.
--
--   Solution : manager.lua déclenche d'abord un event local "union:player:dropping"
--   (AVANT PlayerManager.remove). Tous les modules qui ont besoin du joueur
--   (StatusManager, etc.) écoutent cet event — ils sont certains que le joueur
--   existe encore. Ensuite manager.lua fait PlayerManager.remove().
--
-- FIX CRIT-2 (complémentaire) : isSpawned est mis à true dans handler.lua
--   (union:spawn:confirm) et NON dans un AddEventHandler séparé ici,
--   pour éviter toute ambiguïté sur l'ordre des handlers.

PlayerManager         = {}
PlayerManager.logger  = Logger:child("PLAYER:MANAGER")
PlayerManager.players = {}

function PlayerManager.create(source)
    if PlayerManager.players[source] then
        PlayerManager.logger:warn("Joueur " .. source .. " déjà existant")
        return PlayerManager.players[source]
    end

    if not PlayerClass then
        PlayerManager.logger:error("PlayerClass est nil — vérifier l'ordre de chargement fxmanifest")
        return nil
    end

    local player = PlayerClass.new(source)
    PlayerManager.players[source] = player
    return player
end

function PlayerManager.get(source)
    return PlayerManager.players[source]
end

function PlayerManager.getByLicense(license)
    for _, player in pairs(PlayerManager.players) do
        if player.license == license then return player end
    end
    return nil
end

function PlayerManager.getAll()
    return PlayerManager.players
end

function PlayerManager.remove(source)
    if PlayerManager.players[source] then
        PlayerManager.logger:info("Suppression joueur : " .. (PlayerManager.players[source].name or tostring(source)))
        PlayerManager.players[source] = nil
    end
end

function PlayerManager.count()
    local count = 0
    for _ in pairs(PlayerManager.players) do count = count + 1 end
    return count
end

function PlayerManager.getStats()
    local stats = { total = PlayerManager.count(), admins = 0, moderators = 0, users = 0 }
    for _, player in pairs(PlayerManager.players) do
        if player:isAdmin() then
            stats.admins = stats.admins + 1
        elseif player:isModerator() then
            stats.moderators = stats.moderators + 1
        else
            stats.users = stats.users + 1
        end
    end
    return stats
end

-- ──────────────────────────────────────────────────────────────────────────
-- Joueur rejoint
-- ──────────────────────────────────────────────────────────────────────────

RegisterNetEvent("union:player:joined", function()
    local src = source

    local player = PlayerManager.create(src)
    if not player then
        PlayerManager.logger:error("Impossible de créer l'objet joueur pour source " .. tostring(src))
        DropPlayer(src, "Échec de l'initialisation des données joueur")
        return
    end

    player:loadFromDatabase(function(success)
        if success then
            PlayerManager.logger:info("Joueur " .. player.name .. " chargé")
            Auth.Webhooks.playerJoined(src)
            TriggerClientEvent("union:player:loaded", src)
        else
            PlayerManager.logger:error("Échec du chargement joueur " .. tostring(src))
            DropPlayer(src, "Échec du chargement des données")
        end
    end)
end)

-- ──────────────────────────────────────────────────────────────────────────
-- Joueur quitte
-- FIX CRIT-5 : on déclenche union:player:dropping AVANT PlayerManager.remove.
-- Tous les modules qui dépendent de PlayerManager.get(src) (StatusManager,
-- OfflinePed, etc.) doivent écouter union:player:dropping, pas playerDropped.
-- ──────────────────────────────────────────────────────────────────────────

AddEventHandler("playerDropped", function(reason)
    local src    = source
    local player = PlayerManager.get(src)

    if not player then return end

    -- FIX PM3 : webhook ici, player confirmé non-nil
    Auth.Webhooks.playerLeft(src, reason)
    PlayerManager.logger:info("Joueur " .. player.name .. " déconnecté : " .. tostring(reason))

    -- FIX CRIT-5 : notifier TOUS les modules AVANT de supprimer le joueur.
    -- À ce moment player est encore dans PlayerManager — les handlers peuvent
    -- appeler PlayerManager.get(src) et trouver le joueur.
    TriggerEvent("union:player:dropping", src, player, reason)

    -- FIX PM1 : snapshot COMPLET de toutes les données nécessaires
    local saveData = nil
    if player.currentCharacter and player.isSpawned then
        local char    = player.currentCharacter
        local posJson = nil

        if type(char.position) == "string" then
            posJson = char.position
        elseif type(char.position) == "table" then
            posJson = json.encode(char.position)
        elseif type(char.position) == "vector3" then
            posJson = json.encode({
                x       = char.position.x,
                y       = char.position.y,
                z       = char.position.z,
                heading = char.heading or 0.0,
            })
        end

        saveData = {
            unique_id = char.unique_id,
            health    = char.health or 200,
            armor     = char.armor  or 0,
            posJson   = posJson,
            name      = player.name,
        }
    end

    -- OfflinePed AVANT remove — FIX PM4 : ped_model, FIX PM5 : JSON string
    if player.currentCharacter and OfflinePed then
        local char    = player.currentCharacter
        local posData = char.position

        if posData then
            local posStr
            if type(posData) == "string" then
                posStr = posData
            elseif type(posData) == "table" then
                posStr = json.encode(posData)
            elseif type(posData) == "vector3" then
                posStr = json.encode({
                    x = posData.x, y = posData.y, z = posData.z,
                    heading = char.heading or 0.0,
                })
            end

            if posStr then
                OfflinePed.create({
                    currentCharacter = {
                        unique_id = char.unique_id,
                        ped_model = char.ped_model or "mp_m_freemode_01",
                        position  = posStr,
                    },
                    name = player.name,
                })
            end
        end
    end

    -- remove APRÈS les traitements synchrones et le TriggerEvent dropping
    PlayerManager.remove(src)

    -- Sauvegarde async APRÈS remove (snapshot déjà pris)
    if saveData then
        CreateThread(function()
            if not saveData.posJson then
                PlayerManager.logger:warn("Pas de position à sauvegarder pour " .. saveData.name)
                return
            end

            exports.oxmysql:execute([[
                UPDATE characters SET
                    position = ?, health = ?, armor = ?, last_played = NOW()
                WHERE unique_id = ?
            ]], {
                saveData.posJson,
                saveData.health,
                saveData.armor,
                saveData.unique_id,
            }, function(result)
                if result then
                    PlayerManager.logger:info("Personnage sauvegardé à la déco pour " .. saveData.name)
                else
                    PlayerManager.logger:error("Échec sauvegarde personnage pour " .. saveData.name)
                end
            end)
        end)
    end
end)

return PlayerManager