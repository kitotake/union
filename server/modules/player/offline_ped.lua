-- server/modules/player/offline_ped.lua
-- Gestion des peds persistants quand les joueurs sont déconnectés.
-- Quand un joueur quitte, on spawne un NPC à sa position qui dort.
-- Quand il revient, le NPC est supprimé et le joueur se lève.

OfflinePed = {}
OfflinePed.logger = Logger:child("OFFLINE_PED")

-- Table des peds persistants : source → { netId, uniqueId, ... }
OfflinePed.peds = {}

-- ──────────────────────────────────────────────────────────────────────────
-- Créer un ped persistant pour un joueur qui quitte
-- Appelé depuis playerDropped dans manager.lua
-- ──────────────────────────────────────────────────────────────────────────
function OfflinePed.create(player)
    if not player or not player.currentCharacter then return end

    local char    = player.currentCharacter
    local uniqueId = char.unique_id

    -- Récupérer la position du ped depuis la DB (déjà sauvegardée par persistence.lua)
    local pos     = char.position
    local model   = char.model or (char.gender == "f" and "mp_f_freemode_01" or "mp_m_freemode_01")

    if not pos then return end

    -- Décoder la position si c'est du JSON string
    if type(pos) == "string" then
        local ok, decoded = pcall(json.decode, pos)
        if ok and decoded and decoded.x then
            pos = decoded
        else
            return
        end
    end

    -- Demander au client ayant le moins de charge de spawner le ped
    -- On passe par un event global : un client quelconque spawne le ped réseau
    TriggerClientEvent("union:offlineped:create", -1, {
        uniqueId = uniqueId,
        model    = model,
        x        = pos.x,
        y        = pos.y,
        z        = pos.z,
        heading  = pos.heading or 0.0,
    })

    OfflinePed.logger:info(("Ped hors-ligne créé pour %s (%s)"):format(player.name, uniqueId))
end

-- ──────────────────────────────────────────────────────────────────────────
-- Supprimer le ped persistant quand le joueur revient
-- ──────────────────────────────────────────────────────────────────────────
function OfflinePed.remove(uniqueId)
    if not uniqueId then return end
    TriggerClientEvent("union:offlineped:remove", -1, uniqueId)
    OfflinePed.logger:info(("Ped hors-ligne supprimé pour unique_id=%s"):format(uniqueId))
end

-- ──────────────────────────────────────────────────────────────────────────
-- Events réseau
-- ──────────────────────────────────────────────────────────────────────────

-- Un client signale qu'il a créé le ped → on stocke son netId
RegisterNetEvent("union:offlineped:spawned", function(uniqueId, netId)
    OfflinePed.peds[uniqueId] = netId
    OfflinePed.logger:debug(("Ped enregistré: uid=%s netId=%s"):format(uniqueId, netId))
end)

return OfflinePed