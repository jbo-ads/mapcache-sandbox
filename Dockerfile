FROM ubuntu:bionic
COPY provision/dependencies.sh /tmp
RUN /tmp/dependencies.sh
