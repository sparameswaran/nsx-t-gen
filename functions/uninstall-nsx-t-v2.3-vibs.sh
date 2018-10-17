#!/bin/sh

# removed nsxa, nsx-hyperbus, nsx-lldp, nsx-ctxteng in 2.3

esxcli software vib remove --no-live-install  -n nsx-nestdb -n nsxcli \
-n nsx-exporter -n nsx-netcpa  -n nsx-da -n nsx-nestdb-libs -n nsx-rpc-libs \
-n nsx-metrics-libs -n nsx-aggservice -n nsx-common-libs -n nsx-esx-datapath \
-n nsx-host -n nsx-platform-client -n nsx-sfhc -n nsx-mpa -n nsx-python-gevent \
-n nsx-python-greenlet -n nsx-python-protobuf -n nsx-shared-libs -n nsx-python-logging \
-n nsx-proxy -n nsx-profiling-libs -n nsx-opsagent -n nsx-cli-libs -n epsec-mux
