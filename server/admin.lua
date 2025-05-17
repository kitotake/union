-- server/admin.lua
local Admin = {}
Admin.levels = {
    user = 0,
    moderator = 1,
    admin = 2,
    superadmin = 3
}

Admin.commands = {
    ["goto"] = { level = Admin.levels.moderator, handler = function(player, target)
        -- Téléporter l'admin vers le joueur cible
    end},
    ["kick"] = { level = Admin.levels.moderator, handler = function(player, target, reason)
        -- Kick le joueur
    end},
    -- Plus de commandes...
}

function Admin.registerAdminCommand(name, handler, level)
    RegisterCommand(name, function(source, args, rawCommand)
        local player = GetPlayerFromId(source)
        if not player then return end
        
        -- Vérifier les permissions
        if player.permission < (level or Admin.levels.admin) then
            TriggerClientEvent("union:notify", source, "Permissions insuffisantes", "error")
            return
        end
        
        -- Exécuter la commande
        handler(source, args, rawCommand)
    end, false)
end

-- Initialiser les commandes admin
for cmd, data in pairs(Admin.commands) do
    Admin.registerAdminCommand(cmd, data.handler, data.level)
end