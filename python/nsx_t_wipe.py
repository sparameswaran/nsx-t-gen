#!/usr/bin/env python

# nsx-edge-gen
#
# Copyright (c) 2015-Present Pivotal Software, Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

__author__ = 'Sabha Parameswaran'

import os
import json
import yaml
from pprint import pprint

import client
import mobclient

DEBUG=True
esxi_hosts_file = 'esxi_hosts'

API_VERSION                  = '/api/v1'

EDGE_CLUSTERS_ENDPOINT       = '%s%s' % (API_VERSION, '/edge-clusters')
TRANSPORT_NODES_ENDPOINT     = '%s%s' % (API_VERSION, '/transport-nodes')
FABRIC_NODES_ENDPOINT        = '%s%s' % (API_VERSION, '/fabric/nodes')
ROUTERS_ENDPOINT             = '%s%s' % (API_VERSION, '/logical-routers')
ROUTER_PORTS_ENDPOINT        = '%s%s' % (API_VERSION, '/logical-router-ports')
SWITCHES_ENDPOINT            = '%s%s' % (API_VERSION, '/logical-switches')
SWITCH_PORTS_ENDPOINT        = '%s%s' % (API_VERSION, '/logical-ports')
EDGE_CLUSTERS_ENDPOINT       = '%s%s' % (API_VERSION, '/edge-clusters')
LBR_SERVICES_ENDPOINT        = '%s%s' % (API_VERSION, '/loadbalancer/services')
LBR_VIRTUAL_SERVER_ENDPOINT  = '%s%s' % (API_VERSION, '/loadbalancer/virtual-servers')
LBR_POOLS_ENDPOINT           = '%s%s' % (API_VERSION, '/loadbalancer/pools')
LBR_MONITORS_ENDPOINT        = '%s%s' % (API_VERSION, '/loadbalancer/monitors')

COMPUTE_COLLECTION_FABRIC_TEMPLATES_ENDPOINT = '%s%s' % (API_VERSION, '/fabric/compute-collection-fabric-templates')
COMPUTE_COLLECTION_TRANSPORT_NODES_ENDPOINT  = '%s%s' % (API_VERSION, '/compute-collection-transport-node-templates')

esxi_host_map = {}
edge_transport_node_map = {}


def init():

    nsx_mgr_ip      = os.getenv('NSX_T_MANAGER_IP')
    nsx_mgr_user    = os.getenv('NSX_T_MANAGER_ADMIN_USER', 'admin')
    nsx_mgr_pwd     = os.getenv('NSX_T_MANAGER_ROOT_PWD')
    nsx_mgr_context = {
                      'admin_user' : nsx_mgr_user,
                      'url': 'https://' + nsx_mgr_ip,
                      'admin_passwd' : nsx_mgr_pwd
                    }
    client.set_context(nsx_mgr_context)



def identify_edges_and_hosts():
    fabric_nodes_api_endpoint = FABRIC_NODES_ENDPOINT
    fabric_nodes_resp = client.get(fabric_nodes_api_endpoint)
    for fabric_node in fabric_nodes_resp.json()['results']:
        print 'Fabric Node: {}'.format(fabric_node)
        if fabric_node['resource_type'] == 'EdgeNode':
            edge_transport_node_map[fabric_node['id']] = fabric_node['display_name']
        else:
            esxi_host_map[fabric_node['id']] = fabric_node['display_name']

    # edge_clusters_api_endpoint = EDGE_CLUSTERS_ENDPOINT
    # edge_clusters_resp = client.get(edge_clusters_api_endpoint)
    # for edge_cluster in edge_clusters_resp.json()['results']:
    #     print 'Edge Cluster: {}'.format(edge_cluster)
    #     for member in edge_cluster['members']:
    #         edge_transport_node_map.append(member['transport_node_id'])
    #
    # transport_nodes_api_endpoint = TRANSPORT_NODES_ENDPOINT
    # transport_nodes_resp = client.get(transport_nodes_api_endpoint)
    # for transport_node in transport_nodes_resp.json()['results']:
    #     print 'Transport node: {}'.format(transport_node)
    #     if transport_node['id'] not in edge_transport_node_map:
    #         esxi_host_map.append(transport_node['id'])

