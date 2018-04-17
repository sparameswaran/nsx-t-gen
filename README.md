# nsx-t-gen
concourse pipeline to install nsx-t

## Manually create docker image
* Download and copy the VMware ovftool install bundle (linux 64-bit version) along with nsx-t python modules (including vapi_common, vapi_runtime, vapi_common_client libs) and copy that into the Dockerfile folder
* Run 
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

## Run with concourse   
Use the sample params template file to fill in the nsx-t, vsphere and other configuration details.
Register the pipeline and params against concourse
Run the install-nsx-t job.