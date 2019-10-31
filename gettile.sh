#!/bin/bash

if [ $# -ge 1 ]
then
  ismap=no
  if [ "x$1" == "x--map" ]
  then
    ismap=yes
    shift
  fi
fi

if [ $# -ne 4 ]
then
  printf "Error: Need 4 arguments\n" >&2
  printf "Usage: $0 [ --map ] x y zoom dim\n" >&2
  exit 1
fi
x=$(tr '-' '_' <<< $1)
y=$(tr '-' '_' <<< $2)
z=$3
m=$4

r="20037508.3427892480"
minx=_$r
miny=_$r
maxx=$r
maxy=$r

if [ $ismap == yes ]
then
  # Set map size in number of tiles
  w=5
  h=3
  if [ $z -lt 2 ]
  then
    z=3
  fi

  # Compute tile size at given zoom level
  ntiles=$(dc <<< "2 $z ^pq")
  tilesize=$(dc <<< "20k $r 2 * $ntiles / pq")

  # Compute map extent at given zoom level
  llx=$(echo "20k $x $tilesize $w 2/*-pq" | dc | tr '-' '_')
  lly=$(echo "20k $y $tilesize $h 2/*-pq" | dc | tr '-' '_')
  urx=$(echo "20k $x $tilesize $w 2/*+pq" | dc | tr '-' '_')
  ury=$(echo "20k $y $tilesize $h 2/*+pq" | dc | tr '-' '_')

  # Adjust map extent to world bounds
  read llx urx <<< $(echo "20k $llx sx $urx sX $r sr [lxlXlr--sxlrsX]sV lXlr<V [lxlr+lX-sX0lr-sx]sv lx0lr->v lXlxfq" | dc)
  read lly ury <<< $(echo "20k $lly sy $ury sY $r sr [lylYlr--sylrsY]sV lYlr<V [lylr+lY-sY0lr-sy]sv ly0lr->v lYlyfq" | dc)

  url="http://localhost:8842/mapcache-produit?service=wms"
  req="&request=getmap&layers=produits-es&srs=epsg:3857"
  req="${req}&bbox=${llx},${lly},${urx},${ury}"
  req="${req}&width=$((w*256))&height=$((h*256))&dim_milieu=${m}"
else
  # Move xy coordinates from center to upper left
  xt=$(dc <<< "20k $x $r + pq")
  yt=$(dc <<< "20k $r $y - pq")

  # Compute tile size at given zoom level
  ntiles=$(dc <<< "2 $z ^pq")
  tilesize=$(dc <<< "20k $r 2 * $ntiles / pq")

  # Retrieve tile indexes
  tix=$(dc <<< "$xt $tilesize ~rpq")
  tiy=$(dc <<< "$yt $tilesize ~rpq")

  url="http://localhost:8842/mapcache-produit/wmts?service=wmts"
  req="&request=gettile&layer=produits-es&tilematrixset=GoogleMapsCompatible"
  req="${req}&tilematrix=${z}&tilerow=${tiy}&tilecol=${tix}"
  req="${req}&milieu=${m}"
fi

curl -s "$url$req" > image
if file image | grep -q XML
then
  cat image | xmllint --format - >&2
  exit 1
elif file image | grep -q -v 'image: '
then
  printf "Erreur: pas une image\n" >&2
  exit 1
fi
