fx_version 'cerulean'
game 'gta5'

author 'Cornerstone Scripts'
name "Cornerstone Grant Licenses"
description 'A simple script to grant licenses to players when no cops are online'
version '1.0.2'

shared_scripts {
    '@ox_lib/init.lua',   
    '@oxmysql/lib/MySQL.lua',
}

server_scripts {
    'server/*.lua'
}

client_scripts {
    'client/*.lua',
}

escrow_ignore {
    'server/*.lua',
    'client/*.lua',
}

lua54 'yes'
use_fxv2_oal 'yes'
