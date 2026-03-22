fx_version 'cerulean'

game 'gta5'
description 'The Core resource that provides the functionalities for all other resources.'
lua54 'yes'
version '1.13.4'

shared_scripts {
	'locale.lua',

	'config/config.general.lua',
    'config/config.addonweapon.lua',
	'config/config.weapons.lua',

    'common/main.lua',
    'common/functions.lua',
    'common/modules/*.lua',
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
    'config/config.discordlog.lua',

	'server/common.lua',
	'server/services/*.lua',
	'server/modules/callback.lua',
	'server/classes/player.lua',
	'server/classes/vehicle.lua',
	'server/functions.lua',
	'server/modules/onesync.lua',
	'server/modules/paycheck.lua',

	'server/main.lua',
	'server/modules/commands.lua',
	'server/modules/createJob.lua',
	'server/migration/**/main.lua',
	'server/migration/main.lua',
}

client_scripts {
    'client/main.lua',
	'client/functions.lua',
	'client/modules/callback.lua',
	'client/modules/player_settings.lua',
	'client/modules/events.lua',
    'client/modules/discord_activity.lua',
	'client/modules/death.lua',
	'client/modules/scaleform.lua',
	'client/modules/streaming.lua',
}

files {
	'imports.lua',
	'locales/*.lua',
    "client/imports/*.lua",
}

server_export 'RegisterWeapon'

dependencies {
	'/native:0x6AE51D4B',
    '/native:0xA61C8FC6',
	'oxmysql',
	'ox_lib',
}
