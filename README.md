# ContentaCMS - ContentaJs with Docker

## What it is?

This project is a basic Drupal [ContentaCMS](https://www.contentacms.org/) / [ContentaJS](https://github.com/contentacms/contentajs#readme) environment stack with ddev.

## System Requirements

* [Docker](https://store.docker.com/search?type=edition&offering=community)
* [Docker Compose](https://docs.docker.com/compose/install/)
* [Composer](https://getcomposer.org)
* [ddev](https://github.com/drud/ddev#ddev)

Tested on Ubuntu, referer to [ddev](https://ddev.readthedocs.io/en/latest/#system-requirements) for more details.

## Features

Include default ddev stack (Nginx, Php 7.1 fpm, Mariadb, PhpMyAdmin) and extra services:

* [Pm2](http://pm2.keymetrics.io/docs/usage/docker-pm2-nodejs/)
* [Redis](https://hub.docker.com/_/redis/)
* [Portainer](https://hub.docker.com/r/portainer/portainer)

## Installation

### ddev Installation (Linux example)

* https://ddev.readthedocs.io/en/latest/#installation

```shell
curl -L https://raw.githubusercontent.com/drud/ddev/master/install_ddev.sh | bash
```

### Clone this project!

```shell
git clone https://github.com/Mogtofu33/contenta-ddev
# All next steps need to be done from this project.
cd contenta-ddev
```

### Download ContentaCMS

```shell
composer create-project contentacms/contenta-jsonapi-project contentacms \
--stability dev --no-interaction --remove-vcs --no-progress --prefer-dist
```

## Init ddev project

```shell
ddev config --projectname contenta --docroot contentacms/web --additional-hostnames contentajs
```

Fix Drupal files tmp permissions (or after install change files tmp folder in Drupal settings)

```shell
mkdir -p contentacms/web/sites/default/files/tmp
chmod 777 contentacms/web/sites/default/files
```

### Download ContentaJs

```shell
curl -fSL https://github.com/contentacms/contentajs/archive/master.tar.gz -o contenta.tar.gz
tar -xzf contenta.tar.gz
mv contentajs-master contentajs
```

Edit contentajs/package.json and replace _"start"_ with:

```
"start": "npm run build && pm2-runtime start ecosystem.config.js",
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

### Restart for Contentajs to connect to ContentaCMS

```shell
ddev restart
```

## Usage

For all ddev commands see https://ddev.readthedocs.io/en/latest/users/cli-usage

This stack include a Docker web UI, you can access it on port 9000
* http://contenta.ddev.local:9000

ContentaCMS Backoffice
* http://contenta.ddev.local

ContentaJS
* http://contentajs.ddev.local/api

## Consumer example

### React + Next frontend

Create a hostname for this service in ddev

```shell
ddev config --projectname contenta --docroot contentacms/web --additional-hostnames contentajs,front-react
```

Grab the Sample project:

```shell
git clone https://github.com/contentacms/contenta_react_next.git
mv .ddev/docker-compose.react_next.yaml.dis .ddev/docker-compose.react_next.yaml
```

Prepare React values :

```shell
cp contenta_react_next/reactjs/.env.default contenta_react_next/reactjs/.env
vi contenta_react_next/reactjs/.env
```

Change BACKEND_URL

```shell
BACKEND_URL=http://pm2:3000
```

Access the new frontend from:

* http://front-react.ddev.local

### AngularJs

Create a hostname for this service in ddev

```shell
ddev config --projectname contenta --docroot contentacms/web --additional-hostnames contentajs,front-angular
```

```shell
git clone https://github.com/contentacms/contenta_angular.git
mv .ddev/docker-compose.angular.yaml.dis .ddev/docker-compose.angular.yaml
```

Prepare Angular values and change urls to http://contentajs.ddev.local/api and
http://contenta.ddev.local for images.

```shell
vi contenta_angular/src/ngsw-config.json
vi contenta_angular/src/environments/environment.ts
```

Access the new frontend from:

* http://front-angular.ddev.local
