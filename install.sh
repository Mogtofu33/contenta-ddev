#!/bin/bash
set -e

red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
blu=$'\e[1;34m'
end=$'\e[0m'

if [ "${1:-}" == "ci" ]; then
  set -ev
fi

if [ "${1:-}" == "nuke" ]; then
  __who=${2:-"all"}
  if [ "$__who" == "all" ]; then
    ddev remove
    printf "\\n%s[Info] Remove code...%s\\n" "$blu" "$end"
    rm -rf .ddev contenta_react_next contentacms contentajs
    docker stop ddev-ssh-agent
    docker rm ddev-ssh-agent
  else
    if [ -d "$__who" ] ; then
      ddev remove
      printf "\\n%s[Info] Remove code %s...%s\\n" "$blu" "$__who" "$end"
      rm -rf .ddev "$__who"
    else
      printf "\\n%s[Error] Unknown folder %s%s\\n" "$red" "$__who" "$end"
      exit 1
    fi
  fi
  exit 1
fi

if ! [ -x "$(command -v docker)" ]; then
  printf "%s[Error] Docker is not installed%s\\n" "$red" "$end"
  exit 1
fi

if ! [ -x "$(command -v docker-compose)" ]; then
  printf "%s[Error] Docker-compose is not installed%s\\n" "$red" "$end"
  exit 1
fi

if ! [ -x "$(command -v ddev)" ]; then
  printf "%s[info] Install ddev%s\\n" "$blu" "$end"
  sudo curl -L https://raw.githubusercontent.com/drud/ddev/master/scripts/install_ddev.sh | bash
