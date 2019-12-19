#!/bin/bash

export TZ=Europe/Paris
ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

apt-get update
apt-get install -y software-properties-common
add-apt-repository -y ppa:ubuntugis/ppa
apt-get update
apt-get install -y cmake libspatialite-dev libfcgi-dev libproj-dev \
                   libgeos-dev libgdal-dev libtiff-dev libgeotiff-dev \
                   apache2-dev libpcre3-dev libsqlite3-dev libdb-dev \
                   libxml2-utils apache2 gdal-bin
apt-get install -y libpixman-1-dev libapr1-dev
apt-get install -y sqlite3
apt-get install -y postgresql-10 postgresql-server-dev-10 libpq-dev
apt-get install -y default-jdk
curl -s "https://artifacts.elastic.co/GPG-KEY-elasticsearch" | apt-key add -
add-apt-repository -y "deb https://artifacts.elastic.co/packages/7.x/apt stable main"
apt-get update
apt-get install -y elasticsearch
apt-get install -y dc
apt-get install -y git gawk

mkdir -p /var/www/html/css
cd /var/www/html/css
curl -sLO 'https://cdn.jsdelivr.net/gh/openlayers/openlayers.github.io@master/en/v6.0.1/css/ol.css'
curl -sLO 'https://unpkg.com/ol-layerswitcher@3.4.0/src/ol-layerswitcher.css'

mkdir -p /var/www/html/js
cd /var/www/html/js
curl -sLO 'https://cdn.jsdelivr.net/gh/openlayers/openlayers.github.io@master/en/v6.0.1/build/ol.js'
curl -sL -o ol-layerswitcher.js 'https://unpkg.com/ol-layerswitcher@3.4.0'

