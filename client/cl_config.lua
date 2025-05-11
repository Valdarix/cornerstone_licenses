Config = Config or {}
-- sv_config can be used to set prices and license types
Config.Locations = {
   [1] = {        
        name = 'paleto_sheriff',
        label = 'Inquire about a license',
        pedModel = 'csb_cop',
        location = vec4(-438.55, 6007.58, 31.95, 321.79), -- You do not need to subtract 1 from the Z coord, the script handles that.        
        icon = 'fa-solid fa-gun', 
        description = 'A license to carry a firearm.',
    },
   
}