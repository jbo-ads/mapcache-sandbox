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
	apt-get install -y dc

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
	rm /etc/apache2/conf-enabled/mapcache-*.conf

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
		<grid>GoogleMapsCompatible</grid>
		<format>PNG</format>
		</tileset>
		<!-- terrestris-topo -->
		<source name="terrestris-topo" type="wms">
		<http><url>http://ows.terrestris.de/osm/service?</url></http>
		<getmap><params>
		<format>image/png</format>
		<layers>TOPO-WMS</layers>
		</params></getmap>
		</source>
		<cache name="terrestris-topo" type="sqlite3">
		<dbfile>/tmp/mc/source/terrestris-topo.sqlite3</dbfile>
		</cache>
		<tileset name="terrestris-topo">
		<source>terrestris-topo</source>
		<cache>terrestris-topo</cache>
		<grid>GoogleMapsCompatible</grid>
		<format>PNG</format>
		</tileset>
		<!-- terrestris-topo-osm -->
		<source name="terrestris-topo-osm" type="wms">
		<http><url>http://ows.terrestris.de/osm/service?</url></http>
		<getmap><params>
		<format>image/png</format>
		<layers>TOPO-OSM-WMS</layers>
		</params></getmap>
		</source>
		<cache name="terrestris-topo-osm" type="sqlite3">
		<dbfile>/tmp/mc/source/terrestris-topo-osm.sqlite3</dbfile>
		</cache>
		<tileset name="terrestris-topo-osm">
		<source>terrestris-topo-osm</source>
		<cache>terrestris-topo-osm</cache>
		<grid>GoogleMapsCompatible</grid>
		<format>PNG</format>
		</tileset>
		<!-- terrestris-srtm30-color -->
		<source name="terrestris-srtm30-color" type="wms">
		<http><url>http://ows.terrestris.de/osm/service?</url></http>
		<getmap><params>
		<format>image/png</format>
		<layers>SRTM30-Colored</layers>
		</params></getmap>
		</source>
		<cache name="terrestris-srtm30-color" type="sqlite3">
		<dbfile>/tmp/mc/source/terrestris-srtm30-color.sqlite3</dbfile>
		</cache>
		<tileset name="terrestris-srtm30-color">
		<source>terrestris-srtm30-color</source>
		<cache>terrestris-srtm30-color</cache>
		<grid>GoogleMapsCompatible</grid>
		<format>PNG</format>
		</tileset>
		<!-- terrestris-srtm30-hillshade -->
		<source name="terrestris-srtm30-hillshade" type="wms">
		<http><url>http://ows.terrestris.de/osm/service?</url></http>
		<getmap><params>
		<format>image/png</format>
		<layers>SRTM30-Hillshade</layers>
		</params></getmap>
		</source>
		<cache name="terrestris-srtm30-hillshade" type="sqlite3">
		<dbfile>/tmp/mc/source/terrestris-srtm30-hillshade.sqlite3</dbfile>
		</cache>
		<tileset name="terrestris-srtm30-hillshade">
		<source>terrestris-srtm30-hillshade</source>
		<cache>terrestris-srtm30-hillshade</cache>
		<grid>GoogleMapsCompatible</grid>
		<format>PNG</format>
		</tileset>
		<!-- terrestris-srtm30-color-hillshade -->
		<source name="terrestris-srtm30-color-hillshade" type="wms">
		<http><url>http://ows.terrestris.de/osm/service?</url></http>
		<getmap><params>
		<format>image/png</format>
		<layers>SRTM30-Colored-Hillshade</layers>
		</params></getmap>
		</source>
		<cache name="terrestris-srtm30-color-hillshade" type="sqlite3">
		<dbfile>/tmp/mc/source/terrestris-srtm30-color-hillshade.sqlite3</dbfile>
		</cache>
		<tileset name="terrestris-srtm30-color-hillshade">
		<source>terrestris-srtm30-color-hillshade</source>
		<cache>terrestris-srtm30-color-hillshade</cache>
		<grid>GoogleMapsCompatible</grid>
		<format>PNG</format>
		</tileset>
		<!-- gibs-bluemarble -->
		<source name="gibs-bluemarble" type="wms">
		<http><url>https://gibs.earthdata.nasa.gov/wms/epsg3857/best/wms.cgi?</url></http>
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
		<grid>GoogleMapsCompatible</grid>
		<format>PNG</format>
		</tileset>
		<service type="wmts" enabled="true"/>
		<service type="wms" enabled="true"/>
		<log_level>debug</log_level>
		<threaded_fetching>true</threaded_fetching>
		</mapcache>
		EOF

	# Relance d'Apache pour la prise en compte des premiers réglages de MapCache
	chown -R vagrant:vagrant /tmp/mc
	sed -i 's/www-data/vagrant/' /etc/apache2/envvars
	sed -i '/^LogLevel/s/ mapcache:[a-z0-9]*//' /etc/apache2/apache2.conf
	sed -i '/^LogLevel/s/$/ mapcache:debug/' /etc/apache2/apache2.conf
	apachectl -k stop
	apachectl -k start

	# mapcache-produits: Création de produits simulés et réglages correspondants
	# dans MapCache
	#   L'URL depuis l'hôte commence par "http://localhost:8842/mapcache-produit?"
	cat <<-EOF > /etc/apache2/conf-enabled/mapcache-produit.conf
		<IfModule mapcache_module>
		MapCacheAlias "/mapcache-produit" "/tmp/mc/mapcache-produit.xml"
		</IfModule>
		EOF
	cat <<-EOF > /tmp/mc/mapcache-produit.xml
		<?xml version="1.0" encoding="UTF-8"?>
		<mapcache>
		EOF
	cat <<-EOF > /vagrant/produits.js
		var produits = new ol.layer.Group({
		title: 'Produits', fold: 'open' });
		EOF
	cat <<-EOF > /vagrant/dimproduits.sql
		PRAGMA foreign_keys=OFF;
		BEGIN TRANSACTION;
		CREATE TABLE dim(milieu TEXT, produit TEXT);
		EOF
	mkdir -p /tmp/mc/produit/tiff
	for prod in \
		arcachon:-119075:5565095:carre:terrestris-osm:littoral \
		laruns:-47548:5310224:horizontal:terrestris-osm:montagne \
		somme:180903:6483586:vertical:terrestris-osm:littoral \
		ossau:-49211:5288978:vertical:terrestris-srtm30-color-hillshade:montagne \
		gourette:-37017:5305633:horizontal:terrestris-srtm30-hillshade:montagne \
		larhune:-182061:5359134:horizontal:terrestris-osm:montagne,littoral
	do
		IFS=':' read -a argv <<< "$prod"
		n=${argv[0]}
		x=$(tr '-' '_' <<< ${argv[1]})
		y=$(tr '-' '_' <<< ${argv[2]})
		d=${argv[3]}
		c=${argv[4]}
		if [ $d == "carre" ]; then w=5;h=5;
		elif [ $d == "horizontal" ]; then w=6;h=4;
		elif [ $d == "vertical" ]; then w=4;h=4;
		else w=3;h=3;
		fi
		l=19567.88
		minx=$(echo "2k $x $l $w 2/*-pq" | dc)
		miny=$(echo "2k $y $l $h 2/*-pq" | dc)
		maxx=$(echo "2k $x $l $w 2/*+pq" | dc)
		maxy=$(echo "2k $y $l $h 2/*+pq" | dc)
		width=$(echo 256 $w *pq | dc)
		height=$(echo 256 $h *pq | dc)
		pre="http://localhost:80/mapcache-source?service=wms&request=getmap&srs=epsg:3857"
		url="${pre}&bbox=${minx},${miny},${maxx},${maxy}&width=${width}&height=${height}&layers=$c"
		curl "$url" > /vagrant/${n}.jpg 2>/dev/null
		gdal_translate -a_srs EPSG:3857 -a_ullr ${minx} ${maxy} ${maxx} ${miny} \
			/vagrant/${n}.jpg /vagrant/${n}.tif
		cp /vagrant/${n}.tif /tmp/mc/produit/tiff
		cat <<-EOF >> /tmp/mc/mapcache-produit.xml
			<!-- $n: ${argv[1]}, ${argv[2]} ($width x $height) -->
			<source name="$n" type="gdal">
			<data>/tmp/mc/produit/tiff/$n.tif</data>
			</source>
			<cache name="$n" type="sqlite3">
			<dbfile>/tmp/mc/produit/$n.sqlite3</dbfile>
			</cache>
			<tileset name="$n">
			<source>$n</source>
			<cache>$n</cache>
			<grid>GoogleMapsCompatible</grid>
			<format>PNG</format>
			</tileset>
			EOF
		cat <<-EOF >> /vagrant/produits.js
			var $n = new ol.layer.Tile({
			title: '$n: [ $minx, $miny, $maxx, $maxy ]',
			type: 'base', visible: false,
			source: new ol.source.TileWMS({
			url: 'http://'+location.host+'/mapcache-produit?',
			params: {'LAYERS': '$n', 'VERSION': '1.1.1'}
			}) });
			produits.getLayers().push($n);
			EOF
		IFS=',' read -a milieu <<< "${argv[5]},tout"
		for m in "${milieu[@]}"
		do
			cat <<-EOF >> /vagrant/dimproduits.sql
				INSERT INTO "dim" VALUES("$m","$n");
				EOF
		done
	done
	cat <<-EOF >> /tmp/mc/mapcache-produit.xml
		<service type="wmts" enabled="true"/>
		<service type="wms" enabled="true"/>
		<log_level>debug</log_level>
		<threaded_fetching>true</threaded_fetching>
		</mapcache>
		EOF
	cat <<-EOF >> /vagrant/dimproduits.sql
		COMMIT;
		EOF

	# Mise en place d'une page de navigation pour afficher les couches
	#   L'URL depuis l'hôte est "http://localhost:8842/mapcache-sandbox-browser/"
	mkdir -p /var/www/html/mapcache-sandbox-browser
	mv /vagrant/produits.js /var/www/html/mapcache-sandbox-browser
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
		<script src="produits.js"></script>
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
		var terrestris_osm = new ol.layer.Tile({
		title: 'OSM (Terrestris)', type: 'base', visible: false,
		source: new ol.source.TileWMS({
		url: 'http://'+location.host+'/mapcache-source?',
		params: {'LAYERS': 'terrestris-osm', 'VERSION': '1.1.1'}
		}) });
		var terrestris_topo = new ol.layer.Tile({
		title: 'TOPO (Terrestris)', type: 'base', visible: false,
		source: new ol.source.TileWMS({
		url: 'http://'+location.host+'/mapcache-source?',
		params: {'LAYERS': 'terrestris-topo', 'VERSION': '1.1.1'}
		}) });
		var terrestris_topo_osm = new ol.layer.Tile({
		title: 'TOPO OSM (Terrestris)', type: 'base', visible: false,
		source: new ol.source.TileWMS({
		url: 'http://'+location.host+'/mapcache-source?',
		params: {'LAYERS': 'terrestris-topo-osm', 'VERSION': '1.1.1'}
		}) });
		var terrestris_srtm30_color = new ol.layer.Tile({
		title: 'SRTM30 Colored (Terrestris)', type: 'base', visible: false,
		source: new ol.source.TileWMS({
		url: 'http://'+location.host+'/mapcache-source?',
		params: {'LAYERS': 'terrestris-srtm30-color', 'VERSION': '1.1.1'}
		}) });
		var terrestris_srtm30_hillshade = new ol.layer.Tile({
		title: 'SRTM30 Hillshade (Terrestris)', type: 'base', visible: false,
		source: new ol.source.TileWMS({
		url: 'http://'+location.host+'/mapcache-source?',
		params: {'LAYERS': 'terrestris-srtm30-hillshade', 'VERSION': '1.1.1'}
		}) });
		var terrestris_srtm30_color_hillshade = new ol.layer.Tile({
		title: 'SRTM30 Colored Hillshade (Terrestris)', type: 'base', visible: false,
		source: new ol.source.TileWMS({
		url: 'http://'+location.host+'/mapcache-source?',
		params: {'LAYERS': 'terrestris-srtm30-color-hillshade', 'VERSION': '1.1.1'}
		}) });
		var terrestris = new ol.layer.Group({
		title: 'Terrestris',
		fold: 'open',
		layers: [ terrestris_osm, terrestris_topo, terrestris_topo_osm,
		terrestris_srtm30_color, terrestris_srtm30_hillshade,
		terrestris_srtm30_color_hillshade ]
		});
		var gibs_bluemarble = new ol.layer.Tile({
		title: 'Blue Marble (GIBS)', type: 'base', visible: false,
		source: new ol.source.TileWMS({
		url: 'http://'+location.host+'/mapcache-source?',
		params: {'LAYERS': 'gibs-bluemarble', 'VERSION': '1.1.1'}
		}) });
		var layers = [ produits, terrestris, gibs_bluemarble, sanity_check ];
		var map = new ol.Map({ target: 'map', layers: layers, view: view });
		map.addControl(new ol.control.LayerSwitcher());
		</script>
		</body>
		</html>
		EOF

	# Relance d'Apache pour la prise en compte des nouveaux réglages de MapCache
	chown -R vagrant:vagrant /tmp/mc
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
