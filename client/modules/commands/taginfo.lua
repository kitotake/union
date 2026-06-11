-- client/modules/commands/taginfo.lua
-- Utilise le système natif MP_GAMER_TAG (CreateMpGamerTag / SetMpGamerTagVisibility)
-- au lieu de DrawText3D manuel

local activeTags  = {}  -- [serverId] = { tagHandle, steamName, uniqueId }
local isActive    = false

-- ─── Composants gamer tag utilisés ───────────────────────────────────────────
-- 0  GAMER_NAME       → nom Steam
-- 2  healthArmour     → barre HP/armure native
-- 11 GAMER_NAME_NEARBY → visible à plus grande distance
-- 12 ARROW            → flèche de repérage

local COMPONENTS_ON = { 0, 2, 11, 12 }

local function showComponents(handle, visible)
    for _, id in ipairs(COMPONENTS_ON) do
        SetMpGamerTagVisibility(handle, id, visible)
    end
end

local function createTag(serverId, steamName, uniqueId)
    -- Récupérer le ped local du joueur distant
    local player = GetPlayerFromServerId(serverId)
    if player == -1 then return nil end
    local ped = GetPlayerPed(player)
    if not DoesEntityExist(ped) then return nil end

    -- Créer le gamer tag natif
    -- CreateMpGamerTag(ped, name, isRockstarCrew, isFriend, crewTag, alphaMult)
    local handle = CreateMpGamerTag(ped, steamName, false, false, "", 255)
    if not handle or handle == 0 then return nil end

    -- Afficher les composants voulus
    showComponents(handle, true)

    -- Personnaliser la couleur du nom (blanc)
    SetMpGamerTagColour(handle, 0, 116)  -- 116 = blanc HUD

    -- Afficher l'UID en BIG_TEXT (composant 3)
    SetMpGamerTagName(handle, ("ID:%d | %s"):format(serverId, uniqueId or "?"))
    SetMpGamerTagVisibility(handle, 3, false)  -- BIG_TEXT off par défaut

    return handle
end

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

-- ─── Thread de maintenance ────────────────────────────────────────────────────
-- Recrée les tags si un joueur était absent au moment de la réception
-- et supprime les tags de joueurs qui ont quitté
local function startMaintenanceThread()
    CreateThread(function()
        while isActive do
            Wait(2000)
            if not isActive then break end

            for serverId, entry in pairs(activeTags) do
                local player = GetPlayerFromServerId(serverId)

                if player == -1 then
                    -- Joueur parti : nettoyer le tag
                    if entry.handle and entry.handle ~= 0 then
                        RemoveMpGamerTag(entry.handle)
                        entry.handle = 0
                    end
                else
                    local ped = GetPlayerPed(player)
                    -- Tag invalide ou ped changé : recréer
                    if not entry.handle or entry.handle == 0 or not DoesEntityExist(ped) then
                        if entry.handle and entry.handle ~= 0 then
                            RemoveMpGamerTag(entry.handle)
                        end
                        if DoesEntityExist(ped) then
                            entry.handle = createTag(serverId, entry.steamName, entry.uniqueId)
                        end
                    end
                end
            end
        end
    end)
end

-- ─── Réception des données serveur ───────────────────────────────────────────
RegisterNetEvent("union:taginfo:receive", function(players)
    clearAllTags()
    if not players or #players == 0 then
        Logger:debug("[TAGINFO] Aucun joueur reçu")
        return
    end

    isActive = true
    local created = 0

    for _, p in ipairs(players) do
        local serverId  = p.serverId
        local steamName = p.steamName or ("Player_%d"):format(serverId)
        local uniqueId  = p.uniqueId  or "N/A"

        -- Ne pas créer un tag sur soi-même
        if serverId == GetPlayerServerId(PlayerId()) then goto continue end

        local handle = createTag(serverId, steamName, uniqueId)

        activeTags[serverId] = {
            handle    = handle,
            steamName = steamName,
            uniqueId  = uniqueId,
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
        Logger:info("[TAGINFO] Désactivé manuellement")
        return
    end
    TriggerServerEvent("union:taginfo:request")
    Notifications.send("TagInfo activé — chargement...", "info")
end, false)

-- ─── Nettoyage automatique ────────────────────────────────────────────────────
AddEventHandler("union:character:unloaded", function()
    if isActive then
        clearAllTags()
        Logger:debug("[TAGINFO] Nettoyé (character unloaded)")
    end
end)

-- Nettoyer aussi si la resource redémarre
AddEventHandler("onResourceStop", function(r)
    if r == GetCurrentResourceName() then
        clearAllTags()
    end
end)