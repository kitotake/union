-- bridge/client/k_menu.lua
Bridge.Menu = Bridge.create("k_menu")
Bridge.register("k_menu", Bridge.Menu)

Bridge.Menu._openMenus = {}
Bridge.Menu._currentMenu = nil

local function fallbackMenu(options)
    if not options or not options.items then return end
    print(("^5[MENU FALLBACK] %s^7"):format(options.title or "Menu"))
    for i, item in ipairs(options.items) do
        print(("  ^3[%d]^7 %s"):format(i, item.label or "?"))
    end
    print("^3(k_menu non disponible — utilisez la console)^7")
end

function Bridge.Menu.open(options)
    if not options then
        print("^1[BRIDGE:k_menu] open : options manquantes^7")
        return false
    end
    if not Bridge.Menu:isAvailable() then
        fallbackMenu(options)
        return false
    end
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

function Bridge.Menu.isOpen(menuId)
    if menuId then
        return Bridge.Menu._openMenus[menuId] == true
    end
    return Bridge.Menu._currentMenu ~= nil
end

function Bridge.Menu.context(title, items, position)
    return Bridge.Menu.open({
        title    = title,
        items    = items,
        position = position or "top-left",
    })
end

AddEventHandler("union:character:unloaded", function()
    if Bridge.Menu.isOpen() then
        Bridge.Menu.close()
    end
end)

AddEventHandler("onResourceStop", function(r)
    if r == "k_menu" then
        Bridge.Menu._openMenus   = {}
        Bridge.Menu._currentMenu = nil
    end
end)
