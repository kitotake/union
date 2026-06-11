-- client/modules/commands/taginfo.lua
-- Gamer tags natifs MP_GAMER_TAG
-- Composants actifs :
--   0  GAMER_NAME        → nom Steam
--   2  healthArmour      → barre HP/armure native
--  11  GAMER_NAME_NEARBY → visibilité étendue
--  12  ARROW             → flèche hors champ
--  16  MP_TYPING         → icône clavier quand le joueur écrit
-- Mort : pas de composant natif → BIG_TEXT (3) affiche ☠ + texte rouge

local activeTags = {}   -- [serverId] = { handle, steamName, uniqueId, isDead, isTyping }
local isActive   = false

-- Couleurs HUD utilisables avec SetMpGamerTagColour
-- index 116 = blanc, 6 = rouge, 27 = orange, 116 = blanc
local HUD_WHITE  = 116
local HUD_RED    = 6

-- Composants toujours actifs à la création
local COMPONENTS_BASE = { 0, 2, 11, 12, 16 }

local function showComponents(handle)
    for _, id in ipairs(COMPONENTS_BASE) do
        SetMpGamerTagVisibility(handle, id, true)
    end
end

local function createTag(serverId, steamName, uniqueId)
    local player = GetPlayerFromServerId(serverId)
    if player == -1 then return nil end
    local ped = GetPlayerPed(player)
    if not DoesEntityExist(ped) then return nil end

    local handle = CreateMpGamerTag(ped, steamName, false, false, "", 255)
    if not handle or handle == 0 then return nil end

    showComponents(handle)
    SetMpGamerTagColour(handle, 0, HUD_WHITE)

    -- BIG_TEXT off par défaut (s'active uniquement si mort)
    SetMpGamerTagVisibility(handle, 3, false)

    return handle
end

-- ─── Mort ─────────────────────────────────────────────────────────────────────
-- Pas de composant natif "mort" dans la liste — on utilise BIG_TEXT (3)
-- avec le symbole ☠ et une couleur rouge
local function setDeadState(entry, dead)
    if not entry or not entry.handle or entry.handle == 0 then return end
    if entry.isDead == dead then return end  -- pas de changement inutile
    entry.isDead = dead
    if dead then
        -- Afficher ☠ en BIG_TEXT, couleur rouge
        SetMpGamerTagName(entry.handle, "~r~☠ Mort")
        SetMpGamerTagVisibility(entry.handle, 3, true)
        -- Cacher la barre HP (inutile si mort)
        SetMpGamerTagVisibility(entry.handle, 2, false)
        -- Cacher la flèche (déjà au sol)
        SetMpGamerTagVisibility(entry.handle, 12, false)
    else
        -- Remettre l'état normal
        SetMpGamerTagVisibility(entry.handle, 3, false)
        SetMpGamerTagVisibility(entry.handle, 2, true)
        SetMpGamerTagVisibility(entry.handle, 12, true)
    end
end

-- ─── Typing ───────────────────────────────────────────────────────────────────
-- Le composant 16 MP_TYPING s'active/désactive selon IsPedRunningMobilePhoneTask
-- ou via l'event natif chat. On surveille le flag natif IsPlayerFreeAiming aussi.
-- La méthode la plus fiable : surveiller NetworkIsPlayerTalking pour le micro,
-- et pour le chat on écoute l'event "chatMessage" local (déclenché avant envoi).
-- FiveM expose également IsPedUsingActionMode pour détecter la frappe.
local function setTypingState(entry, typing)
    if not entry or not entry.handle or entry.handle == 0 then return end
    if entry.isTyping == typing then return end
    entry.isTyping = typing
    -- Le composant 16 est géré nativement par GTA quand on est en chat FiveM,
    -- mais on peut aussi le forcer manuellement
    SetMpGamerTagVisibility(entry.handle, 16, typing)
end

-- ─── Suppression ──────────────────────────────────────────────────────────────
local function removeTag(serverId)
    local entry = activeTags[serverId]
    if not entry then return end
    if entry.handle and entry.handle ~= 0 then
        RemoveMpGamerTag(entry.handle)
    end
    activeTags[serverId] = nil
end

local function clearAllTags()
    for serverId in pairs(activeTags) do
        removeTag(serverId)
    end
    activeTags = {}
    isActive   = false
end

-- ─── Thread de maintenance + états dynamiques ─────────────────────────────────
-- Tourne à 500ms : met à jour mort/typing en temps réel
local function startMaintenanceThread()
    CreateThread(function()
        while isActive do
            Wait(500)
            if not isActive then break end

            for serverId, entry in pairs(activeTags) do
                local player = GetPlayerFromServerId(serverId)

                if player == -1 then
                    -- Joueur déconnecté
                    if entry.handle and entry.handle ~= 0 then
                        RemoveMpGamerTag(entry.handle)
                        entry.handle = 0
                    end
                else
                    local ped = GetPlayerPed(player)

                    -- Recréer le tag si invalide (spawn/modèle changé)
                    if not entry.handle or entry.handle == 0 then
                        if DoesEntityExist(ped) then
                            entry.handle   = createTag(serverId, entry.steamName, entry.uniqueId)
                            entry.isDead   = nil   -- force refresh des états
                            entry.isTyping = nil
                        end
                    end

                    if entry.handle and entry.handle ~= 0 and DoesEntityExist(ped) then
                        -- ── État mort ──────────────────────────────────────
                        local dead = IsEntityDead(ped)
                        setDeadState(entry, dead)

                        -- ── État typing ────────────────────────────────────
                        -- NetworkIsPlayerTalking → micro voix
                        -- IsPedRunningMobilePhoneTask → téléphone/frappe
                        -- On combine les deux pour une détection large
                        local typing = IsPedRunningMobilePhoneTask(ped)
                        setTypingState(entry, typing)
                    end
                end
            end
        end
    end)
end

-- ─── Écoute du chat local pour activer MP_TYPING ─────────────────────────────
-- Quand le joueur local ouvre le chat FiveM, on active MP_TYPING sur son
-- propre tag vu par les autres. Ici on écoute le hook côté observateur :
-- quand un autre joueur envoie un message on flash son tag brièvement.
AddEventHandler("chatMessage", function(src, author, text)
    -- Flash typing pendant 1s sur le tag de l'expéditeur
    local serverId = src
    local entry    = activeTags[serverId]
    if not entry then return end
    setTypingState(entry, true)
    SetTimeout(1000, function()
        if activeTags[serverId] then
            setTypingState(entry, false)
        end
    end)
end)

-- ─── Réception des données serveur ───────────────────────────────────────────
RegisterNetEvent("union:taginfo:receive", function(players)
    clearAllTags()
    if not players or #players == 0 then
        Logger:debug("[TAGINFO] Aucun joueur reçu")
        return
    end

    isActive = true
    local created = 0
    local myServerId = GetPlayerServerId(PlayerId())

    for _, p in ipairs(players) do
        local serverId  = p.serverId
        local steamName = p.steamName or ("Player_%d"):format(serverId)
        local uniqueId  = p.uniqueId  or "N/A"

        if serverId == myServerId then goto continue end

        local handle = createTag(serverId, steamName, uniqueId)

        activeTags[serverId] = {
            handle    = handle,
            steamName = steamName,
            uniqueId  = uniqueId,
            isDead    = false,
            isTyping  = false,
        }
        if handle then created = created + 1 end
        ::continue::
    end

    startMaintenanceThread()
    Logger:info(("[TAGINFO] %d tag(s) créé(s) sur %d joueur(s)"):format(created, #players))
end)

-- ─── Commande ─────────────────────────────────────────────────────────────────
RegisterCommand("taginfo", function(_, args)
    if args[1] == "off" then
        clearAllTags()
        Notifications.send("TagInfo désactivé", "info")
        Logger:info("[TAGINFO] Désactivé")
        return
    end
    TriggerServerEvent("union:taginfo:request")
    Notifications.send("TagInfo activé — chargement...", "info")
end, false)

-- ─── Nettoyage ────────────────────────────────────────────────────────────────
AddEventHandler("union:character:unloaded", function()
    if isActive then clearAllTags() end
end)

AddEventHandler("onResourceStop", function(r)
    if r == GetCurrentResourceName() then clearAllTags() end
end)