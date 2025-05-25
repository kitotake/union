-- 📁 client/commands.lua

-- Commande créer personnage
RegisterCommand("createchar", function(_, args)
    local data = {
        firstname = args[1] or "Jean",
        lastname = args[2] or "Dupont", 
        dateofbirth = args[3] or "1990-01-01",
        gender = args[4] or "m"
    }
    
    print("^2[CLIENT] Création personnage: " .. data.firstname .. " " .. data.lastname)
    TriggerServerEvent("union:createCharacter", data)
end, false)

-- Commande lister personnages
RegisterCommand("listchars", function()
    TriggerServerEvent("union:listCharacters")
end, false)

-- Commande sélectionner personnage
RegisterCommand("selectchar", function(_, args)
    local id = tonumber(args[1])
    if not id or id <= 0 then
        print("^1[ERROR] Usage: /selectchar <id>")
        return
    end
    
    print("^2[CLIENT] Sélection personnage ID: " .. id)
    TriggerServerEvent("union:selectCharacter", id)
end, false)

-- Events de confirmation
RegisterNetEvent("union:characterCreated", function(success, id, uniqueID)
    if success then
        print("^2[CLIENT] ✅ Personnage créé! ID: " .. tostring(id) .. " | UID: " .. tostring(uniqueID))
    else
        print("^1[CLIENT] ❌ Échec création personnage")
    end
end)

RegisterNetEvent("union:receiveCharacterList", function(list)
    if not list or #list == 0 then
        print("^1[CLIENT] Aucun personnage trouvé")
        return
    end
    
    print("^2[CLIENT] === PERSONNAGES DISPONIBLES ===")
    for _, char in ipairs(list) do
        print(string.format("^3[ID:%s] %s %s | %s | %s", 
            char.id, char.firstname, char.lastname,
            tostring(char.dateofbirth):sub(1, 10), char.unique_id))
    end
    print("^2[CLIENT] === FIN LISTE ===")
end)

RegisterNetEvent("union:characterSelected", function(success)
    if success then
        print("^2[CLIENT] ✅ Personnage sélectionné")
    else
        print("^1[CLIENT] ❌ Échec sélection personnage")
    end
end)


RegisterCommand("giveweapon", function()
    local flatWeapons = GetFlatWeaponsList()
    local weapon = flatWeapons["pistol"]
    if weapon then
        GiveWeaponToPed(PlayerPedId(), GetHashKey(weapon.hash), weapon.ammo, false, true)
        print("Arme donnée :", weapon.label)
    else
        print("Arme non trouvée.")
    end
end, false)


RegisterCommand("givegun", function(source, args)
    local weaponId = args[1]
    if not weaponId then
        TriggerEvent("chat:addMessage", {
            color = { 255, 50, 50 },
            multiline = true,
            args = { "[ARMES]", "Usage: /givegun [id]" }
        })
        return
    end

    local weapon = flatWeapons[weaponId:lower()]
    if not weapon then
        TriggerEvent("chat:addMessage", {
            color = { 255, 50, 50 },
            multiline = true,
            args = { "[ARMES]", "Arme inconnue: " .. weaponId }
        })
        return
    end

    GiveWeaponToPed(PlayerPedId(), GetHashKey(weapon.hash), weapon.ammo, false, true)
    TriggerEvent("chat:addMessage", {
        color = { 50, 255, 50 },
        multiline = true,
        args = { "[ARMES]", "Arme donnée: " .. weapon.label }
    })
end, false)
