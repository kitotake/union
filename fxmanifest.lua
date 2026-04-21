fx_version 'cerulean'
game 'gta5'

name 'Union Framework'
author 'Union Kitotake'
version '0.0.20'
description 'Framework RP complet pour FiveM modular'

shared_scripts {
    'shared/constants.lua',
    'shared/utils.lua',
}

shared_script 'shared/config/config.lua'
shared_script 'shared/locale.lua'

client_scripts {
    'client/modules/components/logger.lua',
    'client/modules/components/position.lua',
    'client/modules/components/permissions.lua',

    'client/main.lua',

    'client/modules/spawn/main.lua',
    'client/modules/spawn/handler.lua',

    'client/modules/character/main.lua',
    'client/modules/character/create.lua',
    'client/modules/character/select.lua',

    'client/modules/ui/notification.lua',

    'client/modules/commands/character.lua',
    'client/modules/commands/admin.lua',
    'client/modules/commands/debug.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',

    'server/components/logger.lua',
    'server/components/detabase.lua',
    'server/components/utils.lua',

    'server/main.lua',

    -- Auth Module
    'server/modules/auth/connect.lua',
    'server/modules/auth/identifiers.lua',
    'server/modules/auth/webhooks.lua',
    'server/modules/auth/characters.lua',  -- ✅ AJOUT : manquait

    -- Player Module
    'server/modules/player/main.lua',
    'server/modules/player/manager.lua',
    'server/modules/player/persistence.lua',

    -- Character Module
    'server/modules/character/main.lua',
    'server/modules/character/create.lua',
    'server/modules/character/select.lua',
    'server/modules/character/appearance.lua',
    'server/modules/character/database.lua',

    -- Spawn Module
    'server/modules/spawn/main.lua',
    'server/modules/spawn/handler.lua',
    'server/modules/spawn/position.lua',

    -- Job Module
    'server/modules/job/main.lua',
    'server/modules/job/datebase.lua',

    -- Bank Module
    'server/modules/bank/main.lua',
    'server/modules/bank/database.lua',

    -- Permission Module
    'server/modules/permission/main.lua',
    'server/modules/permission/groups.lua',
    'server/modules/permission/database.lua',
}

server_exports {
    'GetPlayerFromId',
    'GetAllPlayers',
    'GetConfig',
    'GetLogger',
}

client_exports {
    'GetConfig',
    'Notify',
    'GetLogger',
}