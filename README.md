# Cornerstone: Licenses

## Description
A simple script to setup grant license for Qbox when no police are online. This script will only grant the player a license, they will still need to purchase the hard copy at a City Hall or some other script.

## Features
- Provide players a weapon license while no police are on line
- Optionally check if the player is a felon and deny the license if they are (al_mdt or lb-tablet)
- Set the maximum police on duty per license; the ped only appears when a license can be sold
- Every purchase is verified on the server (location, distance, police count, ownership, felony, cash)

## Configuration
- `client/cl_config.lua` — locations, ped model, blip
- `server/sv_config.lua` — licenses and prices per location, police job type, felony check and MDT, purchase distance

The location names must match between the two files; the server console warns at startup if they do not.

## Dependencies
- Ox lib
- Ox Target
- Ox Inventory
- oxmysql
- Qbox

## Support

Documentation | https://cornerstonedev.gitbook.io/docs/free-scripts/offline-weapon-license-qbox

There is no support for this script. It was written for use with Ox inventory on a QBox server and will not be updated to support other inventories of frameworks. You are free to make those changes yourself. 

It's crap code, created to serve a singular purpose.
