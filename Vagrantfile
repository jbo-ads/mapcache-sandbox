Vagrant.configure("2") do |config|
  config.vm.box = "hashicorp/bionic64"
  config.vm.hostname = "vagrant-mapcache-sandbox"
  config.vm.synced_folder ".", "/vagrant", type: "virtualbox"
  config.vm.network "forwarded_port", guest: 80, host: 8842
  config.vm.network "forwarded_port", guest: 9200, host: 9242
  config.vm.provider "virtualbox" do |v|
    v.memory = 5120
    v.cpus = 2
  end

  config.vm.provision "shell", inline: <<-DEPS
	# Mise en place des dépendances
	#   Ce script est exécuté une seule fois à la création de la machine virtuelle
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

  config.vm.provision "shell", inline: <<-POSTGRESQL
	# Mise en place de PostgreSQL
	#   Ce script est exécuté une seule fois à la création de la machine virtuelle
	sed -i 's/md5/trust/' /etc/postgresql/10/main/pg_hba.conf
	sed -i 's/peer/trust/' /etc/postgresql/10/main/pg_hba.conf
	echo "log_statement = 'all'" | sudo tee -a /etc/postgresql/10/main/postgresql.conf
	POSTGRESQL

  config.vm.provision "shell", inline: <<-ELASTICSEARCH
	# Mise en place d'ElasticSearch
	#   Ce script est exécuté une seule fois à la création de la machine virtuelle
	sed -i \
		-e "/^#node.name: /s/^/node.name: vagrant-mapcache-sandbox /" \
		-e "/^#network.host: /s/^/network.host: 0.0.0.0 /" \
		-e "/^#cluster.initial_master_nodes: /s/^/cluster.initial_master_nodes: vagrant-mapcache-sandbox /" \
		/etc/elasticsearch/elasticsearch.yml
	ELASTICSEARCH

  config.vm.provision "shell", run: "always", inline: <<-SERVICES
	# Démarrage des services
	#   Ce script est exécuté systématiquement.
	apachectl -k start
	sleep 2
	service postgresql restart
	psql -U postgres -c 'DROP DATABASE mapcache;'
	psql -U postgres -c 'CREATE DATABASE mapcache;'
	systemctl enable elasticsearch.service
	systemctl start elasticsearch.service
	curl -s "http://localhost:9200/"
	SERVICES

  config.vm.provision "shell", run: "always", inline: <<-MAPCACHE
	# Installation de MapCache
	#   Ce script est exécuté systématiquement, mais seules les parties de
	#   MapCache qui ne sont pas déjà en place sont reprises
	cd /vagrant
	if [ ! -d mapcache ]
	then
		git clone https://github.com/jbo-ads/mapcache.git
		cd mapcache
		git checkout apache-profiling
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
	mkdir -p /vagrant/caches/{source,produit}
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
	#   L'URL depuis l'hôte est "http://localhost:8842/mapcache-sandbox-browser/"
	#   Ce script est exécuté systématiquement.
	mkdir -p /var/www/html/mapcache-sandbox-browser
	cat <<-EOF > /var/www/html/mapcache-sandbox-browser/index.html
		<!doctype html>
		<html>
		<head>
		<meta charset="utf-8"/>
		<title>Test de MapCache</title>
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
		<script src="https://unpkg.com/ol-layerswitcher@3.4.0"></script>
		<meta name="anchor" content="insertbefore"/>
		</head>
		<body>
		<h2>Test de MapCache</h2>
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
	#   L'URL depuis l'hôte commence par "http://localhost:8842/mapcache-test?"
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
	#   L'URL depuis l'hôte commence par "http://localhost:8842/mapcache-source?"
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
		"HeiGIT&Nature&https://maps.heigit.org/osm-wms/service?&osm_auto:naturals_z9_to_0" \
		"HeiGIT&Hillshade&https://maps.heigit.org/osm-wms/service?&europe_wms:hs_srtm_europa" \
		"Mundialis&OSM&http://ows.mundialis.de/services/service?&OSM-WMS" \
		"Mundialis&Topo&http://ows.mundialis.de/services/service?&TOPO-WMS" \
		"Mundialis&Topo-OSM&http://ows.mundialis.de/services/service?&TOPO-OSM-WMS" \
		"Mundialis&SRTM30-Color&http://ows.mundialis.de/services/service?&SRTM30-Colored" \
		"Mundialis&SRTM30-Hillshade&http://ows.mundialis.de/services/service?&SRTM30-Hillshade" \
		"Mundialis&SRTM30-Color-Hillshade&http://ows.mundialis.de/services/service?&SRTM30-Colored-Hillshade" \
		"Mundialis&SRTM30-Contour&http://ows.mundialis.de/services/service?&SRTM30-Contour" \
		"Terrestris&OSM&http://ows.terrestris.de/osm/service?&OSM-WMS" \
		"Terrestris&Topo&http://ows.terrestris.de/osm/service?&TOPO-WMS" \
		"Terrestris&Topo-OSM&http://ows.terrestris.de/osm/service?&TOPO-OSM-WMS" \
		"Terrestris&SRTM30-Color&http://ows.terrestris.de/osm/service?&SRTM30-Colored" \
		"Terrestris&SRTM30-Hillshade&http://ows.terrestris.de/osm/service?&SRTM30-Hillshade" \
		"Terrestris&SRTM30-Color-Hillshade&http://ows.terrestris.de/osm/service?&SRTM30-Colored-Hillshade" \
		"Stamen&Terrain&http://tile.stamen.com/terrain/{z}/{x}/{inv_y}.png&<rest>" \
		"Stamen&Watercolor&http://tile.stamen.com/watercolor/{z}/{x}/{inv_y}.jpg&<rest>" \
		"Stamen&Toner&http://tile.stamen.com/toner/{z}/{x}/{inv_y}.png&<rest>" \
		"GIBS&Blue Marble&https://gibs.earthdata.nasa.gov/wms/epsg3857/best/wms.cgi?&BlueMarble_NextGeneration" \
		"GIBS&Blue Marble - Relief&https://gibs.earthdata.nasa.gov/wms/epsg3857/best/wms.cgi?&BlueMarble_ShadedRelief_Bathymetry" \
		"GIBS&Earth at Night&https://gibs.earthdata.nasa.gov/wms/epsg3857/best/wms.cgi?&VIIRS_CityLights_2012" \
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

  config.vm.provision "shell", run: "always", inline: <<-MAPCACHE_PRODUIT
	# Création de produits simulés et réglages correspondants dans MapCache
	#   L'URL depuis l'hôte commence par "http://localhost:8842/mapcache-produit?"
	#   Ce script est exécuté systématiquement, mais seuls les produits qui ne
	#   sont pas déjà en place sont repris.
	mkdir -p /vagrant/caches/produit/image
	sqlite3 /vagrant/caches/produit/dimproduits.sqlite <<-EOF
		PRAGMA foreign_keys=OFF;
		BEGIN TRANSACTION;
		CREATE TABLE IF NOT EXISTS dim(
			milieu TEXT,
			produit TEXT,
			minx REAL,
			miny REAL,
			maxx REAL,
			maxy REAL,
			UNIQUE(milieu,produit)
		);
		COMMIT;
		EOF
	cat <<-EOF > /var/www/html/mapcache-sandbox-browser/mapcache-produit.js
		var mapcache_produit = new ol.layer.Group({
			title: 'Produits',
			fold: 'open'
		});
		layers.unshift(mapcache_produit);
		var mapcache_produit_milieu = new ol.layer.Group({
			title: 'Milieux géographiques', fold: 'open'
		});
		mapcache_produit.getLayers().array_.unshift(mapcache_produit_milieu);
		EOF
	for prod in \
		paris:261398:6250048:carre:stamen-toner:ville \
		lisbonne:-1012288:4687682:vertical:stamen-watercolor:ville,littoral \
		athenes:2641238:4575402:vertical:mundialis-osm:ville,littoral \
		vienne:1822648:6141610:carre:stamen-toner:ville \
		londres:-15915:6710369:horizontal:esri-worldimagery:ville \
		prague:1604255:6461268:horizontal:mundialis-osm:ville
	do
		IFS=':' read -a argv <<< "$prod"
		/vagrant/makeimage.sh "${argv[@]}"
	done
	# Création aléatoire de produits dans des étendues données
	for bbox in \
		"australie:12924584:-3688545:16578885:-2406849" \
		"amazonie:-7800245:-3355891:-5537709:185894" \
		"siberie:9412149:7083572:14362823:11486345" \
		"canada:-13988587:6305749:-10591114:10067673" \
		"alaska:-18002448:8580515:-15693439:11006932"
	do
		IFS=':' read -a argv <<< "$bbox"
		if [ $(find /vagrant/caches -name "${nom}_*.sqlite3" | wc -l) -ge 20 ]
		then
			continue
		fi
		for count in $(seq 1 2)
		do
			/vagrant/makeimage.sh --random "${argv[@]}"
		done
	done
	apachectl -k stop
	sleep 2
	
	
	for milieu in "tout" ### $(sqlite3 /vagrant/caches/produit/dimproduits.sqlite 'SELECT DISTINCT(milieu) FROM dim')
	do
		cat <<-EOF >> /var/www/html/mapcache-sandbox-browser/mapcache-produit.js
			var ${milieu} = new ol.layer.Tile({
				title: '${milieu^} (SQLite sans index, sans requête géographique, sans requête unique)',
				type: 'base',
				visible: false,
				source: new ol.source.TileWMS({
					url: 'http://'+location.host+'/mapcache-produit?dim_milieu=${milieu}&',
					params: {'LAYERS': 'produits', 'VERSION': '1.1.1'}
				})
			});
			mapcache_produit_milieu.getLayers().array_.unshift(${milieu});
			var ${milieu}_geo = new ol.layer.Tile({
				title: '${milieu^} (SQLite sans index, avec requête géographique, sans requête unique)',
				type: 'base',
				visible: false,
				source: new ol.source.TileWMS({
					url: 'http://'+location.host+'/mapcache-produit?dim_milieu=${milieu}&',
					params: {'LAYERS': 'produits-geo', 'VERSION': '1.1.1'}
				})
			});
			mapcache_produit_milieu.getLayers().array_.unshift(${milieu}_geo);
			var ${milieu}_i = new ol.layer.Tile({
				title: '${milieu^} (SQLite avec index, sans requête géographique, sans requête unique)',
				type: 'base',
				visible: false,
				source: new ol.source.TileWMS({
					url: 'http://'+location.host+'/mapcache-produit?dim_milieu=${milieu}&',
					params: {'LAYERS': 'produits-i', 'VERSION': '1.1.1'}
				})
			});
			mapcache_produit_milieu.getLayers().array_.unshift(${milieu}_i);
			var ${milieu}_i_geo = new ol.layer.Tile({
				title: '${milieu^} (SQLite avec index, avec requête géographique, sans requête unique)',
				type: 'base',
				visible: false,
				source: new ol.source.TileWMS({
					url: 'http://'+location.host+'/mapcache-produit?dim_milieu=${milieu}&',
					params: {'LAYERS': 'produits-i-geo', 'VERSION': '1.1.1'}
				})
			});
			mapcache_produit_milieu.getLayers().array_.unshift(${milieu}_i_geo);
			var ${milieu}_map = new ol.layer.Tile({
				title: '${milieu^} (SQLite sans index, sans requête géographique, avec requête unique)',
				type: 'base',
				visible: false,
				source: new ol.source.TileWMS({
					url: 'http://'+location.host+'/mapcache-produit?dim_milieu=${milieu}&',
					params: {'LAYERS': 'produits-map', 'VERSION': '1.1.1'}
				})
			});
			mapcache_produit_milieu.getLayers().array_.unshift(${milieu}_map);
			var ${milieu}_geo_map = new ol.layer.Tile({
				title: '${milieu^} (SQLite sans index, avec requête géographique, avec requête unique)',
				type: 'base',
				visible: false,
				source: new ol.source.TileWMS({
					url: 'http://'+location.host+'/mapcache-produit?dim_milieu=${milieu}&',
					params: {'LAYERS': 'produits-geo-map', 'VERSION': '1.1.1'}
				})
			});
			mapcache_produit_milieu.getLayers().array_.unshift(${milieu}_geo_map);
			var ${milieu}_i_map = new ol.layer.Tile({
				title: '${milieu^} (SQLite avec index, sans requête géographique, avec requête unique)',
				type: 'base',
				visible: false,
				source: new ol.source.TileWMS({
					url: 'http://'+location.host+'/mapcache-produit?dim_milieu=${milieu}&',
					params: {'LAYERS': 'produits-i-map', 'VERSION': '1.1.1'}
				})
			});
			mapcache_produit_milieu.getLayers().array_.unshift(${milieu}_i_map);
			var ${milieu}_i_geo_map = new ol.layer.Tile({
				title: '${milieu^} (SQLite avec index, avec requête géographique, avec requête unique)',
				type: 'base',
				visible: false,
				source: new ol.source.TileWMS({
					url: 'http://'+location.host+'/mapcache-produit?dim_milieu=${milieu}&',
					params: {'LAYERS': 'produits-i-geo-map', 'VERSION': '1.1.1'}
				})
			});
			mapcache_produit_milieu.getLayers().array_.unshift(${milieu}_i_geo_map);
			var ${milieu}_es = new ol.layer.Tile({
				title: '${milieu^} (ElasticSearch sans index, sans requête géographique, sans requête unique)',
				type: 'base',
				visible: false,
				source: new ol.source.TileWMS({
					url: 'http://'+location.host+'/mapcache-produit?dim_milieu=${milieu}&',
					params: {'LAYERS': 'produits-es', 'VERSION': '1.1.1'}
				})
			});
			mapcache_produit_milieu.getLayers().array_.unshift(${milieu}_es);
			var ${milieu}_geo_es = new ol.layer.Tile({
				title: '${milieu^} (ElasticSearch sans index, avec requête géographique, sans requête unique)',
				type: 'base',
				visible: false,
				source: new ol.source.TileWMS({
					url: 'http://'+location.host+'/mapcache-produit?dim_milieu=${milieu}&',
					params: {'LAYERS': 'produits-geo-es', 'VERSION': '1.1.1'}
				})
			});
			mapcache_produit_milieu.getLayers().array_.unshift(${milieu}_geo_es);
			var ${milieu}_i_es = new ol.layer.Tile({
				title: '${milieu^} (ElasticSearch avec index, sans requête géographique, sans requête unique)',
				type: 'base',
				visible: false,
				source: new ol.source.TileWMS({
					url: 'http://'+location.host+'/mapcache-produit?dim_milieu=${milieu}&',
					params: {'LAYERS': 'produits-i-es', 'VERSION': '1.1.1'}
				})
			});
			mapcache_produit_milieu.getLayers().array_.unshift(${milieu}_i_es);
			var ${milieu}_i_geo_es = new ol.layer.Tile({
				title: '${milieu^} (ElasticSearch avec index, avec requête géographique, sans requête unique)',
				type: 'base',
				visible: false,
				source: new ol.source.TileWMS({
					url: 'http://'+location.host+'/mapcache-produit?dim_milieu=${milieu}&',
					params: {'LAYERS': 'produits-i-geo-es', 'VERSION': '1.1.1'}
				})
			});
			mapcache_produit_milieu.getLayers().array_.unshift(${milieu}_i_geo_es);
			var ${milieu}_map_es = new ol.layer.Tile({
				title: '${milieu^} (ElasticSearch sans index, sans requête géographique, avec requête unique)',
				type: 'base',
				visible: false,
				source: new ol.source.TileWMS({
					url: 'http://'+location.host+'/mapcache-produit?dim_milieu=${milieu}&',
					params: {'LAYERS': 'produits-map-es', 'VERSION': '1.1.1'}
				})
			});
			mapcache_produit_milieu.getLayers().array_.unshift(${milieu}_map_es);
			var ${milieu}_geo_map_es = new ol.layer.Tile({
				title: '${milieu^} (ElasticSearch sans index, avec requête géographique, avec requête unique)',
				type: 'base',
				visible: false,
				source: new ol.source.TileWMS({
					url: 'http://'+location.host+'/mapcache-produit?dim_milieu=${milieu}&',
					params: {'LAYERS': 'produits-geo-map-es', 'VERSION': '1.1.1'}
				})
			});
			mapcache_produit_milieu.getLayers().array_.unshift(${milieu}_geo_map_es);
			var ${milieu}_i_map_es = new ol.layer.Tile({
				title: '${milieu^} (ElasticSearch avec index, sans requête géographique, avec requête unique)',
				type: 'base',
				visible: false,
				source: new ol.source.TileWMS({
					url: 'http://'+location.host+'/mapcache-produit?dim_milieu=${milieu}&',
					params: {'LAYERS': 'produits-i-map-es', 'VERSION': '1.1.1'}
				})
			});
			mapcache_produit_milieu.getLayers().array_.unshift(${milieu}_i_map_es);
			var ${milieu}_i_geo_map_es = new ol.layer.Tile({
				title: '${milieu^} (ElasticSearch avec index, avec requête géographique, avec requête unique)',
				type: 'base',
				visible: false,
				source: new ol.source.TileWMS({
					url: 'http://'+location.host+'/mapcache-produit?dim_milieu=${milieu}&',
					params: {'LAYERS': 'produits-i-geo-map-es', 'VERSION': '1.1.1'}
				})
			});
			mapcache_produit_milieu.getLayers().array_.unshift(${milieu}_i_geo_map_es);
			EOF
	done
	
	
	gawk -i inplace '/anchor/&&c==0{print l};{print}' \
		l='<script src="mapcache-produit.js"></script>' \
		/var/www/html/mapcache-sandbox-browser/index.html
	cat <<-EOF > /vagrant/caches/mapcache-produit.xml
		<?xml version="1.0" encoding="UTF-8"?>
		<mapcache>
		<cache name="produits" type="sqlite3">
			<!-- Cache de produit sans index XYZ -->
			<dbfile>/vagrant/caches/produit/{dim:milieu}.sqlite3</dbfile>
			<queries><get>select data from tiles where x=:x and y=:y and z=:z</get></queries>
		</cache>
		<cache name="produits-i" type="sqlite3">
			<!-- Cache de produit avec index XYZ -->
			<dbfile>/vagrant/caches/produit/{dim:milieu}_i.sqlite3</dbfile>
			<queries><get>select data from tiles where x=:x and y=:y and z=:z</get></queries>
		</cache>
		EOF
	
	
	for index in "" "-i" ; do
	for geo in "" "-geo" ; do
	for map in "" "-map" ; do
	for thr in "" "-thr" ; do
		sql="select produit from dim where milieu=:dim"
		dsl='{ "term": { "milieu": ":dim" } }'
		if [ "x${geo}" == "x-geo" ]
		then
			sql="${sql} and minx &lt;= :maxx and maxx &gt;= :minx"
			sql="${sql} and minx &lt;= :maxx and maxx &gt;= :minx"
			dsl='{ "bool" :{ "filter": [ '"${dsl}"
			dsl="${dsl}"', { "range": { "minx": { "lte": :maxx } } }'
			dsl="${dsl}"', { "range": { "maxx": { "gte": :minx } } }'
			dsl="${dsl}"', { "range": { "miny": { "lte": :maxy } } }'
			dsl="${dsl}"', { "range": { "maxy": { "gte": :miny } } }'
			dsl="${dsl}"' ] } }'
		fi
		querybymap="false"
		if [ "x${map}" == "x-map" ]
		then
			querybymap="true"
		fi
		threadsubtiles="false"
		if [ "x${thr}" == "x-thr" ]
		then
			threadsubtiles="true"
		fi
		cat <<-EOF >> /vagrant/caches/mapcache-produit.xml
		<tileset name="produits${index}${geo}${map}${thr}">
			<cache>produits${index}</cache>
			<grid>GoogleMapsCompatible</grid>
			<format>PNG</format>
			<dimensions>
				<assembly_type>stack</assembly_type>
				<store_assemblies>false</store_assemblies>
				<assembly_threaded_fetching>${threadsubtiles}</assembly_threaded_fetching>
				<dimension name="milieu" default="tout" type="sqlite">
					<wms_querybymap>${querybymap}</wms_querybymap>
					<dbfile>/vagrant/caches/produit/dimproduits.sqlite</dbfile>
					<validate_query>${sql}</validate_query>
					<list_query> select distinct(produit) from dim</list_query>
				</dimension>
			</dimensions>
		</tileset>
		<tileset name="produits${index}${geo}${map}${thr}-es">
			<cache>produits${index}</cache>
			<grid>GoogleMapsCompatible</grid>
			<format>PNG</format>
			<dimensions>
				<assembly_type>stack</assembly_type>
				<store_assemblies>false</store_assemblies> 
				<assembly_threaded_fetching>${threadsubtiles}</assembly_threaded_fetching>
				<dimension name="milieu" default="tout" type="elasticsearch">
					<wms_querybymap>${querybymap}</wms_querybymap>
					<http>
						<url>http://localhost:9200/dim/_search</url>
						<headers>
							<Content-Type>application/json</Content-Type>
						</headers>
					</http>
					<validate_query><![CDATA[ {
						"size": 0,
						"aggs": { "items": { "terms": { "field": "produit.keyword", "size": 1000 } } },
						"query": ${dsl}
						} ]]></validate_query>
					<validate_response><![CDATA[
						[ "aggregations", "items", "buckets", "key" ]
						]]></validate_response>
					<list_query><![CDATA[ {
						"size": 0,
						"aggs": { "items": { "terms": { "field": "produit.keyword", "size": 1000 } } }
						} ]]></list_query>
					<list_response><![CDATA[
						[ "aggregations", "items", "buckets", "key" ]
						]]></list_response>
				</dimension>
			</dimensions>
		</tileset>
		EOF
	done ; done ; done ; done
	
	cat <<-EOF >> /vagrant/caches/mapcache-produit.xml
		<!-- gfi: Source et cache destinés à tester le tranfert des requêtes
			"GetFeatureInfo" -->
		<cache name="gfi" type="sqlite3">
			<dbfile>/vagrant/caches/produit/gfi.sqlite3</dbfile>
		</cache>
		<source name="gfi" type="wms">
			<http><url>http://localhost:80/mapcache-produit?</url></http>
			<getmap>
				<params>
					<format>image/png</format>
					<layers>produits</layers>
				</params>
			</getmap>
			<getfeatureinfo>
				<info_formats>text/html</info_formats>
				<params>
					<query_layers>produits</query_layers>
				</params>
			</getfeatureinfo>
		</source>
		<!-- gfi-sqlite: Couche dont la source est "produits" afin de tester le
			tranfert des requêtes "GetFeatureInfo"; Les dimensions sont de
			type SQLite -->
		<tileset name="gfi-sqlite">
			<source>gfi</source>
			<cache>gfi</cache>
			<format>PNG</format>
			<grid>GoogleMapsCompatible</grid>
			<dimensions>
				<assembly_type>stack</assembly_type>
				<store_assemblies>false</store_assemblies>
				<dimension name="milieu" default="tout" type="sqlite">
					<dbfile>/vagrant/caches/produit/dimproduits.sqlite</dbfile>
					<validate_query>select produit from dim where milieu=:dim</validate_query>
					<list_query> select distinct(produit) from dim</list_query>
				</dimension>
			</dimensions>
		</tileset>
		<!-- gfi-regex: Couche dont la source est "produits" afin de tester le
			tranfert des requêtes "GetFeatureInfo"; Les dimensions sont de
			type Regex -->
		<tileset name="gfi-regex">
			<source>gfi</source>
			<cache>gfi</cache>
			<format>PNG</format>
			<grid>GoogleMapsCompatible</grid>
			<dimensions>
				<assembly_type>stack</assembly_type>
				<store_assemblies>false</store_assemblies>
				<dimension name="milieu" default="tout" type="regex">
					<regex>^[a-zA-Z0-9]*$</regex>
				</dimension>
			</dimensions>
		</tileset>
		EOF
	cat <<-EOF >> /vagrant/caches/mapcache-produit.xml
			<service type="wmts" enabled="true"/>
			<service type="wms" enabled="true"/>
			<log_level>debug</log_level>
			<threaded_fetching>true</threaded_fetching>
		</mapcache>
		EOF
	cat <<-EOF > /etc/apache2/conf-enabled/mapcache-produit.conf
		<IfModule mapcache_module>
			MapCacheAlias "/mapcache-produit" "/vagrant/caches/mapcache-produit.xml"
		</IfModule>
		EOF
	apachectl -k start
	sleep 2
	MAPCACHE_PRODUIT

end
