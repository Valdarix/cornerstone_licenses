Config = Config or {}

-- Please use sv_config can be used to set prices and license types
Config.Locations = {
   [1] = {        
        name = 'paleto_sheriff',
        label = 'Inquire about a license',
        pedModel = 'csb_cop',
        location = vec4(-439.01, 6017.59, 31.49, 300.56), -- You do not need to subtract 1 from the Z coord, the script handles that.        
        icon = 'fa-solid fa-gun', 
        description = 'A license to carry a firearm.',
        useBlip = true,
        blip = {
            sprite = 110,
            color = 1,
            scale = 0.8,
            name = 'Firearm License',
        },
    },
   
}