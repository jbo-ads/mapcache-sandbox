#!/bin/bash

cfgdir=/usr/local/etc/mapcache
srcdir=/usr/local/src
mkdir -p ${cfgdir}
cp ${srcdir}/mapcache/tests/data/world.tif ${cfgdir}

cat <<-EOF > ${cfgdir}/world.xml
	<?xml version="1.0" encoding="UTF-8"?>
	<mapcache>
		<source name="world-tif" type="gdal">
			<data>${cfgdir}/world.tif</data>
		</source>
		<cache name="disk" type="disk" layout="template">
			<template>/share/caches/world/{z}/{inv_y}/{x}.jpg</template>
		</cache>
		<tileset name="world">
			<cache>disk</cache>
			<source>world-tif</source>
			<grid maxzoom="6">GoogleMapsCompatible</grid>
			<format>JPEG</format>
			<metatile>1 1</metatile>
		</tileset>
		<service type="wmts" enabled="true"/>
		<service type="wms" enabled="true"/>
	</mapcache>
	EOF

cat <<-EOF > /etc/apache2/conf-enabled/world.conf
	<IfModule mapcache_module>
		MapCacheAlias "/world" "${cfgdir}/world.xml"
	</IfModule>
	EOF

cat <<-EOF > /var/www/html/ol/world.js
	var world = new ol.layer.Tile({
		title: 'Low resolution World (using MapCache)',
		type: 'base',
		visible: false,
		source: new ol.source.TileWMS({
			url: 'http://'+location.host+'/world?',
			params: {'LAYERS': 'world', 'VERSION': '1.1.1'}
		})
	});
	layers.unshift(world)
	EOF

gawk -i inplace '/anchor/{print l};{print}' \
	l='<script src="world.js"></script>' \
	/var/www/html/ol/index.html

