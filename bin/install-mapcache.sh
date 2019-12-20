#!/bin/bash

srcdir=/usr/local/src
mkdir -p ${srcdir}
cd ${srcdir}
if [ ! -d mapcache ]
then
  git clone https://github.com/jbo-ads/mapcache.git
  cd mapcache
  git checkout master
fi

cd ${srcdir}
if [ ! -d mapcache/build ]
then
  mkdir mapcache/build
  cd mapcache/build
  cmake .. -DCMAKE_INSTALL_PREFIX=/usr \
           -DWITH_TIFF=ON \
           -DWITH_GEOTIFF=ON \
           -DWITH_TIFF_WRITE_SUPPORT=ON \
           -DWITH_PCRE=ON \
           -DWITH_SQLITE=ON \
           -DWITH_POSTGRESQL=ON \
           -DWITH_BERKELEY_DB=ON
fi

cd ${srcdir}/mapcache/build
make
make install

if [ ! -f /etc/apache2/mods-enabled/mapcache.load ]
then
  cat <<-EOF > /etc/apache2/mods-enabled/mapcache.load
	LoadModule mapcache_module /usr/lib/apache2/modules/mod_mapcache.so
	<Directory /tmp/mcdata>
	Require all granted
	</Directory>
	<Directory /share/caches>
	Require all granted
	</Directory>
	EOF
fi

rm -f /etc/apache2/conf-enabled/mapcache-*.conf
