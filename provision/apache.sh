#!/bin/bash

apachectl -k stop
sleep 2

sed -i '/^LogLevel/s/ mapcache:[a-z0-9]*//' /etc/apache2/apache2.conf
sed -i '/^LogLevel/s/$/ mapcache:debug/' /etc/apache2/apache2.conf

useradd -u $(stat -c '%u' /share) -U mapcache 2>/dev/null || true
u=$(id -nu $(stat -c '%u' /share))
sed -i "s/www-data/${u}/" /etc/apache2/envvars

apachectl -k start
sleep 2
