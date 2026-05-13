-- server/modules/player/offline_ped.lua
-- FIX OP-1 : char.model → char.ped_model (colonne réelle dans characters).
-- FIX OP-2 : gender supprimé (colonne inexistante).
-- FIX OP-3 : OfflinePed.create reçoit les données snapshottées.
-- FIX OP-4 : create() broadcast à tous les clients SAUF la source qui se déconnecte.
--   Avant : TriggerClientEvent(-1, ...) envoyait le ped au joueur déconnectant lui-même
--   si sa connexion n'était pas encore coupée côté serveur. Le guard côté client
--   (Client.currentCharacter.unique_id == data.uniqueId) peut rater si le perso
--   est déjà unloaded à ce moment.
--   Solution : on itère PlayerManager.getAll() et on exclut explicitement le src
--   dont le ped vient d'être créé.
-- FIX OP-5 : remove() envoyé uniquement aux joueurs qui ont reçu le ped
--   (ceux qui étaient connectés au moment du create, stockés dans OfflinePed.store).
--   Évite le broadcast inutile à des joueurs qui n'ont jamais chargé ce ped.

OfflinePed        = {}
OfflinePed.logger = Logger:child("OFFLINE_PED")

-- Store persistant des peds offline (uid → data)
-- data contient aussi recipients : liste des src auxquels le ped a été envoyé
OfflinePed.store = {}

local function decodePos(pos)
    if type(pos) == "table" then return pos end
    if type(pos) ~= "string" then return nil end

    local ok, data = pcall(json.decode, pos)
    if ok and data and data.x then return data end

    return nil
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CRÉER PED
-- FIX OP-4 : broadcast ciblé, exclut le joueur déconnectant (excludeSrc)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function OfflinePed.create(playerData, excludeSrc)
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

    -- FIX OP-1 : ped_model est la colonne réelle
    local model = char.ped_model or "mp_m_freemode_01"
    if model ~= "mp_m_freemode_01" and model ~= "mp_f_freemode_01" then
        model = "mp_m_freemode_01"
    end

    local data = {
        uniqueId  = char.unique_id,
        model     = model,
        x         = pos.x,
        y         = pos.y,
        z         = pos.z,
        heading   = pos.heading or 0.0,
    }

    -- FIX OP-4 : on envoie uniquement aux joueurs connectés SAUF excludeSrc
    -- et on mémorise à qui on a envoyé pour le remove ciblé (FIX OP-5)
    local recipients = {}
    for src, _ in pairs(PlayerManager.getAll()) do
        if src ~= excludeSrc and GetPlayerEndpoint(src) then
            TriggerClientEvent("union:offlineped:create", src, data)
            recipients[src] = true
        end
    end

    data.recipients = recipients
    OfflinePed.store[char.unique_id] = data

    OfflinePed.logger:info(("Ped offline créé pour uid=%s (%d destinataires)"):format(
        char.unique_id, table.getn and table.getn(recipients) or (function()
            local n = 0; for _ in pairs(recipients) do n = n + 1 end; return n
        end)()
    ))
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SUPPRIMER PED
-- FIX OP-5 : envoyé uniquement aux recipients connus, pas à -1
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function OfflinePed.remove(uniqueId)
    if not uniqueId then return end

    local entry = OfflinePed.store[uniqueId]
    OfflinePed.store[uniqueId] = nil

    if not entry then
        -- Ped inconnu du store (jamais créé ou déjà supprimé) — rien à faire
        return
    end

    -- FIX OP-5 : on notifie uniquement les joueurs qui ont reçu le ped
    -- Si recipients est nil (données migrées / ancien format), fallback à -1
    if entry.recipients then
        for src in pairs(entry.recipients) do
            if GetPlayerEndpoint(src) then
                TriggerClientEvent("union:offlineped:remove", src, uniqueId)
            end
        end
    else
        TriggerClientEvent("union:offlineped:remove", -1, uniqueId)
    end

    OfflinePed.logger:info(("Ped offline supprimé pour uid=%s"):format(uniqueId))
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Envoi du dump initial quand un joueur spawne
-- On met aussi à jour les recipients pour les peds déjà en store
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
AddEventHandler("union:player:spawned", function(src, character)
    if not src or not character then return end

    local list = {}
    for _, data in pairs(OfflinePed.store) do
        if data.uniqueId ~= character.unique_id then
            table.insert(list, data)
            -- Enregistrer ce joueur comme recipient pour les removes futurs
            if data.recipients then
                data.recipients[src] = true
            end
        end
    end

    if #list > 0 then
        TriggerClientEvent("union:offlineped:loadAll", src, list)
        OfflinePed.logger:debug(("Envoi de %d ped(s) offline à src=%s"):format(#list, tostring(src)))
    end
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Nettoyage des recipients à la déco
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
AddEventHandler("union:player:dropping", function(src)
    -- Retirer ce joueur des listes de recipients de tous les peds
    for _, data in pairs(OfflinePed.store) do
        if data.recipients then
            data.recipients[src] = nil
        end
    end
end)

return OfflinePed