#!/bin/bash

apachectl -k stop
sleep 2

useradd -u $(stat -c '%u' /share) -U apacheuser 2>/dev/null || true
u=$(id -nu $(stat -c '%u' /share))
sed -i "s/www-data/${u}/" /etc/apache2/envvars

apachectl -k start
sleep 2
