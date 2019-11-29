#!/bin/bash


# MESURE DE PERFORMANCES DE MAPCACHE AVEC LES TRACES D'APACHE


dcmean="3k0sn[ln1+sn+z1<r]sr0lrxsslsn[ms / ]nlnn[ = ]nlsln/n[ms]pq"

clearlog() {
  vagrant ssh -c 'sudo cp /dev/null /var/log/apache2/error.log' \
      > /dev/null 2>&1
}
getlog() {
  vagrant ssh -c 'sudo cp /var/log/apache2/error.log /vagrant/apache.log' \
      > /dev/null 2>&1
}


###############################################################################
WMTS_1() {
  d=$1 z=$2 x=$3 y=$4 c=$5 l=$6
  f=${FUNCNAME[0]}
  printf "%-10s %-10s %4s %6s %6s %-16s %-20s " $f $d $z $x $y $c $l

  src="http://localhost:8842/${c}/wmts"
  req="SERVICE=WMTS&REQUEST=GetTile"
  lay="&LAYER=${l}&TILEMATRIXSET=GoogleMapsCompatible"
  loc="&TILEMATRIX=${z}&TILEROW=${y}&TILECOL=${x}"
  siz=""
  url="${src}?${req}${lay}${loc}${siz}"

  clearlog

  thost=()
  for i in $(seq 1 ${nmes})
  do
    mes=$(
      (time curl -s "${url}" > tile) \
          2> >(awk -F'[\tms]' '/real/{print ($2*60+$3)*1000}'))
    if file tile | grep -q -E '(JPEG|PNG)'
    then
      thost+=${mes}
    elif file tile | grep -q 'XML'
    then
      echo
      xmllint --format tile
      exit 1
    else
      echo
      cat tile
      exit 1
    fi
  done
  printf "%30s " "$(dc <<< "${thost[@]} ${dcmean}")"

  getlog

  tguest=($(
      ./parselog.py < apache.log \
          | awk -F'[ ,]*' '/END.*mapcache_handler/{print $5/1000}'
  ))
  printf "%30s " "$(dc <<< "${tguest[@]} ${dcmean}")"
  printf "\n"
}


###############################################################################
WMS_1024() {
  d=$1 z=$2 x=$3 y=$4 c=$5 l=$6
  f=${FUNCNAME[0]}
  printf "%-10s %-10s %4s %6s %6s %-16s %-20s " $f $d $z $x $y $c $l

  r="20037508.3427892480"
  ntiles=$(dc <<< "2 $z ^pq")
  tilesize=$(dc <<< "20k $r 2 * $ntiles / pq")
  minx=$(dc <<< "20k 0 $r - $x $tilesize *+pq")
  miny=$(dc <<< "20k 0 $r - $ntiles $y 4+ - $tilesize *+pq")
  maxx=$(dc <<< "20k 0 $r - $x 4+ $tilesize *+pq")
  maxy=$(dc <<< "20k 0 $r - $ntiles $y - $tilesize *+pq")

  src="http://localhost:8842/${c}"
  req="SERVICE=WMS&REQUEST=GetMap"
  lay="&LAYERS=${l}&SRS=EPSG:3857"
  loc="&BBOX=${minx},${miny},${maxx},${maxy}"
  siz="&WIDTH=1024&HEIGHT=1024"
  url="${src}?${req}${lay}${loc}${siz}"

  clearlog

  thost=()
  for i in $(seq 1 ${nmes})
  do
    mes=$(
      (time curl -s "${url}" > map) \
          2> >(awk -F'[\tms]' '/real/{print ($2*60+$3)*1000}'))
    if file map | grep -q -E '(JPEG|PNG)'
    then
      thost+=${mes}
    elif file map | grep -q 'XML'
    then
      printf "\n\nURL: %s\n" "${url}"
      xmllint --format map
      exit 1
    else
      printf "\n\nURL: %s\n" "${url}"
      cat map
      exit 1
    fi
  done
  printf "%30s " "$(dc <<< "${thost[@]} ${dcmean}")"

  getlog

  tguest=($(
    ./parselog.py < apache.log \
        | awk -F'[ ,]*' '/END.*mapcache_handler/{print $5/1000}'
  ))
  printf "%30s " "$(dc <<< "${tguest[@]} ${dcmean}")"
  printf "\n"
}


