-- 📁 client/commands.lua

-- 🧍 Commande : Créer un personnage (exemple de base)
RegisterCommand("createchar", function()
    local data = {
        firstname = "Jean",
        lastname = "Dupont",
        dateofbirth = "1990-01-01",
        gender = "M"
    }

    print("^2[CLIENT] Envoi des données pour créer un personnage...")
    TriggerServerEvent("union:createCharacter", data)
end, false)

-- 📋 Commande : Lister tous les personnages du joueur
RegisterCommand("listchars", function()
    TriggerServerEvent("union:listCharacters")
end, false)

-- ✅ Commande : Sélectionner un personnage par ID
RegisterCommand("selectchar", function(_, args)
    local id = tonumber(args[1])
    if not id or id <= 0 then
        TriggerEvent("chat:addMessage", {
            color = { 255, 50, 50 },
            multiline = true,
            args = { "[ERROR]", "Utilisation : /selectchar <id> - L'ID doit être un nombre positif" }
        })
        return
    end

    print("^2[CLIENT] Demande de sélection du personnage ID : " .. id)
    TriggerServerEvent("union:selectCharacter", id)
end, false)

-- 🔔 Confirmation de création de personnage
RegisterNetEvent("union:characterCreated", function(success, id, uniqueID)
    if success then
        print(("[CLIENT] ✅ Personnage créé avec succès ! ID: %s | UID: %s"):format(id, uniqueID))
    else
        print("[CLIENT] ❌ Échec de la création du personnage.")
    end
end)

-- 📥 Liste reçue depuis le serveur
RegisterNetEvent("union:receiveCharacterList", function(list)
    if not list or #list == 0 then
        print("^1[CLIENT] Aucun personnage trouvé.")
        return
    end

    print("^2[CLIENT] Personnages disponibles :")
    for _, char in ipairs(list) do
        print(("[ID:%s] %s %s | %s | %s"):format(
            char.id,
            char.firstname,
            char.lastname,
            tostring(char.dateofbirth):sub(1, 10),
            char.unique_id
        ))
    end
end)

-- ✅ Confirmation de sélection
RegisterNetEvent("union:characterSelected", function(success)
    if success then
        print("^2[CLIENT] Personnage sélectionné avec succès.")
    else
        print("^1[CLIENT] Échec de la sélection du personnage.")
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
