#!/bin/bash


cat <<-EOF > /tmp/mcdata/mapcache-source.xml
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
  "AJAston&Pirate Map&http://d.tiles.mapbox.com/v3/aj.Sketchy2/{z}/{x}/{inv_y}.png&<rest maxzoom=\"6\">" \
  "MakinaCorpus&Toulouse Pencil&https://d-tiles-vuduciel2.makina-corpus.net/toulouse-hand-drawn/{z}/{x}/{inv_y}.png&<rest minzoom=\"13\" maxzoom=\"18\" minx=\"136229\" miny=\"5386020\" maxx=\"182550\" maxy=\"5419347\">"
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
    cat <<-EOF >> /tmp/mcdata/mapcache-source.xml
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
    gridopt=$(sed 's/^.*<rest\(.*\)>$/\1/' <<< "${layer}")
    cat <<-EOF >> /tmp/mcdata/mapcache-source.xml
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
    cat <<-EOF >> /tmp/mcdata/mapcache-source.xml
	<cache name="${mclayer}" type="sqlite3">
		<dbfile>/share/caches/source/${mclayer}.sqlite3</dbfile>
	</cache>
	<tileset name="${mclayer}">
		<source>${mclayer}</source>
		<format>PNG</format>
		<cache>${mclayer}</cache>
		<grid${gridopt}>GoogleMapsCompatible</grid>
	</tileset>
	EOF
done

cat <<-EOF >> /tmp/mcdata/mapcache-source.xml
	<service type="wmts" enabled="true"/>
	<service type="wms" enabled="true">
	<maxsize>4096</maxsize>
	</service>
	<log_level>debug</log_level>
	<threaded_fetching>true</threaded_fetching>
	</mapcache>
	EOF

cat <<-EOF > /etc/apache2/conf-enabled/mapcache-source.conf
	<IfModule mapcache_module>
		MapCacheAlias "/mapcache-source" "/tmp/mcdata/mapcache-source.xml"
	</IfModule>
	EOF

gawk -i inplace '/anchor/&&c==0{print l};{print}' \
          l='<script src="mapcache-source.js"></script>' \
          /var/www/html/mapcache-sandbox-browser/index.html

