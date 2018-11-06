#!/bin/bash

if ! [ -x "$(command -v docker)" ]; then
  echo 'Error: Docker is not installed.' >&2
  exit 1
fi

if ! [ -x "$(command -v docker-compose)" ]; then
  echo 'Error: Docker-compose is not installed.' >&2
  exit 1
fi

if ! [ -x "$(command -v composer)" ]; then
  echo 'Error: Composer is not installed.' >&2
  exit 1
fi

if ! [ -x "$(command -v ddev)" ]; then
  printf "[info] Install ddev\\n"
  curl -L https://raw.githubusercontent.com/drud/ddev/master/install_ddev.sh | bash
else
  printf "[info] ddev installed\\n"
fi

printf "[info] Download ContentaCMS\\n"
composer create-project contentacms/contenta-jsonapi-project contentacms \
  --stability dev --no-interaction --remove-vcs --no-progress --prefer-dist -v

# Hotfix PR https://github.com/contentacms/contenta_jsonapi/pull/333
curl -fL https://gist.githubusercontent.com/Mogtofu33/5742674ea3235c954d36c2aa7b8eb4ad/raw/a183fd49cfc8fccbed9cea33aa53f31c309ad333/EntityNormalizer.php -o EntityNormalizer.php
mv EntityNormalizer.php contentacms/web/modules/contrib/jsonapi/src/Normalizer/

printf "[info] Init ddev project\\n"
ddev config --projectname contenta --docroot contentacms/web \
  --additional-hostnames contentajs,front-vue

printf "[info] Install ContentaJS\\n"
curl -fSL https://github.com/contentacms/contentajs/archive/master.tar.gz -o contenta.tar.gz
tar -xzf contenta.tar.gz && mv contentajs-master contentajs
rm -f contenta.tar.gz

sed -i 's#node ./node_modules/.bin/pm2 start --name contentajs --env production#pm2-runtime start ecosystem.config.js#g' contentajs/package.json
sed -i 's/3000/80/g' contentajs/ecosystem.config.js

cat >contentajs/config/local.yml <<EOL
cms:
  host: http://contenta.ddev.local
cors:
  origin:
    - '*'
EOL

cp ddev-files/*.yaml .ddev

printf "[info] Install Contenta Vue consumer\\n"
curl -fSL https://github.com/contentacms/contenta_vue_nuxt/archive/master.tar.gz -o contenta_vue_nuxt.tar.gz
tar -xzf contenta_vue_nuxt.tar.gz && mv contenta_vue_nuxt-master contenta_vue_nuxt
rm -f contenta_vue_nuxt.tar.gz

cp ddev-files/docker-compose.vue_nuxt.yaml.dis .ddev/docker-compose.vue_nuxt.yaml

sed -i 's#"dev": "nuxt"#"dev": "HOST=0.0.0.0 node_modules/.bin/nuxt"#g' contenta_vue_nuxt/package.json
sed -i "s#serverBaseUrl = 'https://back-end.contentacms.io'#serverBaseUrl = 'http://contentajs.ddev.local'#g" contenta_vue_nuxt/nuxt.config.js
sed -i "s#serverFilesUrl = 'https://back-end.contentacms.io'#serverFilesUrl = 'http://contenta.ddev.local'#g" contenta_vue_nuxt/nuxt.config.js

printf "[info] Start ddev\\n"
ddev start

printf "[info] Install ContentaCMS\\n"
mkdir -p ./contentacms/web/sites/default/files/tmp && mkdir -p ./contentacms/web/sites/default/files/sync
chmod -R 777 ./contentacms/web/sites/default/files
cp -r ./contentacms/web/profiles/contrib/contenta_jsonapi/config/sync/*.yml ./contentacms/web/sites/default/files/sync/
ddev exec drush si contenta_jsonapi --account-pass=admin --verbose

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
