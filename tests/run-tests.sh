#!/bin/bash
set -e

red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
blu=$'\e[1;34m'
end=$'\e[0m'

_error=0

printf "${blu}[test] Test ContentaCMS${end}\\n"
status=$(ddev exec drush st --field=bootstrap)
status=${status//[[:space:]]/}

if [ $status == 'Successful' ]; then
  printf "   ... ${grn}OK :: %s${end}\\n" "$status"
  printf "${yel}[test] Check ContentaCMS${end}\\n"
  ddev exec drush status --fields=drupal-version,db-status,bootstrap,php-bin,install-profile
else
  printf "   ... ${red}Failed${end}\\n"
  # Print all status for debug.
  ddev exec drush status
  _error=1
fi

printf "${blu}[test] Test ContentaCMS API${end}\\n"
test=$(curl --write-out %{http_code} --silent --output /dev/null http://contenta.ddev.site/api)

if [ $test == '200' ]; then
  printf "   ... ${grn}OK :: %s${end}\\n" "$test"
  # curl -H "Access-Control-Request-Method: GET" -H "Origin: http://contenta.ddev.site" -I http://contenta.ddev.site/api
  if [ -x "$(command -v jq)" ]; then
    printf "\\n${blu}[test] Test ContentaCMS API with CORS${end}\\n"
    curl -sH "Access-Control-Request-Method: GET" -H "Origin: http://contenta.ddev.site" http://contenta.ddev.site/api | jq '.links.self'
    curl -sH "Access-Control-Request-Method: GET" -H "Origin: http://contenta.ddev.site" http://contenta.ddev.site/api/pages | jq '.jsonapi.version'
  fi
else
  printf "   ... ${red}Failed :: %s${end}\\n" "$test"
  # Print all status for debug.
  curl -I http://contenta.ddev.site/api
  _error=1
fi

printf "\\n${yel}[test] Check ContentaJS logs${end}\\n"
ddev logs -s pm2 --tail 10

printf "\\n${blu}[test] Test ContentaJS${end}\\n"
test=$(curl --write-out %{http_code} --silent --output /dev/null http://contentajs.ddev.site/api)
if [ $test == '200' ]; then
  printf "   ... ${grn}OK :: %s${end}\\n" "$test"
  # curl -H "Access-Control-Request-Method: GET" -H "Origin: http://contenta.ddev.site" -I http://contentajs.ddev.site/api
  if [ -x "$(command -v jq)" ]; then
    printf "\\n${blu}[test] Test ContentaJS API with CORS${end}\\n"
    curl -sH "Access-Control-Request-Method: GET" -H "Origin: http://contenta.ddev.site" http://contentajs.ddev.site/api | jq '.links.self'
    curl -sH "Access-Control-Request-Method: GET" -H "Origin: http://contenta.ddev.site" http://contentajs.ddev.site/api/pages | jq '.jsonapi.version'
  fi
else
  printf "   ... ${red}Failed :: %s${end}\\n" "$test"
  # Print all status for debug.
  curl -I http://contentajs.ddev.site/api
  _error=1
fi

printf "\\n${yel}[test] Check Front React logs${end}\\n"
ddev logs -s front_react --tail 8

# printf "\\n${blu}[test] Prepare Front React tests${end}\\n"
# Force restart to ensure front_react check with api.
# ddev restart
# sleep 10s
curl --silent --output /dev/null http://contenta.ddev.site/api
curl --silent --output /dev/null http://contentajs.ddev.site/api

printf "\\n${blu}[test] Test Front React access${end}\\n"
test=$(curl --write-out %{http_code} --silent --output /dev/null http://front-react.ddev.site)
if [ $test == '200' ]; then
  printf "   ... ${grn}OK :: %s${end}\\n" "$test"
else
  printf "   ... ${red}Failed :: %s${end}\\n" "$test"
  # Print all status for debug.
  curl -I http://front-react.ddev.site
  _error=1
fi

printf "\\n${blu}[test] Test Redis access${end}\\n"
test=$(curl --write-out %{http_code} --silent --output /dev/null http://contenta.ddev.site:8081)
if [ $test == '200' ]; then
  printf "   ... ${grn}OK :: %s${end}\\n" "$test"
else
  printf "   ... ${red}Failed :: %s${end}\\n" "$test"
  # Print all status for debug.
  curl -I http://contenta.ddev.site:8081
  _error=1
fi

if [ $_error == '1' ]; then
  printf "\\n${red}[ERROR]${end} Some tests failed\\n"
  exit 1
fi
