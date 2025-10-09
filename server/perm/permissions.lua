-- server/perm/permissions.lua
Permissions = {}

-- Liste des groupes et leurs permissions
Permissions.Groups = {
    fondateur = { "admin.all", "admin.setgroup", "admin.healrevive", "admin.kick", "admin.ban" },
    admin = { "admin.healrevive", "admin.kick" },
    moderateur = { "admin.healrevive" },
    user = {}
}

-- Fichier JSON pour sauvegarde
Permissions.File = "permissions_data.json"

-- Joueurs avec leur groupe assigné par défaut
Permissions.Players = {
    ["license:dc4bad28419a2afc1d4df061b45b76268f9e7d2a"] = "admin" -- <-- Ici le groupe attribué
}

--Permissions.Players = {} -- [identifier] = "group"
