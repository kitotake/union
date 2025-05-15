fx_version 'cerulean'
game 'gta5'

name "union"

description "Union Framework, a new framework for FiveM"

author "kitotake"

version "0.0.1"

lua54 'yes'

shared_scripts {
	'shared/*.lua'
}

client_scripts {
	'client/*.lua'
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/*.lua'
	
}

dependencies {
    'oxmysql',
}

files {

	
}