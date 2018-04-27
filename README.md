# nsx-t-gen
Concourse pipeline to install NSX-T v2.1

The concourse pipeline uses [ansible scripts](https://github.com/yasensim/nsxt-ansible) created by Yasen Simeonov and [forked](https://github.com/sparameswaran/nsxt-ansible) by the author of this pipeline.

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

Not handled by pipeline (as of 4/26/18):

* Load Balancer creation
* BGP or Static Route setup (outside of NSX-T) for T0 Routers

## Warning
This is purely a trial work-in-progress and not officially supported by anyone. Please use caution while using it.

## Pre-reqs
* Concourse setup
* There should be atleast one free vmnic on each of the ESXI hosts
* Ovftool would fail to deploy the Edge VMs in the absence of `VM Network` or standard switch (non NSX-T) with `Host did not have any virtual network defined` error message. So, ensure presence of either one.
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
Use the sample params template file (under pipelines) to fill in the nsx-t, vsphere and other configuration details.
Register the pipeline and params against concourse.

## Sample setup
Copy over the sample params as nsx-t-params.yml and then use following script to register the pipeline (after eding the concourse endpoint, target etc.)

```
#!/bin/bash

# EDIT names and domain 
CONCOURSE_ENDPOINT=concourse.corp.local.com
CONCOURSE_TARGET=nsx-concourse
PIPELINE_NAME=install-nsx-t

alias fly-s="fly -t $CONCOURSE_TARGET set-pipeline -p $PIPELINE_NAME -c pipelines/nsx-t-install.yml -l nsx-t-params.yml"
alias fly-l="fly -t $CONCOURSE_TARGET containers | grep $PIPELINE_NAME"
alias fly-h="fly -t $CONCOURSE_TARGET hijack -b "

echo "Concourse target set to $CONCOURSE_ENDPOINT"
echo "Login using fly"
echo ""

fly --target $CONCOURSE_TARGET login --insecure --concourse-url https://${CONCOURSE_ENDPOINT} -n main

```
After registering the pipeline, unpause the pipeline before kicking off any job group

## Options to run
* Run the full-install-nsx-t group for full deployment of ova's followed by configuration of routers and nat rules.

* Run the smaller independent group:
> `base-install` for just deployment of ovas and control management plan.
This uses ansible scripts under the covers.
  
> `add-routers` for creation of the various transport zones, nodes, hostswitches and T0/T1 Routers with Logical switches. This also uses ansible scripts under the covers.

> `config-nsx-t-extras` for adding nat rules, route redistribution, HA Switching Profile, Self-signed certs. This particular job is currently done via direct api calls and does not use Ansible scripts.
