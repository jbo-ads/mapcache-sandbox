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
	apt-get install -y gdb

	# Compilation de MapCache
	cd /vagrant
	test -d mapcache || git clone https://github.com/jbo-ads/mapcache.git
	cd mapcache
	git checkout amend-dbfile-dim-sanitization
	rm -rf build
	mkdir build
	cd build
	cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Debug \
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
		</mapcache>
		EOF
	cp /vagrant/mapcache/tests/data/world.tif /tmp/mc

	# mapcache-dim2nd: Réglages pour des dimensions de second niveau
	#   L'URL depuis l'hôte commence par "http://localhost:8842/mapcache-dim2nd?"
	mkdir -p /tmp/mc/dim2nd
	rm -f /tmp/mc/dim2nd/dim.sqlite
	sqlite3 /tmp/mc/dim2nd/dim.sqlite <<-EOF
		PRAGMA foreign_keys=OFF;
		BEGIN TRANSACTION;
		CREATE TABLE dim(groupe TEXT, item TEXT);
		INSERT INTO "dim" VALUES('srtm','hillshade');
		INSERT INTO "dim" VALUES('srtm','color');
		INSERT INTO "dim" VALUES('srtm','hillshade-color');
		INSERT INTO "dim" VALUES('osm','base');
		INSERT INTO "dim" VALUES('osm','topo-osm');
		INSERT INTO "dim" VALUES('topo','topo-osm');
		INSERT INTO "dim" VALUES('topo','topo');
		INSERT INTO "dim" VALUES('osm','overlay');
		INSERT INTO "dim" VALUES('all','hillshade');
		INSERT INTO "dim" VALUES('all','color');
		INSERT INTO "dim" VALUES('all','hillshade-color');
		INSERT INTO "dim" VALUES('all','base');
		INSERT INTO "dim" VALUES('all','topo-osm');
		INSERT INTO "dim" VALUES('all','topo');
		INSERT INTO "dim" VALUES('all','overlay');
		INSERT INTO "dim" VALUES('path','dim2nd/base');
		INSERT INTO "dim" VALUES('path','dim2nd/topo-osm');
		INSERT INTO "dim" VALUES('path','dim2nd/overlay');
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
		<cache name="dims" type="sqlite3">
		<dbfile>/tmp/mc/dim2nd/{dim:source}.sqlite3</dbfile>
		<queries><get>select data from tiles where x=:x and y=:y and z=:z</get></queries>
		</cache>
		<cache name="dimspath" type="sqlite3">
		<dbfile ALLOW_PATH_IN_DIM="YES">/tmp/mc/{dim:source}.sqlite3</dbfile>
		<queries><get>select data from tiles where x=:x and y=:y and z=:z</get></queries>
		</cache>
		<tileset name="dims">
		<cache>dims</cache>
		<grid>WGS84</grid>
		<format>PNG</format>
		<dimensions>
		<assembly_type>stack</assembly_type>
		<store_assemblies>true</store_assemblies>
		<dimension name="source" default="osm" type="sqlite">
		<dbfile>/tmp/mc/dim2nd/dim.sqlite</dbfile>
		<validate_query>select item from dim where groupe=:dim</validate_query>
		<list_query> select distinct(item) from dim</list_query>
		</dimension>
		</dimensions>
		</tileset>
		<tileset name="dimspg">
		<cache>dims</cache>
		<grid>WGS84</grid>
		<format>PNG</format>
		<dimensions>
		<assembly_type>stack</assembly_type>
		<store_assemblies>false</store_assemblies>
		<dimension name="source" default="osm" type="postgresql">
		<connection>user=postgres dbname=mapcache</connection>
		<validate_query>select item from dim where groupe=:dim</validate_query>
		<list_query> select distinct(item) from dim</list_query>
		</dimension>
		</dimensions>
		</tileset>
		<tileset name="dimses">
		<cache>dims</cache>
		<grid>WGS84</grid>
		<format>PNG</format>
		<dimensions>
		<assembly_type>stack</assembly_type>
		<store_assemblies>false</store_assemblies>
		<dimension name="source" default="osm" type="elasticsearch">
		<http>
		<url>http://localhost:9200/dim/_search</url>
		<headers>
		<Content-Type>application/json</Content-Type>
		</headers>
		</http>
		<validate_query><![CDATA[ {
		"size": 0,
		"aggs": { "items": { "terms": { "field": "item.keyword" } } },
		"query": { "term": { "groupe": ":dim" } }
		} ]]></validate_query>
		<validate_response><![CDATA[
		[ "aggregations", "items", "buckets", "key" ]
		]]></validate_response>
		<list_query><![CDATA[ {
		"size": 0,
		"aggs": { "items": { "terms": { "field": "item.keyword" } } }
		} ]]></list_query>
		<list_response><![CDATA[
		[ "aggregations", "items", "buckets", "key" ]
		]]></list_response>
		</dimension>
		</dimensions>
		</tileset>
		<tileset name="dimspath">
		<cache>dimspath</cache>
		<grid>WGS84</grid>
		<format>PNG</format>
		<dimensions>
		<assembly_type>stack</assembly_type>
		<store_assemblies>false</store_assemblies>
		<dimension name="source" default="osm" type="sqlite">
		<dbfile>/tmp/mc/dim2nd/dim.sqlite</dbfile>
		<validate_query>select item from dim where groupe=:dim</validate_query>
		<list_query> select distinct(item) from dim</list_query>
		</dimension>
		</dimensions>
		</tileset>
		<tileset name="dimspgpath">
		<cache>dimspath</cache>
		<grid>WGS84</grid>
		<format>PNG</format>
		<dimensions>
		<assembly_type>stack</assembly_type>
		<store_assemblies>false</store_assemblies>
		<dimension name="source" default="osm" type="postgresql">
		<connection>user=postgres dbname=mapcache</connection>
		<validate_query>select item from dim where groupe=:dim</validate_query>
		<list_query> select distinct(item) from dim</list_query>
		</dimension>
		</dimensions>
		</tileset>
		<tileset name="dimsespath">
		<cache>dimspath</cache>
		<grid>WGS84</grid>
		<format>PNG</format>
		<dimensions>
		<assembly_type>stack</assembly_type>
		<store_assemblies>false</store_assemblies>
		<dimension name="source" default="osm" type="elasticsearch">
		<http>
		<url>http://localhost:9200/dim/_search</url>
		<headers>
		<Content-Type>application/json</Content-Type>
		</headers>
		</http>
		<validate_query><![CDATA[ {
		"size": 0,
		"aggs": { "items": { "terms": { "field": "item.keyword" } } },
		"query": { "term": { "groupe": ":dim" } }
		} ]]></validate_query>
		<validate_response><![CDATA[
		[ "aggregations", "items", "buckets", "key" ]
		]]></validate_response>
		<list_query><![CDATA[ {
		"size": 0,
		"aggs": { "items": { "terms": { "field": "item.keyword" } } }
		} ]]></list_query>
		<list_response><![CDATA[
		[ "aggregations", "items", "buckets", "key" ]
		]]></list_response>
		</dimension>
		</dimensions>
		</tileset>
		<service type="wmts" enabled="true"/>
		<service type="wms" enabled="true"/>
		<log_level>debug</log_level>
		</mapcache>
		EOF

	# Relance d'Apache pour la prise en compte des réglages de MapCache
	chown -R www-data:www-data /tmp/mc
	apachectl -k stop
	apachectl -k start

	# Mise en place de PostgreSQL
	sed -i 's/md5/trust/' /etc/postgresql/10/main/pg_hba.conf
	sed -i 's/peer/trust/' /etc/postgresql/10/main/pg_hba.conf
	echo "log_statement = 'all'" | sudo tee -a /etc/postgresql/10/main/postgresql.conf
	service postgresql restart
	psql -U postgres -c 'DROP DATABASE mapcache;'
	psql -U postgres -c 'CREATE DATABASE mapcache;'
	sqlite3 /tmp/mc/dim2nd/dim.sqlite '.dump' | grep -v PRAGMA | psql -U postgres -d mapcache
	psql -U postgres -d mapcache -c 'SELECT * FROM dim;'

	# Mise en place d'ElasticSearch
	sed -i \
		-e "/^#node.name: /s/^/node.name: vagrant-mapcache-sandbox /" \
		-e "/^#network.host: /s/^/network.host: 0.0.0.0 /" \
		-e "/^#cluster.initial_master_nodes: /s/^/cluster.initial_master_nodes: vagrant-mapcache-sandbox /" \
		/etc/elasticsearch/elasticsearch.yml
	systemctl enable elasticsearch.service
	systemctl start elasticsearch.service
	curl -s -XDELETE "http://localhost:9200/dim"
	curl -s -XPUT "http://localhost:9200/dim"
	for i in $(sqlite3 /tmp/mc/dim2nd/dim.sqlite 'SELECT * FROM dim' \
		| awk -F'|' '{print "{\\"groupe\\":\\""$1"\\",\\"item\\":\\""$2"\\"}"}')
	do
		curl -s -XPOST -H "Content-Type: application/json" "http://localhost:9200/dim/_doc" -d "$i"
        done

	SHELL
end
