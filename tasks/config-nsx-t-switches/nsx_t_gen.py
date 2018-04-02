import os
import json
import yaml
from pprint import pprint

import client

DEBUG=True

EDGE_CLUSTERS_ENDPOINT       = '/api/v1/edge-clusters'
TRANSPORT_ZONES_ENDPOINT     = '/api/v1/transport-zones'
ROUTERS_ENDPOINT             = '/api/v1/logical-routers'
ROUTER_PORTS_ENDPOINT        = '/api/v1/logical-router-ports'
SWITCHES_ENDPOINT            = '/api/v1/logical-switches'
SWITCH_PORTS_ENDPOINT        = '/api/v1/logical-ports'
SWITCHING_PROFILE_ENDPOINT   = '/api/v1/switching-profiles'
CONTAINER_IP_BLOCKS_ENDPOINT = '/api/v1/pools/ip-blocks'
EXTERNAL_IP_POOL_ENDPOINT    = '/api/v1/pools/ip-pools'

global_id_map = { }


def init():
	nsx_mgr_ip          = os.getenv('NSX_T_MANAGER_IP')
	nsx_mgr_user        = os.getenv('NSX_T_MANAGER_ADMIN_USER', 'admin')
	nsx_mgr_pwd         = os.getenv('NSX_T_MANAGER_ADMIN_PWD')
	transport_zone_name = os.getenv('NSX_T_MANAGER_TRANSPORT_ZONE')
	nsx_mgr_context     = { 'admin_user' : nsx_mgr_user, 'url': 'https://' + nsx_mgr_ip, 'admin_passwd' : nsx_mgr_pwd }

	client.set_context(nsx_mgr_context)

def print_global_ip_map():
	print '-----------------------------------------------'
	for key in global_id_map:
		print(" {} : {}".format(key, global_id_map[key]))
	print '-----------------------------------------------'

def load_edge_clusters():

  api_endpoint = EDGE_CLUSTERS_ENDPOINT
  resp=client.get(api_endpoint)
  for result in resp.json()['results']:
	  edge_cluster_name = result['display_name']
	  edge_cluster_id = result['id']
	  global_id_map['EDGE_CLUSTER:'+edge_cluster_name] = edge_cluster_id
	  if global_id_map.get('DEFAULT_EDGE_CLUSTER_NAME') is None:
	  	global_id_map['DEFAULT_EDGE_CLUSTER_NAME'] = edge_cluster_name

def get_edge_cluster():

	edge_cluster_name = global_id_map.get('DEFAULT_EDGE_CLUSTER_NAME')
	if edge_cluster_name is None:
		load_edge_clusters()

	return global_id_map['DEFAULT_EDGE_CLUSTER_NAME']

def get_edge_cluster_id():

	default_edge_cluster_name = get_edge_cluster()
	return global_id_map['EDGE_CLUSTER:' + default_edge_cluster_name]

# def get_edge_cluster_id(edge_cluster_name):

# 	if edge_cluster_name is not None and edge_cluster_name != '':
# 		return global_id_map['EDGE_CLUSTER:' + edge_cluster_name]

# 	default_edge_cluster_name = get_edge_cluster()
# 	return global_id_map['EDGE_CLUSTER:' + default_edge_cluster_name]

def load_transport_zones():
  api_endpoint = TRANSPORT_ZONES_ENDPOINT
  resp=client.get(api_endpoint)
  for result in resp.json()['results']:
	  transport_zone_name = result['display_name']
	  transport_zone_id = result['id']
	  global_id_map['TZ:'+transport_zone_name] = transport_zone_id

	  if global_id_map.get('DEFAULT_TRANSPORT_ZONE_NAME') is None:
	  	global_id_map['DEFAULT_TRANSPORT_ZONE_NAME'] = transport_zone_name

def get_transport_zone():

	transport_zone_name = global_id_map.get('DEFAULT_TRANSPORT_ZONE_NAME')
	if transport_zone_name is None:
		load_transport_zones()
			
	return global_id_map['DEFAULT_TRANSPORT_ZONE_NAME']

