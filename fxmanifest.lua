fx_version 'cerulean'
game 'gta5'

name 'Union Framework'
author 'Union Kitotake'
version '3.8'
description 'Framework RP modulaire — Bridge System (Fixed)'

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SHARED
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
shared_scripts {
    '@kt_lib/init.lua',
    'shared/constants.lua',
    'shared/utils.lua',
    'shared/bridge/bridge_base.lua',
}

shared_script 'shared/config/config.lua'
shared_script 'shared/config/status_config.lua'
shared_script 'shared/locale.lua'
shared_script 'shared/config/webhooks.lua'

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CLIENT
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
client_scripts {
    -- ① Composants de base (pas de dépendances)
    'client/modules/components/logger.lua',
    'client/modules/components/notifications.lua',
    'client/modules/components/permissions.lua',
    'client/modules/components/position.lua',

    -- ② Entry point (dépend de Logger, Notifications)
    'client/main.lua',

    -- ③ Bridges clients (dépendent de Bridge, Logger)
    'bridge/client/kt_character.lua',
    'bridge/client/kt_hud.lua',
    'bridge/client/kt_target.lua',
    'bridge/client/kt_interact_data.lua',
    -- FIX: stub vide — kt_interact_editor était un doublon de kt_interact_data
    'bridge/client/kt_interact_editor.lua',
    'bridge/client/kt_rotation.lua',
    'bridge/client/k_menu.lua',

    -- ④ Spawn main (déclare Spawn = {} uniquement, sans handler)
    -- FIX CRITIQUE: union:spawn:apply est UNIQUEMENT dans handler.lua
    'client/modules/spawn/main.lua',

    -- ⑤ Character (dépend de Logger, Notifications, Spawn)
    'client/modules/character/main.lua',
    'client/modules/character/create.lua',
    'client/modules/character/select.lua',
    'client/modules/character/characterManager.lua',

    -- ⑥ Player (dépend de Logger, Client)
    'client/modules/player/status/status_client.lua',
    'client/modules/player/offline_ped.lua',

    -- ⑦ Apparence client (dépend de Bridge.Character, OfflinePeds, Logger)
    -- FIX: était absent du manifest — le module était silencieusement ignoré
    'client/modules/character/appearance.lua',

    -- ⑧ Vehicle (dépend de Logger, Notifications)
    'client/modules/vehicle/main.lua',

    -- ⑨ Commands (dépendent de tout ce qui précède)
    'client/modules/commands/character.lua',
    'client/modules/commands/admin.lua',
    'client/modules/commands/debug.lua',
    'client/modules/commands/taginfo.lua',
    'client/modules/commands/job.lua',
    'client/modules/commands/bank.lua',
    'client/modules/commands/vehicle.lua',

    -- ⑩ Bridge exports (dépend de Client, Logger, Notifications, StatusClient)
    'client/modules/bridge/exports.lua',

    -- ⑪ Spawn handler EN DERNIER
    --    Contient le CreateThread principal de connexion
    --    ET le seul RegisterNetEvent("union:spawn:apply")
    --    Dépend de tout : Spawn, Character, Bridge.Character, OfflinePeds, Position, Config
    'client/modules/spawn/handler.lua',
}

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SERVER
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
server_scripts {
    '@oxmysql/lib/MySQL.lua',

    -- ① Composants de base (pas de dépendances)
    'server/components/logger.lua',
    'server/components/database.lua',
    'server/components/utils.lua',

    -- ② Entry point (dépend de Logger)
    'server/main.lua',

    -- ③ Bridges serveur (dépendent de Bridge, Logger)
    'bridge/server/kt_inventory.lua',
    'bridge/server/statebags.lua',

    -- ④ Auth (dépend de Database, ServerUtils, Logger)
    'server/modules/auth/connect.lua',
    'server/modules/auth/identifiers.lua',
    'server/modules/auth/webhooks.lua',
    'server/modules/auth/characters.lua',
    'server/modules/auth/whitelist.lua',

    -- ⑤ Permission (dépend de Logger, Database)
    -- FIX ordre: groups avant main car main appelle PermissionGroups
    'server/modules/permission/groups.lua',
    'server/modules/permission/main.lua',
    'server/modules/permission/database.lua',

    -- ⑥ Player (dépend de Auth, Permission, Database, Logger)
    -- FIX ordre: main (PlayerClass) AVANT manager (PlayerManager) et offline_ped
    'server/modules/player/main.lua',
    'server/modules/player/offline_ped.lua',
    'server/modules/player/manager.lua',
    'server/modules/player/persistence.lua',
    'server/modules/player/status/manager.lua',
    'server/modules/player/status/status_tick.lua',

    -- ⑦ Character (dépend de PlayerManager, Database, BankDB, ServerUtils)
    -- FIX ordre: database avant main car main appelle CharacterDB
    -- FIX ordre: select avant characterManager car characterManager appelle CharacterSelect
    'server/modules/character/database.lua',
    'server/modules/character/create.lua',
    'server/modules/character/select.lua',
    'server/modules/character/main.lua',
    'server/modules/character/appearance.lua',
    'server/modules/character/characterManager.lua',

    -- ⑧ Spawn (dépend de PlayerManager, Character, Config)
    -- FIX CRITIQUE: main.lua est un stub serveur léger (l'ancien contenait du code client)
    'server/modules/spawn/main.lua',
    'server/modules/spawn/position.lua',
    'server/modules/spawn/handler.lua',

    -- ⑨ Inventory (dépend de Bridge.Inventory)
    'server/modules/inventory/main.lua',

    -- ⑩ Vehicle (dépend de PlayerManager, Database)
    'server/modules/vehicle/main.lua',
    'server/modules/vehicle/database.lua',

    -- ⑪ Job (dépend de PlayerManager, Database)
    'server/modules/job/main.lua',
    'server/modules/job/database.lua',

    -- ⑫ Bank (dépend de PlayerManager, Database)
    -- FIX ordre: database avant main car main appelle BankDB
    'server/modules/bank/database.lua',
    'server/modules/bank/main.lua',

    -- ⑬ Commands (dépendent de tout ce qui précède)
    'server/modules/commands/character.lua',
    'server/modules/commands/admin.lua',
    'server/modules/commands/cardlist.lua',
    'server/modules/commands/debug.lua',
    'server/modules/commands/taginfo.lua',
    'server/modules/commands/job.lua',
    'server/modules/commands/bank.lua',
    -- FIX: permission.lua était absent du manifest — /setgroup n'existait pas en jeu
    'server/modules/commands/permission.lua',
}

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- DÉPENDANCES
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
dependencies {
    'oxmysql',
}

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- EXPORTS SERVER
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
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
    'GetCharacterState',
    'GetJobState',
    'GetUniqueIdState',
    'GetPlayerStatus',
    'SetPlayerStat',
    'AddPlayerStat',
    'SetStat',
    'AddStat',
    'GetPlayerAppearance',
    'SetPlayerAppearance',
    'UpgradePlayerAppearance',
    'ReloadPlayerAppearance',
    'GiveCharacter',
}

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- EXPORTS CLIENT
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
client_exports {
    'GetConfig',
    'Notify',
    'GetLogger',
    'GetCurrentCharacter',
    'IsSpawned',
    'GetActiveCharacter',
    'GetActiveJob',
    'GetStatus',
    'SetStat',
    'AddStat',
    'AddPlayerStat',
    'RequestAppearance',
    'UpdateAppearance',
    'UpgradeAppearance',
}