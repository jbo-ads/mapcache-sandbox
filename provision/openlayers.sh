#!/bin/bash

mkdir -p /var/www/html/mapcache-sandbox-browser
cat <<-EOF > /var/www/html/mapcache-sandbox-browser/index.html
	<!doctype html>
	<html>
		<head>
			<meta charset="utf-8"/>
			<title>MapCache</title>
			<link href="https://cdn.jsdelivr.net/gh/openlayers/openlayers.github.io@master/en/v6.0.1/css/ol.css" rel="stylesheet" type="text/css" />
			<link href="https://unpkg.com/ol-layerswitcher@3.4.0/src/ol-layerswitcher.css" rel="stylesheet" type="text/css" />
			<style type="text/css">
				.map {
					height: 98vh;
					width: 99vw;
				}
			</style>
			<script src="https://cdn.jsdelivr.net/gh/openlayers/openlayers.github.io@master/en/v6.0.1/build/ol.js"></script>
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
