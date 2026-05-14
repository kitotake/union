-- client/modules/character/appearance.lua
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Gère les events d'apparence côté client :
--
--  union:player:apparenceUpgrade:apply  → applique un changement PARTIEL sur
--                                         le ped actuel sans toucher au reste.
--
-- union:player:apparence et union:player:UpdateApparence utilisent
-- kt_appearance:apply (géré par kt_character/client/appearance.lua).
-- Ce fichier ne duplique pas ce handler.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ClientAppearance        = {}
ClientAppearance.logger = Logger:child("CLIENT:APPEARANCE")

-- ─── Helpers ──────────────────────────────────────────────────────────────

local VALID_COMPONENTS = { 1, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
local VALID_PROPS      = { 0, 1, 2, 6, 7 }

local OVERLAY_COLOR_TYPES = {
    [0]=0,[1]=1,[2]=1,[3]=0,[4]=2,[5]=2,
    [6]=0,[7]=0,[8]=2,[9]=0,[10]=1,[11]=0,[12]=0,
}

local function applyHair(ped, hair)
    if not hair then return end
    local style     = hair.style     or hair.hair or 0
    local color     = hair.color     or 0
    local highlight = hair.highlight or 0
    SetPedComponentVariation(ped, 2, style, 0, 0)
    SetPedHairColor(ped, color, highlight)
end

local function applyHeadBlend(ped, hb)
    if not hb then return end
    SetPedHeadBlendData(
        ped,
        hb.shapeFirst  or 0, hb.shapeSecond or 0, 0,
        hb.skinFirst   or 0, hb.skinSecond  or 0, 0,
        hb.shapeMix    or 0.5, hb.skinMix   or 0.5, 0.0,
        false
    )
end

local function applyHeadOverlays(ped, overlays)
    if not overlays then return end
    for i = 0, 12 do
        local overlay = overlays[tostring(i)] or overlays[i]
        if overlay then
            SetPedHeadOverlay(ped, i, overlay.index or 0, overlay.opacity or 1.0)
            local ct = OVERLAY_COLOR_TYPES[i] or 0
            if ct > 0 and (overlay.index or 0) > 0 then
                SetPedHeadOverlayColor(ped, i, ct, overlay.firstColor or 0, overlay.secondColor or 0)
            end
        end
    end
end

local function applyFaceFeatures(ped, ff)
    if not ff then return end
    for i = 0, 19 do
        local val = ff[i + 1] or ff[tostring(i)]
        if val ~= nil then
            SetPedFaceFeature(ped, i, math.max(-1.0, math.min(1.0, tonumber(val) or 0.0)))
        end
    end
end

local function applyComponents(ped, components)
    if not components then return end
    for _, id in ipairs(VALID_COMPONENTS) do
        local comp = components[tostring(id)] or components[id]
        if comp then
            SetPedComponentVariation(ped, id, comp.drawable or 0, comp.texture or 0, comp.palette or 0)
        end
    end
end

local function applyProps(ped, props)
    if not props then return end
    for _, anchor in ipairs(VALID_PROPS) do
        local prop = props[tostring(anchor)] or props[anchor]
        if prop then
            if prop.propIndex and prop.propIndex >= 0 then
                SetPedPropIndex(ped, anchor, prop.propIndex, prop.propTextureIndex or 0, true)
            else
                ClearPedProp(ped, anchor)
            end
        end
    end
end

local function applyTattoos(ped, tattoos, clearFirst)
    if clearFirst then ClearPedDecorations(ped) end
    if not tattoos or #tattoos == 0 then return end
    for _, tattoo in ipairs(tattoos) do
        if tattoo.collection and tattoo.overlay then
            AddPedDecorationFromHashes(ped, GetHashKey(tattoo.collection), GetHashKey(tattoo.overlay))
        end
    end
end

-- ─── Changement de modèle (ped_model) ─────────────────────────────────────

local function applyPedModel(model, callback)
    local pedModel = model
    if pedModel ~= "mp_m_freemode_01" and pedModel ~= "mp_f_freemode_01" then
        pedModel = "mp_m_freemode_01"
    end

    local hash = GetHashKey(pedModel)
    if GetEntityModel(PlayerPedId()) == hash then
        if callback then callback(PlayerPedId()) end
        return
    end

    RequestModel(hash)
    local t = GetGameTimer()
    CreateThread(function()
        while not HasModelLoaded(hash) do
            Wait(50)
            if GetGameTimer() - t > 5000 then
                ClientAppearance.logger:warn("Timeout chargement modèle " .. pedModel)
                if callback then callback(PlayerPedId()) end
                return
            end
        end
        SetPlayerModel(PlayerId(), hash)
        SetModelAsNoLongerNeeded(hash)
        Wait(0)
        if callback then callback(PlayerPedId()) end
    end)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- EVENT : union:player:apparenceUpgrade:apply
-- Applique seulement les champs reçus sur le ped actuel.
-- Aucun champ absent n'est réinitialisé.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RegisterNetEvent("union:player:apparenceUpgrade:apply", function(partial)
    if not partial then return end

    local fields = {}
    for k in pairs(partial) do table.insert(fields, k) end
    ClientAppearance.logger:info("apparenceUpgrade:apply → [" .. table.concat(fields, ", ") .. "]")

    Citizen.CreateThread(function()
        -- Si changement de modèle, on l'applique d'abord
        if partial.ped_model then
            applyPedModel(partial.ped_model, function(ped)
                ClientAppearance._applyPartialFields(ped, partial)
            end)
        else
            local ped = PlayerPedId()
            ClientAppearance._applyPartialFields(ped, partial)
        end
    end)
end)

function ClientAppearance._applyPartialFields(ped, partial)
    if not ped or ped == 0 then return end

    if partial.hair         then applyHair(ped, partial.hair)                         end
    if partial.headBlend    then applyHeadBlend(ped, partial.headBlend)               end
    if partial.headOverlays then applyHeadOverlays(ped, partial.headOverlays)         end
    if partial.faceFeatures then applyFaceFeatures(ped, partial.faceFeatures)         end
    if partial.components   then applyComponents(ped, partial.components)             end
    if partial.props        then applyProps(ped, partial.props)                       end
    if partial.tattoos      then applyTattoos(ped, partial.tattoos, true)             end

    ClientAppearance.logger:info("apparenceUpgrade appliqué sur le ped")
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- EXPORTS CLIENT
-- Utilisables depuis d'autres ressources clientes
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Demande au serveur de charger et appliquer l'apparence depuis la BDD
exports("RequestAppearance", function()
    TriggerServerEvent("union:player:apparence")
end)

-- Envoie un update complet d'apparence au serveur
exports("UpdateAppearance", function(data)
    TriggerServerEvent("union:player:UpdateApparence", data)
end)

-- Envoie un upgrade partiel au serveur
exports("UpgradeAppearance", function(partial)
    TriggerServerEvent("union:player:apparenceUpgrade", partial)
end)

return ClientAppearance
