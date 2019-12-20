#!/bin/bash

mkdir -p /var/www/html/{ol,res}
cd /var/www/html/res
curl -sLO 'https://cdn.jsdelivr.net/gh/openlayers/openlayers.github.io@master/en/v6.1.1/css/ol.css'
curl -sLO 'https://unpkg.com/ol-layerswitcher@3.4.0/src/ol-layerswitcher.css'
curl -sLO 'https://cdn.jsdelivr.net/gh/openlayers/openlayers.github.io@master/en/v6.1.1/build/ol.js'
curl -sL -o ol-layerswitcher.js 'https://unpkg.com/ol-layerswitcher@3.4.0'
tar xzf /tmp/world.tgz

cat <<-EOF > /var/www/html/ol/ol-local.js
	var layers = [ ];
	var ol_local = new ol.layer.Tile({
		title: 'Low resolution World (OpenLayers only)',
		type: 'base',
		visible: true,
		source: new ol.source.XYZ({
			url: '../res/world/{z}/{y}/{x}.jpg'
		})
	});
	layers.unshift(ol_local)
	EOF

cat <<-EOF > /var/www/html/ol/index.html
	<!doctype html>
	<html>
		<head>
			<meta charset="utf-8"/>
			<title>MapCache</title>
			<link href="../res/ol.css" rel="stylesheet" type="text/css" />
			<link href="../res/ol-layerswitcher.css" rel="stylesheet" type="text/css" />
			<style type="text/css">
				.map {
					height: 98vh;
					width: 99vw;
				}
			</style>
			<script src="../res/ol.js"></script>
			<script src="../res/ol-layerswitcher.js"></script>
			<script src="ol-local.js"></script>
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
