SVConfig = {}

-- Job type counted as police. qbx_core reports on-duty players per job type.
SVConfig.CopJobType = 'leo'

-- Deny a license to anyone with a felony on record. Requires a supported MDT below.
SVConfig.CheckFelony = true
SVConfig.MDT = 'lb-tablet' -- currently supports al_mdt, lb-tablet

-- How close (metres) a player must be to the location's ped to purchase there.
SVConfig.MaxDistance = 10.0

-- Licenses sold at each location. The key must match a location name in
-- client/cl_config.lua. cop_count is the most police that may be on duty for
-- the license to be available; 0 means only when no police are online.
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
