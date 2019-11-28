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
tuile() {
d=$1
z=$2
x=$3
y=$4
c=$5
l=$6
cat << EOF



 # ${d}: Récupération d'une tuile en WMTS
 # 
 # La tuile récupérée est au niveau ${z}, ligne ${y}, colonne ${x}.
 # La couche est "${l}" de la configuration "${c}".
 # Deux mesures sont réalisées:
 #  - côté client en utilisant la commande "time" sur une requête "curl"
 #  - côté serveur en exploitant les traces d'Apache sur la fonction
 #    "mapcache_handler()"
 # ${nmes} mesures individuelles sont réalisées et une moyenne est fournie en
 # résultat.

EOF

src="http://localhost:8842/${c}/wmts"
req="SERVICE=WMTS&REQUEST=GetTile"
lay="&LAYER=${l}&TILEMATRIXSET=GoogleMapsCompatible"
loc="&TILEMATRIX=${z}&TILEROW=${y}&TILECOL=${x}"
siz=""
url="${src}?${req}${lay}${loc}${siz}"

printf "Côté client (curl): "
clearlog

thost=($(
for i in $(seq 1 ${nmes})
do
  (time curl -s "${url}" > tile) \
      2> >(awk -F'[\tms]' '/real/{print ($2*60+$3)*1000}')
  (file tile | grep -q -E '(JPEG|PNG)') || (echo KO >&2 ; exit 1)
done
))
echo ${thost[@]} "${dcmean}" | dc

printf "Côté serveur (mapcache_handler): "
getlog

tguest=($(
./parselog.py < apache.log \
    | awk -F'[ ,]*' '/END.*mapcache_handler/{print $5/1000}'
))
echo ${tguest[@]} "${dcmean}" | dc
}


###############################################################################
carte() {
d=$1
c=$2
l=$3
cat << EOF



 # ${d} Récupération d'une carte WMS au niveau 2
 #
 # La carte récupérée est une couverture mondiale au niveau 2.
 # La couche est "${l}" de la configuration "${c}".
 # Deux mesures sont réalisées:
 #  - côté client en utilisant la commande "time" sur une requête "curl"
 #  - côté serveur en exploitant les traces d'Apache sur la fonction
 #    "mapcache_handler()"
 # ${nmes} mesures individuelles sont réalisées et une moyenne est fournie en
 # résultat.

EOF

src="http://localhost:8842/${c}"
req="SERVICE=WMS&REQUEST=GetMap"
lay="&LAYERS=${l}&SRS=EPSG:3857"
loc="&BBOX=-20037508.3428,-20037508.3428,20037508.3428,20037508.3428"
siz="&WIDTH=1024&HEIGHT=1024"
url="${src}?${req}${lay}${loc}${siz}"

printf "Côté client (curl): "
clearlog

thost=($(
for i in $(seq 1 ${nmes})
do
  (time curl -s "${url}" > map) \
      2> >(awk -F'[\tms]' '/real/{print ($2*60+$3)*1000}')
  (file map | grep -q -E '(JPEG|PNG)') || (echo KO >&2 ; exit 1)
done
))
echo ${thost[@]} "${dcmean}" | dc

printf "Côté serveur (mapcache_handler): "
getlog

tguest=($(
./parselog.py < apache.log \
    | awk -F'[ ,]*' '/END.*mapcache_handler/{print $5/1000}'
))
echo ${tguest[@]} "${dcmean}" | dc
}