###############################################################################
WMTS_16() {
  d=$1 z=$2 x=$3 y=$4 c=$5 l=$6
  f=${FUNCNAME[0]}
  printf "%-10s %-10s %4s %6s %6s %-16s %-20s " $f $d $z $x $y $c $l

  src="http://localhost:8842/${c}/wmts"
  req="SERVICE=WMTS&REQUEST=GetTile"
  lay="&LAYER=${l}&TILEMATRIXSET=GoogleMapsCompatible"
  loc="&TILEMATRIX=0&TILEROW=0&TILECOL=0"
  siz=""
  url="${src}?${req}${lay}${loc}${siz}"

  clearlog

  thost=()
  for i in $(seq 1 ${nmes})
  do
    curl -s "${src}?SERVICE=WMTS&REQUEST=MarkStartMap" > /dev/null 2>&1
    cmd="eval "
    for dx in 0 1 2 3
    do
      for dy in 0 1 2 3
      do
        loc="&TILEMATRIX=${z}&TILEROW=$((y+dy))&TILECOL=$((x+dx))"
        url="${src}?${req}${lay}${loc}${siz}"
        cmd="${cmd} curl -s '${url}' > tile${dx}${dy} &"
      done
    done
    mes=$(time ( ${cmd} ; wait ) \
        2> >(awk -F'[\tms]' '/real/{print ($2*60+$3)*1000}'))
    curl -s "${src}?SERVICE=WMTS&REQUEST=MarkStopMap" > /dev/null 2>&1
    for dx in 0 1 2 3
    do
      for dy in 0 1 2 3
      do
        if file tile${dx}${dy} | grep -q -E '(JPEG|PNG)'
        then
          :
        elif file tile${dx}${dy} | grep -q 'XML'
        then
          echo
          xmllint --format tile${dx}${dy}
          exit 1
        else
          echo
          cat tile${dx}${dy}
          exit 1
        fi
      done
    done
    thost+=${mes}
  done
  printf "%30s " "$(dc <<< "${thost[@]} ${dcmean}")"

  getlog

  rm -f apachelog_*
  csplit --quiet --digits=4 --prefix=apachelog_ apache.log '/MarkStartMap/' '{*}'
  rm -f apachelog_0000
  tguest=($(
    for i in apachelog_00*
    do
      printf "3p\n\$-7p\n" | ed -s $i
    done \
      | awk -F'[ :]' '{
          t2=(($4*60+$5)*60+$6)*1000;
          if(t1>0){printf"%12g\n",t2-t1;t1=0}else{t1=t2}}'
  ))
  printf "%30s " "$(dc <<< "${tguest[@]} ${dcmean}")"
  printf "\n"
}


###############################################################################
printf "# %-8s %-10s %4s %6s %6s %-16s %-20s %30s %30s\n" \
    'type' 'id' 'zoom' 'minx' 'miny' 'conf.' 'layer' 'total client' 'total server' \
    '----' '--' '----' '----' '----' '-----' '-----' '------------' '------------'

