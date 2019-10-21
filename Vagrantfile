Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/bionic64"
  config.vm.hostname = "vagrant-mapcache-sandbox"
  config.vm.synced_folder ".", "/vagrant", type: "virtualbox"
  config.vm.network "forwarded_port", guest: 80, host: 8842
  config.vm.network "forwarded_port", guest: 9200, host: 9242
  config.vm.provider "virtualbox" do |v|
    v.memory = 2048
  end
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
	apt-get install -y postgresql-10 postgresql-server-dev-10 libpq-dev
	apt-get install -y default-jdk
	curl -s "https://artifacts.elastic.co/GPG-KEY-elasticsearch" | apt-key add -
	add-apt-repository -y "deb https://artifacts.elastic.co/packages/7.x/apt stable main"
	apt-get update
	apt-get install -y elasticsearch

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
		-DWITH_POSTGRESQL=ON \
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
		<threaded_fetching>true</threaded_fetching>
		</mapcache>
		EOF
	cp /vagrant/mapcache/tests/data/world.tif /tmp/mc

	# mapcache-source: Réglages pour diverses sources WMS destinées à construire
	# des produits simulés
	#   L'URL depuis l'hôte commence par "http://localhost:8842/mapcache-source?"
	cat <<-EOF > /etc/apache2/conf-enabled/mapcache-source.conf
		<IfModule mapcache_module>
		MapCacheAlias "/mapcache-source" "/tmp/mc/mapcache-source.xml"
		</IfModule>
		EOF
	cat <<-EOF > /tmp/mc/mapcache-source.xml
		<?xml version="1.0" encoding="UTF-8"?>
		<mapcache>
		<!-- terrestris-osm -->
		<source name="terrestris-osm" type="wms">
		<http><url>http://ows.terrestris.de/osm/service?</url></http>
		<getmap><params>
		<format>image/png</format>
		<layers>OSM-WMS</layers>
		</params></getmap>
		</source>
		<cache name="terrestris-osm" type="sqlite3">
		<dbfile>/tmp/mc/source/terrestris-osm.sqlite3</dbfile>
		</cache>
		<tileset name="terrestris-osm">
		<source>terrestris-osm</source>
		<cache>terrestris-osm</cache>
		<grid>WGS84</grid>
		<format>PNG</format>
		</tileset>
		<!-- gibs-bluemarble -->
		<source name="gibs-bluemarble" type="wms">
		<http><url>https://gibs.earthdata.nasa.gov/wms/epsg4326/best/wms.cgi?</url></http>
		<getmap><params>
		<format>image/png</format>
		<layers>BlueMarble_NextGeneration</layers>
		</params></getmap>
		</source>
		<cache name="gibs-bluemarble" type="sqlite3">
		<dbfile>/tmp/mc/source/gibs-bluemarble.sqlite3</dbfile>
		</cache>
		<tileset name="gibs-bluemarble">
		<source>gibs-bluemarble</source>
		<cache>gibs-bluemarble</cache>
		<grid>WGS84</grid>
		<format>PNG</format>
		</tileset>
		<service type="wmts" enabled="true"/>
		<service type="wms" enabled="true"/>
		<log_level>debug</log_level>
		</mapcache>
		EOF

	# Mise en place d'une page de navigation pour afficher les couches
	#   L'URL depuis l'hôte est "http://localhost:8842/mapcache-sandbox-browser/"
	mkdir -p /var/www/html/mapcache-sandbox-browser
	cat <<-EOF > /var/www/html/mapcache-sandbox-browser/index.html
		<!doctype html>
		<html>
		<head>
		<title>MapCache sandbox browser</title>
		<link href="https://cdn.jsdelivr.net/gh/openlayers/openlayers.github.io@master/en/v6.0.1/css/ol.css"
		rel="stylesheet" type="text/css" />
		<link href="https://unpkg.com/ol-layerswitcher@3.4.0/src/ol-layerswitcher.css"
		rel="stylesheet" type="text/css" />
		<style type="text/css">
		.map {
		height: 800px;
		width: 100%;
		}
		</style>
		<script
		src="https://cdn.jsdelivr.net/gh/openlayers/openlayers.github.io@master/en/v6.0.1/build/ol.js">
		</script>
		<script src="https://unpkg.com/ol-layerswitcher@3.4.0">
		</script>
		</head>
		<body>
		<h2>MapCache sandbox browser</h2>
		<div id="map" class="map"></div>
		<script type="text/javascript">
		var view = new ol.View({ projection: 'EPSG:3857', center: ol.proj.fromLonLat([0, 0]), zoom: 0 });
		var sanity_check = new ol.layer.Tile({
		title: 'Sanity check layer', type: 'base',
		source: new ol.source.TileWMS({
		url: 'http://'+location.host+'/mapcache-test?',
		params: {'LAYERS': 'global', 'VERSION': '1.1.1'}
		}) });
		var layers = [ sanity_check ];
		var map = new ol.Map({ target: 'map', layers: layers, view: view });
		map.addControl(new ol.control.LayerSwitcher());
		</script>
		</body>
		</html>
		EOF

	# Relance d'Apache pour la prise en compte des réglages de MapCache
	chown -R vagrant:vagrant /tmp/mc
	sed -i 's/www-data/vagrant/' /etc/apache2/envvars
	apachectl -k stop
	apachectl -k start

	# Mise en place de PostgreSQL
	sed -i 's/md5/trust/' /etc/postgresql/10/main/pg_hba.conf
	sed -i 's/peer/trust/' /etc/postgresql/10/main/pg_hba.conf
	echo "log_statement = 'all'" | sudo tee -a /etc/postgresql/10/main/postgresql.conf
	service postgresql restart
	psql -U postgres -c 'DROP DATABASE mapcache;'
	psql -U postgres -c 'CREATE DATABASE mapcache;'

	# Mise en place d'ElasticSearch
	sed -i \
		-e "/^#node.name: /s/^/node.name: vagrant-mapcache-sandbox /" \
		-e "/^#network.host: /s/^/network.host: 0.0.0.0 /" \
		-e "/^#cluster.initial_master_nodes: /s/^/cluster.initial_master_nodes: vagrant-mapcache-sandbox /" \
		/etc/elasticsearch/elasticsearch.yml
	systemctl enable elasticsearch.service
	systemctl start elasticsearch.service
	curl -s -XDELETE "http://localhost:9200/dim"
	curl -s "http://localhost:9200/"

	SHELL
end
