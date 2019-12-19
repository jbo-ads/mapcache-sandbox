FROM ubuntu:bionic

COPY provision/dependencies.sh /tmp
RUN /tmp/dependencies.sh

COPY provision/openlayers.sh \
     provision/mapcache.sh \
     provision/mapcache-test.sh \
     provision/mapcache-source.sh \
     /tmp/

RUN /tmp/openlayers.sh \
    && /tmp/mapcache.sh \
    && /tmp/mapcache-test.sh \
    && /tmp/mapcache-source.sh
