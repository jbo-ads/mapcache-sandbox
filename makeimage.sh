#!/bin/bash


# ARGUMENTS

if [ $# -ne 6 ]
then
  printf "Error: Need 6 arguments\n" >&2
  printf "Usage: $0 name center-x center-y format source keywords\n" >&2
  printf "  alt: $0 --random name xmin ymin xmax ymax\n" >&2
  exit 1
fi

if [ "x$1" == "x--random" ]
then
  name=${2}_$(uuidgen | tr '-' '_')
  xmin=$(tr '-' '_' <<< ${3})
  ymin=$(tr '-' '_' <<< ${4})
  xmax=$(tr '-' '_' <<< ${5})
  ymax=$(tr '-' '_' <<< ${6})
  x=$(dc <<< "20k ${xmax} ${xmin} - $RANDOM 32768/* ${xmin}+p" | tr '-' '_')
  y=$(dc <<< "20k ${ymax} ${ymin} - $RANDOM 32768/* ${ymin}+p" | tr '-' '_')
  fmts=(carre horizontal vertical)
  fmt=${fmts[$((RANDOM*${#fmts[@]}/32768))]}
  srcs=(terrestris-osm stamen-terrain esri-worldimagery noaa-darkgray)
  src=${srcs[$((RANDOM*${#srcs[@]}/32768))]}
  kw=${2}
  echo $name $x $y $fmt $src $kw
else
  name=$1
  x=$(tr '-' '_' <<< $2)
  y=$(tr '-' '_' <<< $3)
  fmt=$4
  src=$5
  kw=$6
fi


# SERVEURS APACHE ET ELASTICSEARCH

basedir=$(cd $(dirname $0) ; pwd)
http="http://localhost:80"
es="http://localhost:9200"
curl -s "${http}" > /dev/null 2>&1 \
  || http="http://localhost:8842" \
     es="http://localhost:9242"
if ! curl -s "${http}" > /dev/null 2>&1
then
  printf "Error: MapCache server has failed\n" >&2
  exit 1
fi


# PARAMETRES DE L'IMAGE

if   [ ${fmt} == "carre" ];      then w=10;h=10;
elif [ ${fmt} == "horizontal" ]; then w=12;h=8;
elif [ ${fmt} == "vertical" ];   then w=8 ;h=12;
else                                  w=6 ;h=6;
fi

l=9783.94
minx=$(echo "2k $x $l $w 2/*-pq" | dc)
miny=$(echo "2k $y $l $h 2/*-pq" | dc)
maxx=$(echo "2k $x $l $w 2/*+pq" | dc)
maxy=$(echo "2k $y $l $h 2/*+pq" | dc)
width=$(echo 256 $w *pq | dc)
height=$(echo 256 $h *pq | dc)


# IMAGE JPEG SIMPLE DEPUIS WMS

if [ ! -f ${basedir}/caches/produit/image/${name}.jpg ]
then
  req="${http}/mapcache-source?SERVICE=WMS&REQUEST=GetMap&SRS=EPSG:3857"
  req="${req}&LAYERS=${src}&WIDTH=${width}&HEIGHT=${height}"
  req="${req}&BBOX=${minx},${miny},${maxx},${maxy}"
  retry=0
  while true
  do
    curl "${req}" > ${basedir}/caches/produit/image/${name}.jpg 2> /dev/null
    if file ${basedir}/caches/produit/image/${name}.jpg | grep -q JPEG
    then
      break
    fi
    printf "Error downloading image \"${name}\", retrying\n" >&2
    sleep ${retry}
    retry=$((retry+1))
    if [ ${retry} -ge 20 ]
    then
      rm -f ${basedir}/caches/produit/image/${name}.jpg
      printf "Failed to download image \"${name}\", terminating\n" >&2
      exit 1
    fi
  done
fi


# IMAGE GEOTIFF DEPUIS JPEG

if [ ! -f ${basedir}/caches/produit/image/${name}.tif ]
then
  gdal_translate -a_srs EPSG:3857 -a_ullr ${minx} ${maxy} ${maxx} ${miny} \
    ${basedir}/caches/produit/image/${name}.jpg \
    ${basedir}/caches/produit/image/${name}.tif
fi


# CACHE SQLITE DEPUIS GEOTIFF

if [ ! -f ${basedir}/caches/produit/${name}.sqlite3 ]
then
  cat <<-EOF > ${basedir}/caches/mapcache-${name}.xml
	<?xml version="1.0" encoding="UTF-8"?>
	<mapcache>
		<source name="${name}" type="gdal">
			<data>${basedir}/caches/produit/image/${name}.tif</data>
		</source>
		<cache name="${name}" type="sqlite3">
			<dbfile>${basedir}/caches/produit/${name}.sqlite3</dbfile>
		</cache>
		<tileset name="${name}">
			<source>${name}</source>
			<cache>${name}</cache>
			<grid>GoogleMapsCompatible</grid>
			<format>PNG</format>
		</tileset>
		<service type="wmts" enabled="true"/>
		<service type="wms" enabled="true"/>
		<log_level>debug</log_level>
		<threaded_fetching>true</threaded_fetching>
	</mapcache>
	EOF

  mapcache_seed -c ${basedir}/caches/mapcache-${name}.xml \
                -e ${minx},${miny},${maxx},${maxy} \
                -g GoogleMapsCompatible \
                -t ${name} \
                -z 0,13 \
  && rm ${basedir}/caches/mapcache-${name}.xml \
  || exit 1

  cp ${basedir}/caches/produit/${name}.sqlite3 \
     ${basedir}/caches/produit/${name}_i.sqlite3
  sqlite3 ${basedir}/caches/produit/${name}_i.sqlite3 \
          'CREATE UNIQUE INDEX xyz ON tiles(x,y,z);'
fi


# ENTREES DES CATALOGUES SQLITE ET ELASTICSEARCH

catalogue="${basedir}/caches/produit/dimproduits.sqlite"
IFS=',' read -a cles <<< "${kw},tout"
for k in "${cles[@]}"
do
  sqlite3 "${catalogue}" \
    "INSERT OR IGNORE INTO dim(milieu,produit,minx,miny,maxx,maxy)
     VALUES(\"${k}\",\"${name}\",${minx},${miny},${maxx},${maxy});"
  doc='{"milieu":"'${k}'","produit":"'${name}'"'
  doc="${doc}"',"minx":'${minx}',"miny":'${miny}
  doc="${doc}"',"maxx":'${maxx}',"maxy":'${maxy}'}'
  curl -s -XPOST -H "Content-Type: application/json" "${es}/dim/_doc" -d "$doc"
  echo
done


