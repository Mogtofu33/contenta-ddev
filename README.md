# ContentaCMS - ContentaJs with Docker

## What it is?

This project is a basic Drupal Contenta environment stack with ddev.

## System Requirements

* Docker
* Docker Compose
* Composer
* ddev

Tested on Ubuntu, referer to ddev for compatibility.

## Features

Include default ddev stack (Nginx, Php 7.1 fpm, Mariadb, PhpMyAdmin) and extra services:

* Pm2
* Redis
* Portainer

## Installation

### Ddev Installation (Linux example)

* https://ddev.readthedocs.io/en/latest/#installation

    curl -L https://raw.githubusercontent.com/drud/ddev/master/install_ddev.sh | bash
    
### Clone this project!

    git clone https:/// contenta-ddev
    # All next steps need to be done from this project.
    cd contenta-ddev

### Download ContentaCMS

    composer create-project contentacms/contenta-jsonapi-project contentacms \
    --stability dev --no-interaction --remove-vcs --no-progress --prefer-dist

## Init DDEV project

    ddev config --project-name contenta --docroot contentacms/web
    
Fix tmp permissions (or after install change files tmp folder in Drupal settings)

    mkdir -p contentacms/web/sites/default/files/tmp
    chmod 777 contentacms/web/sites/default/files/tmp

### Download ContentaJs

    curl -fSL https://github.com/contentacms/contentajs/archive/master.tar.gz -o contenta.tar.gz
    tar -xzf contenta.tar.gz
    mv contentajs-master contentajs

_Note_: Nodejs is included in the docker service and used to install the project,
if you want to install the project locally (npm install) 
Edit contentajs/package.json and replace _"start"_ with:

    "start": "npm run build && pm2-runtime start ecosystem.config.js --env production",

### Launch the stack

Copy specific Contenta files from _ddev-files_ in _.ddev_ folder

    cp ddev-files/*.yaml .ddev

    ddev start

### Install ContentaCMS

    ddev exec drupal composer run-script install:with-mysql

## Set Contentjs config and restart

    touch contentajs/config/local.yml

```yaml
cms:
  host: http://contenta.ddev.local

cors:
  origin:
    # It's OK to use '*' in local development.
    - '*'
```

    ddev restart pm2
 
### Bonus, add a React frontend

### Bonus, add an AngularJs frontend
