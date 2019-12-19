FROM ubuntu:bionic

COPY provision/dependencies.sh /tmp
RUN /tmp/dependencies.sh

COPY provision/apache.sh /tmp
RUN /tmp/apache.sh

COPY provision/openlayers.sh /tmp
RUN /tmp/openlayers.sh

COPY provision/mapcache.sh /tmp
RUN /tmp/mapcache.sh

COPY provision/mapcache-test.sh /tmp
RUN /tmp/mapcache-test.sh

COPY provision/mapcache-source.sh /tmp
RUN /tmp/mapcache-source.sh
