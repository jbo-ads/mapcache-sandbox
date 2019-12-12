#!/bin/bash


# SERVEUR ELASTICSEARCH

basedir=$(cd $(dirname $0) ; pwd)
es="http://localhost:9200"
curl -s "${es}" > /dev/null 2>&1 \
  || es="http://localhost:9292"
if ! curl -s "${es}" > /dev/null 2>&1
then
  printf "Error: ElasticSearch server has failed\n" >&2
  exit 1
fi


# MÉNAGE TOTAL DANS ELASTICSEARCH

curl -s -XDELETE "${es}/_all"


# COPIE DE SQLITE DANS ELASTICSEARCH

for ligne in $(sqlite3 ${basedir}/caches/produit/dimproduits.sqlite 'SELECT * FROM dim')
do
  IFS="|" read milieu produit minx miny maxx maxy <<< "${ligne}"
  doc='{"milieu":"'${milieu}'","produit":"'${produit}'"'
  doc="${doc}"',"minx":'${minx}',"miny":'${miny}
  doc="${doc}"',"maxx":'${maxx}',"maxy":'${maxy}'}'
  curl -s -XPOST -H "Content-Type: application/json" "${es}/dim/_doc" -d "$doc"
  echo
done
