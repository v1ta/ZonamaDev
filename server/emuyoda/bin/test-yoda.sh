#!/bin/bash
set -x

clear
curl -s -H 'authorization: 7fe042ae5fe71888ef88ab04c0fdab9e' 'http://172.16.10.253:44480/api/control?command=backup' | python -m json.tool

exit 

# Server status
curl -s -H 'authorization: 7fe042ae5fe71888ef88ab04c0fdab9e' 'http://172.16.10.253:44480/api/status/' | python -m json.tool

# Add first admin account
curl -s -X POST \
    -H "Content-Type: application/json" \
    -H 'authorization: 7fe042ae5fe71888ef88ab04c0fdab9e' \
    -d '{ "account": { "username":"lordkator","password":"youwish", "admin_level": 15 } }' \
    'http://172.16.10.253:44480/api/account/' | python -m json.tool

# Get server config
curl -s -H 'authorization: 7fe042ae5fe71888ef88ab04c0fdab9e' 'http://172.16.10.253:44480/api/config/' | python -m json.tool

# Set server config (Zones)
curl -s -X PUT \
    -H "Content-Type: application/json" \
    -H 'authorization: 7fe042ae5fe71888ef88ab04c0fdab9e' \
    -d '{ "config": { "emu": { "ZonesEnabled": [ "yavin4", "lok", "tutorial" ] } } }' \
    'http://172.16.10.253:44480/api/config/' | python -m json.tool
