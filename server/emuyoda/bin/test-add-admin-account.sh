#!/bin/bash
#
# test-add-admin-account.sh - Add an admin account
#
# Author: Lord Kator <lordkator@swgemu.com>
#
# Created: Fri Jan 22 08:40:26 EST 2016
#

AUTH_TOKEN=$( (cat ~/server/emuyoda/yoda-config.lua;echo 'print(yodaSecret)')|lua -)

curl -s -X POST \
    -H "Content-Type: application/json" \
    -H 'authorization: '${AUTH_TOKEN} \
    -d '{ "account": { "username":"lordvader","password":"lukeImURFather", "admin_level": 15 } }' \
    'http://127.0.0.1:44480/api/account/' | python -m json.tool