if [ $# -eq 0 ]
then

  printf "\n# Couverture globale de l'image de test: une tuile au niveau 0 et 16 tuiles au niveau 2\n"
  nmes=100 WMTS_1    TEST_001 0 0 0 mapcache-test global
  nmes=100 WMS_1024  TEST_002 2 0 0 mapcache-test global
  nmes=100 WMTS_16   TEST_003 2 0 0 mapcache-test global

  printf "\n# Couverture globale du catalogue des produits: une tuile au niveau 0 et 16 tuiles au niveau 2\n"
  nmes=10  WMTS_1    TEST_004 0 0 0 mapcache-produit produits
  nmes=10  WMTS_1    TEST_004 0 0 0 mapcache-produit produits-geo
  nmes=10  WMTS_1    TEST_004 0 0 0 mapcache-produit produits-i
  nmes=10  WMTS_1    TEST_004 0 0 0 mapcache-produit produits-i-geo
  nmes=10  WMS_1024  TEST_005 2 0 0 mapcache-produit produits-i-geo
  nmes=10  WMTS_16   TEST_006 2 0 0 mapcache-produit produits-i-geo

  printf "\n Couverture par quartiers du catalogue des produits 4x16 tuiles au niveau 3\n"
  nmes=10 WMS_1024   TEST_007 3 0 0 mapcache-produit produits-i-geo
  nmes=10 WMS_1024   TEST_007 3 4 0 mapcache-produit produits-i-geo
  nmes=10 WMS_1024   TEST_007 3 0 4 mapcache-produit produits-i-geo
  nmes=10 WMS_1024   TEST_007 3 4 4 mapcache-produit produits-i-geo
  nmes=10 WMTS_16    TEST_007 3 0 0 mapcache-produit produits-i-geo
  nmes=10 WMTS_16    TEST_007 3 4 0 mapcache-produit produits-i-geo
  nmes=10 WMTS_16    TEST_007 3 0 4 mapcache-produit produits-i-geo
  nmes=10 WMTS_16    TEST_007 3 4 4 mapcache-produit produits-i-geo

  printf "\n Couverture par seizième du catalogue des produits 16x16tuiles au niveau 4\n"
  nmes=10 WMS_1024   TEST_007 4  0  0 mapcache-produit produits-i-geo
  nmes=10 WMS_1024   TEST_007 4  4  0 mapcache-produit produits-i-geo
  nmes=10 WMS_1024   TEST_007 4  8  0 mapcache-produit produits-i-geo
  nmes=10 WMS_1024   TEST_007 4 12  0 mapcache-produit produits-i-geo
  nmes=10 WMS_1024   TEST_007 4  0  4 mapcache-produit produits-i-geo
  nmes=10 WMS_1024   TEST_007 4  4  4 mapcache-produit produits-i-geo
  nmes=10 WMS_1024   TEST_007 4  8  4 mapcache-produit produits-i-geo
  nmes=10 WMS_1024   TEST_007 4 12  4 mapcache-produit produits-i-geo
  nmes=10 WMS_1024   TEST_007 4  0  8 mapcache-produit produits-i-geo
  nmes=10 WMS_1024   TEST_007 4  4  8 mapcache-produit produits-i-geo
  nmes=10 WMS_1024   TEST_007 4  8  8 mapcache-produit produits-i-geo
  nmes=10 WMS_1024   TEST_007 4 12  8 mapcache-produit produits-i-geo
  nmes=10 WMS_1024   TEST_007 4  0 12 mapcache-produit produits-i-geo
  nmes=10 WMS_1024   TEST_007 4  4 12 mapcache-produit produits-i-geo
  nmes=10 WMS_1024   TEST_007 4  8 12 mapcache-produit produits-i-geo
  nmes=10 WMS_1024   TEST_007 4 12 12 mapcache-produit produits-i-geo
  nmes=10 WMTS_16    TEST_007 4  0  0 mapcache-produit produits-i-geo
  nmes=10 WMTS_16    TEST_007 4  4  0 mapcache-produit produits-i-geo
  nmes=10 WMTS_16    TEST_007 4  8  0 mapcache-produit produits-i-geo
  nmes=10 WMTS_16    TEST_007 4 12  0 mapcache-produit produits-i-geo
  nmes=10 WMTS_16    TEST_007 4  0  4 mapcache-produit produits-i-geo
  nmes=10 WMTS_16    TEST_007 4  4  4 mapcache-produit produits-i-geo
  nmes=10 WMTS_16    TEST_007 4  8  4 mapcache-produit produits-i-geo
  nmes=10 WMTS_16    TEST_007 4 12  4 mapcache-produit produits-i-geo
  nmes=10 WMTS_16    TEST_007 4  0  8 mapcache-produit produits-i-geo
  nmes=10 WMTS_16    TEST_007 4  4  8 mapcache-produit produits-i-geo
  nmes=10 WMTS_16    TEST_007 4  8  8 mapcache-produit produits-i-geo
  nmes=10 WMTS_16    TEST_007 4 12  8 mapcache-produit produits-i-geo
  nmes=10 WMTS_16    TEST_007 4  0 12 mapcache-produit produits-i-geo
  nmes=10 WMTS_16    TEST_007 4  4 12 mapcache-produit produits-i-geo
  nmes=10 WMTS_16    TEST_007 4  8 12 mapcache-produit produits-i-geo
  nmes=10 WMTS_16    TEST_007 4 12 12 mapcache-produit produits-i-geo

elif [ $# -eq 7 ]
then

  nmes=1 eval $1 $2 $3 $4 $5 $6 $7

fi







