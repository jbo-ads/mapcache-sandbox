#!/bin/bash

export TZ=UTC
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
apt-get install -y git gawk vim
