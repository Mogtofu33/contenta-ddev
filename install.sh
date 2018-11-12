#!/bin/bash

if [ "${1:-}" == "nuke" ]; then
  __who=${2:-"all"}
  if [ $__who == "all" ]; then
    ddev rm
    rm -rf .ddev contenta_vue_nuxt contentacms contentajs
  else
    if [ -d $__who ] ; then
      ddev rm
      rm -rf .ddev $__who
    else
      printf "[Error] Unknown folder %s\\n" $__who
      exit 1
    fi
  fi
  exit 1
fi

if ! [ -x "$(command -v docker)" ]; then
  printf "[Error] Docker is not installed\\n" >&2
  exit 1
fi

if ! [ -x "$(command -v docker-compose)" ]; then
  printf "[Error] Docker-compose is not installed\\n" >&2
  exit 1
fi

if ! [ -x "$(command -v ddev)" ]; then
  printf "[info] Install ddev\\n"
  curl -L https://raw.githubusercontent.com/drud/ddev/master/install_ddev.sh | bash
else
  printf "[info] ddev already installed\\n"
fi

# Install ContentaJS.
if ! [ -f "contentajs/package.json" ] ; then
  printf "[info] Install ContentaJS\\n"
  curl -fsSL https://github.com/contentacms/contentajs/archive/master.tar.gz -o contentajs.tar.gz
  tar -xzf contentajs.tar.gz && mv contentajs-master contentajs
  rm -f contentajs.tar.gz

  # Fix start script to match PM2 with Docker.
  sed -i 's#node ./node_modules/.bin/pm2 start --name contentajs --env production#PM2_HOME=/home/node/app pm2-runtime start ecosystem.config.js --name contentajs --no-auto-exit#g' contentajs/package.json
  sed -i 's/watch: false/watch: true/g' contentajs/ecosystem.config.js
  sed -i '/watch: true,/a\      ignore_watch: ["node_modules", "client/img", "logs", "pids", "touch", "pm2.pid", "rpc.sock", "pub.sock"],' contentajs/ecosystem.config.js
  # Fix warning: http://pm2.keymetrics.io/docs/usage/environment/#specific-environment-variables
  sed -i '/port: 3000,/a\      instance_var: "INSTANCE_ID",' contentajs/ecosystem.config.js
else
  printf "[info] ContentaJS already installed, remove folder contentajs to re-install.\\n"
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
  printf "[info] Install Contenta Vue consumer\\n"
  curl -fsSL https://github.com/contentacms/contenta_vue_nuxt/archive/master.tar.gz -o contenta_vue_nuxt.tar.gz
  tar -xzf contenta_vue_nuxt.tar.gz && mv contenta_vue_nuxt-master contenta_vue_nuxt
  rm -f contenta_vue_nuxt.tar.gz

  sed -i 's#"dev": "nuxt"#"dev": "HOST=0.0.0.0 node_modules/.bin/nuxt"#g' contenta_vue_nuxt/package.json
else
  printf "[info] Contenta Vue Nuxt already installed, remove folder contenta_vue_nuxt to re-install.\\n"
fi

if [ -f "contenta_vue_nuxt/nuxt.config.js" ] ; then
  sed -i "s#serverBaseUrl = 'https://back-end.contentacms.io'#serverBaseUrl = 'http://pm2:3000'#g" contenta_vue_nuxt/nuxt.config.js
  sed -i "s#serverFilesUrl = 'https://back-end.contentacms.io'#serverFilesUrl = 'http://contenta.ddev.local'#g" contenta_vue_nuxt/nuxt.config.js
fi

printf "[info] Init ddev project\\n"
if ! [ -d "./contentacms/web/sites/default" ]; then
  mkdir -p ./contentacms/web/sites/default
fi

ddev config --projecttype drupal8 --projectname contenta --docroot contentacms/web \
  --additional-hostnames front-vue

if ! [ -d "./.ddev" ]; then
  printf "[Error] ddev not initiated\\n" >&2
  exit 1
fi

printf "[info] Start ddev\\n"
cp ddev-files/*.yaml .ddev
cp ddev-files/docker-compose.vue_nuxt.yaml.dis .ddev/docker-compose.vue_nuxt.yaml
ddev start

if ! [ -d "contentacms/web/core" ] ; then
  printf "[info] Download ContentaCMS with Composer from ddev\\n"
  ddev exec composer create-project contentacms/contenta-jsonapi-project /tmp/contentacms \
    --stability dev --no-interaction --remove-vcs --no-progress --prefer-dist -v
  ddev exec cp -r /tmp/contentacms/ /var/www/html/
  ddev exec rm -rf /tmp/contentacms/
else
  printf "[info] ContentaCMS already downloaded, remove folder contentacms to re-install.\\n"
fi

if ! [ -f "contentacms/web/sites/default/files/sync/core.extension.yml" ] ; then
  printf "[info] Prepare ContentaCMS\\n"
  mkdir -p contentacms/web/sites/default/files/tmp && mkdir -p contentacms/web/sites/default/files/sync
  cp -r contentacms/web/profiles/contrib/contenta_jsonapi/config/sync/ contentacms/web/sites/default/files/
fi

# @TODO: remove when PR#333 accepted.
if [ -f "contentacms/web/modules/contrib/jsonapi/src/Normalizer/EntityNormalizer.php" ]; then
  # Hotfix PR https://github.com/contentacms/contenta_jsonapi/pull/333
  curl -fsSL https://gist.githubusercontent.com/Mogtofu33/5742674ea3235c954d36c2aa7b8eb4ad/raw/a183fd49cfc8fccbed9cea33aa53f31c309ad333/EntityNormalizer.php \
  -o contentacms/web/modules/contrib/jsonapi/src/Normalizer/EntityNormalizer.php
fi

if ! [ -d "contentacms/keys" ] ; then
  printf "[info] Install ContentaCMS\\n"
  # Ensure settings and permissions.
  ddev config --projecttype drupal8 --projectname contenta --docroot contentacms/web \
    --additional-hostnames front-vue
  # Install with drush, db info are in settings.ddev.php created by config line above.
  ddev exec drush si contenta_jsonapi --account-pass=admin --verbose
else
  printf "[info] ContentaCMS already installed, remove folder contentacms to re-install.\\n"
fi

if [ -f "contentacms/web/sites/default/services.yml" ] ; then
  # Open CORS on Drupal.
  sed -i "s/- localhost/- '*'/g"  contentacms/web/sites/default/services.yml
  sed -i "s/localhost:/local:/g"  contentacms/web/sites/default/services.yml
else
  printf "[warning] Missing ContentaCMS services.yml file\\n"
fi

# Ensure PM2 is fully install before restart, npm install can be long.
while [ ! -f 'contentajs/pm2.pid' ]
do
  printf "[info] Waiting for ContentaJS to be installed...\\n"
  sleep 10s
done

# Avoid install on restart for npm.
sed -i 's/command: sh -c/#command: sh -c/g' .ddev/docker-compose.pm2.yaml
sed -i 's/#command: npm/command: npm/g' .ddev/docker-compose.pm2.yaml
sed -i 's/command: sh -c/#command: sh -c/g' .ddev/docker-compose.vue_nuxt.yaml
sed -i 's/#command: npm/command: npm/g' .ddev/docker-compose.vue_nuxt.yaml

printf "[info] Restart ddev\\n"
ddev restart