def get_transport_zone_id(transport_zone):
	default_transport_zone = get_transport_zone()

	transport_zone_id = global_id_map.get('TZ:' + default_transport_zone)
	if transport_zone_id is None:
		return global_id_map['TZ:' + default_transport_zone]
	
	return transport_zone_id

def update_tag(api_endpoint, tag_map):

	tags = []
	resp = client.get(api_endpoint)
	updated_payload = resp.json()

	for key in tag_map:
		entry = { 'scope': key, 'tag': tag_map[key] }
		tags.append(entry)
	updated_payload['tags'] = tags
	
	resp = client.put(api_endpoint, updated_payload)	

def check_switching_profile(switching_profile_name):
  api_endpoint = SWITCHING_PROFILE_ENDPOINT
  
  resp = client.get(api_endpoint)

  switching_profile_id = None
  for result in resp.json()['results']:
  	global_id_map['SP:' + result['display_name']] = result['id']
  	if result['display_name'] == switching_profile_name:
  		switching_profile_id = result['id']

  return switching_profile_id


def create_ha_switching_profile(switching_profile_name):
  api_endpoint = SWITCHING_PROFILE_ENDPOINT  
  
  switching_profile_id=check_switching_profile(switching_profile_name)
  if switching_profile_id is not None:
    return switching_profile_id  

  payload={
      'resource_type': 'SpoofGuardSwitchingProfile',
      'description': 'Spoofguard switching profile for ncp-cluster-ha, created by nsx-t-gen!!',
      'display_name': switching_profile_name, 
      'white_list_providers': ['LSWITCH_BINDINGS']
    }
  resp = client.post(api_endpoint, payload )
  switching_profile_id=resp.json()['id']

  global_id_map['SP:' + switching_profile_name] = switching_profile_id
  return switching_profile_id

def check_logical_router(router_name):
  api_endpoint = ROUTERS_ENDPOINT
  
  resp = client.get(api_endpoint)

  logical_router_id = None
  for result in resp.json()['results']:
  	global_id_map[result['router_type'] + 'ROUTER:' + result['display_name']] = result['id']
  	if result['display_name'] == router_name:
  		logical_router_id = result['id']

  return logical_router_id

def create_t0_logical_router(router_name):
  api_endpoint = ROUTERS_ENDPOINT
  
  router_type='TIER0'
  edge_cluster_id=get_edge_cluster_id()

  t0_router_id=check_logical_router(router_name)
  if t0_router_id is not None:
    return t0_router_id  

  payload={
      'resource_type': 'LogicalRouter',
      'description': "Logical router of type {}, created by nsx-t-gen!!".format(router_type),
      'display_name': router_name,
      'edge_cluster_id': edge_cluster_id,      
      'router_type': router_type,
      'high_availability_mode': 'ACTIVE_STANDBY',
    }
  resp = client.post(api_endpoint, payload )

  router_id=resp.json()['id']
  print("Created Logical Router '{}' of type '{}'".format(router_name, router_type))
  global_id_map['TIER0ROUTER:' + router_name] = router_id
  return router_id

def create_t1_logical_router(router_name):
  api_endpoint = ROUTERS_ENDPOINT
  
  router_type='TIER1'
  edge_cluster_id=get_edge_cluster_id()

  t1_router_id=check_logical_router(router_name)
  if t1_router_id is not None:
    return t1_router_id
  
  payload={
      'resource_type': 'LogicalRouter',
      'description': "Logical router of type {}, created by nsx-t-gen!!".format(router_type),
      'display_name': router_name,
      'edge_cluster_id': edge_cluster_id,      
      'router_type': router_type
    }
  resp = client.post(api_endpoint, payload )

  router_id=resp.json()['id']
  global_id_map['TIER1ROUTER:' + router_name] = router_id
  print("Created Logical Router '{}' of type '{}'".format(router_name, router_type))
  return router_id


