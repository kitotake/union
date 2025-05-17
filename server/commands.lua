-- 📦 Commande pour créer un personnage
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

-- 📦 Liste les personnages du joueur
RegisterCommand("listchars", function()
    TriggerServerEvent("union:listCharacters")
end, false)

-- 📦 Sélectionne un personnage via son ID (entier)
RegisterCommand("selectchar", function(_, args)
    local id = tonumber(args[1])
    if not id then
        print("^1[CLIENT] Utilisation : /selectchar <id>")
        return
    end

    print("^2[CLIENT] Demande de sélection du personnage ID " .. id)
    TriggerServerEvent("union:selectCharacter", id)
end, false)

-- 🎯 Réception confirmation création
RegisterNetEvent("union:characterCreated", function(success, id, uniqueID)
    if success then
        print(("[CLIENT] ✅ Personnage créé ! ID interne: %s | UID: %s"):format(id, uniqueID))
    else
        print("[CLIENT] ❌ Échec de la création du personnage.")
    end
end)

-- 🎯 Réception de la liste
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

-- 🎯 Réception confirmation sélection
RegisterNetEvent("union:characterSelected", function(success)
    if success then
        print("^2[CLIENT] Personnage sélectionné avec succès.")
    else
        print("^1[CLIENT] Erreur lors de la sélection du personnage.")
    end
end)
