# nsx-t-gen
concourse pipeline to install nsx-t

## Manually create docker image
* Download and copy the VMware ovftool install bundle (linux 640bit version) and copy that into the Dockerfile folder
* Run 
```
docker build -t nsx-t-gen-worker Dockerfile
docker tag  nsx-t-gen-worker nsxedgegen/nsx-t-gen-worker:latest
docker push  nsx-t-gen-worker nsxedgegen/nsx-t-gen-worker:latest
```
