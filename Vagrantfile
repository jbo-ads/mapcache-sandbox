Vagrant.configure("2") do |config|
  config.vm.box = "hashicorp/bionic64"
  config.vm.hostname = "mapcache-sandbox"
  config.vm.synced_folder ".", "/vagrant", type: "virtualbox"
  config.vm.network "forwarded_port", guest: 80, host: 8080
  config.vm.network "forwarded_port", guest: 9200, host: 9292
  config.vm.provider "virtualbox" do |v|
    v.name = "mapcache-sandbox"
    v.memory = 4096
    v.cpus = 2
  end

  config.vm.provision "shell", inline: <<-DEPS
	# Mise en place des dépendances
	#   Ce script est exécuté une seule fois à la création de la machine virtuelle
	add-apt-repository -y ppa:ubuntugis/ppa
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
	DEPS

  config.vm.provision "shell", inline: <<-APACHE
	# Mise en place d'Apache
	#   Ce script est exécuté une seule fois à la création de la machine virtuelle
	apachectl -k stop
	sleep 2
	sed -i 's/www-data/vagrant/' /etc/apache2/envvars
	sed -i '/^LogLevel/s/ mapcache:[a-z0-9]*//' /etc/apache2/apache2.conf
	sed -i '/^LogLevel/s/$/ mapcache:debug/' /etc/apache2/apache2.conf
	APACHE

  config.vm.provision "shell", run: "always", inline: <<-MAPCACHE
	# Installation de MapCache
	#   Ce script est exécuté systématiquement, mais seules les parties de
	#   MapCache qui ne sont pas déjà en place sont reprises
	cd /vagrant
	if [ ! -d mapcache ]
	then
		git clone https://github.com/jbo-ads/mapcache.git
		cd mapcache
		git checkout master
	fi
	cd /vagrant
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
	cd /vagrant/mapcache/build
	make
	make install
	# Réglages d'ensemble
	mkdir -p /vagrant/caches
	if [ ! -f /etc/apache2/mods-enabled/mapcache.load ]
	then
		cat <<-EOF > /etc/apache2/mods-enabled/mapcache.load
			LoadModule mapcache_module /usr/lib/apache2/modules/mod_mapcache.so
			<Directory /vagrant/caches>
			Require all granted
			</Directory>
			EOF
	fi
	rm -f /etc/apache2/conf-enabled/mapcache-*.conf
	MAPCACHE

  config.vm.provision "shell", run: "always", inline: <<-OPENLAYERS_PREP
	# Préparation d'une page de navigation pour afficher les couches de MapCache
	#   L'URL depuis l'hôte est "http://localhost:8080/mapcache-sandbox-browser/"
	#   Ce script est exécuté systématiquement.
	mkdir -p /var/www/html/mapcache-sandbox-browser
	cat <<-EOF > /var/www/html/mapcache-sandbox-browser/index.html
		<!doctype html>
		<html>
		<head>
		<meta charset="utf-8"/>
		<title>MapCache</title>
		<link href="https://cdn.jsdelivr.net/gh/openlayers/openlayers.github.io@master/en/v6.0.1/css/ol.css"
		rel="stylesheet" type="text/css" />
		<link href="https://unpkg.com/ol-layerswitcher@3.4.0/src/ol-layerswitcher.css"
		rel="stylesheet" type="text/css" />
		<style type="text/css">
		.map {
		height: 98vh;
		width: 99vw;
		}
		</style>
		<script
		src="https://cdn.jsdelivr.net/gh/openlayers/openlayers.github.io@master/en/v6.0.1/build/ol.js">
		</script>
		<script src="https://unpkg.com/ol-layerswitcher@3.4.0"></script>
		<meta name="anchor" content="insertbefore"/>
		</head>
		<body>
		<div id="map" class="map"></div>
		<script type="text/javascript">
		var view = new ol.View({ projection: 'EPSG:3857', center: ol.proj.fromLonLat([0, 0]), zoom: 0 });
		var map = new ol.Map({ target: 'map', layers: layers, view: view });
		map.addControl(new ol.control.LayerSwitcher());
		</script>
		</body>
		</html>
		EOF
	OPENLAYERS_PREP

  config.vm.provision "shell", run: "always", inline: <<-MAPCACHE_TEST
	# Mise en place d'une configuration de MapCache pour vérifier son bon
	# fonctionnement
	#   L'URL depuis l'hôte commence par "http://localhost:8080/mapcache-test?"
	#   Ce script est exécuté systématiquement.
	apachectl -k stop
	sleep 2
	cp /vagrant/mapcache/tests/data/world.tif /vagrant/caches
	cat <<-EOF > /vagrant/caches/mapcache-test.xml
		<?xml version="1.0" encoding="UTF-8"?>
		<mapcache>
			<source name="global-tif" type="gdal">
				<data>/vagrant/caches/world.tif</data>
			</source>
			<cache name="disk" type="disk" layout="template">
				<template>/vagrant/caches/test/{z}/{y}/{x}.jpg</template>
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
	chown vagrant:vagrant /vagrant/caches/mapcache-test.xml
	cat <<-EOF > /etc/apache2/conf-enabled/mapcache-test.conf
		<IfModule mapcache_module>
			MapCacheAlias "/mapcache-test" "/vagrant/caches/mapcache-test.xml"
		</IfModule>
		EOF
	cat <<-EOF > /var/www/html/mapcache-sandbox-browser/mapcache-test.js
		var layers = [ ];
		var mapcache_test = new ol.layer.Tile({
			title: 'Image de test en faible résolution',
			type: 'base',
			visible: true,
			source: new ol.source.TileWMS({
				url: 'http://'+location.host+'/mapcache-test?',
				params: {'LAYERS': 'global', 'VERSION': '1.1.1'}
			})
		});
		layers.unshift(mapcache_test)
		EOF
	gawk -i inplace '/anchor/&&c==0{print l};{print}' \
		l='<script src="mapcache-test.js"></script>' \
		/var/www/html/mapcache-sandbox-browser/index.html
	apachectl -k start
	sleep 2
	MAPCACHE_TEST

  config.vm.provision "shell", run: "always", inline: <<-MAPCACHE_SOURCE
	# Mise en place d'une configuration de MapCache composée de sources WMS
	# externes
	#   L'URL depuis l'hôte commence par "http://localhost:8080/mapcache-source?"
	#   Ce script est exécuté systématiquement.
	apachectl -k stop
	sleep 2
	cat <<-EOF > /vagrant/caches/mapcache-source.xml
		<?xml version="1.0" encoding="UTF-8"?>
		<mapcache>
		EOF
	cat <<-EOF > /var/www/html/mapcache-sandbox-browser/mapcache-source.js
		var mapcache_source = new ol.layer.Group({
			title: 'Sources externes',
			fold: 'open'
		});
		layers.unshift(mapcache_source)
		EOF
	for source in \
		"HeiGIT&OSM&https://maps.heigit.org/osm-wms/service?&osm_auto:all" \
		"Mundialis&OSM&http://ows.mundialis.de/services/service?&OSM-WMS" \
		"Terrestris&OSM&http://ows.terrestris.de/osm/service?&OSM-WMS" \
		"Stamen&Terrain&http://tile.stamen.com/terrain/{z}/{x}/{inv_y}.png&<rest>" \
		"Stamen&Watercolor&http://tile.stamen.com/watercolor/{z}/{x}/{inv_y}.jpg&<rest>" \
		"GIBS&Blue Marble - Relief&https://gibs.earthdata.nasa.gov/wms/epsg3857/best/wms.cgi?&BlueMarble_ShadedRelief_Bathymetry" \
		"ESRI&World Imagery&https://clarity.maptiles.arcgis.com/arcgis/rest/services/World_Imagery/MapServer/tile/{z}/{inv_y}/{x}&<rest>" \
		"NOAA&Dark Gray&https://server.arcgisonline.com/arcgis/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{inv_y}/{x}&<rest>" \
		"AJAston&Pirate Map&http://d.tiles.mapbox.com/v3/aj.Sketchy2/{z}/{x}/{inv_y}.png&<rest maxzoom=\\"6\\">" \
		"MakinaCorpus&Toulouse Pencil&https://d-tiles-vuduciel2.makina-corpus.net/toulouse-hand-drawn/{z}/{x}/{inv_y}.png&<rest minzoom=\\"13\\" maxzoom=\\"18\\" minx=\\"136229\\" miny=\\"5386020\\" maxx=\\"182550\\" maxy=\\"5419347\\">"
	do
		IFS='&' read provider name url layer <<< "${source}"
		lprovider=$(tr [:upper:] [:lower:] <<< ${provider})
		mclayer=$(tr [:upper:] [:lower:] <<< "${provider}-${name}" | sed 's/ //g')
		jslayer=$(tr '-' '_' <<< ${mclayer})
		if grep -q -v ${provider} <<< ${providers}
		then
			providers=${providers}:${provider}
			cat <<-EOF >> /var/www/html/mapcache-sandbox-browser/mapcache-source.js
				var mapcache_source_${lprovider} = new ol.layer.Group({
					title: '${provider}',
					fold: 'close'
				});
				mapcache_source.getLayers().array_.unshift(mapcache_source_${lprovider});
				EOF
		fi
		cat <<-EOF >> /var/www/html/mapcache-sandbox-browser/mapcache-source.js
			var ${jslayer} = new ol.layer.Tile({
				title: '${name}',
				type: 'base',
				visible: false,
				source: new ol.source.TileWMS({
					url: 'http://'+location.host+'/mapcache-source?',
					params: {'LAYERS': '${mclayer}', 'VERSION': '1.1.1'}
				})
			});
			mapcache_source_${lprovider}.getLayers().array_.unshift(${jslayer});
			EOF
		if grep -q -v "<rest" <<< "${layer}"
		then
			cat <<-EOF >> /vagrant/caches/mapcache-source.xml
				<!-- ${mclayer} -->
				<source name="${mclayer}" type="wms">
					<http><url>${url}</url></http>
					<getmap><params>
						<format>image/png</format>
						<layers>${layer}</layers>
					</params></getmap>
				</source>
				EOF
		else
			gridopt=$(sed 's/^.*<rest\\(.*\\)>$/\\1/' <<< "${layer}")
			cat <<-EOF >> /vagrant/caches/mapcache-source.xml
				<!-- ${mclayer} -->
				<cache name="remote-${mclayer}" type="rest">
					<url>${url}</url>
				</cache>
				<tileset name="remote-${mclayer}">
					<cache>remote-${mclayer}</cache>
					<grid>GoogleMapsCompatible</grid>
				</tileset>
				<source name="${mclayer}" type="wms">
					<http><url>http://localhost:80/mapcache-source?</url></http>
					<getmap><params>
						<format>image/png</format>
						<layers>remote-${mclayer}</layers>
					</params></getmap>
				</source>
				EOF
		fi
		cat <<-EOF >> /vagrant/caches/mapcache-source.xml
			<cache name="${mclayer}" type="sqlite3">
				<dbfile>/vagrant/caches/source/${mclayer}.sqlite3</dbfile>
			</cache>
			<tileset name="${mclayer}">
				<source>${mclayer}</source>
				<format>PNG</format>
				<cache>${mclayer}</cache>
				<grid${gridopt}>GoogleMapsCompatible</grid>
			</tileset>
			EOF
	done
	cat <<-EOF >> /vagrant/caches/mapcache-source.xml
			<service type="wmts" enabled="true"/>
			<service type="wms" enabled="true">
			<maxsize>4096</maxsize>
			</service>
			<log_level>debug</log_level>
			<threaded_fetching>true</threaded_fetching>
		</mapcache>
		EOF
	chown vagrant:vagrant /vagrant/caches/mapcache-source.xml
	cat <<-EOF > /etc/apache2/conf-enabled/mapcache-source.conf
		<IfModule mapcache_module>
			MapCacheAlias "/mapcache-source" "/vagrant/caches/mapcache-source.xml"
		</IfModule>
		EOF
	gawk -i inplace '/anchor/&&c==0{print l};{print}' \
		l='<script src="mapcache-source.js"></script>' \
		/var/www/html/mapcache-sandbox-browser/index.html
	apachectl -k start
	sleep 2
	MAPCACHE_SOURCE


end
