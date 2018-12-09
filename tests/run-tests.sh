#!/bin/bash
set -ev

# Test ContentaCMS
ddev exec drush status

curl -H "Access-Control-Request-Method: GET" -H "Origin: http://contenta.ddev.local" -I http://contenta.ddev.local/api

curl -s -H "Access-Control-Request-Method: GET" -H "Origin: http://contenta.ddev.local" http://contenta.ddev.local/api | jq '.links.self'

curl -s -H "Access-Control-Request-Method: GET" -H "Origin: http://contenta.ddev.local" http://contenta.ddev.local/api/pages | jq '.jsonapi.version'

# Test ContentaJS
ddev logs -s pm2

curl -H "Access-Control-Request-Method: GET" -H "Origin: http://contenta.ddev.local" -I http://contenta.ddev.local:3000/api

#curl -s -H "Access-Control-Request-Method: GET" -H "Origin: http://contenta.ddev.local" http://contenta.ddev.local:3000/api | jq '.links.self'

#curl -s -H "Access-Control-Request-Method: GET" -H "Origin: http://contenta.ddev.local" http://contenta.ddev.local:3000/api/pages | jq '.jsonapi.version'

# Test Front VUE
ddev logs -s front_vue

curl -I http://front-vue.ddev.local

# Test Redis
curl -I http://contenta.ddev.local:8081
