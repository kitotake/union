-- bridge/client/k_menu.lua
-- Bridge client vers k_menu
-- Wrapper avec guard, fallback console et gestion état personnage

Bridge.Menu = Bridge.create("k_menu")
Bridge.register("k_menu", Bridge.Menu)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ÉTAT INTERNE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Bridge.Menu._openMenus = {}
Bridge.Menu._currentMenu = nil

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- FALLBACK : menu console si k_menu absent
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local function fallbackMenu(options)
    if not options or not options.items then return end

    print(("^5[MENU FALLBACK] %s^7"):format(options.title or "Menu"))
    for i, item in ipairs(options.items) do
        print(("  ^3[%d]^7 %s"):format(i, item.label or "?"))
    end
    print("^3(k_menu non disponible — utilisez la console)^7")
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- API PUBLIQUE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Ouvre un menu
-- options = {
--   id       : string (identifiant unique du menu)
--   title    : string
--   items    : { { label, description, icon, onSelect, disabled, arrow } }
--   onClose  : function
--   position : "top-left" | "top-right" | "bottom-left" | "bottom-right"
-- }
function Bridge.Menu.open(options)
    if not options then
        print("^1[BRIDGE:k_menu] open : options manquantes^7")
        return false
    end

    if not Bridge.Menu:isAvailable() then
        fallbackMenu(options)
        return false
    end

    -- Ferme le menu actuel si ouvert
    if Bridge.Menu._currentMenu then
        Bridge.Menu.close()
    end

    local ok, menuId = pcall(function()
        return exports["k_menu"]:Open(options)
    end)

    if not ok then
        print(("^1[BRIDGE:k_menu] open erreur : %s^7"):format(tostring(menuId)))
        fallbackMenu(options)
        return false
    end

    Bridge.Menu._currentMenu = options.id or menuId
    if options.id then
        Bridge.Menu._openMenus[options.id] = true
    end

    return menuId or true
end

-- Ferme le menu actuel (ou un menu spécifique)
function Bridge.Menu.close(menuId)
    if not Bridge.Menu:isAvailable() then
        Bridge.Menu._currentMenu = nil
        return true
    end

    local ok, err = pcall(function()
        if menuId then
            exports["k_menu"]:Close(menuId)
        else
            exports["k_menu"]:CloseAll()
        end
    end)

    if not ok then
        print(("^1[BRIDGE:k_menu] close erreur : %s^7"):format(tostring(err)))
        return false
    end

    if menuId then
        Bridge.Menu._openMenus[menuId] = nil
    else
        Bridge.Menu._openMenus = {}
    end

    Bridge.Menu._currentMenu = nil
    return true
end

-- Ajoute un item à un menu existant
function Bridge.Menu.addItem(menuId, item)
    if not menuId or not item then return false end

    if not Bridge.Menu:isAvailable() then return false end

    local ok, err = pcall(function()
        exports["k_menu"]:AddItem(menuId, item)
    end)

    if not ok then
        print(("^1[BRIDGE:k_menu] addItem erreur : %s^7"):format(tostring(err)))
        return false
    end

    return true
end

-- Vérifie si un menu est ouvert
function Bridge.Menu.isOpen(menuId)
    if menuId then
        return Bridge.Menu._openMenus[menuId] == true
    end
    return Bridge.Menu._currentMenu ~= nil
end

-- Menu contextuel rapide (shortcut)
-- items = { { label, icon, onSelect } }
function Bridge.Menu.context(title, items, position)
    return Bridge.Menu.open({
        title    = title,
        items    = items,
        position = position or "top-left",
    })
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- FERMETURE AUTOMATIQUE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Ferme tous les menus quand le personnage est déchargé
AddEventHandler("union:character:unloaded", function()
    if Bridge.Menu.isOpen() then
        Bridge.Menu.close()
    end
end)

-- Ferme tous les menus si k_menu s'arrête
AddEventHandler("onResourceStop", function(r)
    if r == "k_menu" then
        Bridge.Menu._openMenus   = {}
        Bridge.Menu._currentMenu = nil
    end
end)
