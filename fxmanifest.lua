fx_version 'cerulean'
game 'gta5'

name 'Union Framework'
author 'Union Kitotake'
version '3.5'
description 'Framework RP modulaire — Bridge System'

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SHARED
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
shared_scripts {
    '@kt_lib/init.lua',
    'shared/constants.lua',
    'shared/utils.lua',

    -- ① Bridge base — DOIT être chargé en premier
    'shared/bridge/bridge_base.lua',
}

shared_script 'shared/config/config.lua'
shared_script 'shared/config/status_config.lua'
shared_script 'shared/locale.lua'
shared_script 'shared/config/webhooks.lua'

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CLIENT
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
client_scripts {
    -- ① Composants de base
    'client/modules/components/logger.lua',
    'client/modules/components/position.lua',
    'client/modules/components/permissions.lua',
    'client/modules/components/notifications.lua',

    -- ② Entry point (déclare Client = {})
    'client/main.lua',

    -- ③ Bridges clients (chargés AVANT les modules qui les utilisent)
    'bridge/client/kt_character.lua',
    'bridge/client/kt_hud.lua',
    'bridge/client/kt_target.lua',
    'bridge/client/kt_interact.lua',
    'bridge/client/kt_rotation.lua',
    'bridge/client/k_menu.lua',

    -- ④ Spawn (utilise Bridge.Character)
    'client/modules/spawn/main.lua',
    'client/modules/spawn/handler.lua',

    -- ⑤ Character
    'client/modules/character/main.lua',
    'client/modules/character/create.lua',
    'client/modules/character/select.lua',
    'client/modules/character/characterManager.lua',

    -- ⑥ Player
     'client/modules/player/status/status_client.lua',
    'client/modules/player/offline_ped.lua',

    -- ⑦ Vehicle
    'client/modules/vehicle/main.lua',

    -- ⑧ Commands
    'client/modules/commands/character.lua',
    'client/modules/commands/admin.lua',
    'client/modules/commands/debug.lua',
    'client/modules/commands/taginfo.lua',
    'client/modules/commands/job.lua',
    'client/modules/commands/bank.lua',
    'client/modules/commands/vehicle.lua',

    -- ⑨ Bridge exports
    'client/modules/bridge/exports.lua',
}

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SERVER
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
server_scripts {
    '@oxmysql/lib/MySQL.lua',

    -- ① Composants de base
    'server/components/logger.lua',
    'server/components/database.lua',
    'server/components/utils.lua',

    -- ② Entry point
    'server/main.lua',

    -- ③ Bridges serveur (chargés AVANT les modules qui les utilisent)
    'bridge/server/kt_inventory.lua',
    'bridge/server/statebags.lua',

    -- ④ Auth
    'server/modules/auth/connect.lua',
    'server/modules/auth/identifiers.lua',
    'server/modules/auth/webhooks.lua',
    'server/modules/auth/characters.lua',
    'server/modules/auth/whitelist.lua',

    -- ⑤ Player
    'server/modules/player/main.lua',
    'server/modules/player/manager.lua',
    'server/modules/player/persistence.lua',
    'server/modules/player/offline_ped.lua',
    'server/modules/player/status/manager.lua',
    'server/modules/player/status/status_tick.lua',

    -- ⑥ Character
    'server/modules/character/main.lua',
    'server/modules/character/create.lua',
    'server/modules/character/select.lua',
    'server/modules/character/appearance.lua',
    'server/modules/character/database.lua',
    'server/modules/character/characterManager.lua',

    -- ⑦ Spawn
    'server/modules/spawn/main.lua',
    'server/modules/spawn/handler.lua',
    'server/modules/spawn/position.lua',

    -- ⑧ Inventory (proxy vers Bridge.Inventory)
    'server/modules/inventory/main.lua',

    -- ⑨ Vehicle
    'server/modules/vehicle/main.lua',
    'server/modules/vehicle/database.lua',

    -- ⑩ Job
    'server/modules/job/main.lua',
    'server/modules/job/database.lua',

    -- ⑪ Bank
    'server/modules/bank/main.lua',
    'server/modules/bank/database.lua',

    -- ⑫ Permission
    'server/modules/permission/main.lua',
    'server/modules/permission/groups.lua',
    'server/modules/permission/database.lua',

    -- ⑬ Commands
    'server/modules/commands/character.lua',
    'server/modules/commands/admin.lua',
    'server/modules/commands/debug.lua',
    'server/modules/commands/taginfo.lua',
    'server/modules/commands/job.lua',
    'server/modules/commands/bank.lua',
}

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- DÉPENDANCES
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
dependencies {
    'oxmysql',
    -- Modules optionnels : Union reste fonctionnel sans eux
    -- 'kt_character',
    -- 'kt_inventory',
    -- 'kt_hud',
    -- 'kt_target',
    -- 'kt_interact',
    -- 'kt_rotation',
    -- 'k_menu',
}

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- EXPORTS SERVER
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
server_exports {
    -- Player
    'GetPlayerFromId',
    'GetAllPlayers',
    'GetConfig',
    'GetLogger',

    -- Inventory (via Bridge)
    'AddItem',
    'RemoveItem',
    'GetItemCount',
    'CanCarryItem',
    'GiveMoney',
    'RemoveMoney',
    'GetMoney',

    -- StateBags
    'GetCharacterState',
    'GetJobState',
    'GetUniqueIdState',

    -- Status 
    'SetPlayerStat',
    'AddPlayerStat',
}

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- EXPORTS CLIENT
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
client_exports {
    'GetConfig',
    'Notify',
    'GetLogger',
    'GetActiveCharacter',
    'GetActiveJob',
    'GetStatus',
    'SetStat',
    'AddStat',
}
