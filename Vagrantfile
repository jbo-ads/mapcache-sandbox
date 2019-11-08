Vagrant.configure("2") do |config|
  config.vm.box = "hashicorp/bionic64"
  config.vm.hostname = "vagrant-mapcache-sandbox"
  config.vm.synced_folder ".", "/vagrant", type: "virtualbox"
  config.vm.network "forwarded_port", guest: 80, host: 8842
  config.vm.network "forwarded_port", guest: 9200, host: 9242
  config.vm.provider "virtualbox" do |v|
    v.memory = 4096
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
	curl -s -XDELETE "http://localhost:9200/dim"
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
                "AJAston&Pirate Map&http://d.tiles.mapbox.com/v3/aj.Sketchy2/{z}/{x}/{inv_y}.png&<rest maxzoom:6>"
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
				<cache name="${mclayer}" type="sqlite3">
					<dbfile>/vagrant/caches/source/${mclayer}.sqlite3</dbfile>
				</cache>
				<tileset name="${mclayer}">
					<source>${mclayer}</source>
					<format>PNG</format>
				EOF
		else
			cat <<-EOF >> /vagrant/caches/mapcache-source.xml
				<cache name="${mclayer}" type="rest">
					<url>${url}</url>
				</cache>
				<tileset name="${mclayer}">
				EOF
		fi
		cat <<-EOF >> /vagrant/caches/mapcache-source.xml
				<cache>${mclayer}</cache>
				<grid>GoogleMapsCompatible</grid>
			</tileset>
			EOF
	done
	cat <<-EOF >> /vagrant/caches/mapcache-source.xml
			<service type="wmts" enabled="true"/>
			<service type="wms" enabled="true"/>
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
			UNIQUE(milieu,produit)
		);
		COMMIT;
		EOF
	cat <<-EOF > /vagrant/caches/mapcache-produit-unitaire.xml
		<?xml version="1.0" encoding="UTF-8"?>
		<mapcache>
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
		var mapcache_produit_unitaire = new ol.layer.Group({
			title: 'Produits unitaires', fold: 'close'
		});
		mapcache_produit.getLayers().array_.unshift(mapcache_produit_unitaire);
		EOF
	for prod in \
		arcachon:-119075:5565095:carre:terrestris-osm:littoral \
		laruns:-47548:5310224:horizontal:terrestris-osm:montagne \
		somme:180903:6483586:vertical:terrestris-osm:littoral \
		ossau:-49211:5288978:vertical:terrestris-srtm30-color-hillshade:montagne \
		gourette:-37017:5305633:horizontal:terrestris-srtm30-hillshade:montagne \
		larhune:-182061:5359134:horizontal:terrestris-osm:montagne,littoral \
		paris:261398:6250048:carre:stamen-toner:ville \
		zurich:951019:6002165:carre:stamen-terrain:montagne,ville \
		newyork:-8230858:4983630:vertical:stamen-watercolor:ville,littoral \
		sanantonio:-10963423:3429943:horizontal:esri-worldimagery:ville \
		minneapolis:-10379828:5616929:horizontal:terrestris-osm:ville \
		coimbra:-938061:4896085:vertical:stamen-terrain:ville \
		lisbonne:-1012288:4687682:vertical:stamen-watercolor:ville,littoral \
		barcelone:242054:5072037:carre:noaa-darkgray:ville,littoral \
		andorre:169396:5237260:carre:esri-worldimagery:montagne \
		istanbul:3226039:5013592:horizontal:esri-worldimagery:ville,littoral \
		samos:3007574:4538268:horizontal:stamen-watercolor:littoral \
		ephese:3043770:4571106:horizontal:stamen-terrain:littoral \
		athenes:2641238:4575402:vertical:terrestris-osm:ville,littoral \
		persepolis:5887633:3495213:carre:esri-worldimagery:desert \
		bam:6497415:3390004:carre:esri-worldimagery:desert \
		vienne:1822648:6141610:carre:stamen-toner:ville \
		prague:1604255:6461268:horizontal:terrestris-osm:ville \
		pise:1157348:5422676:horizontal:stamen-watercolor:ville,littoral \
		florence:1252274:5430634:vertical:terrestris-osm:ville \
		sienne:1261495:5360547:horizontal:stamen-terrain:ville
	do
		IFS=':' read -a argv <<< "$prod"
		n=${argv[0]}
		x=$(tr '-' '_' <<< ${argv[1]})
		y=$(tr '-' '_' <<< ${argv[2]})
		d=${argv[3]}
		c=${argv[4]}
		if [ $d == "carre" ]; then w=5;h=5;
		elif [ $d == "horizontal" ]; then w=6;h=4;
		elif [ $d == "vertical" ]; then w=4;h=6;
		else w=3;h=3;
		fi
		l=19567.88
		minx=$(echo "2k $x $l $w 2/*-pq" | dc)
		miny=$(echo "2k $y $l $h 2/*-pq" | dc)
		maxx=$(echo "2k $x $l $w 2/*+pq" | dc)
		maxy=$(echo "2k $y $l $h 2/*+pq" | dc)
		width=$(echo 256 $w *pq | dc)
		height=$(echo 256 $h *pq | dc)
		if [ ! -f /vagrant/caches/produit/${n}.sqlite3 ]
		then
			if [ ! -f /vagrant/caches/produit/image/${n}.tif ]
			then
				if [ ! -f /vagrant/caches/produit/image/${n}.jpg ]
				then
					pre="http://localhost:80/mapcache-source?service=wms&request=getmap&srs=epsg:3857"
					url="${pre}&bbox=${minx},${miny},${maxx},${maxy}&width=${width}&height=${height}&layers=$c"
					while true
					do
						curl "$url" > /vagrant/caches/produit/image/${n}.jpg 2>/dev/null
						if file /vagrant/caches/produit/image/${n}.jpg | grep -q -v XML
						then
							break
						fi
						echo Erreur:${n} nouvel essai >&2
					done
				fi
				gdal_translate -a_srs EPSG:3857 -a_ullr ${minx} ${maxy} ${maxx} ${miny} \
					/vagrant/caches/produit/image/${n}.jpg /vagrant/caches/produit/image/${n}.tif
			fi
		fi
		cat <<-EOF >> /vagrant/caches/mapcache-produit-unitaire.xml
			<!-- ${n}: ${argv[1]}, ${argv[2]} (${width} x ${height}) -->
			<source name="${n}" type="gdal">
				<data>/vagrant/caches/produit/image/${n}.tif</data>
			</source>
			<cache name="${n}" type="sqlite3">
				<dbfile>/vagrant/caches/produit/${n}.sqlite3</dbfile>
			</cache>
			<tileset name="${n}">
				<source>${n}</source>
				<cache>${n}</cache>
				<grid>GoogleMapsCompatible</grid>
				<format>PNG</format>
			</tileset>
			EOF
		cat <<-EOF >> /var/www/html/mapcache-sandbox-browser/mapcache-produit.js
			var ${n} = new ol.layer.Tile({
				title: '${n}: [ ${minx}, ${miny}, ${maxx}, ${maxy} ]',
				type: 'base', visible: false,
				source: new ol.source.TileWMS({
					url: 'http://'+location.host+'/mapcache-produit-unitaire?',
					params: {'LAYERS': '${n}', 'VERSION': '1.1.1'}
				})
			});
			mapcache_produit_unitaire.getLayers().array_.unshift(${n});
			EOF
		IFS=',' read -a milieu <<< "${argv[5]},tout"
		for m in "${milieu[@]}"
		do
			sqlite3 /vagrant/caches/produit/dimproduits.sqlite <<-EOF
				BEGIN TRANSACTION;
				INSERT OR IGNORE INTO dim(milieu,produit) VALUES("${m}","${n}");
				COMMIT;
				EOF
		done
	done
	# Création aléatoire de produits dans des étendues données
	for bbox in \
		"chine,9000000,2800000,13000000,5500000" \
		"amazonie,-7800000,-3300000,-5400000,-100000"
	do
		IFS=',' read nom xmin ymin xmax ymax <<< "$bbox"
		xmin=$(tr '-' '_' <<< "${xmin}")
		ymin=$(tr '-' '_' <<< "${ymin}")
		xmax=$(tr '-' '_' <<< "${xmax}")
		ymax=$(tr '-' '_' <<< "${ymax}")
		if [ $(find /vagrant/caches -name "${nom}_*.sqlite3" | wc -l) -ge 20 ]
		then
			continue
		fi
		for count in $(seq 1 3)
		do
			x=$(dc <<< "20k $xmax $xmin - $RANDOM 32768/* $xmin+p" | tr '-' '_')
			y=$(dc <<< "20k $ymax $ymin - $RANDOM 32768/* $ymin+p" | tr '-' '_')
			#  1. Récupération d'une image JPG depuis une source
			n=${nom}_$(uuidgen | tr '-' '_')
			l=19567.88
			w=5
			h=5
			d=${nom}
			c=esri-worldimagery
			minx=$(echo "2k $x $l $w 2/*-pq" | dc)
			miny=$(echo "2k $y $l $h 2/*-pq" | dc)
			maxx=$(echo "2k $x $l $w 2/*+pq" | dc)
			maxy=$(echo "2k $y $l $h 2/*+pq" | dc)
			width=$(echo 256 $w *pq | dc)
			height=$(echo 256 $h *pq | dc)
			pre="http://localhost:80/mapcache-source?service=wms&request=getmap&srs=epsg:3857"
			url="${pre}&bbox=${minx},${miny},${maxx},${maxy}&width=${width}&height=${height}&layers=${c}"
			while true
			do
				curl "$url" > /vagrant/caches/produit/image/${n}.jpg 2>/dev/null
				if file /vagrant/caches/produit/image/${n}.jpg | grep -q -v XML
				then
					break
				fi
				echo Erreur:${n} nouvel essai >&2
			done
			# 2. Conversion du JPG en GeoTiff
			gdal_translate -a_srs EPSG:3857 -a_ullr ${minx} ${maxy} ${maxx} ${miny} \
				/vagrant/caches/produit/image/${n}.jpg /vagrant/caches/produit/image/${n}.tif
			# 3. Création d'une configuration MapCache pour préparer la conversion en cache
			cat <<-EOF > /vagrant/caches/mapcache-alea.xml
				<?xml version="1.0" encoding="UTF-8"?>
				<mapcache>
					<source name="${n}" type="gdal">
						<data>/vagrant/caches/produit/image/${n}.tif</data>
					</source>
					<cache name="${n}" type="sqlite3">
						<dbfile>/vagrant/caches/produit/${n}.sqlite3</dbfile>
					</cache>
					<tileset name="${n}">
						<source>${n}</source>
						<cache>${n}</cache>
						<grid>GoogleMapsCompatible</grid>
						<format>PNG</format>
					</tileset>
					<service type="wmts" enabled="true"/>
					<service type="wms" enabled="true"/>
					<log_level>debug</log_level>
					<threaded_fetching>true</threaded_fetching>
				</mapcache>
				EOF
			# 4. Conversion du GeoTiff en cache SQLite
			ll=$(gdalinfo /vagrant/caches/produit/image/${n}.tif | sed 's/[)(]//g;s/,/, /' | awk '/Lower Left/{print $3$4}')
			ur=$(gdalinfo /vagrant/caches/produit/image/${n}.tif | sed 's/[)(]//g;s/,/, /' | awk '/Upper Right/{print $3$4}')
			mapcache_seed -c /vagrant/caches/mapcache-alea.xml -e $ll,$ur -g GoogleMapsCompatible -t ${n} -z 0,12
			# 5. Ajout du cache dans les dimensions
			IFS=',' read -a milieu <<< "${d},tout"
			for m in "${milieu[@]}"
			do
				sqlite3 /vagrant/caches/produit/dimproduits.sqlite <<-EOF
					BEGIN TRANSACTION;
					INSERT OR IGNORE INTO dim(milieu,produit) VALUES("${m}","${n}");
					COMMIT;
					EOF
			done
		done
	done
	apachectl -k stop
	sleep 2
	cat <<-EOF >> /vagrant/caches/mapcache-produit-unitaire.xml
			<service type="wmts" enabled="true"/>
			<service type="wms" enabled="true"/>
			<log_level>debug</log_level>
			<threaded_fetching>true</threaded_fetching>
		</mapcache>
		EOF
	for i in $(sqlite3 /vagrant/caches/produit/dimproduits.sqlite 'SELECT * FROM dim' \
		| awk -F'|' '{print "{\\"milieu\\":\\""$1"\\",\\"produit\\":\\""$2"\\"}"}')
	do
		curl -s -XPOST -H "Content-Type: application/json" "http://localhost:9200/dim/_doc" -d "$i"
	done
	cat <<-EOF > /etc/apache2/conf-enabled/mapcache-produit-unitaire.conf
		<IfModule mapcache_module>
			MapCacheAlias "/mapcache-produit-unitaire" "/vagrant/caches/mapcache-produit-unitaire.xml"
		</IfModule>
		EOF
	for produit in $(sqlite3 /vagrant/caches/produit/dimproduits.sqlite 'select distinct(produit) from dim')
	do
		if [ ! -f /vagrant/caches/produit/${produit}.sqlite3 ]
		then
			ll=$(gdalinfo /vagrant/caches/produit/image/${produit}.tif | sed 's/[)(]//g;s/,/, /' | awk '/Lower Left/{print $3$4}')
			ur=$(gdalinfo /vagrant/caches/produit/image/${produit}.tif | sed 's/[)(]//g;s/,/, /' | awk '/Upper Right/{print $3$4}')
			mapcache_seed -c /vagrant/caches/mapcache-produit-unitaire.xml -e $ll,$ur -g GoogleMapsCompatible -t ${produit} -z 0,12
		fi
	done
	for milieu in $(sqlite3 /vagrant/caches/produit/dimproduits.sqlite 'SELECT DISTINCT(milieu) FROM dim')
	do
		cat <<-EOF >> /var/www/html/mapcache-sandbox-browser/mapcache-produit.js
			var ${milieu} = new ol.layer.Tile({
				title: '${milieu^} (SQLite)',
				type: 'base',
				visible: false,
				source: new ol.source.TileWMS({
					url: 'http://'+location.host+'/mapcache-produit?dim_milieu=${milieu}&',
					params: {'LAYERS': 'produits', 'VERSION': '1.1.1'}
				})
			});
			mapcache_produit_milieu.getLayers().array_.unshift(${milieu});
			var ${milieu}_es = new ol.layer.Tile({
				title: '${milieu^} (ElasticSearch)',
				type: 'base',
				visible: false,
				source: new ol.source.TileWMS({
					url: 'http://'+location.host+'/mapcache-produit?dim_milieu=${milieu}&',
					params: {'LAYERS': 'produits-es', 'VERSION': '1.1.1'}
				})
			});
			mapcache_produit_milieu.getLayers().array_.unshift(${milieu}_es);
			EOF
	done
	gawk -i inplace '/anchor/&&c==0{print l};{print}' \
		l='<script src="mapcache-produit.js"></script>' \
		/var/www/html/mapcache-sandbox-browser/index.html
	cat <<-EOF > /vagrant/caches/mapcache-produit.xml
		<?xml version="1.0" encoding="UTF-8"?>
		<mapcache>
		EOF
	cat <<-EOF >> /vagrant/caches/mapcache-produit.xml
		<!-- tous les produits, par milieu -->
		<cache name="produits" type="sqlite3">
			<dbfile>/vagrant/caches/produit/{dim:milieu}.sqlite3</dbfile>
			<queries><get>select data from tiles where x=:x and y=:y and z=:z</get></queries>
		</cache>
		<tileset name="produits">
			<cache>produits</cache>
			<grid>GoogleMapsCompatible</grid>
			<format>PNG</format>
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
		<tileset name="produits-es">
			<cache>produits</cache>
			<grid>GoogleMapsCompatible</grid>
			<format>PNG</format>
			<dimensions>
				<assembly_type>stack</assembly_type>
				<store_assemblies>false</store_assemblies> 
				<dimension name="milieu" default="tout" type="elasticsearch">
					<http>
						<url>http://localhost:9200/dim/_search</url>
						<headers>
							<Content-Type>application/json</Content-Type>
						</headers>
					</http>
					<validate_query><![CDATA[ {
						"size": 0,
						"aggs": { "items": { "terms": { "field": "produit.keyword", "size": 100 } } },
						"query": { "term": { "milieu": ":dim" } }
						} ]]></validate_query>
					<validate_response><![CDATA[
						[ "aggregations", "items", "buckets", "key" ]
						]]></validate_response>
					<list_query><![CDATA[ {
						"size": 0,
						"aggs": { "items": { "terms": { "field": "produit.keyword", "size": 100 } } }
						} ]]></list_query>
					<list_response><![CDATA[
						[ "aggregations", "items", "buckets", "key" ]
						]]></list_response>
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
