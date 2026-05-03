-- server/modules/player/offline_ped.lua
-- FIXES:
--   #1 : Race condition dans playerDropped — OfflinePed.create() est maintenant
--        appelé AVANT PlayerManager.remove() dans manager.lua.
--        Ce fichier expose OfflinePed.create() qui reçoit directement les données
--        du personnage (plus de dépendance à player.currentCharacter après drop).
--   #2 : Ajout d'un store persistant (OfflinePed.store) pour garder les peds
--        en mémoire et les envoyer aux clients qui rejoignent plus tard.
--   #3 : Suppression du handler union:offlineped:spawned (netId supprimé car
--        les peds sont maintenant locaux côté client).
--   #4 : Ajout de l'event union:offlineped:loadAll envoyé au spawn pour que
--        le client reçoive tous les peds offline existants.

OfflinePed = {}
OfflinePed.logger = Logger:child("OFFLINE_PED")

-- FIX #2 : store persistant des données de peds offline
-- Clé = unique_id, valeur = table de données envoyée aux clients
OfflinePed.store = {}

local function decodePos(pos)
    if type(pos) == "table" then return pos end
    if type(pos) ~= "string" then return nil end

    local ok, data = pcall(json.decode, pos)
    if ok and data and data.x then return data end

    return nil
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CRÉER PED (broadcast à tous les clients)
-- FIX #1 : reçoit directement les données du personnage
--          (évite la dépendance à player.currentCharacter après drop)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function OfflinePed.create(playerData)
    if not playerData or not playerData.currentCharacter then
        OfflinePed.logger:warn("create: données manquantes")
        return
    end

    local char = playerData.currentCharacter
    local pos  = decodePos(char.position)

    if not pos or not pos.x then
        OfflinePed.logger:warn("Position invalide pour ped offline uid=" .. tostring(char.unique_id))
        return
    end

    local model = char.model or "mp_m_freemode_01"
    if model ~= "mp_m_freemode_01" and model ~= "mp_f_freemode_01" then
        model = (char.gender == "f") and "mp_f_freemode_01" or "mp_m_freemode_01"
    end

    local data = {
        uniqueId = char.unique_id,
        model    = model,
        x        = pos.x,
        y        = pos.y,
        z        = pos.z,
        heading  = pos.heading or 0.0,
    }

    -- FIX #2 : stocker pour les joueurs qui rejoignent plus tard
    OfflinePed.store[char.unique_id] = data

    -- Broadcast à tous les clients connectés
    TriggerClientEvent("union:offlineped:create", -1, data)

    OfflinePed.logger:info(("Ped offline créé pour uid=%s"):format(char.unique_id))
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SUPPRIMER PED (broadcast à tous)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function OfflinePed.remove(uniqueId)
    if not uniqueId then return end

    -- FIX #2 : retirer du store
    OfflinePed.store[uniqueId] = nil

    TriggerClientEvent("union:offlineped:remove", -1, uniqueId)

    OfflinePed.logger:info(("Ped offline supprimé pour uid=%s"):format(uniqueId))
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- FIX #4 : Envoi du dump initial quand un joueur spawne
-- Permet de voir les peds des joueurs déconnectés AVANT notre connexion
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
AddEventHandler("union:player:spawned", function(src, character)
    if not src or not character then return end

    -- Construire la liste des peds offline actuellement en store
    local list = {}
    for _, data in pairs(OfflinePed.store) do
        -- Ne pas envoyer le ped du personnage qui vient de spawner
        if data.uniqueId ~= character.unique_id then
            table.insert(list, data)
        end
    end

    if #list > 0 then
        TriggerClientEvent("union:offlineped:loadAll", src, list)
        OfflinePed.logger:debug(("Envoi de %d ped(s) offline à src=%s"):format(#list, tostring(src)))
    end
end)

-- FIX #3 : suppression du handler union:offlineped:spawned
-- Les peds sont maintenant locaux côté client, plus de netId à synchroniser.

return OfflinePed
