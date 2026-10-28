fx_version 'cerulean'
game 'gta5'

author 'Cornerstone Scripts'
name 'Cornerstone - Licenses'
description 'Lets players buy licenses from a desk clerk ped while few or no police are on duty.'
version '1.1.4'

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

escrow_ignore {
    'client/cl_config.lua',
    'server/sv_config.lua',
}

lua54 'yes'
use_fxv2_oal 'yes'