def create_t1_logical_router_and_port(t0_router_name, t1_router_name):
  api_endpoint = ROUTER_PORTS_ENDPOINT
  
  t0_router_id=create_t0_logical_router(t0_router_name)
  t1_router_id=create_t1_logical_router(t1_router_name)
  
  name = "LogicalRouterLinkPortFrom%sTo%s" % (t0_router_name, t1_router_name )
  descp = "Port created on %s router for %s" % (t0_router_name, t1_router_name )
  target_display_name = "LinkedPort_%sTo%s" % (t0_router_name, t1_router_name )

  payload1={
      'resource_type': 'LogicalRouterLinkPortOnTIER0',
      'description': descp,
      'display_name': name,
      'logical_router_id': t0_router_id      
    }
      
  resp = client.post(api_endpoint, payload1)
  target_id=resp.json()['id']

  name = "LogicalRouterLinkPortFrom%sTo%s" % (t1_router_name, t0_router_name )
  descp = "Port created on %s router for %s" % (t1_router_name, t0_router_name )
  target_display_name = "LinkedPort_%sTo%s"% (t1_router_name, t0_router_name )

  payload2 = {
        'resource_type': 'LogicalRouterLinkPortOnTIER1',
        'description': descp,
        'display_name': name,
        'logical_router_id': t1_router_id,   
        'linked_logical_router_port_id' : {
          'target_display_name' : target_display_name,
          'target_type' : 'LogicalRouterLinkPortOnTIER0',
          'target_id' : target_id
        }
      }

  resp = client.post(api_endpoint, payload2)
  print("Created Logical Router Port between T0Router: '{}' and T1Router: '{}'".format(t0_router_name, t1_router_name))
  logical_router_port_id=resp.json()['id']
  return logical_router_port_id


def check_logical_switch(logical_switch):
  api_endpoint = SWITCHES_ENDPOINT
  
  resp = client.get(api_endpoint )

  logical_switch_id = None
  for result in resp.json()['results']:
  	global_id_map['LS:' + result['display_name']] = result['id']
  	if result['display_name'] == logical_switch:
  		logical_switch_id = result['id']

  return logical_switch_id


def create_logical_switch(logical_switch_name):
  api_endpoint = SWITCHES_ENDPOINT
  transport_zone_id=get_transport_zone_id(None)

  payload={ 'transport_zone_id': transport_zone_id,
        'display_name': logical_switch_name,
        'admin_state': 'UP',
        'replication_mode': 'MTEP'
      }

  resp = client.post(api_endpoint, payload )

  logical_switch_id=resp.json()['id']
  print("Created Logical Switch '{}'".format(logical_switch_name))
  
  global_id_map['LS:' + logical_switch_name] = logical_switch_id
  return logical_switch_id


def create_logical_switch_port(logical_switch_name, logical_switch_id):
  api_endpoint = SWITCH_PORTS_ENDPOINT
  switch_port_name = logical_switch_name + 'RouterPortSwitchPort'

  payload={
        'logical_switch_id': logical_switch_id,
        'display_name': switch_port_name,        
        'admin_state': 'UP'
      }

  resp = client.post(api_endpoint, payload )

  logical_switch_port_id=resp.json()['id']
  global_id_map['LSP:' + switch_port_name] = logical_switch_port_id
  
  return logical_switch_port_id

def associate_logical_switch_port(t1_router_name, logical_switch_name, subnet):
  api_endpoint = ROUTER_PORTS_ENDPOINT

  network=subnet.split('/')[0]
  cidr=subnet.split('/')[1]
  
  t1_router_id=check_logical_router(t1_router_name)
  logical_switch_id=check_logical_switch(logical_switch_name)
  logical_switch_port=create_logical_switch_port(logical_switch_name, logical_switch_id )

  name = logical_switch_name+ 'RouterPort'
  switch_port_name = logical_switch_name + 'RouterPortSwitchPort'

  payload={
        'resource_type' : 'LogicalRouterDownLinkPort',
        'display_name' : name,
        'logical_router_id' : t1_router_id,
        'linked_logical_switch_port_id' : {
          'target_display_name' : switch_port_name,
          'target_type' : 'LogicalPort',
          'target_id' : logical_switch_port
        },
        'subnets' : [ {
          'ip_addresses' : [ network ],
          'prefix_length' : cidr
        } ]
      }

  resp=client.post(api_endpoint, payload)

  logical_router_port_id=resp.json()['id']
  print("Created Logical Switch Port from Logical Switch {} with name: {} "
  			+ "to T1Router: {}".format(logical_switch_name, switch_port_name, t1_router_name))
  
  global_id_map['LRP:' + name] = logical_router_port_id
  return logical_router_port_id

