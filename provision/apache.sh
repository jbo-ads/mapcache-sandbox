#!/bin/bash

apachectl -k stop
sleep 2
sed -i 's/www-data/vagrant/' /etc/apache2/envvars
sed -i '/^LogLevel/s/ mapcache:[a-z0-9]*//' /etc/apache2/apache2.conf
sed -i '/^LogLevel/s/$/ mapcache:debug/' /etc/apache2/apache2.conf
