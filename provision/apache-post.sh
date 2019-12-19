#!/bin/bash

useradd -u $(stat -c '%u' /share) -U mapcache 2>/dev/null || true
u=$(id -nu $(stat -c '%u' /share))
sed -i "s/www-data/${u}/" /etc/apache2/envvars

apachectl -k start
sleep 2