def create_container_ip_block(ip_block_name, cidr):
  api_endpoint = CONTAINER_IP_BLOCKS_ENDPOINT
  
  payload={
      'resource_type': 'IpBlock',
      'display_name': ip_block_name,
      'cidr': cidr
    }
  resp = client.post(api_endpoint, payload )

  ip_block_id=resp.json()['id']
  print("Created Container IP Block '{}' with cidr: {}".format(ip_block_name, cidr))
  
  global_id_map['IPBLOCK:' + ip_block_name] = ip_block_id
  return ip_block_id

def create_external_ip_pool(ip_pool_name, cidr, gateway, start_ip, end_ip):
  api_endpoint = EXTERNAL_IP_POOL_ENDPOINT
  
  payload={
      'resource_type': 'IpPool',
      'display_name': ip_pool_name,      
      'subnets' : [ {  
      	'allocation_ranges' : [ { 
      		'start' : start_ip,
        	'end' : end_ip
	      } ],
	      'cidr' : cidr,
	      'gateway_ip' : gateway,
	      'dns_nameservers' : [ ]
       } ],
    }
  resp = client.post(api_endpoint, payload )

  ip_pool_id=resp.json()['id']
  print("Created External IP Pool '{}' with cidr: {}, gateway: {}, start: {},"
  	+ " end: {}".format(ip_pool_name, cidr, gateway, start_ip, end_ip))
  global_id_map['IPPOOL:' + ip_pool_name] = ip_pool_id
  return ip_pool_id


def main():
	init()
	load_edge_clusters()
	load_transport_zones()
	
	t0_router_name    = os.getenv('NSX_T_T0ROUTER')
	t1_router_content = os.getenv('NSX_T_T1ROUTER_LOGICAL_SWITCHES')
  t1_routers        = yaml.load(t1_router_content)
  
	t0_router_id   = create_t0_logical_router(t0_router_name)

	pas_tag_name    = os.getenv('NSX_T_PAS_TAG')	
	pas_tags = { 	
						'ncp/cluster': pas_tag_name , 
						'ncp/shared_resource': 'true' 
					}
	update_tag(ROUTERS_ENDPOINT + '/' + t0_router_id, pas_tags)

	ha_switching_profile = os.getenv('NSX_T_HA_SWITCHING_PROFILE', 'HASwitchingProfile')
	switching_profile_id=create_ha_switching_profile(ha_switching_profile)
	switching_profile_tags = { 	
															'ncp/cluster': pas_tag_name , 
															'ncp/shared_resource': 'true' , 
															'ncp/ha': 'true' 
														}
	update_tag(SWITCHING_PROFILE_ENDPOINT + '/' + switching_profile_id, switching_profile_tags)

	ip_blocks   = yaml.load(os.getenv('NSX_T_CONTAINER_IP_BLOCK'))
	for ip_block in ip_blocks:
		container_ip_block_id = create_container_ip_block(ip_block['name'], ip_block['cidr'])
		update_tag(CONTAINER_IP_BLOCKS_ENDPOINT + '/' + container_ip_block_id, pas_tags)
	
	ip_pools    = yaml.load(os.getenv('NSX_T_EXTERNAL_IP_POOL'))
	for ip_pool in ip_pools:
		create_external_ip_pool(ip_pool['name'], 
														ip_pool['cidr'], 
														ip_pool['gateway'], 
														ip_pool['start'], 
														ip_pool['end'])

	for t1_router in t1_routers:
		t1_router_name = t1_router['name']
		create_t1_logical_router_and_port(t0_router_name, t1_router_name)
		logical_switches = t1_router['switches']
		for logical_switch_entry in logical_switches:
			logical_switch_name = logical_switch_entry['name']
			logical_switch_subnet = logical_switch_entry['subnet']
			create_logical_switch(logical_switch_name)
			associate_logical_switch_port(t1_router_name, logical_switch_name, logical_switch_subnet)

if __name__ == '__main__':
	main()