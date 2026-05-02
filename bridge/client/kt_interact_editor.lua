-- bridge/client/kt_interact_editor.lua
-- Bridge client vers kt_interact_editor.
-- Délègue entièrement à kt_interact_editor (debug.lua + exports).
-- Ce bridge NE réimplémente PAS la logique d'édition — il expose
-- une interface stable pour les autres ressources Union qui veulent
-- ouvrir l'éditeur ou vérifier son état.

Bridge.InteractEditor = Bridge.create("kt_interact_editor")
Bridge.register("kt_interact_editor", Bridge.InteractEditor)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- API PUBLIQUE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

--- Ouvre l'éditeur d'interactions (mode debug) si le joueur a la permission.
--- Délègue à l'export kt_interact_editor:openEditor qui vérifie l'ACE.
function Bridge.InteractEditor.open()
    if not Bridge.InteractEditor:isAvailable() then
        print("^3[BRIDGE:kt_interact_editor] open ignoré — ressource non disponible^7")
        return false
    end

    local ok, err = pcall(function()
        exports["kt_interact_editor"]:openEditor()
    end)

    if not ok then
        print(("^1[BRIDGE:kt_interact_editor] open erreur : %s^7"):format(tostring(err)))
        return false
    end

    return true
end

--- Retourne true si le mode éditeur est actuellement actif.
---@return boolean
function Bridge.InteractEditor.isActive()
    if not Bridge.InteractEditor:isAvailable() then return false end

    local ok, result = pcall(function()
        return exports["kt_interact_editor"]:isDebugActive()
    end)

    return ok and result == true
end

--- Recharge toutes les interactions (équivalent à /reloadinteractions).
function Bridge.InteractEditor.reloadAll()
    if not Bridge.InteractEditor:isAvailable() then
        print("^3[BRIDGE:kt_interact_editor] reloadAll ignoré — ressource non disponible^7")
        return false
    end

    local ok, err = pcall(function()
        exports["kt_interact_editor"]:reloadAll()
    end)

    if not ok then
        print(("^1[BRIDGE:kt_interact_editor] reloadAll erreur : %s^7"):format(tostring(err)))
        return false
    end

    return true
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- NETTOYAGE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

AddEventHandler("onResourceStop", function(r)
    if r == "kt_interact_editor" then
        -- L'éditeur s'est arrêté : rien à nettoyer côté bridge
        -- (l'état interne est dans kt_interact_editor, pas ici)
    end
end)