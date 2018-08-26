# Configuring Static Routes for NSX-T T0 Router

The components running on NSX-T Fabric can be exposed to the external world via two options: BGP and Static Routes. BGP is not discussed in this doc.

## Exposing External IPs over the T0 Router using static routing

The NSX-T T0 router should be gateway for all the deployed components that are using the T0 Router (like PAS or PKS or Ops Mgr). Setting up this portion of a static route differs based on the conditions for routing to the NSX-T T0 Router.  

### Using Transient networks to route over T0 Router

If the client setup allows using any CIDR or subnet to be used as a routable ip (like a POD or some dedicated private network and not necessarily shared with others) that can be self-administered, then one can use a transient network to be used as the exposed external ip while keeping the actual ip pools separate.
This can be the case with a private Ubiquiti Edge Router that acts as gateway to the entire NSX-T install.

Sample step to include static routing in a VMware vPod Environment on the main vPod Router vm:
```
post-up route add -net 10.208.40.0 netmask 255.255.255.0 gw 192.168.100.3
pre-down route del -net 10.208.40.0 netmask 255.255.255.0 gw 192.168.100.3
```

| T0 Router |  T0 IP | Transient subnet for External IP Pool | \# of IPs that can be exposed | Sample DNAT and SNAT |
|-------------|---------------|-------------------|----|-----------------|
| T0 Router 1 | 10.193.105.10 | Pool1 - 10.208.40.0/24    | 254| Map DNAT from 10.208.40.11 to be translated to Ops Mgr at 172.23.1.5; SNAT from internal network 172.23.1.0/24 to 10.208.40.10 for going out |
| T0 Router 1 | 10.193.105.10 | Pool2 - 10.208.50.0/24  | 254 | Map DNAT from 10.208.50.11 to be translated to something internal at 172.23.2.10; SNAT from internal network 172.23.2..0/24 to 10.208.50.10 for going out |
| T0 Router 2 | 10.193.105.15 | Pool3 - 10.208.60.0/24  | 254 | Map DNAT from 10.208.60.11 to be translated to something internal at 182.23.1.10; SNAT from internal network 182.23.1..0/24 to 10.208.60.10 for going out |
| ......... | ....... | .......... | ...| ..... |

Here the transient network only exists between the External Router and the connected T0 Router. IPs from this transient network would be using the NAT configurations to reach things like the Ops Mgr internal private ip. Load balancers might use the IP from the External IP pool to expose a VIP.

After deciding on the IPs that are already reserved for exposed components like Ops Mgr, PAS GoRouter, PAS SSH Proxy, Harbor, PKS Controller etc., allot or divide up the remaining IPs for the PAS and PKS external ip pools by tweaking the range of the external IP Pool.

| Pool Name |  CIDR | Start | End | Notes
|-----------|----------------|---------------|-------------|-----------------|
| PAS-Pool1 | 10.208.40.0/24 |  10.208.40.21 | 10.208.40.254  | Reserving first 20 IPs for Ops Mgr, PAS external facing components. Externally exposed PAS Apps would use from the PAS-Pool.
| PKS-Pool2 | 10.208.50.0/24 |  10.208.50.21 | 10.208.50.254  | Reserving first 20 IPs for PKS Controller, Harbor external facing components. Rest can be used by the PKS Clusters.

### Using Same CIDR for T0 and External IP Pool

If the T0 Router and the external ip pool need to share the same CIDR, then it requires careful planning to setup the routing of the externally exposed IPs via the T0 Router ip. This is applicable in setups where a /24 CIDR is allotted to the client to use and everything needs to be within that CIDR to be routable or exposed to outside as there can be several such similar setups in a big shared infrastructure.

Sample Requirement: User allowed to only use a specific CIDR for exposing to outside. All IPs need to be in the 10.193.105.28/25 range. Things need to be routed via the T0 Router IP : 10.193.105.10.

This requires a careful division of the subnet (here 10.193.105.0/24) into smaller subnets so a specific CIDR would be statically routed through the T0 router without overlapping against the IPs meant for the T0 Routers.

Here, we are dividing 10.193.105.0/24 into 2 big subnets, with first half allotted for the T0 Router (the split can only in ranges of 2) and external IPs in second half 10.193.105.128-10.193.105.255 getting routed via the 10.193.105.10.

| T0 Router |  T0 IP | Subnet for external ip pool |
\# of IPs that can be exposed |
|-------------|---------------|-------------------|---------|
| T0 Router 1 | 10.193.105.10 | Pool1 - 10.193.105.128/25 | 128 |

If more than one pool needs to be exposed, then divide the subnet to make them smaller so they are all routed via the same T0 Router:

| T0 Router |  T0 IP | Subnet for external ip pools |
\# of IPs that can be exposed |
|-------------|---------------|-------------------|---------|
| T0 Router 1 | 10.193.105.10 | Pool1 - 10.193.105.128/26 | 64 |
| T0 Router 1 | 10.193.105.10 | Pool2 - 10.193.105.192/26 | 64 |


If there are additional T0 Routers, then this becomes a task of of reducing the range for the external pools and sharing it with other T0 Router instances.
Same way, if more external pools need to be exposed, keep shrinking the pool size.

| T0 Router |  T0 IP | Subnet for external ip pool |
\# of IPs that can be exposed |
|------------|---------------|-------------------|---|
| T0 Router 1 | 10.193.105.10 | Pool1 - 10.193.105.64/27  | 32 |
| T0 Router 1 | 10.193.105.10 | Pool2 - 10.193.105.96/27  | 32 |
| T0 Router 2 | 10.193.105.15 | Pool3 - 10.193.105.128/26 | 64 |
| T0 Router 3 | 10.193.105.20 | Pool4 - 10.193.105.192/26 | 64 |
| ......... | ....... | .......... | ...|

If there are even more additional T0 Routers, then the above CIDR for external ip pool needs to be made even smaller to make room for another exposed subnet (like 10.193.105.128-10.193.105.192 using 10.193.105.128/26) and so on.

The above table is assuming that the pool of IPs exposed to outside is quite small and there is just one /24 CIDR that can be used for a given install/client for both T0 Router and external IPs and it needs to be all completed within the /24 range.

In the static route configuration, the next hop would be the gateway of the T0 Router. Set the admin distance for the hop to be 1.

Sample Image of configuring static route when T0 Router and external ip pool are on the same CIDR
<div><img src="../images/nsx-v-staticrouting.png" width="500"/></div>

Similar to the transient network approach, after deciding on the IPs that are already reserved for exposed components like Ops Mgr, PAS GoRouter, PAS SSH Proxy, Harbor, PKS Controller etc., allot or divide up the remaining IPs for the PAS and PKS external ip pools by tweaking the range of the external IP Pool.

| Pool Name |  CIDR | Start | End | Notes |
|-----------|----------------|---------------|-------------|-----------------|
| PAS-Pool1 | 10.193.105.64/27  |  10.193.105.72 | 10.193.105.94  | Reserving first 8 IPs for Ops Mgr, PAS external facing components. Externally exposed PAS Apps would use from the PAS-Pool.|
| PAS-Pool2 | 10.193.105.96/27  |  10.193.105.104 | 10.193.105.126  | Reserving first 8 IPs for PKS Controller, Harbor external facing components. Rest can be used by the PKS clusters.|

### Sample NAT setup

Sample Image of NATs on T0 Router (external ip pools are on different CIDR than T0)
<div><img src="../images/nats-transient-network.png" width="500"/></div>
