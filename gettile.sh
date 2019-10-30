#!/bin/bash

if [ $# -ne 4 ]
then
  printf "Error: Need 3 arguments" >&2
  printf "Usage: $0 x y zoom dim" >&2
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
curl -s "$url$req" > image
if file image | grep -q XML
then
  cat image | xmllint --format -
elif file image | grep -q -v 'image: '
then
  printf "Erreur: pas une image\n" >&2 ; exit 1
fi
