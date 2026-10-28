# Installing Cornerstone - Licenses

Written for server owners.

## Dependencies

Hard dependencies (the manifest lists them in `dependencies`, so the resource will not start
without them):

- [ox_lib](https://github.com/overextended/ox_lib): locale, progress bar, context menu, logger and callbacks.
- [oxmysql](https://github.com/overextended/oxmysql): read-only felony lookups.
- [ox_target](https://github.com/overextended/ox_target): the interaction on the clerk ped.
- [qbx_core](https://github.com/Qbox-project/qbx_core): police counts, the player, cash and the license metadata.

Optional, only when `SVConfig.CheckFelony = true` (the default): one of the MDT resources below,
installed with its database tables.

- `lb-tablet` (LB Tablet)
- `al_mdt`

The script calls no inventory directly. Qbox takes the cash and keeps the ox_inventory money item
in step.

## server.cfg

```cfg
ensure ox_lib
ensure oxmysql
ensure ox_target
ensure qbx_core
ensure ox_inventory
ensure lb-tablet       # or al_mdt, when CheckFelony is on
ensure cornerstone_licenses
```

## Frameworks

Qbox only (`qbx_core`). There is no setting to choose a framework, and no QBCore or ESX support:
the code calls `exports.qbx_core` for the player, duty counts and cash, and stores licenses in the
player's `licences` metadata.

## Inventories

Not applicable. The script gives and takes no items. A purchase removes cash through
`qbx_core`, which works with ox_inventory's money item.

## Configuration

Two files, both left editable by `escrow_ignore`. The location names must match between them; the
server console prints a warning at start for any that do not.

### `client/cl_config.lua` (`Config.Locations`)

Each entry of `Config.Locations` has:

| option | default | what it does |
|---|---|---|
| `name` | `'paleto_sheriff'` | unique key; must match a key in `SVConfig.AvailableLicenses` |
| `label` | `'Inquire about a license'` | text of the target option |
| `pedModel` | `'csb_cop'` | model of the clerk ped |
| `location` | `vec4(-439.01, 6017.59, 31.49, 300.56)` | ped position and heading; the script lowers Z by 1 itself |
| `icon` | `'fa-solid fa-gun'` | icon of the target option |
| `description` | `'A license to carry a firearm.'` | description of the target option |
| `useBlip` | `true` | show a map blip while the clerk is present |
| `blip.sprite` | `110` | blip sprite |
| `blip.color` | `1` | blip colour |
| `blip.scale` | `0.8` | blip scale |
| `blip.name` | `'Firearm License'` | blip name (falls back to `label`) |

### `server/sv_config.lua` (`SVConfig`)

| option | default | what it does |
|---|---|---|
| `SVConfig.CopJobType` | `'leo'` | job type that counts as police, read with `GetDutyCountType` |
| `SVConfig.CheckFelony` | `true` | refuse the license to anyone with a felony on record |
| `SVConfig.MDT` | `'lb-tablet'` | MDT to read felonies from: `al_mdt` or `lb-tablet` |
| `SVConfig.MaxDistance` | `10.0` | metres from the desk within which a purchase is accepted |
| `SVConfig.AvailableLicenses` | one `paleto_sheriff` entry | licenses sold per location (below) |

Each license under `SVConfig.AvailableLicenses[<location name>]`:

| option | default | what it does |
|---|---|---|
| `name` | `'weapon'` | license key written to the character's `licences` metadata |
| `label` | `'Weapon License'` | name shown in the menu and the success message |
| `description` | `'Allows you to purchase and carry a firearm.'` | menu text |
| `icon` | `'fa-solid fa-gun'` | menu icon |
| `cost` | `5000` | cash price; `0` makes it free |
| `cop_count` | `0` | most police that may be on duty for it to be sold; `0` means none |

Text shown to players is in `locales/en.json`. Copy it to `locales/<lang>.json` and set ox_lib's
`ox:locale` convar to translate it. Granted licenses are written to ox_lib's logger under
`license_granted`.

## Database

The script creates no tables. It only reads tables that the MDT you select creates for itself:

| `SVConfig.MDT` | tables read |
|---|---|
| `al_mdt` | `mdt_criminal_record` |
| `lb-tablet` | `lbtablet_police_cases_charges`, `lbtablet_police_offences` |

Install the MDT first. With `CheckFelony = false` the script runs no query at all.

## Troubleshooting

- **Every purchase says "Licensing is unavailable right now":** `CheckFelony` is on but the MDT
  named in `SVConfig.MDT` is not installed (its tables are missing), or `MDT` is not
  `al_mdt` or `lb-tablet`. Install the MDT, or set `SVConfig.CheckFelony = false`.
- **The clerk never appears:** the police on duty exceed every license's `cop_count`, the location
  has no entry in `SVConfig.AvailableLicenses`, or the names differ between the two config files
  (check the console at start). `SVConfig.CopJobType` must be the job type of your police jobs.
- **"You need to be at the licensing desk":** the player is further than `SVConfig.MaxDistance`
  from the location in `cl_config.lua`.
- **The clerk does not disappear when police go on duty:** the count updates a second after a duty
  change and is rechecked every minute.