###############################################################################
multituile() {
d=$1
c=$2
l=$3
cat << EOF



 # ${d} Récupération des tuiles au niveau 2 en WMTS
 #
 # Les tuiles récupérées sont les 16 de la couverture mondiale au niveau 2.
 # La couche est "${l}" de la configuration "${c}".
 # Deux mesures sont réalisées:
 #  - côté client en utilisant la commande "time" sur un groupe de requêtes
 #    "curl" lancées en parallèle
 #  - côté serveur en exploitant les traces d'Apache sur les marques de
 #    délimitation de groupes de tuiles correspondant aux groupes de requêtes
 #    "curl"
 # ${nmes} mesures individuelles sont réalisées et une moyenne est fournie en
 # résultat.

EOF

src="http://localhost:8842/${c}/wmts"
req="SERVICE=WMTS&REQUEST=GetTile"
lay="&LAYER=${l}&TILEMATRIXSET=GoogleMapsCompatible"
loc="&TILEMATRIX=0&TILEROW=0&TILECOL=0"
siz=""
url="${src}?${req}${lay}${loc}${siz}"

printf "Côté client (curl): "
clearlog

thost=($(
for i in $(seq 1 ${nmes})
do
curl -s "${src}?SERVICE=WMTS&REQUEST=MarkStartMap" > /dev/null 2>&1
time (
curl -s "${src}?${req}${lay}&TILEMATRIX=2&TILEROW=0&TILECOL=0" > tile00 &
curl -s "${src}?${req}${lay}&TILEMATRIX=2&TILEROW=1&TILECOL=0" > tile01 &
curl -s "${src}?${req}${lay}&TILEMATRIX=2&TILEROW=2&TILECOL=0" > tile02 &
curl -s "${src}?${req}${lay}&TILEMATRIX=2&TILEROW=3&TILECOL=0" > tile03 &
curl -s "${src}?${req}${lay}&TILEMATRIX=2&TILEROW=0&TILECOL=1" > tile10 &
curl -s "${src}?${req}${lay}&TILEMATRIX=2&TILEROW=1&TILECOL=1" > tile11 &
curl -s "${src}?${req}${lay}&TILEMATRIX=2&TILEROW=2&TILECOL=1" > tile12 &
curl -s "${src}?${req}${lay}&TILEMATRIX=2&TILEROW=3&TILECOL=1" > tile13 &
curl -s "${src}?${req}${lay}&TILEMATRIX=2&TILEROW=0&TILECOL=2" > tile20 &
curl -s "${src}?${req}${lay}&TILEMATRIX=2&TILEROW=1&TILECOL=2" > tile21 &
curl -s "${src}?${req}${lay}&TILEMATRIX=2&TILEROW=2&TILECOL=2" > tile22 &
curl -s "${src}?${req}${lay}&TILEMATRIX=2&TILEROW=3&TILECOL=2" > tile23 &
curl -s "${src}?${req}${lay}&TILEMATRIX=2&TILEROW=0&TILECOL=3" > tile30 &
curl -s "${src}?${req}${lay}&TILEMATRIX=2&TILEROW=1&TILECOL=3" > tile31 &
curl -s "${src}?${req}${lay}&TILEMATRIX=2&TILEROW=2&TILECOL=3" > tile32 &
curl -s "${src}?${req}${lay}&TILEMATRIX=2&TILEROW=3&TILECOL=3" > tile33 &
wait) \
    2> >(awk -F'[\tms]' '/real/{print ($2*60+$3)*1000}')
curl -s "${src}?SERVICE=WMTS&REQUEST=MarkStopMap" > /dev/null 2>&1
(file tile00 | grep -q -E '(JPEG|PNG)') || (echo KO >&2 ; exit 1)
(file tile01 | grep -q -E '(JPEG|PNG)') || (echo KO >&2 ; exit 1)
(file tile02 | grep -q -E '(JPEG|PNG)') || (echo KO >&2 ; exit 1)
(file tile03 | grep -q -E '(JPEG|PNG)') || (echo KO >&2 ; exit 1)
(file tile10 | grep -q -E '(JPEG|PNG)') || (echo KO >&2 ; exit 1)
(file tile11 | grep -q -E '(JPEG|PNG)') || (echo KO >&2 ; exit 1)
(file tile12 | grep -q -E '(JPEG|PNG)') || (echo KO >&2 ; exit 1)
(file tile13 | grep -q -E '(JPEG|PNG)') || (echo KO >&2 ; exit 1)
(file tile20 | grep -q -E '(JPEG|PNG)') || (echo KO >&2 ; exit 1)
(file tile21 | grep -q -E '(JPEG|PNG)') || (echo KO >&2 ; exit 1)
(file tile22 | grep -q -E '(JPEG|PNG)') || (echo KO >&2 ; exit 1)
(file tile23 | grep -q -E '(JPEG|PNG)') || (echo KO >&2 ; exit 1)
(file tile30 | grep -q -E '(JPEG|PNG)') || (echo KO >&2 ; exit 1)
(file tile31 | grep -q -E '(JPEG|PNG)') || (echo KO >&2 ; exit 1)
(file tile32 | grep -q -E '(JPEG|PNG)') || (echo KO >&2 ; exit 1)
(file tile33 | grep -q -E '(JPEG|PNG)') || (echo KO >&2 ; exit 1)
done
))
echo ${thost[@]} "${dcmean}" | dc

printf "Côté serveur (marques de cartes): "
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
echo ${tguest[@]} "${dcmean}" | dc
}


###############################################################################
nmes=50  tuile       TEST_001 0 0 0 mapcache-test global
nmes=50  carte       TEST_002 mapcache-test global
nmes=50  multituile  TEST_003 mapcache-test global
nmes=5   tuile       TEST_004 0 0 0 mapcache-produit produits-i-geo
nmes=5   carte       TEST_005 mapcache-produit produits-i-geo
nmes=5   multituile  TEST_006 mapcache-produit produits-i-geo







