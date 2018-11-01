# ContentaCMS - ContentaJs with Docker managed by ddev

This project is a basic Drupal [ContentaCMS](https://www.contentacms.org/) / [ContentaJS](https://github.com/contentacms/contentajs#readme) environment stack with [ddev](https://github.com/drud/ddevv).

- [System Requirements](#system-requirements)
- [Features](#features)
- [Installation](#installation)
  - [ddev Installation (Linux example)](#ddev-installation-linux-example)
  - [Clone this project and get in](#clone-this-project-and-get-in)
  - [ContentaCMS](#contentacms)
- [Init ddev project](#init-ddev-project)
  - [Download ContentaJs](#download-contentajs)
  - [Prepare the stack](#prepare-the-stack)
- [Launch](#launch)
  - [Install ContentaCMS](#install-contentacms)
  - [Restart for Contentajs to connect to ContentaCMS](#restart-for-contentajs-to-connect-to-contentacms)
- [Usage](#usage)
- [Consumer example](#consumer-example)
  - [Vue + Nuxt frontend](#vue--nuxt-frontend)
  - [React + Next frontend](#react--next-frontend)
- [Issues](#issues)

## System Requirements

- [Docker](https://store.docker.com/search?type=edition&offering=community)
- [Docker Compose](https://docs.docker.com/compose/install/)
- [Composer](https://getcomposer.org)
- [ddev](https://github.com/drud/ddev)

Tested on Ubuntu, referer to [ddev](https://ddev.readthedocs.io/en/latest/#system-requirements) for more details.

## Features

Include default ddev stack for Drupal (Nginx, Php 7.1 fpm, Mariadb, PhpMyAdmin) and extra services:

- [Pm2](http://pm2.keymetrics.io/docs/usage/docker-pm2-nodejs/)
- [Redis](https://hub.docker.com/_/redis/)
- [Portainer](https://hub.docker.com/r/portainer/portainer)

## Installation

### ddev Installation (Linux example)

- [https://ddev.readthedocs.io/en/latest/#installation](https://ddev.readthedocs.io/en/latest/#installation)

```shell
curl -L https://raw.githubusercontent.com/drud/ddev/master/install_ddev.sh | bash
```

### Clone this project and get in

```shell
curl -fSL https://github.com/contentacms/contentajs/archive/master.tar.gz -o contenta-ddev.tar.gz
tar -xzf contenta-ddev.tar.gz
mv contenta-ddev-master contenta-ddev
cd contenta-ddev
```

### ContentaCMS

Install with composer locally:

```shell
composer create-project contentacms/contenta-jsonapi-project contentacms \
--stability dev --no-interaction --remove-vcs --no-progress --prefer-dist
```

If you don't have composer locally you can use [Docker](https://hub.docker.com/_/composer/):

```shell
docker run --rm --interactive --tty \
    --volume $PWD:/app \
    --user $(id -u):$(id -g) \
      composer create-project contentacms/contenta-jsonapi-project contentacms \
      --stability dev --no-interaction --remove-vcs --no-progress --prefer-dist -vvv
```

## Init ddev project

```shell
ddev config --projectname contenta --docroot contentacms/web --additional-hostnames contentajs
```

Fix Drupal files tmp permissions (or after install change files tmp folder in Drupal settings)

```shell
mkdir -p contentacms/web/sites/default/files/tmp
chmod -R 777 contentacms/web/sites/default/files
```

### Download ContentaJs

```shell
curl -fSL https://github.com/contentacms/contentajs/archive/master.tar.gz -o contenta.tar.gz
tar -xzf contenta.tar.gz
mv contentajs-master contentajs
```

Edit contentajs/package.json and replace _"start"_ with:

```json
"start": "npm run build && pm2-runtime start ecosystem.config.js --watch",
```

Set a local config

```shell
touch contentajs/config/local.yml
```

```yaml
cms:
  host: http://contenta.ddev.local

cors:
  origin:
    # It's OK to use '*' in local development.
    - '*'
```

### Prepare the stack

Copy specific Contenta files from _ddev-files_ in _.ddev_ folder

```shell
cp ddev-files/*.yaml .ddev
```

_Note_: Nodejs is included in the docker service and used to install ContentaJs,
if you want to install the project locally (npm install), edit and switch _command_
line in .ddev/docker-compose.pm2.yaml

## Launch

```shell
ddev start
```

### Install ContentaCMS

```shell
ddev exec drush site-install contenta_jsonapi --verbose --yes \
  --db-url=mysql://db:db@db/db \
  --site-mail=admin@local \
  --account-mail=admin@local \
  --site-name="Contenta CMS demo" \
  --account-name=admin \
  --account-pass=admin
```

### Restart for ContentaJJS to connect to ContentaCMS

```shell
ddev restart
```

## Usage

For all ddev commands see [https://ddev.readthedocs.io/en/latest/users/cli-usage](https://ddev.readthedocs.io/en/latest/users/cli-usage)

This stack include a Docker web UI, you can access it on port 9000

- [http://contenta.ddev.local:9000](http://contenta.ddev.local:9000)

ContentaCMS Backoffice

- [http://contenta.ddev.local](http://contenta.ddev.local)

ContentaJS

- [http://contentajs.ddev.local/api](http://contentajs.ddev.local/api)

## Consumer example

Currently consumers will mostly failed with 403 because of ddev router, an Nginx proxy. Here is the [issue](https://github.com/Mogtofu33/contenta-ddev/issues/1).
A solution is to open this proxy, each time the stack start / restart you must run:

```shell
docker exec -d ddev-router sh -c "echo 'proxy_set_header Origin \"\"; add_header \"Access-Control-Allow-Origin\" \"*\" always;' >> /etc/nginx/conf.d/default.conf"
docker exec -d ddev-router nginx -s reload
```

### React + Next frontend

Create a hostname for this service in ddev

```shell
ddev config --projectname contenta --docroot contentacms/web --additional-hostnames contentajs,front-react
```

Grab the Sample project and install:

```shell
curl -fSL https://github.com/contentacms/contenta_react_next/archive/master.tar.gz -o contenta_react_next.tar.gz
tar -xzf contenta_react_next.tar.gz
mv contenta_react_next-master contenta_react_next
cp ddev-files/docker-compose.react_next.yaml.dis .ddev/docker-compose.react_next.yaml
```

_Note_: Yarn is included in the docker service and used to install this project,
if you want to install the project locally (yarn install), edit and switch _command_
line in .ddev/docker-compose.react_next.yaml

Prepare React values :

```shell
cp contenta_react_next/reactjs/.env.default contenta_react_next/reactjs/.env
```

Change BACKEND_URL

```shell
BACKEND_URL=http://pm2:3000
```

Restart ddev

```shell
ddev restart
```

Access the new frontend from:

- [http://front-react.ddev.local](http://front-react.ddev.local)

### Vue + Nuxt frontend

Create a hostname for this service in ddev

```shell
ddev config --projectname contenta --docroot contentacms/web --additional-hostnames contentajs,front-vue
```

Grab the Sample project and install:

```shell
curl -fSL https://github.com/contentacms/contenta_vue_nuxt/archive/master.tar.gz -o contenta_vue_nuxt.tar.gz
tar -xzf contenta_vue_nuxt.tar.gz
mv contenta_vue_nuxt-master contenta_vue_nuxt
cp ddev-files/docker-compose.vue_nuxt.yaml.dis .ddev/docker-compose.vue_nuxt.yaml
```

_Note_: Npm is included in the docker service and used to install this project,
if you want to install the project locally (npm install), edit and switch _command_
line in .ddev/docker-compose.vue_nuxt.yaml

Change Nuxt script values in package.json:

```json
"scripts": {
  "dev": "HOST=0.0.0.0 node_modules/.bin/nuxt"
```

Set Nuxt values in _contenta_vue_nuxt/nuxt.config.js_

Change serverBaseUrl

```json
const serverBaseUrl = 'http://contentajs.ddev.local',
# Uncoment to try directly using Drupal
#const serverBaseUrl = 'http://contenta.ddev.local',
```

Restart ddev

```shell
ddev restart
```

Access the new frontend from:

- [http://front-vue.ddev.local](http://front-vue.ddev.local)

## Issues

ContentaJS:

- api path uri are _contenta.ddev.local_ instead of _contentajs.ddev.local_

React + Next consumer:

- Images are loaded from _front-react.ddev.local_ instead of _contenta.ddev.local_

Vue + Nuxt consumer:

- Images are loaded from _front-vue.ddev.local_ instead of _contenta.ddev.local_
