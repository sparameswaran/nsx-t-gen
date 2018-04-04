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
