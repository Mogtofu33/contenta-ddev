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
    printf "\\n${blu}[Info] Remove code...${end}\\n"
    rm -rf .ddev contenta_vue_nuxt contentacms contentajs
    docker stop ddev-ssh-agent
    docker rm ddev-ssh-agent
  else
    if [ -d "$__who" ] ; then
      ddev remove
      printf "\\n${blu}[Info] Remove code %s...${end}\\n" "$__who"
      rm -rf .ddev "$__who"
    else
      printf "\\n${red}[Error] Unknown folder %s${end}\\n" "$__who"
      exit 1
    fi
  fi
  exit 1
fi

if ! [ -x "$(command -v docker)" ]; then
  printf "${red}[Error] Docker is not installed${end}\\n" >&2
  exit 1
fi

if ! [ -x "$(command -v docker-compose)" ]; then
  printf "${red}[Error] Docker-compose is not installed${end}\\n" >&2
  exit 1
fi

if ! [ -x "$(command -v ddev)" ]; then
  printf "${blu}[info] Install ddev${end}\\n"
  sudo curl -L https://raw.githubusercontent.com/drud/ddev/master/install_ddev.sh | bash
else
  printf "${yel}[info] ddev already installed, please ensure to update to latest version${end}\\n"
fi

# Install ContentaJS.
if ! [ -f "contentajs/package.json" ] ; then
  printf "\\n${blu}[info] Install ContentaJS${end}\\n"
  curl -fsSL https://github.com/contentacms/contentajs/archive/master.tar.gz -o contentajs.tar.gz
  tar -xzf contentajs.tar.gz && mv contentajs-master contentajs
  rm -f contentajs.tar.gz

  # Fix start script to match PM2 with Docker.
  sed -i 's#node ./node_modules/.bin/pm2 start --name contentajs --env production#PM2_HOME=/home/node/app pm2-runtime start ecosystem.config.js --name contentajs --no-auto-exit#g' contentajs/package.json
  sed -i 's/watch: false/watch: true/g' contentajs/ecosystem.config.js
  sed -i '/watch: true,/a\      ignore_watch: ["node_modules", "client/img", "logs", "pids", "touch", "pm2.pid", "rpc.sock", "pub.sock"],' contentajs/ecosystem.config.js
  # Fix warning: http://pm2.keymetrics.io/docs/usage/environment/#specific-environment-variables
  sed -i '/port: 3000,/a\      instance_var: "INSTANCE_ID",' contentajs/ecosystem.config.js
  printf "\\n ... ${grn}done${end}\\n"
else
  printf "\\n${yel}[info] ContentaJS already installed, remove folder contentajs to re-install.${end}\\n"
fi

if ! [ -f "contentajs/config/local.yml" ] ; then
  cat >contentajs/config/local.yml <<EOL
cms:
  host: http://contenta.ddev.local
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

if ! [ -f "contenta_vue_nuxt/package.json" ] ; then
  printf "\\n${blu}[info] Install Contenta Vue consumer${end}\\n"
  curl -fsSL https://github.com/contentacms/contenta_vue_nuxt/archive/master.tar.gz -o contenta_vue_nuxt.tar.gz
  tar -xzf contenta_vue_nuxt.tar.gz && mv contenta_vue_nuxt-master contenta_vue_nuxt
  rm -f contenta_vue_nuxt.tar.gz

  sed -i 's#"dev": "nuxt"#"dev": "HOST=0.0.0.0 node_modules/.bin/nuxt"#g' contenta_vue_nuxt/package.json
else
  printf "\\n${yel}[info] Contenta Vue Nuxt already installed, remove folder contenta_vue_nuxt to re-install.${end}\\n"
fi

if [ -f "contenta_vue_nuxt/nuxt.config.js" ] ; then
  sed -i "s#serverBaseUrl = 'https://back-end.contentacms.io'#serverBaseUrl = 'http://pm2:3000'#g" contenta_vue_nuxt/nuxt.config.js
  sed -i "s#serverFilesUrl = 'https://back-end.contentacms.io'#serverFilesUrl = 'http://contenta.ddev.local'#g" contenta_vue_nuxt/nuxt.config.js
