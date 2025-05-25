fx_version 'cerulean'
game 'gta5'

name "union"

description "Union Framework, a new framework for FiveM"

author "kitotake"

version "0.0.1"

lua54 'yes'

shared_scripts {
	'shared/client/*.lua',
	'shared/lange/*.lua',
	'shared/*.lua'
}

-- 🧠 Scripts client
client_scripts {
    'client/utils.lua',
    'client/notification.lua',
    'client/position.lua',
    'client/create.lua',
    'client/spawn.lua',
    'client/commands.lua',
    'client/main.lua'
}

-- 🧠 Scripts serveur
server_scripts {
    '@oxmysql/lib/MySQL.lua', -- si tu utilises oxmysql
    'server/character_data.lua',
    'server/spawn_functions.lua',
    'server/player.lua',
    'server/events.lua',
    'server/connect.lua',
    'server/commands.lua',
    'server/admin.lua',
    'server/spawn.lua',
    'server/main.lua'
}

dependencies {
    'oxmysql',
}

files {

	
}