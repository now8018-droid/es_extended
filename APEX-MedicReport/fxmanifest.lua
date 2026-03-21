fx_version 'adamant'

game 'gta5'
description 'MedicReport' 
author 'Nakins'
version '1.0'
lua54 'yes'

client_script {
  'config.lua',
  'client.lua',
}

server_script {
  '@oxmysql/lib/MySQL.lua',
	'config.lua',
	'server.lua'
}

ui_page "html/index.html"
files {
    'html/index.html',
    'html/script.js',
    'html/style.css',
    'html/img/*.png',
    'html/sounds/*.*',
    'html/*.ttf'
}

export 'SendAlert'
export 'ToggleTablet'