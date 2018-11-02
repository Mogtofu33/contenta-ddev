# ContentaCMS - ContentaJs with Docker managed by ddev

This project is a basic Drupal [ContentaCMS](https://www.contentacms.org/) / [ContentaJS](https://github.com/contentacms/contentajs#readme) environment stack with [ddev](https://github.com/drud/ddevv).

- [System Requirements](#system-requirements)
- [Features](#features)
- [Installation](#installation)
  - [ddev Installation (Linux example)](#ddev-installation-linux-example)
  - [Get this project as a starting point](#get-this-project-as-a-starting-point)
  - [ContentaCMS](#contentacms)
- [Init ddev project with hostnames](#init-ddev-project-with-hostnames)
  - [Download ContentaJs](#download-contentajs)
  - [Prepare the stack](#prepare-the-stack)
    - [(Optionnal) Vue + Nuxt frontend](#optionnal-vue--nuxt-frontend)
    - [(Optionnal) React + Next frontend](#optionnal-react--next-frontend)
- [Launch](#launch)
  - [Install ContentaCMS](#install-contentacms)
  - [Restart for ContentaJS to connect to ContentaCMS](#restart-for-contentajs-to-connect-to-contentacms)
- [Usage](#usage)
- [Issues](#issues)

## System Requirements

- [Docker](https://store.docker.com/search?type=edition&offering=community)
- [Docker Compose](https://docs.docker.com/compose/install/)
- [ddev](https://github.com/drud/ddev)
- (Optionnal) [Composer](https://getcomposer.org)

Tested on Ubuntu, referer to [ddev](https://ddev.readthedocs.io/en/latest/#system-requirements) for more details.

## Features

Include default ddev stack for Drupal (Nginx, Php 7.1 fpm, Mariadb, PhpMyAdmin) and extra services:

- [Pm2](http://pm2.keymetrics.io/docs/usage/docker-pm2-nodejs/) to run [ContentaJS](https://github.com/contentacms/contentajs)
- [Redis](https://hub.docker.com/_/redis/), WIP to connect with [ContentaJS](https://github.com/contentacms/contentajs)
- [Portainer](https://hub.docker.com/r/portainer/portainer) for Docker administration

## Installation

### ddev Installation (Linux example)

- [https://ddev.readthedocs.io/en/latest/#installation](https://ddev.readthedocs.io/en/latest/#installation)

```shell
curl -L https://raw.githubusercontent.com/drud/ddev/master/install_ddev.sh | bash
```

### Get this project as a starting point

```shell
curl -fSL https://github.com/Mogtofu33/contenta-ddev/archive/master.tar.gz -o contenta-ddev.tar.gz
tar -xzf contenta-ddev.tar.gz && mv contenta-ddev-master contenta-ddev
cd contenta-ddev
```

### ContentaCMS

Vanilla install with composer locally:

```shell
composer create-project contentacms/contenta-jsonapi-project contentacms \
  --stability dev --no-interaction --remove-vcs --no-progress --prefer-dist -vvv
```

_OR_ if you don't have Composer locally you can use [Docker library](https://hub.docker.com/_/composer/):

```shell
docker run --rm --interactive --tty \
    --volume $PWD:/app \
    --user $(id -u):$(id -g) \
      composer create-project contentacms/contenta-jsonapi-project contentacms \
      --stability dev --no-interaction --remove-vcs --no-progress --prefer-dist -vvv
```

## Init ddev project with hostnames

```shell
ddev config --projectname contenta --docroot contentacms/web \
  --additional-hostnames contentajs,front-vue,front-react
```

Fix Drupal files tmp permissions (or after install change files tmp folder in Drupal settings)

```shell
mkdir -p contentacms/web/sites/default/files/tmp && chmod -R 777 contentacms/web/sites/default/files
```

### Download ContentaJs

```shell
curl -fSL https://github.com/contentacms/contentajs/archive/master.tar.gz -o contenta.tar.gz
tar -xzf contenta.tar.gz && mv contentajs-master contentajs
```

Edit __contentajs/package.json__ and replace __start__ with:

```json
"start": "npm run build && pm2-runtime start ecosystem.config.js",
```

Edit __contentajs/ecosystem.config.js__ and replace listening __port__ to __80__ (set __watch__ to _true_ for dev):

```json
port: 80,
```

Create a local config in __contentajs/config/local.yml__

```yaml
cms:
  host: http://contenta.ddev.local

cors:
  origin:
    # It's OK to use '*' in local development.
    - '*'
```

### Prepare the stack

Copy specific Contenta files from __ddev-files__ in __.ddev__ folder

```shell
cp ddev-files/*.yaml .ddev
```

_Note_: _Nodejs_ is included in the docker service and used to install ContentaJs,
if you want to install the project locally (eg: npm install), edit and switch
__command__ line in __.ddev/docker-compose.pm2.yaml__ file.
To avoid re-install on each restart you can switch the __command__ after the first
launch.

#### (Optionnal) Vue + Nuxt frontend

- [https://github.com/contentacms/contenta_vue_nuxt](https://github.com/contentacms/contenta_vue_nuxt)

```shell
curl -fSL https://github.com/contentacms/contenta_vue_nuxt/archive/master.tar.gz -o contenta_vue_nuxt.tar.gz
tar -xzf contenta_vue_nuxt.tar.gz && mv contenta_vue_nuxt-master contenta_vue_nuxt
cp ddev-files/docker-compose.vue_nuxt.yaml.dis .ddev/docker-compose.vue_nuxt.yaml
```

_Note_: _Npm_ is included in the docker service and used to install this project,
if you want to install the project locally (npm install), edit and switch
__command__ line in __.ddev/docker-compose.vue_nuxt.yaml__ file.
To avoid re-install on each restart you can switch the __command__ after the first
launch.

Change Nuxt script values in __package.json__:

```json
"scripts": {
  "dev": "HOST=0.0.0.0 node_modules/.bin/nuxt",
```

Set Nuxt values in __contenta_vue_nuxt/nuxt.config.js__, change __serverBaseUrl__:

```json
const serverBaseUrl = 'http://contentajs.ddev.local';
```

#### (Optionnal) React + Next frontend

- [https://github.com/contentacms/contenta_react_next](https://github.com/contentacms/contenta_react_next)

```shell
curl -fSL https://github.com/contentacms/contenta_react_next/archive/master.tar.gz -o contenta_react_next.tar.gz
tar -xzf contenta_react_next.tar.gz && mv contenta_react_next-master contenta_react_next
cp ddev-files/docker-compose.react_next.yaml.dis .ddev/docker-compose.react_next.yaml
```

_Note_: _Yarn_ is included in the docker service and used to install this project,
if you want to install the project locally (yarn install), edit and switch
__command__ line in __.ddev/docker-compose.react_next.yaml__
To avoid re-install on each restart you can switch the __command__ after the first
launch..

Prepare React values :

```shell
cp contenta_react_next/reactjs/.env.default contenta_react_next/reactjs/.env
```

Edit __reactjs/.env__ and set BACKEND_URL

```shell
BACKEND_URL=http://contentajs.ddev.local
```

## Launch

```shell
ddev start
```

### Install ContentaCMS

```shell
ddev exec drush si contenta_jsonapi --account-pass=admin
```

Open CORS on ContentaCMS, edit __contentacms/web/sites/default/services.yml__ and
replace __allowedOrigins__

```yml
    allowedOrigins:
      - '*'
```

### Restart for ContentaJS to connect to ContentaCMS

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

If installed, access the vue frontend from:

- [http://front-vue.ddev.local](http://front-vue.ddev.local)

If installed, access the react frontend from:

- [http://front-react.ddev.local](http://front-vue.ddev.local)

## Issues

ContentaJS:

- api path uri are _contenta.ddev.local_ instead of _contentajs.ddev.local_

React + Next consumer:

- Images are loaded from _front-react.ddev.local_ instead of _contenta.ddev.local_

Vue + Nuxt consumer:

- Images are loaded from _front-vue.ddev.local_ instead of _contenta.ddev.local_, see this [PR](https://github.com/contentacms/contenta_vue_nuxt/pull/48)
