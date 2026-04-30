-- bridge/client/kt_character.lua
-- Bridge client vers kt_character
-- Remplace tous les appels directs à exports["kt_character"] dans spawn/main.lua

Bridge.Character = Bridge.create("kt_character")
Bridge.register("kt_character", Bridge.Character)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- APPARENCE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Applique l'apparence d'un personnage sur le ped local
-- Retourne true si succès, false si fallback sur modèle par défaut
function Bridge.Character.applyAppearance(charData)
    if not charData then return false end

    if not Bridge.Character:isAvailable() then
        Bridge.Character._applyFallback(charData)
        return false
    end

    local ok, err = pcall(function()
        exports["kt_character"]:ApplyPreview(charData)
    end)

    if not ok then
        print(("^1[BRIDGE:kt_character] ApplyPreview échoué : %s — fallback activé^7"):format(tostring(err)))
        Bridge.Character._applyFallback(charData)
        return false
    end

    return true
end

-- Fallback : applique juste le modèle de base selon le genre
function Bridge.Character._applyFallback(charData)
    local gender = charData and charData.gender or "m"
    local model  = gender == "f" and "mp_f_freemode_01" or "mp_m_freemode_01"

    local hash = GetHashKey(model)
    if not HasModelLoaded(hash) then
        RequestModel(hash)
        local t = GetGameTimer()
        while not HasModelLoaded(hash) do
            Wait(50)
            if GetGameTimer() - t > 5000 then
                print("^1[BRIDGE:kt_character] Timeout chargement modèle fallback^7")
                return
            end
        end
    end

    SetPlayerModel(PlayerId(), hash)
    SetModelAsNoLongerNeeded(hash)
    print("^3[BRIDGE:kt_character] Fallback appliqué — modèle: " .. model .. "^7")
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CRÉATION DE PERSONNAGE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Ouvre l'interface de création de personnage
function Bridge.Character.openCreator(data)
    if not Bridge.Character:isAvailable() then
        print("^3[BRIDGE:kt_character] openCreator ignoré — kt_character non disponible^7")
        -- Fallback : commande console pour info
        TriggerEvent("chat:addMessage", {
            args = { "^3UNION", "Interface de création indisponible — kt_character non chargé" }
        })
        return false
    end

    local ok, err = pcall(function()
        TriggerNetEvent("kt_character:openCreator", data)
    end)

    if not ok then
        print(("^1[BRIDGE:kt_character] openCreator erreur : %s^7"):format(tostring(err)))
        return false
    end

    return true
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SAUVEGARDE D'APPARENCE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Récupère les données d'apparence actuelles du ped
function Bridge.Character.getCurrentAppearance()
    if not Bridge.Character:isAvailable() then return nil end
    return Bridge.Character:call("GetCurrentAppearance")
end

-- Sauvegarde l'apparence actuelle côté serveur
function Bridge.Character.saveAppearance(uniqueId)
    if not Bridge.Character:isAvailable() then return false end

    local appearance = Bridge.Character.getCurrentAppearance()
    if not appearance then return false end

    TriggerServerEvent("union:character:saveAppearance", uniqueId, appearance)
    return true
end
