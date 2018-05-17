## FAQs
* Basics of [Concourse](https://concourse-ci.org/)
* Basics of running [Concourse using docker-compose](https://github.com/concourse/concourse-docker)
* Basics of the pipeline functioning
  * Check the blog post: [ Introducing nsx-t-gen: Automating NSX-T Install with Concourse](https://allthingsmdw.blogspot.com/2018/05/introducing-nsx-t-gen-automating-nsx-t.html)
* `Adding additional edges after first install`.
  * Recommend planning ahead of time and creating the edges all in the beginning rather than adding them later.
  * If its really required, recommend manually installing any additional edges using direct deployment of OVAs while ensuring the names are following previously installed edge instance name convention (like nsx-t-edge-0?), then update the parameters to specify the additional edge ips (assuming they use the same edge naming convention) and let the controller (as part of the base-install or just full-install) to do a rejoin of the edges followed by other jobs/tasks. Only recommended for advanced users who are ready to drill down/debug.
* Downloading the bits
  * Download NSX-T 2.1 bits from
    https://my.vmware.com/group/vmware/details?downloadGroup=NSX-T-210&productId=673
    Check https://my.vmware.com for link to new installs
  * Download [VMware-ovftool-4.2.0-5965791-lin.x86_64.bundle v4.2](https://my.vmware.com/group/vmware/details?productId=614&downloadGroup=OVFTOOL420#)

  Ensure ovftool version is 4.2. Older 4.0 has issues with deploying ova images.
* Installing Webserver
  Install nginx and copy the bits to be served
	``` 
	# Sample nginx server to host bits
	sudo apt-get nginx
	cp <*ova> <VMware-ovftool*.bundle> /var/www/html
	# Edit nginx config and start
	```
* Unable to reach the webserver hosting the ova bits
  * Check for proxy interfering with the concourse containers. 
  If using docker-compose, use the sample [docker-compose](./docker-compose.yml) template to add DNS and proxy settings. Add the webserver to the no_proxy list.
  * Disable ubuntu firewall (ufw) or relax iptables rules if there was usage of both docker concourse and docker-compose.
    Change ufw 
  	```
	sudo ufw allow 8080
	sudo ufw default allow routed
	```
	or relax iptables rules
	```
	sudo iptables -P INPUT ACCEPT
	sudo iptables -P FORWARD ACCEPT
	sudo iptables -P OUTPUT ACCEPT
	```
* Pipeline exits after reporting problem with ovas or ovftool
  * Verify the file names and paths are correct. If the download of the ovas by the pipeline at start was too fast, then it means errors with the files downloaded as each of the ova is upwards of 500 MB.
* Running out of memory resources on vcenter 
  * Turn off reservation
  ```
  nsx_t_keep_reservation: false # for POC or memory constrained setup
  ```
* Install pipeline reports the VMs are unreachable after deployment of the OVAs and creation of the VMs.
  Sample output:
  ```
	Deployment of NSX Edge ova succcessfull!! Continuing with rest of configuration!!
	Rechecking the status and count of Mgr, Ctrl, Edge instances !!
	All VMs of type NSX Mgr up, total: 1
	All VMs of type NSX Controller up, total: 3
	All VMs of type NSX Edge down, total: 2
	 Would deploy NSX Edge ovas

	Some problem with the VMs, one or more of the vms (mgr, controller, edge) failed to come up or not accessible!
	Check the related vms!!
  ```
  If the vms are correctly up but suspect its a timing issue, just rerun the pipeline task.
  This should detect the vms are up and no need for redeploying the ovas again and continue to where it left of earlier.
* Unable to deploy the Edge OVAs with error message: `Host did not have any virtual network defined`. 
  * Refer to [add-vm-network](./add-vm-network.md)
  * Or deploy the ovas directly ensuring the name of the edge instances follows the naming convention (like nsx-t-edge-01)
* Unable to add ESXi Hosts. Error: `FAILED - RETRYING: Check Fabric Node Status`
  * Empty the value for `esxi_hosts_config` and fill in `compute_vcenter_...` section in the parameter file.
  	```
	esxi_hosts_config: # Leave it blank

    # Fill following fields
	compute_vcenter_manager: # FILL ME - any name for the compute vcenter manager 
	compute_vcenter_host:    # FILL ME - Addr of the vcenter host
	compute_vcenter_usr:     # FILL ME - Use Compute vCenter Esxi hosts as transport node
	compute_vcenter_pwd:     # FILL ME - Use Compute vCenter Esxi hosts as transport node
	compute_vcenter_cluster: # FILL ME - Use Compute vCenter Esxi hosts as transport node
  	```
   Apply the new params using set-pipeline and then rerun the pipeline.
* Use different compute manager or Esxi hosts for Transport nodes compared vCenter used for NSX-T components
  * The main vcenter configs would be used for deploying the NSX Mgr, Controller and Edges.
    The ESXi Hosts for transport nodes can be on a different vcenter or compute manager. Use the compute_vcenter_... fields or esxi_hosts_config to add them as needed.
* Control/specify which Edges are used to host a given T0 Router.
  * Edit the edge_indexes section within T0Router definition to specify different edge instances.
    Index starts with 1 (would map to nsx-t-edge-01).
  ```
  nsx_t_t0router_spec: |
  t0_router:
    name: DefaultT0Router
    ha_mode: 'ACTIVE_STANDBY'
    # Specify the edges to be used for hosting the T0Router instance
    edge_indexes:
      # Index starts from 1 -> denoting nsx-t-edge-01
      primary: 1   # Index for primary edge to be used
      secondary: 2 # Index for secondary edge to be used
    vip: 10.13.12.103/27
    ....
  ```
* Adding additional T1 Routers or Logical Switches
  * Modify the parameters to specify additional T1 routers or switches and rerun add-routers.
* Adding additional T0 Routers
  * Only one T0 Router can be created during a run of the pipeline. But additional T0Routers can be added by  modifying the parameters and rerunning the add-routers and config-nsx-t-extras jobs.
    * Create a new copy or edit the parameters to modify the T0Router definition.
    * Edit T0Router references across T1 Routers as well as any tags that should be used to identify a specific T0Router.
    * Add or edit any additional ip blocks or pools, nats, lbrs
    * Register parameters with the pipeline 
    * Rerun add-routers followed by config-nsx-t-extras job group
