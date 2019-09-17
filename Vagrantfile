Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/bionic64"
  config.vm.hostname = "vagrant-mapcache-sandbox"
  config.vm.synced_folder ".", "/vagrant", type: "virtualbox"
  config.vm.network "forwarded_port", guest: 80, host: 8842
  config.vm.provision "shell", run: "always", inline: <<-SHELL

	# Mise en place des dépendances
	add-apt-repository -y ppa:ubuntugis/ubuntugis-unstable
	apt-get update
	apt-get install -y cmake libspatialite-dev libfcgi-dev libproj-dev \
		libgeos-dev libgdal-dev libtiff-dev libgeotiff-dev \
		apache2-dev libpcre3-dev libsqlite3-dev libdb-dev \
		libxml2-utils apache2 gdal-bin
	apt-get install -y libpixman-1-dev libapr1-dev
	apt-get install -y sqlite3

	# Compilation de MapCache
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

	# Réglages d'ensemble
	cat <<-EOF > /etc/apache2/mods-enabled/mapcache.load
		LoadModule mapcache_module /usr/lib/apache2/modules/mod_mapcache.so
		<Directory /tmp/mc>
		Require all granted
		</Directory>
		EOF
	mkdir -p /tmp/mc

	# mapcache-test: Réglages pour le petit test de bon fonctionnement
	#   L'URL depuis l'hôte commence par "http://localhost:8842/mapcache-test?"
	cat <<-EOF > /etc/apache2/conf-enabled/mapcache-test.conf
		<IfModule mapcache_module>
		MapCacheAlias "/mapcache-test" "/tmp/mc/mapcache-test.xml"
		</IfModule>
		EOF
	cat <<-EOF > /tmp/mc/mapcache-test.xml
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

	# mapcache-dim2nd: Réglages pour des dimensions de second niveau
	rm -f /tmp/mc/dim.sqlite
	sqlite3 /tmp/mc/dim.sqlite <<-EOF
		PRAGMA foreign_keys=OFF;
		BEGIN TRANSACTION;
		CREATE TABLE dim(groupe,item);
		INSERT INTO "dim" VALUES('srtm','hillshade');
		INSERT INTO "dim" VALUES('srtm','color');
		INSERT INTO "dim" VALUES('srtm','hillshade-color');
		INSERT INTO "dim" VALUES('osm','base');
		INSERT INTO "dim" VALUES('osm','topo-osm');
		INSERT INTO "dim" VALUES('topo','topo-osm');
		INSERT INTO "dim" VALUES('topo','topo');
		INSERT INTO "dim" VALUES('osm','overlay');
		COMMIT;
		EOF
	cat <<-EOF > /etc/apache2/conf-enabled/mapcache-dim2nd.conf
		<IfModule mapcache_module>
		MapCacheAlias "/mapcache-dim2nd" "/tmp/mc/mapcache-dim2nd.xml"
		</IfModule>
		EOF
	cat <<-EOF > /tmp/mc/mapcache-dim2nd.xml
		<?xml version="1.0" encoding="UTF-8"?>
		<mapcache>
		<source name="base" type="wms">
		<http><url>http://ows.terrestris.de/osm/service?</url></http>
		<getmap><params>
		<format>image/png</format>
		<layers>OSM-WMS</layers>
		</params></getmap>
		</source>
		<source name="overlay" type="wms">
		<http><url>http://ows.terrestris.de/osm/service?</url></http>
		<getmap><params>
		<format>image/png</format>
		<layers>OSM-Overlay-WMS</layers>
		</params></getmap>
		</source>
		<source name="topo" type="wms">
		<http><url>http://ows.terrestris.de/osm/service?</url></http>
		<getmap><params>
		<format>image/png</format>
		<layers>TOPO-WMS</layers>
		</params></getmap>
		</source>
		<source name="topo-osm" type="wms">
		<http><url>http://ows.terrestris.de/osm/service?</url></http>
		<getmap><params>
		<format>image/png</format>
		<layers>TOPO-OSM-WMS</layers>
		</params></getmap>
		</source>
		<source name="hillshade" type="wms">
		<http><url>http://ows.terrestris.de/osm/service?</url></http>
		<getmap><params>
		<format>image/png</format>
		<layers>SRTM30-Hillshade</layers>
		</params></getmap>
		</source>
		<source name="color" type="wms">
		<http><url>http://ows.terrestris.de/osm/service?</url></http>
		<getmap><params>
		<format>image/png</format>
		<layers>SRTM30-Colored</layers>
		</params></getmap>
		</source>
		<source name="hillshade-color" type="wms">
		<http><url>http://ows.terrestris.de/osm/service?</url></http>
		<getmap><params>
		<format>image/png</format>
		<layers>SRTM30-Colored-Hillshade</layers>
		</params></getmap>
		</source>
		<cache name="base" type="sqlite3">
		<dbfile>/tmp/mc/dim2nd/base.sqlite3</dbfile>
		</cache>
		<cache name="overlay" type="sqlite3">
		<dbfile>/tmp/mc/dim2nd/overlay.sqlite3</dbfile>
		</cache>
		<cache name="topo" type="sqlite3">
		<dbfile>/tmp/mc/dim2nd/topo.sqlite3</dbfile>
		</cache>
		<cache name="topo-osm" type="sqlite3">
		<dbfile>/tmp/mc/dim2nd/topo-osm.sqlite3</dbfile>
		</cache>
		<cache name="hillshade" type="sqlite3">
		<dbfile>/tmp/mc/dim2nd/hillshade.sqlite3</dbfile>
		</cache>
		<cache name="color" type="sqlite3">
		<dbfile>/tmp/mc/dim2nd/color.sqlite3</dbfile>
		</cache>
		<cache name="hillshade-color" type="sqlite3">
		<dbfile>/tmp/mc/dim2nd/hillshade-color.sqlite3</dbfile>
		</cache>
		<tileset name="base">
		<source>base</source>
		<cache>base</cache>
		<grid>WGS84</grid>
		<format>PNG</format>
		</tileset>
		<tileset name="overlay">
		<source>overlay</source>
		<cache>overlay</cache>
		<grid>WGS84</grid>
		<format>PNG</format>
		</tileset>
		<tileset name="topo">
		<source>topo</source>
		<cache>topo</cache>
		<grid>WGS84</grid>
		<format>PNG</format>
		</tileset>
		<tileset name="topo-osm">
		<source>topo-osm</source>
		<cache>topo-osm</cache>
		<grid>WGS84</grid>
		<format>PNG</format>
		</tileset>
		<tileset name="hillshade">
		<source>hillshade</source>
		<cache>hillshade</cache>
		<grid>WGS84</grid>
		<format>PNG</format>
		</tileset>
		<tileset name="color">
		<source>color</source>
		<cache>color</cache>
		<grid>WGS84</grid>
		<format>PNG</format>
		</tileset>
		<tileset name="hillshade-color">
		<source>hillshade-color</source>
		<cache>hillshade-color</cache>
		<grid>WGS84</grid>
		<format>PNG</format>
		</tileset>
		<service type="wmts" enabled="true"/>
		<service type="wms" enabled="true"/>
		<log_level>debug</log_level>
		</mapcache>
		EOF
	#

	# Relance d'Apache pour le prise en compte des réglages de MapCache
	chown -R www-data:www-data /tmp/mc
	apachectl -k stop
	apachectl -k start
	SHELL
end
