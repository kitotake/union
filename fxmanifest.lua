fx_version 'cerulean'
game 'gta5'

name "union"

description "Union Framework, a new framework for FiveM"

author "kitotake"

version "0.0.1"

lua54 'yes'

shared_scripts {
	'shared/webhooks.lua',
	'shared/client/*.lua',
	'shared/lange/*.lua',
	'shared/*.lua'
}

client_scripts {
	'client/*.lua',
	'shared/**/*.lua',
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/*.lua',
	'shared/**/*.lua'
	
}

dependencies {
    'oxmysql',
}

files {

	
}