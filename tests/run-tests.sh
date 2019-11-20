#!/bin/bash
set -e

red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
blu=$'\e[1;34m'
end=$'\e[0m'

printf "${blu}[test] Test ContentaCMS${end}\\n"
status=$(ddev exec drush st --field=bootstrap)

if [ $status == 'Successful' ]; then
  printf "   ... ${grn}OK :: %s${end}\\n" "$status"
  printf "${yel}[test] Check ContentaCMS${end}\\n"
  ddev exec drush status --fields=drupal-version,db-status,bootstrap,php-bin,install-profile
else
  printf "   ... ${red}Failed${end}\\n"
  # Print all status for debug.
  ddev exec drush status
  exit 1
fi

printf "${blu}[test] Test ContentaCMS API${end}\\n"
test=$(curl --write-out %{http_code} --silent --output /dev/null http://contenta.ddev.local/api)

if [ $test == '200' ]; then
  printf "   ... ${grn}OK :: %s${end}\\n" "$test"
  # curl -H "Access-Control-Request-Method: GET" -H "Origin: http://contenta.ddev.local" -I http://contenta.ddev.local/api
  if [ -x "$(command -v jq)" ]; then
    printf "\\n${blu}[test] Test ContentaCMS API with CORS${end}\\n"
    curl -sH "Access-Control-Request-Method: GET" -H "Origin: http://contenta.ddev.local" http://contenta.ddev.local/api | jq '.links.self'
    curl -sH "Access-Control-Request-Method: GET" -H "Origin: http://contenta.ddev.local" http://contenta.ddev.local/api/pages | jq '.jsonapi.version'
  fi
else
  printf "   ... ${red}Failed :: %s${end}\\n" "$test"
  # Print all status for debug.
  curl -I http://contenta.ddev.local/api
  exit 1
fi

printf "\\n${yel}[test] Check ContentaJS logs${end}\\n"
ddev logs -s pm2 --tail 10

printf "\\n${blu}[test] Test ContentaJS${end}\\n"
test=$(curl --write-out %{http_code} --silent --output /dev/null http://contenta.ddev.local:3000/api)
if [ $test == '200' ]; then
  printf "   ... ${grn}OK :: %s${end}\\n" "$test"
  # curl -H "Access-Control-Request-Method: GET" -H "Origin: http://contenta.ddev.local" -I http://contenta.ddev.local:3000/api
  if [ -x "$(command -v jq)" ]; then
    printf "\\n${blu}[test] Test ContentaJS API with CORS${end}\\n"
    curl -sH "Access-Control-Request-Method: GET" -H "Origin: http://contenta.ddev.local" http://contenta.ddev.local:3000/api | jq '.links.self'
    curl -sH "Access-Control-Request-Method: GET" -H "Origin: http://contenta.ddev.local" http://contenta.ddev.local:3000/api/pages | jq '.jsonapi.version'
  fi
else
  printf "   ... ${red}Failed :: %s${end}\\n" "$test"
  # Print all status for debug.
  curl -I http://contenta.ddev.local:3000/api
  exit 1
fi

printf "\\n${yel}[test] Check Front VUE logs${end}\\n"
ddev logs -s front_vue --tail 8

printf "\\n${blu}[test] Prepare Front VUE tests${end}\\n"
# Force restart to ensure front_vue check with api.
ddev restart
sleep 10s
curl --silent --output /dev/null http://contenta.ddev.local/api
curl --silent --output /dev/null http://contenta.ddev.local:3000/api

printf "\\n${blu}[test] Test Front VUE access${end}\\n"
test=$(curl --write-out %{http_code} --silent --output /dev/null http://front-vue.ddev.local)
if [ $test == '200' ]; then
  printf "   ... ${grn}OK :: %s${end}\\n" "$test"
else
  printf "   ... ${red}Failed :: %s${end}\\n" "$test"
  # Print all status for debug.
  curl -I http://front-vue.ddev.local
  exit 1
fi

printf "\\n${blu}[test] Test Redis access${end}\\n"
test=$(curl --write-out %{http_code} --silent --output /dev/null http://contenta.ddev.local:8081)
if [ $test == '200' ]; then
  printf "   ... ${grn}OK :: %s${end}\\n" "$test"
else
  printf "   ... ${red}Failed :: %s${end}\\n" "$test"
  # Print all status for debug.
  curl -I http://contenta.ddev.local:8081
  exit 1
fi
