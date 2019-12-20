FROM ubuntu:bionic

COPY bin/install*.sh \
     data/world.tgz \
     /tmp/

RUN /tmp/install.sh

