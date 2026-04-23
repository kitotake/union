fx_version 'cerulean'
game 'gta5'

name 'Union Framework'
author 'Union Kitotake'
version '0.0.25'
description 'Framework RP modular'

shared_scripts {
    '@kt_lib/init.lua',
    'shared/constants.lua',
    'shared/utils.lua',
}

shared_script 'shared/config/config.lua'
shared_script 'shared/locale.lua'
shared_script 'shared/config/webhooks.lua'

client_scripts {
    'client/modules/components/logger.lua',
    'client/modules/components/position.lua',
    'client/modules/components/permissions.lua',
    'client/modules/components/notifications.lua',

    'client/main.lua',

    'client/modules/spawn/main.lua',
    'client/modules/spawn/handler.lua',

    'client/modules/character/main.lua',
    'client/modules/character/create.lua',
    'client/modules/character/select.lua',

    -- Peds persistants hors-ligne (doit être chargé avant spawn/main.lua si possible,
    -- mais après logger.lua — l'ordre ici est correct)
    'client/modules/player/offline_ped.lua',

    'client/modules/commands/character.lua',
    'client/modules/commands/admin.lua',
    'client/modules/commands/debug.lua',
    'client/modules/commands/taginfo.lua',
    'client/modules/commands/job.lua',
    'client/modules/commands/bank.lua',
    'client/modules/commands/vehicle.lua',

    
    'client/modules/bridge/exports.lua',

}

server_scripts {
    '@oxmysql/lib/MySQL.lua',

    'server/components/logger.lua',
    'server/components/database.lua',
    'server/components/utils.lua',

    'server/main.lua',

    -- Auth Module
    'server/modules/auth/connect.lua',
    'server/modules/auth/identifiers.lua',
    'server/modules/auth/webhooks.lua',
    'server/modules/auth/characters.lua',
    'server/modules/auth/whitelist.lua',

    -- Player Module
    'server/modules/player/main.lua',
    'server/modules/player/manager.lua',
    'server/modules/player/persistence.lua',
    'server/modules/player/offline_ped.lua',   -- ← NOUVEAU

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

    -- Inventory Module
    'server/modules/inventory/main.lua',

    -- Vehicle Module
    /*'server/modules/vehicle/main.lua',
    'server/modules/vehicle/database.lua',*/

    -- Job Module
    'server/modules/job/main.lua',
    /*'server/modules/job/database.lua',*/

    -- Bank Module
    'server/modules/bank/main.lua',
    'server/modules/bank/database.lua',

    -- Permission Module
    'server/modules/permission/main.lua',
    'server/modules/permission/groups.lua',
    'server/modules/permission/database.lua',

    -- Commands
    'server/modules/commands/character.lua',
    'server/modules/commands/admin.lua',
    'server/modules/commands/debug.lua',
    'server/modules/commands/taginfo.lua',
    'server/modules/commands/job.lua',
}

dependencies {
    'kt_lib',
}

server_exports {
    'GetPlayerFromId',
    'GetAllPlayers',
    'GetConfig',
    'GetLogger',
    'AddItem',
    'RemoveItem',
    'GetItemCount',
    'CanCarryItem',
    'GiveMoney',
    'RemoveMoney',
    'GetMoney',
}

client_exports {
    'GetConfig',
    'Notify',
    'GetLogger',
}