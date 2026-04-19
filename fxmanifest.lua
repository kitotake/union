fx_version 'cerulean'
game 'gta5'

name 'Union Framework'
author 'Union Kitotake'
version '0.0.15'
description 'Framework RP complet pour FiveM modular with an architecture'

-- ============================================
-- SHARED SCRIPTS (Available to both client & server)
-- ============================================
shared_scripts {
    'shared/config/config.lua',
    'shared/constants.lua',
    'shared/utils.lua',
    'shared/locale.lua',
}

-- ============================================
-- CLIENT SCRIPTS (LOAD ORDER IS IMPORTANT!)
-- ============================================
client_scripts {
    -- Components FIRST (Logger needed by main and other modules)
    'client/components/logger.lua',
    'client/components/position.lua',
    'client/components/permissions.lua',
    
    -- Main client entry AFTER components
    'client/main.lua',
    
    -- Modules
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

-- ============================================
-- SERVER SCRIPTS (LOAD ORDER IS IMPORTANT!)
-- ============================================
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    
    -- Components FIRST (Logger and Database needed by everything)
    'server/components/logger.lua',
    'server/components/database.lua',
    'server/components/utils.lua',
    
    -- Main server entry AFTER components
    'server/main.lua',
    
    -- Auth Module
    'server/modules/auth/connect.lua',
    'server/modules/auth/identifiers.lua',
    'server/modules/auth/webhooks.lua',
    
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
    'server/modules/job/database.lua',
    
    -- Bank Module
    'server/modules/bank/main.lua',
    'server/modules/bank/database.lua',
    
    -- Permission Module
    'server/modules/permission/main.lua',
    'server/modules/permission/groups.lua',
    'server/modules/permission/database.lua',
}

-- ============================================
-- SERVER EXPORTS (Public API)
-- ============================================
server_exports {
    'GetPlayerFromId',
    'GetAllPlayers',
    'GetConfig',
    'GetLogger',
}

-- ============================================
-- CLIENT EXPORTS (Public API)
-- ============================================
client_exports {
    'GetConfig',
    'Notify',
    'GetLogger',
}

-- ============================================
-- DEPENDENCIES
-- ============================================
-- ensure oxmysql
-- ensure ox_inventory (optional)
-- ensure ox_lib (optional)