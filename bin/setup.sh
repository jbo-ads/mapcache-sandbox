#!/bin/bash

bindir="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"

for component in mapcache apache
do
  ${bindir}/setup-${component}.sh
done
