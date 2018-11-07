#!/bin/bash

if [ "${1}" == "nuke" ]; then
  ddev rm
  rm -rf .ddev contenta_vue_nuxt contentacms contentajs
  exit 1
fi

if ! [ -x "$(command -v docker)" ]; then
  echo '[Error] Docker is not installed.' >&2
  exit 1
fi

if ! [ -x "$(command -v docker-compose)" ]; then
  echo '[Error] Docker-compose is not installed.' >&2
  exit 1
fi

if ! [ -x "$(command -v ddev)" ]; then
  printf "[info] Install ddev\\n"
  curl -L https://raw.githubusercontent.com/drud/ddev/master/install_ddev.sh | bash
else
  printf "[info] ddev already installed\\n"
fi

printf "[info] Install ContentaJS\\n"
curl -fSL https://github.com/contentacms/contentajs/archive/master.tar.gz -o contenta.tar.gz
tar -xzf contenta.tar.gz && mv contentajs-master contentajs
rm -f contenta.tar.gz

sed -i 's#node ./node_modules/.bin/pm2 start --name contentajs --env production#pm2-runtime start ecosystem.config.js#g' contentajs/package.json
sed -i 's/3000/80/g' contentajs/ecosystem.config.js
sed -i 's/watch: false/watch: true/g' contentajs/ecosystem.config.js

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

printf "[info] Install Contenta Vue consumer\\n"
curl -fSL https://github.com/contentacms/contenta_vue_nuxt/archive/master.tar.gz -o contenta_vue_nuxt.tar.gz
tar -xzf contenta_vue_nuxt.tar.gz && mv contenta_vue_nuxt-master contenta_vue_nuxt
rm -f contenta_vue_nuxt.tar.gz

sed -i 's#"dev": "nuxt"#"dev": "HOST=0.0.0.0 node_modules/.bin/nuxt"#g' contenta_vue_nuxt/package.json
sed -i "s#serverBaseUrl = 'https://back-end.contentacms.io'#serverBaseUrl = 'http://contentajs.ddev.local'#g" contenta_vue_nuxt/nuxt.config.js
sed -i "s#serverFilesUrl = 'https://back-end.contentacms.io'#serverFilesUrl = 'http://contenta.ddev.local'#g" contenta_vue_nuxt/nuxt.config.js

cp ddev-files/docker-compose.vue_nuxt.yaml.dis .ddev/docker-compose.vue_nuxt.yaml

printf "[info] Init ddev project\\n"
if ! [ -d "./contentacms/web/sites/default" ]; then
  mkdir -p ./contentacms/web/sites/default
fi
ddev config --projecttype drupal8 --projectname contenta --docroot contentacms/web \
  --additional-hostnames contentajs,front-vue

if ! [ -d "./.ddev" ]; then
  echo '[Error] ddev not initiated.' >&2
  exit 1
fi

printf "[info] Start ddev\\n"
cp ddev-files/*.yaml .ddev
ddev start

printf "[info] Download ContentaCMS with Composer from ddev\\n"
ddev exec composer create-project contentacms/contenta-jsonapi-project /tmp/contentacms \
  --stability dev --no-interaction --remove-vcs --no-progress --prefer-dist -v
ddev exec cp -r /tmp/contentacms/ /var/www/html/
ddev exec rm -rf /tmp/contentacms/

if ! [ -d "contentacms/web/core" ] ; then
  echo '[Error] ContentaCMS not installed.' >&2
  exit 1
fi

printf "[info] Prepare ContentaCMS\\n"
mkdir -p contentacms/web/sites/default/files/tmp && mkdir -p contentacms/web/sites/default/files/sync
cp -r contentacms/web/profiles/contrib/contenta_jsonapi/config/sync/ contentacms/web/sites/default/files/

# @TODO: remove when PR#333 accepted.
if [ -f "contentacms/web/modules/contrib/jsonapi/src/Normalizer/EntityNormalizer.php" ]; then
  # Hotfix PR https://github.com/contentacms/contenta_jsonapi/pull/333
  curl -fL https://gist.githubusercontent.com/Mogtofu33/5742674ea3235c954d36c2aa7b8eb4ad/raw/a183fd49cfc8fccbed9cea33aa53f31c309ad333/EntityNormalizer.php \
  -o contentacms/web/modules/contrib/jsonapi/src/Normalizer/EntityNormalizer.php
fi

printf "[info] Install ContentaCMS\\n"
# Ensure settings and permissions.
ddev config --projecttype drupal8 --projectname contenta --docroot contentacms/web \
  --additional-hostnames contentajs,front-vue
ddev exec drush si contenta_jsonapi --account-pass=admin --verbose
rm -rf contentacms/keys

# Open CORS on Drupal.
sed -i "s/- localhost/- '*'/g"  contentacms/web/sites/default/services.yml
sed -i "s/localhost:/local:/g"  contentacms/web/sites/default/services.yml

# Avoid install on restart for npm / yarn.
sed -i 's/command: sh -c/#command: sh -c/g' .ddev/docker-compose.pm2.yaml
sed -i 's/#command: npm/command: npm/g' .ddev/docker-compose.pm2.yaml
sed -i 's/command: sh -c/#command: sh -c/g' .ddev/docker-compose.vue_nuxt.yaml
sed -i 's/#command: npm/command: npm/g' .ddev/docker-compose.vue_nuxt.yaml

printf "[info] Restart ddev\\n"
ddev restart