def create_esxi_hosts():
    esxi_root_pwd = os.getenv('ESXI_HOSTS_ROOT_PWD')
    esxi_host_file_map = { 'esxi_hosts' : { 'hosts' : {} }}
    output_esxi_host_map = { }
    for esxi_host_id in esxi_host_map:
        esxi_host_name = esxi_host_map[esxi_host_id]
        output_esxi_host_map[esxi_host_name] = {
                                                'ansible_ssh_host': esxi_host_name,
                                                'ansible_ssh_user': 'root',
                                                'ansible_ssh_pass': esxi_root_pwd
                                            }
    esxi_host_file_map = { 'esxi_hosts' : { 'hosts' : output_esxi_host_map } }
    write_config(esxi_host_file_map, 'esxi_hosts', useNoAliasDumper=True)

def handle_wipe_env():

    # Before we can wipe the env. we need to remove the hosts as transport nodes

    # we need to disable auto-install of nsx, remove the auto-addition as transport node
    disable_auto_install_for_compute_fabric()

    # Then remove the vcenter extension for nsx
    handle_nsxt_extension_removal()

    # remove the LBRs
    delete_lbrs()

    # clean up all the routers and switches
    delete_routers_and_switches()

    # remove the edge Clusters
    delete_edge_clusters()

    # finally remove the host from transport node list
    uninstall_nsx_from_hosts()

def disable_auto_install_for_compute_fabric():
    compute_fabric_collection_api_endpoint = COMPUTE_COLLECTION_FABRIC_TEMPLATES_ENDPOINT
    transport_node_collection_api_endpoint = COMPUTE_COLLECTION_TRANSPORT_NODES_ENDPOINT

    outer_resp = client.get(compute_fabric_collection_api_endpoint)
    #print 'Got Compute collection respo: {}'.format(outer_resp)
    compute_fabric_templates = outer_resp.json()['results']
    for compute_fabric in compute_fabric_templates:
        #print 'Iterating over Compute fabric respo: {}'.format(compute_fabric)
        compute_fabric['auto_install_nsx'] = False
        compute_fabric_id = compute_fabric['id']

        compute_collection_id = compute_fabric['compute_collection_id']

        # First remove the related transport node template from the compute collection relationship
        transport_node_association_from_compute_fabric_api_endpoint = '%s?compute_collection_id=%s' % (transport_node_collection_api_endpoint, compute_collection_id)

        get_resp = client.get(transport_node_association_from_compute_fabric_api_endpoint, check=False )
        if get_resp.status_code == 200:
            try:
                for transport_node in get_resp.json()['results']:
                    transport_node_id = transport_node['id']
                    transport_node_removal_api_endpoint = '%s/%s' % (transport_node_collection_api_endpoint, transport_node_id)
                    delete_resp = client.delete(transport_node_removal_api_endpoint, check=False )
                    print 'Removed auto-linking of Host as Transport Node in Fabric for Compute Manager: {}'.format(compute_fabric['compute_collection_id'])
            except Exception as e:
                print 'No transport nodes associated'
                #ignore
        # Now change the compute fabric template
        compute_fabric_update_api_endpoint = '%s/%s' % (compute_fabric_collection_api_endpoint, compute_fabric_id)
        resp = client.put(compute_fabric_update_api_endpoint, compute_fabric, check=False )

        if resp.status_code < 400:
            print 'Disabled auto install of NSX in Compute Fabric: {}'.format(compute_fabric['compute_collection_id'])
            print ''
        else:
            print 'Problem in disabling auto install in Compute Fabric: {}'.format(compute_fabric['compute_collection_id'])
            print 'Associated Error: {}'.format(resp.json())
            exit(1)

