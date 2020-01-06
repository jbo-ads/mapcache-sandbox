#!/bin/bash

bindir=/share/bin
if [ ! -e ${bindir} ]
then
  bindir="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"
fi

sed -i '/^LogLevel/s/ mapcache:[a-z0-9]*//' /etc/apache2/apache2.conf
sed -i '/^LogLevel/s/$/ mapcache:debug/' /etc/apache2/apache2.conf

for conf in world
do
  ${bindir}/conf-mapcache-${conf}.sh
done
