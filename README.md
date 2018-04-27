# nsx-t-gen
Concourse pipeline to install NSX-T v2.1

Things handled by the pipeline:
* Deploy the VMware NSX-T Manager, Controller and Edge ova images
* Configure the Controller cluster and add it to the management plane
* Configure hostswitches, profiles, transport zones
* Configure the Edges and ESXi Hosts to be part of the Fabric
* Create T0 Router (one per run, in HA vip mode) with uplink and static route
* Configure set of T1 Routers with logical switches and ports
* NAT setup for T0 Router
* Container IP Pools and External IP Blocks
* Self-signed cert generation and registration against NSX-T Manager
* Route redistribution
* HA Spoofguard Switching Profile

The pipeline uses [ansible scripts](https://github.com/yasensim/nsxt-ansibl) created by Yasen Simeonov and [forked](https://github.com/sparameswaran/nsxt-ansible) by the author of this pipeline

Not handled by pipeline (as of 4/26/18):
* Load Balancer creation

## Warning
This is purely a trial work-in-progress and not officially supported by anyone. Please use caution while using it.

## Pre-reqs
* Concourse setup
* There should be atleast one free vmnic on each of the ESXI hosts
* Ovftool would fail to deploy in the absence of `VM Network` or non NSX-T logical network with `Host did not have any virtual network defined` error message. So, ensure presence of either one.
* Web server to serve the ova images and ovftool
* Docker hub connectivity to pull docker image for the concourse pipeline
* NSX-T 2.1 ova images and ovftool install bits for linux
* vCenter Access

## Offline envs
This is only applicable if the docker image `nsxedgegen/nsx-t-gen-worker:latest` is unavailable or env is restricted to offline. 

* Download and copy the VMware ovftool install bundle (linux 64-bit version) along with nsx-t python modules (including vapi_common, vapi_runtime, vapi_common_client libs) and copy that into the Dockerfile folder
* Create and push the docker image using 
```
docker build -t nsx-t-gen-worker Dockerfile
docker tag  nsx-t-gen-worker nsxedgegen/nsx-t-gen-worker:latest
docker push nsxedgegen/nsx-t-gen-worker:latest
```


## VMware NSX-T 2.1.* bits

Download and make the following bits available on a webserver so it can be used by pipeline to install the NSX-T 2.1 bits:

```
# Download NSX-T 2.1 bits from
# https://my.vmware.com/group/vmware/details?downloadGroup=NSX-T-210&productId=673

#nsx-mgr-ova
nsx-unified-appliance-2.1.0.0.0.7380167.ova   

#nsx-ctrl-ova
nsx-controller-2.1.0.0.0.7395493.ova  

#nsx-edge-ova
nsx-edge-2.1.0.0.0.7395502.ova  

# Download VMware ovftool from https://my.vmware.com/group/vmware/details?productId=614&downloadGroup=OVFTOOL420#
VMware-ovftool-4.2.0-5965791-lin.x86_64.bundle  
```

Edit the pipelines/nsx-t-install.yml with the correct webserver endpoint and path to the files.

## Register with concourse   
Use the sample params template file to fill in the nsx-t, vsphere and other configuration details.
Register the pipeline and params against concourse

## Options to run
* Run the full-install-nsx-t group for full deployment of ova's followed by configuration of routers.
* Run the smaller group `install-nsx-t` or `add-routers` for either stopping at deployment of ovas and basic controller setup or configuration of the T0 and T1 routers and logical switches respectively.
