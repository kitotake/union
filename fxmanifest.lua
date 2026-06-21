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
    -- REORG: déplacé vers spawn/manager/
    'client/modules/spawn/manager/main.lua',

    -- ⑤ Character (dépend de Logger, Notifications, Spawn)
    -- REORG: create -> creation/, select -> selection/, characterManager -> manager/
    'client/modules/character/main.lua',
    'client/modules/character/creation/create.lua',
    'client/modules/character/selection/select.lua',
    'client/modules/character/manager/characterManager.lua',

    -- ⑥ Player (dépend de Logger, Client)
    -- REORG: offline_ped -> manager/
    'client/modules/player/manager/offline_ped.lua',

    -- ⑦ Apparence client (dépend de Bridge.Character, OfflinePeds, Logger)
    -- FIX: était absent du manifest — le module était silencieusement ignoré
    'client/modules/character/appearance.lua',

    -- ⑧ Vehicle (dépend de Logger, Notifications)
    -- REORG: main -> manager/
    'client/modules/vehicle/manager/main.lua',

    -- ⑨ Commands (dépendent de tout ce qui précède)
    -- REORG: tous déplacés vers commands/manager/
    'client/modules/commands/manager/character.lua',
    'client/modules/commands/manager/admin.lua',
    'client/modules/commands/manager/debug.lua',
    'client/modules/commands/manager/taginfo.lua',
    'client/modules/commands/manager/job.lua',
    'client/modules/commands/manager/bank.lua',
    'client/modules/commands/manager/vehicle.lua',

    -- ⑩ Bridge exports (dépend de Client, Logger, Notifications, StatusClient)
    -- REORG: exports -> bridge/manager/
    'client/modules/bridge/manager/exports.lua',

    -- ⑪ Spawn handler EN DERNIER
    --    Contient le CreateThread principal de connexion
    --    ET le seul RegisterNetEvent("union:spawn:apply")
    --    Dépend de tout : Spawn, Character, Bridge.Character, OfflinePeds, Position, Config
    --    REORG: handler -> spawn/manager/
    --    FIX PERF: attente kt_character réduite de 5000ms à 1500ms max + log explicite
    'client/modules/spawn/manager/handler.lua',
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
    -- REORG: whitelist -> selection/, le reste -> manager/
    'server/modules/auth/manager/connect.lua',
    'server/modules/auth/manager/identifiers.lua',
    'server/modules/auth/manager/webhooks.lua',
    'server/modules/auth/manager/characters.lua',
    'server/modules/auth/selection/whitelist.lua',

    -- ⑤ Permission (dépend de Logger, Database)
    -- FIX ordre: groups avant main car main appelle PermissionGroups
    -- REORG: groups -> manager/, main -> manager/, database -> persistence/
    'server/modules/permission/manager/groups.lua',
    'server/modules/permission/manager/main.lua',
    'server/modules/permission/persistence/database.lua',

    -- ⑥ Player (dépend de Auth, Permission, Database, Logger)
    -- FIX ordre: main (PlayerClass) AVANT manager (PlayerManager) et offline_ped
    -- REORG: main/manager/offline_ped -> manager/, persistence -> persistence/
    'server/modules/player/manager/main.lua',
    'server/modules/player/manager/offline_ped.lua',
    'server/modules/player/manager/manager.lua',
    'server/modules/player/persistence/persistence.lua',


    -- ⑦ Character (dépend de PlayerManager, Database, BankDB, ServerUtils)
    -- FIX ordre: database avant main car main appelle CharacterDB
    -- FIX ordre: select avant characterManager car characterManager appelle CharacterSelect
    -- REORG: database -> persistence/, create -> creation/, select -> selection/, characterManager -> manager/
    -- FIX PERF: appearance.lua — suppression du double chargement au spawn (SetTimeout 600ms retiré)
    'server/modules/character/persistence/database.lua',
    'server/modules/character/creation/create.lua',
    'server/modules/character/selection/select.lua',
    'server/modules/character/main.lua',
    'server/modules/character/appearance.lua',
    'server/modules/character/manager/characterManager.lua',

    -- ⑧ Spawn (dépend de PlayerManager, Character, Config)
    -- FIX CRITIQUE: main.lua est un stub serveur léger (l'ancien contenait du code client)
    -- REORG: main/handler -> manager/, position -> persistence/
    'server/modules/spawn/manager/main.lua',
    'server/modules/spawn/persistence/position.lua',
    'server/modules/spawn/manager/handler.lua',

    -- ⑨ Inventory (dépend de Bridge.Inventory)
    -- REORG: main -> manager/
    'server/modules/inventory/manager/main.lua',

    -- ⑩ Vehicle (dépend de PlayerManager, Database)
    -- REORG: main/commands -> manager/, database -> persistence/
    'server/modules/vehicle/manager/main.lua',
    'server/modules/vehicle/persistence/database.lua',

    -- ⑪ Job (dépend de PlayerManager, Database)
    -- REORG: main -> manager/, database -> persistence/
    'server/modules/job/manager/main.lua',
    'server/modules/job/persistence/database.lua',

    -- ⑫ Bank (dépend de PlayerManager, Database)
    -- FIX ordre: database avant main car main appelle BankDB
    -- REORG: database -> persistence/, main -> manager/
    'server/modules/bank/persistence/database.lua',
    'server/modules/bank/manager/main.lua',

    -- ⑬ Commands (dépendent de tout ce qui précède)
    -- REORG: tous déplacés vers commands/manager/
    'server/modules/commands/manager/character.lua',
    'server/modules/commands/manager/admin.lua',
    'server/modules/commands/manager/cardlist.lua',
    'server/modules/commands/manager/debug.lua',
    'server/modules/commands/manager/taginfo.lua',
    'server/modules/commands/manager/job.lua',
    'server/modules/commands/manager/bank.lua',
    -- FIX: permission.lua était absent du manifest — /setgroup n'existait pas en jeu
    'server/modules/commands/manager/permission.lua',
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
    
    'RequestAppearance',
    'UpdateAppearance',
    'UpgradeAppearance',
}
