# Issues: Cornerstone - Licenses

Known bugs and deviations from the Cornerstone standard and the FiveM Dev Tool house rules.
First-pass review, 2026-10-28.

## Bugs

- **The default config can block every purchase.** `server/sv_config.lua:7-8` ship
  `CheckFelony = true` and `MDT = 'lb-tablet'`. On a server without LB Tablet the lookup at
  `server/server.lua:108` fails on the missing table, `pcall` at `server/server.lua:205` catches it
  and the player is told to contact an admin on every purchase. Fix: ship `CheckFelony = false`, or
  check at start that the MDT's tables exist and warn.
- **The money is taken before the license is set, and the set is not checked.**
  `server/server.lua:180` removes cash, `server/server.lua:186` calls `SetMetaData` and the result is
  ignored, so a failed write costs the player the price and gives no license. Fix: check the
  `SetMetaData` result and refund on failure.
- **A clerk can reappear after it was removed.** `spawn` (`client/client.lua:129`) reserves
  `peds[i] = true` and then yields while the model loads. If `despawn` (`client/client.lua:110`) runs
  in that window it clears the slot, and `spawn` still creates the ped and sets `peds[i] = ped` at
  `client/client.lua:150`, so a clerk stands there while police are on duty. Fix: after the model
  loads, re-check that `peds[i] == true` and that the location can still sell.
- **`cornerstone_licenses:server:hasLicense` has no caller in the resource.**
  `server/server.lua:132` registers it and nothing calls it. Remove it or document it as an API.

## Deviations from the standard

- **`config-not-escrow-ignored` (2, fixed):** `fxmanifest.lua:14` (`client/cl_config.lua`) and
  `fxmanifest.lua:18` (`server/sv_config.lua`) were not covered; `escrow_ignore` now lists both.
- **`sql-table-not-created` (1, `server/server.lua:104`):** an info rule. The queries read tables
  that `al_mdt` and `lb-tablet` own, so this resource must not create them. Nothing to fix.
- **Config layout:** config is split into `client/cl_config.lua` and `server/sv_config.lua`, and
  `SVConfig` is a global. The house rules use `config/shared.lua`, `config/client.lua` and
  `config/server.lua`. `Config.Locations` reaches the server through `shared_scripts`
  (`fxmanifest.lua:14`).
- **QBCore event names:** the script listens to `QBCore:Server:SetDuty`, `OnJobUpdate`,
  `PlayerLoaded` and `OnPlayerUnload` (`server/server.lua:73,74,76,77`) and
  `QBCore:Client:OnPlayerLoaded` (`client/client.lua:214`). These are compatibility events that
  Qbox may drop. Fix: use the `qbx_core:*` events only.
- **`playerDropped` is handled twice:** it is in the event list (`server/server.lua:79`) and has its
  own handler at `server/server.lua:84`. Harmless; merge them.

## Security

The `inquire` callback (`server/server.lua:194`) re-derives everything on the server: the location
and license come from config, the distance from the server's coordinates for `source`, the police
count from Qbox, the license from the player's own metadata, and the price from config. It has a
per-player lock and a 2-second cooldown. No client value reaches money, items or SQL, and every
query is parameterised.

- **No rate limit on the read callbacks.** `server/server.lua:119` (`getLicenseTypes`) and
  `server/server.lua:123` (`getCopCount`) can be called at any rate by any client. They return only
  config text and a number, so the cost is low. Fix: add a short cooldown if a server sees abuse.
- **The `al_mdt` felony search is a `LIKE '%Felony%'` on free text** (`server/server.lua:105`). A
  record whose text contains the word counts as a felony. This is an accuracy issue, not an
  injection risk (the value is a literal, not client input). Fix: match a charge class if `al_mdt`
  stores one.