def handle_nsxt_extension_removal():
    vcenter_context = { }
    compute_managers_config_raw = os.getenv('COMPUTE_MANAGER_CONFIGS')
    if compute_managers_config_raw is None or compute_managers_config_raw == '':
        print 'Compute manager config is empty, returning'
        return

    compute_managers_config = yaml.load(compute_managers_config_raw)['compute_managers']

  # compute_managers:
  # - vcenter_name: vcenter-01
  #   vcenter_host: vcenter-01.corp.local
  #   vcenter_usr: administrator@vsphere.local
  #   vcenter_pwd: VMWare1!
  #   # Multiple clusters under same vcenter can be specified
  #   clusters:
  #   - vcenter_cluster: Cluster1
  #     overlay_profile_mtu: 1600 # Min 1600
  #     overlay_profile_vlan: EDIT_ME # VLAN ID for the TEP/Overlay network
  #     # Specify an unused vmnic on esxi host to be used for nsx-t
  #     # can be multiple vmnics separated by comma
  #     uplink_vmnics: vmnic1 # vmnic1,vmnic2...

    for vcenter in compute_managers_config:
        vcenter_context = {
                            'address'      : vcenter['vcenter_host'],
                            'admin_user'   : vcenter['vcenter_usr'],
                            'admin_passwd' : vcenter['vcenter_pwd']
                        }
        print 'Removing nsx-t extension from vcenter : {}\n'.format(vcenter_context['address'])
        mobclient.set_context(vcenter_context)
        mobclient.remove_nsxt_extension_from_vcenter()

def delete_routers_and_switches():
    delete_router_ports()
    delete_routers()
    delete_logical_switch_ports()
    delete_logical_switches()

def delete_routers():
    api_endpoint = ROUTERS_ENDPOINT
    print 'Starting deletion of Routers!'
    router_resp = client.get(api_endpoint)
    for instance in router_resp.json()['results']:
        instance_api_endpoint = '%s/%s' % (api_endpoint, instance['id'])
        client.delete(instance_api_endpoint)
    print ' Deleted Routers!'

def delete_router_ports():
    api_endpoint = ROUTER_PORTS_ENDPOINT
    print 'Starting deletion of Router Ports!'
    router_ports_resp = client.get(api_endpoint)
    for instance in router_ports_resp.json()['results']:
        instance_api_endpoint = '%s/%s' % (api_endpoint, instance['id'])
        client.delete(instance_api_endpoint)
    print ' Deleted Router Ports!'

def delete_logical_switch_ports():
    api_endpoint = SWITCH_PORTS_ENDPOINT
    print 'Starting deletion of Logical Switch Ports!'
    logical_switch_ports_resp = client.get(api_endpoint)
    for instance in logical_switch_ports_resp.json()['results']:
        instance_api_endpoint = '%s/%s' % (api_endpoint, instance['id'])
        client.delete(instance_api_endpoint)
    print ' Deleted Logical Switch Ports!'

def delete_logical_switches():
    api_endpoint = SWITCHES_ENDPOINT
    print 'Starting deletion of Logical Switches!'
    logical_switches_resp = client.get(api_endpoint)
    for instance in logical_switches_resp.json()['results']:
        instance_api_endpoint = '%s/%s' % (api_endpoint, instance['id'])
        client.delete(instance_api_endpoint)
    print ' Deleted Logical Switches!'

