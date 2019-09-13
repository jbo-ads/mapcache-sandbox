Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/bionic64"
  config.vm.hostname = "vagrant-mapcache-sandbox"
  config.vm.synced_folder ".", "/vagrant", type: "virtualbox"
  config.vm.network "forwarded_port", guest: 80, host: 8842
  config.vm.provision "shell", run: "always", inline: <<-SHELL
	mv /etc/apt/sources.list.d/pgdg* /tmp
	apt-get purge -y libgdal* libgeos* libspatialite*
	add-apt-repository -y ppa:ubuntugis/ubuntugis-unstable
	apt-get update
	apt-get install -y cmake libspatialite-dev libfcgi-dev libproj-dev \
		libgeos-dev libgdal-dev libtiff-dev libgeotiff-dev \
		apache2-dev libpcre3-dev libsqlite3-dev libdb-dev \
		libxml2-utils apache2 gdal-bin
	apt-get install -y libpixman-1-dev libapr1-dev

	cd /vagrant
	test -d mapcache || git clone https://github.com/jbo-ads/mapcache.git
	cd mapcache
	git checkout master
	rm -rf build
	mkdir build
	cd build
	cmake .. -DCMAKE_INSTALL_PREFIX=/usr \
		-DWITH_TIFF=ON \
		-DWITH_GEOTIFF=ON \
		-DWITH_TIFF_WRITE_SUPPORT=ON \
		-DWITH_PCRE=ON \
		-DWITH_SQLITE=ON \
		-DWITH_BERKELEY_DB=ON
	make
	make install

	mkdir -p /tmp/mc
	cat <<-EOF > /tmp/mc/mapcache.xml
		<?xml version="1.0" encoding="UTF-8"?>
		<mapcache>
		<source name="global-tif" type="gdal">
		<data>/tmp/mc/world.tif</data>
		</source>
		<cache name="disk" type="disk">
		<base>/tmp/mc</base>
		</cache>
		<tileset name="global">
		<cache>disk</cache>
		<source>global-tif</source>
		<grid maxzoom="17">GoogleMapsCompatible</grid>
		<format>JPEG</format>
		<metatile>1 1</metatile>
		</tileset>
		<service type="wmts" enabled="true"/>
		<service type="wms" enabled="true"/>
		<log_level>debug</log_level>
		</mapcache>
		EOF
	cp /vagrant/mapcache/tests/data/world.tif /tmp/mc
	chown -R www-data:www-data /tmp/mc

	cat <<-EOF > /etc/apache2/conf-enabled/mapcache.conf
		LoadModule mapcache_module /usr/lib/apache2/modules/mod_mapcache.so
		<IfModule mapcache_module>
		<Directory /tmp/mc>
		Require all granted
		</Directory>
		MapCacheAlias "/mapcache" "/tmp/mc/mapcache.xml"
		</IfModule>
		EOF
	apachectl -k stop
	apachectl -k start
	SHELL
end
