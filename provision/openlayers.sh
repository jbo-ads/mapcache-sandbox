#!/bin/bash

mkdir -p /var/www/html/mapcache-sandbox-browser
cat <<-EOF > /var/www/html/mapcache-sandbox-browser/index.html
	<!doctype html>
	<html>
		<head>
			<meta charset="utf-8"/>
			<title>MapCache</title>
			<link href="../css/ol.css" rel="stylesheet" type="text/css" />
			<link href="../css/ol-layerswitcher.css" rel="stylesheet" type="text/css" />
			<style type="text/css">
				.map {
					height: 98vh;
					width: 99vw;
				}
			</style>
			<script src="../js/ol.js"></script>
			<script src="../js/ol-layerswitcher.js"></script>
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
