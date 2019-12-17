#!/bin/bash


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
