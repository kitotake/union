fx_version 'cerulean'
game 'gta5'

name 'Union Framework'
author 'Union Kitotake'
version '3.7'
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
    -- ① Composants de base
    'client/modules/components/logger.lua',
    'client/modules/components/position.lua',
    'client/modules/components/permissions.lua',
    'client/modules/components/notifications.lua',

    -- ② Entry point
    'client/main.lua',

    -- ③ Bridges clients
    'bridge/client/kt_character.lua',
    'bridge/client/kt_hud.lua',
    'bridge/client/kt_target.lua',
    'bridge/client/kt_interact_data.lua',
    -- FIX: kt_interact_editor.lua était une copie identique de kt_interact_data.lua
    -- causant un double enregistrement. Le fichier est maintenant vide (stub).
    'bridge/client/kt_interact_editor.lua',
    'bridge/client/kt_rotation.lua',
    'bridge/client/k_menu.lua',

    -- ④ Spawn main (déclare Spawn = {}, SANS RegisterNetEvent union:spawn:apply)
    -- FIX CRITIQUE: le handler union:spawn:apply est UNIQUEMENT dans handler.lua
    'client/modules/spawn/main.lua',

    -- ⑤ Character
    'client/modules/character/main.lua',
    'client/modules/character/create.lua',
    'client/modules/character/select.lua',
    'client/modules/character/characterManager.lua',
    'client/modules/character/appearance.lua',

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

    -- ⑩ Spawn handler EN DERNIER — contient le CreateThread principal
    --    ET le seul RegisterNetEvent("union:spawn:apply")
    'client/modules/spawn/handler.lua',
}

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SERVER
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
server_scripts {
    '@oxmysql/lib/MySQL.lua',

    -- ① Composants de base
    'server/components/logger.lua',
    'server/components/database.lua',
    'server/components/utils.lua',

    -- ② Entry point
    'server/main.lua',

    -- ③ Bridges serveur
    'bridge/server/kt_inventory.lua',
    'bridge/server/statebags.lua',

    -- ④ Auth
    'server/modules/auth/connect.lua',
    'server/modules/auth/identifiers.lua',
    'server/modules/auth/webhooks.lua',
    'server/modules/auth/characters.lua',
    'server/modules/auth/whitelist.lua',

    -- ⑤ Permission
    'server/modules/permission/main.lua',
    'server/modules/permission/groups.lua',
    'server/modules/permission/database.lua',

    -- ⑥ Player
    'server/modules/player/main.lua',
    'server/modules/player/offline_ped.lua',
    'server/modules/player/manager.lua',
    'server/modules/player/persistence.lua',
    'server/modules/player/status/manager.lua',
    'server/modules/player/status/status_tick.lua',

    -- ⑦ Character
    'server/modules/character/main.lua',
    'server/modules/character/create.lua',
    'server/modules/character/select.lua',
    'server/modules/character/appearance.lua',
    'server/modules/character/database.lua',
    'server/modules/character/characterManager.lua',

    -- ⑧ Spawn
    -- FIX CRITIQUE: server/modules/spawn/main.lua contenait du code CLIENT
    -- Il est maintenant un stub serveur léger
    'server/modules/spawn/main.lua',
    'server/modules/spawn/handler.lua',
    'server/modules/spawn/position.lua',

    -- ⑨ Inventory
    'server/modules/inventory/main.lua',

    -- ⑩ Vehicle
    'server/modules/vehicle/main.lua',
    'server/modules/vehicle/database.lua',

    -- ⑪ Job
    'server/modules/job/main.lua',
    'server/modules/job/database.lua',

    -- ⑫ Bank
    'server/modules/bank/main.lua',
    'server/modules/bank/database.lua',

    -- ⑬ Commands
    'server/modules/commands/character.lua',
    'server/modules/commands/admin.lua',
    'server/modules/commands/cardlist.lua',
    'server/modules/commands/debug.lua',
    'server/modules/commands/taginfo.lua',
    'server/modules/commands/job.lua',
    'server/modules/commands/bank.lua',
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
