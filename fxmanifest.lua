fx_version 'cerulean'
game 'gta5'

author 'Cornerstone Scripts'
name "Cornerstone Grant Licenses"
description 'A simple script to grant licenses to players when no cops are online'
version '1.1.2'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    '@oxmysql/lib/MySQL.lua',
    'client/cl_config.lua', -- locations are shared so the server can check where a buyer is standing
}

server_scripts {
    'server/sv_config.lua',
    'server/server.lua',
}

client_scripts {
    'client/client.lua',
}

files {
    'locales/*.json',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'ox_target',
    'qbx_core',
}

lua54 'yes'
use_fxv2_oal 'yes'
