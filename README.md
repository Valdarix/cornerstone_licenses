# Cornerstone - Licenses

A licensing desk for Qbox servers. Players buy a license such as a weapon license from a clerk ped,
but only while few enough police are on duty.

## What it is

A clerk stands at each configured location. When police on duty are at or below a license's limit,
the clerk is there and sells it. When too many police are on duty, the clerk and the map blip
disappear. The script sets the license on the character only: the player still gets the physical
copy from a City Hall or another script.

## How it plays

1. Find the clerk (on the map as a blip if the location has one) and use the target on the ped.
2. Pick a license from the menu. Only licenses sold right now are listed, each with its price.
3. A short background check runs (about two seconds). You can cancel it.
4. The price is taken in cash and the license is added to your character. A felony on record
   (when the server checks it) or a license you already hold stops the purchase, and you are told
   why.

You must be standing at the desk when the purchase goes through.

## Commands and keybinds

| command or key | what it does |
|---|---|
| none | The script has no commands or keybinds. Use the target option on the clerk. |

## Credit

Released under the GNU General Public License v3.0 (`LICENSE.md`).

Documentation: https://cornerstonedev.gitbook.io/docs/free-scripts/offline-weapon-license-qbox

There is no support for this script. It was written for Qbox with ox_inventory and is not updated
for other frameworks or inventories. You are free to change it yourself under the licence.
