#!/bin/sh

esxcli software vib remove --no-live-install  -n nsxa -n nsx-hyperbus -n nsx-nestdb \
-n nsxcli -n nsx-exporter -n nsx-netcpa  -n nsx-da -n nsx-nestdb-libs -n nsx-rpc-libs \
-n nsx-metrics-libs -n nsx-lldp -n nsx-ctxteng -n nsx-aggservice -n nsx-common-libs \
-n nsx-esx-datapath -n nsx-host -n nsx-support-bundle-client -n nsx-platform-client \
-n nsx-sfhc -n nsx-mpa -n nsx-python-gevent -n nsx-python-greenlet -n nsx-python-protobuf \
-n nsx-shared-libs -n epsec-mux -n nsx-proxy -n nsx-profiling-libs -n nsx-opsagent