else
  printf "%s[info] ddev already installed, checking version%s\\n" "$yel" "$end"
  __last_version=$(curl --silent "https://api.github.com/repos/drud/ddev/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')
  __local_verion=$(ddev version | grep version | awk '{print $3}')
  if [ "${__local_verion}" == "${__last_version}" ]; then
    printf "%s[success] you have the last version: %s%s\\n" "$grn" "$__last_version" "$end"
  else
    printf "%s[Error] last version: %s, Your version: %s%s\\nSee documentation: https://ddev.readthedocs.io/en/stable/#installation\\n" "$red" "$__last_version" "$__local_verion" "$end"
    exit 1
  fi
fi

# Install ContentaJS.
if ! [ -f "contentajs/package.json" ] ; then
  printf "\\n%s[info] Install ContentaJS%s\\n" "$blu" "$end"
  curl -fsSL https://github.com/contentacms/contentajs/archive/master.tar.gz -o contentajs.tar.gz
  tar -xzf contentajs.tar.gz && mv contentajs-master contentajs
  rm -f contentajs.tar.gz

  # Fix start script to match PM2 with Docker.
  sed -i 's#node ./node_modules/.bin/pm2 start --name contentajs --env production#PM2_HOME=/home/node/app pm2-runtime start ecosystem.config.js --name contentajs --no-auto-exit#g' contentajs/package.json
  sed -i 's/watch: false/watch: true/g' contentajs/ecosystem.config.js
  sed -i '/watch: true,/a\      ignore_watch: ["node_modules", "client/img", "logs", "pids", "touch", "pm2.pid", "rpc.sock", "pub.sock"],' contentajs/ecosystem.config.js
  # Fix warning: http://pm2.keymetrics.io/docs/usage/environment/#specific-environment-variables
  sed -i '/port: 3000,/a\      instance_var: "INSTANCE_ID",' contentajs/ecosystem.config.js
  printf "\\n ... %sdone%s\\n" "$grn" "$end"
else
  printf "\\n%s[info] ContentaJS already installed, remove folder contentajs to re-install.%s\\n" "$yel" "$end"
fi

if ! [ -f "contentajs/config/local.yml" ] ; then
  cat >contentajs/config/local.yml <<EOL
cms:
  host: http://contenta.ddev.site
got:
  applicationCache:
    activePlugin: redis
    plugins:
      redis:
        host: redis
        port: 6379
        prefix: 'contentajs::'
cors:
  origin:
    - '*'
EOL
fi

if ! [ -f "contenta_react_next/package.json" ] ; then
  printf "\\n%s[info] Install Contenta React Next consumer%s\\n" "$blu" "$end"
  curl -fsSL https://github.com/contentacms/contenta_react_next/archive/master.tar.gz -o contenta_react_next.tar.gz
  tar -xzf contenta_react_next.tar.gz && mv contenta_react_next-master/reactjs contenta_react_next
  rm -rf contenta_react_next-master contenta_react_next.tar.gz

  cp contenta_react_next/.env.default contenta_react_next/.env
  sed -i "s#BACKEND_URL=https://live-contentacms.pantheonsite.io#BACKEND_URL=http://contentajs.ddev.site:3000#g" contenta_react_next/.env
else
  printf "\\n%s[info] Contenta React Next already installed, remove folder contenta_react_next to re-install.%s\\n" "$yel" "$end"
fi

printf "\\n%s[info] Init ddev project%s\\n" "$blu" "$end"
if ! [ -d "./contentacms/web/sites/default" ]; then
  mkdir -p ./contentacms/web/sites/default
fi

ddev config --project-type drupal8 --project-name contenta --docroot contentacms/web \
  --additional-hostnames front-react,contentajs

if ! [ -d "./.ddev" ]; then
  printf "\\n%s[Error] ddev not initiated%s\\n" "$red" "$end"
  exit 1
fi

printf "\\n%s[info] Prepare ddev%s\\n" "$blu" "$end"
cp ddev-files/*.yaml .ddev
cp ddev-files/docker-compose.react_next.yaml.dis .ddev/docker-compose.react_next.yaml

# Detect if we have a local composer to speed up a bit.
if [ -x "$(command -v composer)" ]; then
  __cache=$(composer global config cache-dir)
  if [ "${__cache}" ]; then
    sed -i 's/#volumes/volumes/g' .ddev/docker-compose.override.yaml
    sed -i 's/#-/-/g' .ddev/docker-compose.override.yaml
    sed -i "s#YOUR_COMPOSER_CACHE_DIR#$__cache#g" .ddev/docker-compose.override.yaml
  fi
fi

if [ "${1:-}" == "ci" ]; then
  # Fix npm permission error on ci.
  sudo chmod -R 777 contentajs
  sudo chmod -R 777 contenta_react_next
fi

# First start of the stack.
if [ "${1:-}" == "ci" ]; then
  n | ddev start
else
  ddev start
fi

if ! [ -d "contentacms/web/core" ] ; then
  printf "\\n%s[info] Download ContentaCMS with Composer from ddev%s\\n" "$blu" "$end"
  # Boost composer.
  ddev exec composer global require hirak/prestissimo --profile
  ddev exec composer create-project contentacms/contenta-jsonapi-project /tmp/contentacms \
    --stability dev --no-interaction --remove-vcs --no-progress --prefer-dist --profile
  ddev exec cp -r /tmp/contentacms/ /var/www/html/
  ddev exec rm -rf /tmp/contentacms/
else
  printf "\\n%s[info] ContentaCMS already downloaded, remove folder contentacms to re-install.%s\\n" "$yel" "$end"
fi

if ! [ -f "contentacms/web/sites/default/files/sync/core.extension.yml" ] ; then
  printf "\\n%s[info] Prepare ContentaCMS%s\\n" "$blu" "$end"
  mkdir -p contentacms/web/sites/default/files/tmp && mkdir -p contentacms/web/sites/default/files/sync
  cp -r contentacms/web/profiles/contrib/contenta_jsonapi/config/sync/ contentacms/web/sites/default/files/
fi

if ! [ -d "contentacms/keys" ] ; then
  printf "\\n%s[info] Install ContentaCMS%s\\n" "$blu" "$end"
  # Create Ddev project.
  ddev config --project-type drupal8 --project-name contenta --docroot contentacms/web \
    --additional-hostnames front-react,contentajs

  # Install with drush, db info are in settings.ddev.php created by config line above.
  ddev exec drush si -y contenta_jsonapi --account-pass=admin --verbose
else
  printf "\\n%s[info] ContentaCMS already installed, remove folder contentacms to re-install.%s\\n" "$yel" "$end"
fi

if [ -f "contentacms/web/sites/default/services.yml" ] ; then
  # Open CORS on Drupal.
  sed -i "s/- localhost/- '*'/g"  contentacms/web/sites/default/services.yml
  sed -i "s/localhost:/local:/g"  contentacms/web/sites/default/services.yml
else
  printf "\\n%s[warning] Missing ContentaCMS services.yml file%s\\n" "$red" "$end"
fi

# Ensure PM2 is fully installed before restart, npm install can be long.
while [ ! -f 'contentajs/pm2.pid' ]
do
  printf "\\n%s[info] Waiting for ContentaJS to be installed...%s\\n" "$yel" "$end"
  sleep 10s
  printf "\\n   ... %sIf this get stuck, break and re-run install.sh%s\\n" "$yel" "$end"
done

# Avoid install on restart for npm.
sed -i 's/command: sh -c/#command: sh -c/g' .ddev/docker-compose.pm2.yaml
sed -i 's/#command: npm/command: npm/g' .ddev/docker-compose.pm2.yaml
sed -i 's/command: sh -c/#command: sh -c/g' .ddev/docker-compose.react_next.yaml
sed -i 's/#command: yarn/command: yarn/g' .ddev/docker-compose.react_next.yaml

printf "\\n%s[info] Restart ddev%s\\n" "$blu" "$end"
ddev restart

printf "\\n%s  Login in Drupal with admin / admin at http://contenta.ddev.site/user%s\\n\\n" "$blu" "$end"

printf "%s    React            http://front-react.ddev.site%s\\n" "$blu" "$end"
printf "%s    Drupal api       http://contenta.ddev.site/api%s\\n" "$blu" "$end"
printf "%s    ConentaJS api    http://contentajs.ddev.site/api%s\\n" "$blu" "$end"
printf "%s    Redis commander  http://contenta.ddev.site:8081%s\\n" "$blu" "$end"
printf "%s    Protainer        http://contenta.ddev.site:9000%s\\n" "$blu" "$end"

printf "\\n%s ... done, see README.md for more info, happy testing! ;)%s\\n" "$grn" "$end"
