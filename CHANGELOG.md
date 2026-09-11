# Version 1.0.0
Initial Release

# Version 1.0.1
- Added support for multiple MDTs (lb-tablet, al_mdt)
- Added config option to allow for checking for felonies.
- Refactored several pieces of code to clean up stupid mistakes made in 1.0.0
- Improved ped spawn logic and reduced timer for check. 
- Added config options to setup a blip for the ped.

# Version 1.0.2
- Added better cop count detection to address client side memory leak. 
- Cleaned up duplicate blip creation. 
- Made sure blip is properly destroyed if ped despawns. 

# Version 1.1.0
- Every purchase is now checked on the server: the license must be sold at that location, the player must be at the desk, police must be below the license's limit, the license must not already be held, and the felony and cash checks run last. Nothing sent by the client is trusted.
- Fixed notifications not showing (the felony, success and "already owned" messages now appear).
- Fixed a second location crashing the script, and a location with several licenses only using the first one's police limit.
- Fixed an unsupported MDT setting freezing the purchase; it now refuses politely and warns in the console at startup.
- Players with too little cash are now told how much they need instead of nothing happening.
- Fixed being charged twice when buying the same license quickly.
- Fixed duplicate peds appearing at a location after joining.
- Peds, blips and interaction targets are removed when the resource stops or restarts.
- The menu only lists licenses that can be bought right now.
- Police count is updated when someone goes on or off duty instead of every 10 seconds, with a slow safety check every minute.
- The police job type and the purchase distance are configurable.
- Startup warns about location and license names that do not match between the two config files.
- Release workflow fixed: it now reads the version correctly and triggers on [release] in the commit message.