def delete_lbrs():
    api_endpoint = LBR_SERVICES_ENDPOINT
    print 'Starting deletion of Loadbalancers!'
    lbrs_resp = client.get(api_endpoint)
    for instance in lbrs_resp.json()['results']:
        instance_api_endpoint = '%s/%s' % (api_endpoint, instance['id'])
        client.delete(instance_api_endpoint)
    print ' Deleted Loadbalancers!'

    api_endpoint = LBR_VIRTUAL_SERVER_ENDPOINT
    print 'Starting deletion of Virtual Servers!'
    virtual_servers_resp = client.get(api_endpoint)
    for instance in virtual_servers_resp.json()['results']:
        instance_api_endpoint = '%s/%s' % (api_endpoint, instance['id'])
        client.delete(instance_api_endpoint)
    print ' Deleted Virtual Servers!'

    api_endpoint = LBR_POOLS_ENDPOINT
    print 'Starting deletion of Server Pools!'
    pool_servers_resp = client.get(api_endpoint)
    for instance in pool_servers_resp.json()['results']:
        instance_api_endpoint = '%s/%s' % (api_endpoint, instance['id'])
        client.delete(instance_api_endpoint)
    print ' Deleted Server Pools!'

def delete_edge_clusters():
    api_endpoint = EDGE_CLUSTERS_ENDPOINT
    print 'Starting deletion of Edge Clusters!'
    edge_clusters_resp = client.get(api_endpoint)
    for instance in edge_clusters_resp.json()['results']:
        instance_api_endpoint = '%s/%s' % (api_endpoint, instance['id'])
        resp = client.delete(instance_api_endpoint)
        print 'Deleted Edge Cluster: {}'.format(resp)
    print ' Deleted Edge Clusters!'

def uninstall_nsx_from_hosts():
    transport_nodes_api_endpoint = TRANSPORT_NODES_ENDPOINT
    fabric_nodes_api_endpoint = FABRIC_NODES_ENDPOINT

    uninstall_failed = False
    print '\nStarting uninstall of NSX Components from Fabric!!\n'
    for edge_node in edge_transport_node_map.keys():
        print 'Deleting Edge from Transport and Fabric nodes: {}'.format(edge_transport_node_map[edge_node])
        transport_node_delete_url = '%s/%s' % (transport_nodes_api_endpoint, edge_node)
        transport_nodes_resp = client.delete(transport_node_delete_url)
        print '  Deleted response from Transport nodes: {}'.format(transport_nodes_resp)

        fabric_node_delete_url = '%s/%s' % (fabric_nodes_api_endpoint, edge_node)
        fabric_node_delete_resp = client.delete(fabric_node_delete_url)
        print '  Deleted response from Fabric nodes: {}'.format(fabric_node_delete_resp)

    for esxi_host in esxi_host_map.keys():
        print 'Deleting Host from Transport and Fabric nodes: {}'.format(esxi_host_map[esxi_host])
        transport_node_delete_url = '%s/%s' % (transport_nodes_api_endpoint, esxi_host)
        transport_nodes_resp = client.delete(transport_node_delete_url)
        print '  Delete response from Transport nodes: {}'.format(transport_nodes_resp)

        fabric_node_delete_url = '%s/%s' % (fabric_nodes_api_endpoint, esxi_host)
        fabric_node_delete_resp = client.delete(fabric_node_delete_url)
        print '  Delete response from Fabric nodes: {}'.format(fabric_node_delete_resp)

        if fabric_node_delete_resp.status_code >= 400:
            uninstall_failed = True
    print ' Uninstalled NSX Components from Fabric!'

    return uninstall_failed

def write_config(content, destination, useNoAliasDumper=True):
	dumper = NoAliasDumper if useNoAliasDumper else None
	try:
		with open(destination, 'w') as output_file:
			if useNoAliasDumper:
				yaml.dump(content, output_file,  Dumper=dumper)
			else:
				yaml.dump(content, output_file)

	except IOError as e:
		print('Error : {}'.format(e))
		print >> sys.stderr, 'Problem with writing out a yaml file.'
		sys.exit(1)

class NoAliasDumper(yaml.Dumper):
	def ignore_aliases(self, data):
		return True

def main():
    global esxi_hosts_file

    esxi_hosts_file = sys.argv[1]
    init()
    identify_edges_and_hosts()
    handle_wipe_env()

if __name__ == '__main__':
  main()
