## Adding *VM Network*

Thanks to Niran Even Chen, [@NiranEC](https://twitter.com/NiranEC), for the detailed steps.

The ESXi servers where the OVAs get deployed is required to have a default `VM Network` port group.
This is due to a bug with the Ovftool that the pipeline is utilizing. Users would get an error about `Host did not have any virtual network defined` and ovftool would fail to deploy the NSX Edges on the NSX-T management plane. 

If you don’t have the `VM Network`, set up a VSS port group as detailed below. 

* Create a “VM network” VSS port group in each server in the management cluster, no NICS are required to be attached to that.
* In the vCenter client highlight the ESXi server and click Configure -> Virtual Switches -> Add networking:
![Add Networking](./1-add-networking.png)
* Select `Virtual Machine Port Group for a Standard Switch`
![VirtualMac Portgroup](./2-virtualmac-portgroup.png)
* Select `New Standard Switch`
![Standard Switch](./3-standard-switch.png)
* No Adapters are needed. Click Next.
![No Adapter](./4-no-adapter.png)
* Click next to have `VM Network` port group
* Submit Changes
![Finish](./5-submit.png)

* Repeat steps for all the other ESXi hosts that need to be part of the transport nodes.