fi

printf "\\n${blu}[info] Init ddev project${end}\\n"
if ! [ -d "./contentacms/web/sites/default" ]; then
  mkdir -p ./contentacms/web/sites/default
fi

ddev config --project-type drupal8 --project-name contenta --docroot contentacms/web \
  --additional-hostnames front-vue

if ! [ -d "./.ddev" ]; then
  printf "\\n${red}[Error] ddev not initiated${end}\\n" >&2
  exit 1
fi

printf "\\n${blu}[info] Prepare ddev${end}\\n"
cp ddev-files/*.yaml .ddev
cp ddev-files/docker-compose.vue_nuxt.yaml.dis .ddev/docker-compose.vue_nuxt.yaml

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
  sudo chmod -R 777 contenta_vue_nuxt
fi

# First start of the stack.
ddev start

if ! [ -d "contentacms/web/core" ] ; then
  printf "\\n${blu}[info] Download ContentaCMS with Composer from ddev${end}\\n"
  # Boost composer.
  ddev exec composer global require hirak/prestissimo --profile
  ddev exec composer create-project contentacms/contenta-jsonapi-project /tmp/contentacms \
    --stability dev --no-interaction --remove-vcs --no-progress --prefer-dist --profile
  ddev exec cp -r /tmp/contentacms/ /var/www/html/
  ddev exec rm -rf /tmp/contentacms/
else
  printf "\\n${yel}[info] ContentaCMS already downloaded, remove folder contentacms to re-install.${end}\\n"
fi

if ! [ -f "contentacms/web/sites/default/files/sync/core.extension.yml" ] ; then
  printf "\\n${blu}[info] Prepare ContentaCMS${end}\\n"
  mkdir -p contentacms/web/sites/default/files/tmp && mkdir -p contentacms/web/sites/default/files/sync
  cp -r contentacms/web/profiles/contrib/contenta_jsonapi/config/sync/ contentacms/web/sites/default/files/
fi

if ! [ -d "contentacms/keys" ] ; then
  printf "\\n${blu}[info] Install ContentaCMS${end}\\n"
  # Ensure settings and permissions.
  ddev config --project-type drupal8 --project-name contenta --docroot contentacms/web \
    --additional-hostnames front-vue

  # Install with drush, db info are in settings.ddev.php created by config line above.
  ddev exec drush si contenta_jsonapi --account-pass=admin --verbose
else
  printf "\\n${yel}[info] ContentaCMS already installed, remove folder contentacms to re-install.${end}\\n"
fi

if [ -f "contentacms/web/sites/default/services.yml" ] ; then
  # Open CORS on Drupal.
  sed -i "s/- localhost/- '*'/g"  contentacms/web/sites/default/services.yml
  sed -i "s/localhost:/local:/g"  contentacms/web/sites/default/services.yml
else
  printf "\\n${red}[warning] Missing ContentaCMS services.yml file${end}\\n"
fi

# Ensure PM2 is fully installed before restart, npm install can be long.
while [ ! -f 'contentajs/pm2.pid' ]
do
  printf "\\n${yel}[info] Waiting for ContentaJS to be installed...${end}\\n"
  sleep 5s
  printf "\\n   ... ${yel}If this get stuck, break and re-run install.sh${end}\\n"
done

# Avoid install on restart for npm.
sed -i 's/command: sh -c/#command: sh -c/g' .ddev/docker-compose.pm2.yaml
sed -i 's/#command: npm/command: npm/g' .ddev/docker-compose.pm2.yaml
sed -i 's/command: sh -c/#command: sh -c/g' .ddev/docker-compose.vue_nuxt.yaml
sed -i 's/#command: npm/command: npm/g' .ddev/docker-compose.vue_nuxt.yaml

printf "\\n${blu}[info] Restart ddev${end}\\n"
ddev restart

printf "\\n${grn}   ... done${end}\\n"
