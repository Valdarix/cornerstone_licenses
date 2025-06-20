SVConfig = {}


SVConfig.CheckFelony = true
SVConfig.MDT = 'lb-tablet' -- currently supports al_mdt, lb-tablet

SVConfig.AvailableLicenses = {
    paleto_sheriff  = {        
        {
            name = 'weapon',            
            label = 'Weapon License',
            description = 'Allows you to purchase and carry a firearm.',
            icon = 'fa-solid fa-gun', 
            cost = 5000, 
            cop_count = 0,           
        }
        -- Add more license types here.   
    }, 
  
}