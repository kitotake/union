fx_version 'cerulean'
game 'gta5'

name 'Union Framework'
author 'Union Kitotake'
version '0.0.10'
description 'Framework RP complet pour FiveM'

-- Configuration partagée
shared_scripts {
    'shared/config.lua',
    'shared/lange/locale.lua'
}

-- Scripts client
client_scripts {
    'shared/client/log.lua',
    'shared/client/weapons.lua',
    'client/utils.lua',
    'client/position.lua',
    'client/notification.lua',
    'client/spawn.lua',
    'client/main.lua',
    'client/commands.lua',
    'client/create.lua'
}

-- Scripts serveur
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/connect.lua',
    'server/character_data.lua',
    'server/spawn_functions.lua',
    'server/player.lua',
    'server/events.lua',
    'server/spawn.lua',
    'server/admin.lua',
    'server/commands.lua',
    'server/main.lua'
}

-- -- Interface utilisateur
-- ui_page 'web/index.html'

-- files {
--     'web/index.html',
--     'web/css/*.css',
--     'web/js/*.js',
--     'web/img/*.png',
--     'web/img/*.jpg'
-- }

-- -- Dépendances requises
-- dependencies {
--     'oxmysql',
--     'ox_inventory'
-- }

-- -- Dépendances optionnelles
-- optional_dependencies {
--     'ox_lib',   
--     'ox_target',
-- }

-- Configuration serveur
server_exports {
    'GetPlayerFromId',
    'GetAllPlayers',
    'GetConfig'
}

-- Configuration client
client_exports {
    'GetConfig',
    'notify'
}