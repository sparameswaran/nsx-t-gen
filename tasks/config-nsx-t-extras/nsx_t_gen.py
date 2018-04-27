import os
import json
import yaml
from pprint import pprint

import client

DEBUG=True

API_VERSION                  = '/api/v1'

EDGE_CLUSTERS_ENDPOINT       = '%s%s' % (API_VERSION, '/edge-clusters')
TRANSPORT_ZONES_ENDPOINT     = '%s%s' % (API_VERSION, '/transport-zones')
ROUTERS_ENDPOINT             = '%s%s' % (API_VERSION, '/logical-routers')
ROUTER_PORTS_ENDPOINT        = '%s%s' % (API_VERSION, '/logical-router-ports')
SWITCHES_ENDPOINT            = '%s%s' % (API_VERSION, '/logical-switches')
SWITCH_PORTS_ENDPOINT        = '%s%s' % (API_VERSION, '/logical-ports')
SWITCHING_PROFILE_ENDPOINT   = '%s%s' % (API_VERSION, '/switching-profiles')
CONTAINER_IP_BLOCKS_ENDPOINT = '%s%s' % (API_VERSION, '/pools/ip-blocks')
EXTERNAL_IP_POOL_ENDPOINT    = '%s%s' % (API_VERSION, '/pools/ip-pools')
TRUST_MGMT_CSRS_ENDPOINT     = '%s%s' % (API_VERSION, '/trust-management/csrs')
TRUST_MGMT_CRLS_ENDPOINT     = '%s%s' % (API_VERSION, '/trust-management/crls')
TRUST_MGMT_SELF_SIGN_CERT    = '%s%s' % (API_VERSION, '/trust-management/csrs/')
TRUST_MGMT_UPDATE_CERT       = '%s%s' % (API_VERSION, '/node/services/http?action=apply_certificate')

global_id_map = { }


def init():
	nsx_mgr_ip          = os.getenv('NSX_T_MANAGER_IP')
	nsx_mgr_user        = os.getenv('NSX_T_MANAGER_ADMIN_USER', 'admin')
	nsx_mgr_pwd         = os.getenv('NSX_T_MANAGER_ROOT_PWD')
	transport_zone_name = os.getenv('NSX_T_OVERLAY_TRANSPORT_ZONE')
	nsx_mgr_context     = { 
													'admin_user' : nsx_mgr_user, 
													'url': 'https://' + nsx_mgr_ip, 
													'admin_passwd' : nsx_mgr_pwd 
												}
	global_id_map['DEFAULT_TRANSPORT_ZONE_NAME'] = transport_zone_name

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

#   if edge_cluster_name is not None and edge_cluster_name != '':
#     return global_id_map['EDGE_CLUSTER:' + edge_cluster_name]

#   default_edge_cluster_name = get_edge_cluster()
#   return global_id_map['EDGE_CLUSTER:' + default_edge_cluster_name]

def load_transport_zones():
	api_endpoint = TRANSPORT_ZONES_ENDPOINT  

	resp=client.get(api_endpoint)
	for result in resp.json()['results']:
		transport_zone_name = result['display_name']
		transport_zone_id = result['id']
		global_id_map['TZ:'+transport_zone_name] = transport_zone_id

def get_transport_zone():

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

def load_logical_routers():
	api_endpoint = ROUTERS_ENDPOINT
	resp=client.get(api_endpoint)
	for result in resp.json()['results']:
		router_name = result['display_name']
		router_id = result['id']
		router_type = result['router_type']
		global_id_map['ROUTER:'+router_type+':'+router_name] = router_id

def check_logical_router(router_name):
	api_endpoint = ROUTERS_ENDPOINT
	
	resp = client.get(api_endpoint)

	logical_router_id = None
	for result in resp.json()['results']:
		global_id_map[result['router_type'] + 'ROUTER:' + result['display_name']] = result['id']
		if result['display_name'] == router_name:
			logical_router_id = result['id']

	return logical_router_id

def check_logical_router_port(router_id):
	api_endpoint = ROUTER_PORTS_ENDPOINT
	
	resp = client.get(api_endpoint)

	logical_router_port_id = None
	for result in resp.json()['results']:
		global_id_map['ROUTER_PORT:' + result['display_name']] = result['id']
		if result['logical_router_id'] == router_id:
			logical_router_port_id = result['id']

	return logical_router_port_id

def create_t0_logical_router(t0_router):
	api_endpoint = ROUTERS_ENDPOINT
	
	router_type='TIER0'
	edge_cluster_id=get_edge_cluster_id()

	router_name = t0_router['name']
	t0_router_id=check_logical_router(router_name)
	if t0_router_id is not None:
		return t0_router_id  

	payload={
			'resource_type': 'LogicalRouter',
			'description': "Logical router of type {}, created by nsx-t-gen!!".format(router_type),
			'display_name': router_name,
			'edge_cluster_id': edge_cluster_id,      
			'router_type': router_type,
			'high_availability_mode': t0_router['ha_mode'],
		}
	resp = client.post(api_endpoint, payload )

	router_id=resp.json()['id']
	print("Created Logical Router '{}' of type '{}'".format(router_name, router_type))
	global_id_map['TIER0ROUTER:' + router_name] = router_id
	return router_id

def create_t0_logical_router_and_port(t0_router):

	api_endpoint = ROUTER_PORTS_ENDPOINT
	router_name = t0_router['name']
	subnet = t0_router['subnet']
	
	router_id=create_t0_logical_router(router_name)  
	logical_router_port_id=check_logical_router_port(t0_router_id)
	if logical_router_port_id is not None:
		return t0_router_id

	name = "LogicalRouterUplinkPortFor%s" % (router_name )
	descp = "Uplink Port created for %s router" % (router_name)
	target_display_name = "LogicalRouterUplinkFor%s" % (router_name)

	network=subnet.split('/')[0]
	cidr=subnet.split('/')[1]

	payload1={
			'resource_type': 'LogicalRouterUpLinkPort',
			'description': descp,
			'display_name': name,
			'logical_router_id': router_id,
			'edge_cluster_member_index' : [ t0_router['edge_index'] ],
			'subnets' : [ {
					'ip_addresses' : [ network ],
					'prefix_length' : cidr
				} ]    
		}
			
	resp = client.post(api_endpoint, payload1)
	target_id=resp.json()['id']

	print("Created Logical Router Uplink Port for T0Router: '{}'".format(router_name))
	logical_router_port_id=resp.json()['id']
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


def create_t1_logical_router_and_port(t0_router_name, t1_router_name, t0_router_subnet):
	api_endpoint = ROUTER_PORTS_ENDPOINT
	
	t0_router_id=create_t0_logical_router_and_port(t0_router_name, t0_router_subnet)
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

def create_pas_tags():
	pas_tag_name   = os.getenv('NSX_T_PAS_NCP_CLUSTER_TAG') 
	pas_tags = {  
						'ncp/cluster': pas_tag_name , 
						'ncp/shared_resource': 'true' 
					}
	return pas_tags

def create_container_ip_blocks():
	ip_blocks = yaml.load(os.getenv('NSX_T_CONTAINER_IP_BLOCK_SPEC'))
	for ip_block in ip_blocks['container_ip_blocks']:
		ip_block_name   = ip_block('name')
		ip_block_cidr   = ip_block('cidr')    
		container_ip_block_id = create_container_ip_block(ip_block_name, ip_block_cidr)
		update_tag(CONTAINER_IP_BLOCKS_ENDPOINT + '/' + container_ip_block_id, create_pas_tags())
		
def create_external_ip_pools():
	ip_pools    = yaml.load(os.getenv('NSX_T_EXTERNAL_IP_POOL_SPEC'))
	for ip_pool in ip_pools['external_ip_pools']:
		ip_pool_id - create_external_ip_pool(ip_pool['name'], 
														ip_pool['cidr'], 
														ip_pool['gateway'], 
														ip_pool['start'], 
														ip_pool['end']) 

		external_ip_pool_profile_tags = {  
																'ncp/cluster': pas_tag_name , 
																'ncp/external': 'true'
															}
		update_tag(EXTERNAL_IP_POOL_ENDPOINT + '/' + ip_pool_id, external_ip_pool_profile_tags)


def create_ha_switching_profile():
	pas_tag_name   = os.getenv('NSX_T_PAS_NCP_CLUSTER_TAG')
	ha_switching_profiles = yaml.load(os.getenv('NSX_T_HA_SWITCHING_PROFILE_SPEC'))['ha_switching_profiles']
	
	api_endpoint = SWITCHING_PROFILE_ENDPOINT

	for ha_switching_profile in ha_switching_profiles:
		switching_profile_name = ha_switching_profile['name']  
		switching_profile_id   = check_switching_profile(ha_switching_profile['name'])
		if switching_profile_id is None:
			payload={
					'resource_type': 'SpoofGuardSwitchingProfile',
					'description': 'Spoofguard switching profile for ncp-cluster-ha, created by nsx-t-gen!!',
					'display_name': switching_profile_name, 
					'white_list_providers': ['LSWITCH_BINDINGS']
				}
			resp = client.post(api_endpoint, payload )
			switching_profile_id=resp.json()['id']

		global_id_map['SP:' + switching_profile_name] = switching_profile_id
		switching_profile_tags = {  
																'ncp/cluster': pas_tag_name , 
																'ncp/shared_resource': 'true' , 
																'ncp/ha': 'true' 
															}
		update_tag(SWITCHING_PROFILE_ENDPOINT + '/' + switching_profile_id, switching_profile_tags)
	print('Done creating HASwitchingProfiles\n')

def list_certs():
	csr_request = yaml.load(os.getenv('NSX_T_CSR_REQUEST_SPEC'))['csr_request']
	
	api_endpoint = TRUST_MGMT_CSRS_ENDPOINT
	existing_csrs_response = client.get(api_endpoint).json()
	if existing_csrs_response['result_count'] > 0:
		for csr_entry in existing_csrs_response['results']:
			print('CSR Entry: {}'.format(csr_entry))
	print('Done listing CSRs\n')

def generate_self_signed_cert():
	
	nsx_t_manager_fqdn = os.getenv('NSX_T_MANAGER_FQDN')
	csr_request = yaml.load(os.getenv('NSX_T_CSR_REQUEST_SPEC'))['csr_request']
	
	api_endpoint = TRUST_MGMT_CSRS_ENDPOINT
	existing_csrs_response = client.get(api_endpoint).json()
	# if existing_csrs_response['result_count'] > 0:
	# 	print('Error! CSR already exists!!,\n\t count of csrs:{}'.format( existing_csrs_response['result_count']))
	# 	for csr_entry in existing_csrs_response['results']:
	# 		print('\t CSR Entry: {}'.format(csr_entry))
	# 	return

	tokens = csr_request['common_name'].split('.')
	if len(tokens) < 3:
		print('Error!! CSR common name is not a full qualified domain name: {}!!'.format(csr_request['common_name']))
		exit(-1)

	payload = { 
						'subject': {            
							'attributes': [              
								{ 'key':'CN','value': nsx_t_manager_fqdn },
								{ 'key':'O','value':  csr_request['org_name'] },
								{ 'key':'OU','value': csr_request['org_unit'] },
								{ 'key':'C','value':  csr_request['country'] },
								{ 'key':'ST','value': csr_request['state'] },
								{ 'key':'L','value':  csr_request['city'] }
							]
						},
						'key_size': csr_request['key_size'],
						'algorithm': csr_request['algorithm']
					}

	resp = client.post(api_endpoint, payload )
	csr_id = resp.json()['id']

	self_sign_cert_api_endpint = TRUST_MGMT_SELF_SIGN_CERT
	self_sign_cert_url = '%s%s%s' % (self_sign_cert_api_endpint, csr_id, '?action=self_sign')
	self_sign_csr_response = client.post(self_sign_cert_url, '').json()

	self_sign_csr_id = self_sign_csr_response['id'] 

	update_api_endpint = '%s%s%s' % (TRUST_MGMT_UPDATE_CERT, '&certificate_id=', self_sign_csr_id)
	update_csr_response = client.post(update_api_endpint, '')

	print('NSX Mgr updated to use newly generated CSR!!'
	 			+ '\n\tUpdate response code:{}'.format(update_csr_response.status_code))

def build_routers():
	init()
	load_edge_clusters()
	load_transport_zones()
	
	t0_router_content  = os.getenv('NSX_T_T0ROUTER_SPEC')
	t0_router         = yaml.load(t0_router_content)['t0_router']
	t0_router_id      = create_t0_logical_router_and_port(t0_router)

	t1_router_content = os.getenv('NSX_T_T1ROUTER_LOGICAL_SWITCHES_SPEC')
	t1_routers        = yaml.load(t1_router_content)['t1_routers']

	pas_tags = create_pas_tags()
	update_tag(ROUTERS_ENDPOINT + '/' + t0_router_id, pas_tags)

	create_ha_switching_profile()
	create_container_ip_blocks()
	create_external_ip_pools()

	for t1_router in t1_routers:
		t1_router_name = t1_router['name']
		create_t1_logical_router_and_port(t0_router_name, t1_router_name, t0_router_subnet)
		logical_switches = t1_router['switches']
		for logical_switch_entry in logical_switches:
			logical_switch_name = logical_switch_entry['name']
			logical_switch_subnet = logical_switch_entry['subnet']
			create_logical_switch(logical_switch_name)
			associate_logical_switch_port(t1_router_name, logical_switch_name, logical_switch_subnet)

def set_t0_route_redistribution():
	for key in global_id_map:
		if key.startswith('ROUTER:TIER0'):
			t0_router_id = global_id_map[key]
			api_endpoint = '%s/%s/%s' % (ROUTERS_ENDPOINT, t0_router_id, 'routing/redistribution')
	
			cur_redistribution_resp = client.get(api_endpoint ).json()
			payload={
					'resource_type': 'RedistributionConfig',
					'logical_router_id': t0_router_id,
					'bgp_enabled': True,
					'_revision': cur_redistribution_resp['_revision']
				}
			resp = client.put(api_endpoint, payload )
	print('Done enabling route redisribution for T0Routers\n')

def print_t0_route_nat_rules():
	for key in global_id_map:
		if key.startswith('ROUTER:TIER0:'):
			t0_router_id = global_id_map[key]
			api_endpoint = '%s/%s/%s' % (ROUTERS_ENDPOINT, t0_router_id, 'nat/rules')
			resp = client.get(api_endpoint).json()
			print('NAT Rules for T0 Router: {}\n{}'.format(t0_router_id, resp))

def reset_t0_route_nat_rules():
	for key in global_id_map:
		if key.startswith('ROUTER:TIER0:'):
			t0_router_id = global_id_map[key]
			api_endpoint = '%s/%s/%s' % (ROUTERS_ENDPOINT, t0_router_id, 'nat/rules')
			resp = client.get(api_endpoint).json()
			nat_rules = resp['results']
			for nat_rule in nat_rules:
				delete_api_endpint = '%s%s%s' % (api_endpoint, '/', nat_rule['id'])
				resp = client.delete(delete_api_endpint )


def check_for_existing_rule(existing_nat_rules, new_nat_rule):
	if (len(existing_nat_rules) == 0):
		return None

	for existing_nat_rule in existing_nat_rules:
		if (
			existing_nat_rule['translated_network'] == new_nat_rule['translated_network']
		   and existing_nat_rule['action'] == new_nat_rule['action']
		   and existing_nat_rule.get('match_destination_network') == new_nat_rule.get('match_destination_network')
		   and existing_nat_rule.get('match_source_network') == new_nat_rule.get('match_source_network')
	   ):
			return existing_nat_rule
	return None

def add_t0_route_nat_rules():

	nat_rules_defn = yaml.load(os.getenv('NSX_T_NAT_RULES_SPEC'))['nat_rules']
	if len(nat_rules_defn) <= 0:
		return

	t0_router_id = global_id_map['ROUTER:TIER0:' + nat_rules_defn[0]['t0_router']]
	if t0_router_id is None:
		print('Error!! No T0Router found with name: {}'.format(nat_rules_defn[0]['t0_router']))
		exit -1

	api_endpoint = '%s/%s/%s' % (ROUTERS_ENDPOINT, t0_router_id, 'nat/rules')

	changes_detected = False
	existing_nat_rules = client.get(api_endpoint ).json()['results']
	for nat_rule in nat_rules_defn:
		
		rule_payload = {
				'resource_type': 'NatRule',
				'enabled' : True,
				'rule_priority': nat_rule['rule_priority'],
				'translated_network' : nat_rule['translated_network']
		}

		if nat_rule['nat_type'] == 'dnat':
			rule_payload['action'] = 'DNAT'
			rule_payload['match_destination_network'] = nat_rule['destination_network']
		else:
			rule_payload['action'] = 'SNAT'
			rule_payload['match_source_network'] = nat_rule['source_network']

		existing_nat_rule = check_for_existing_rule(existing_nat_rules, rule_payload )
		if None == existing_nat_rule:
			changes_detected = True
			print('Adding new Nat rule: {}'.format(rule_payload))
			resp = client.post(api_endpoint, rule_payload )
		else:
			rule_payload['id'] = existing_nat_rule['id']
			rule_payload['display_name'] = existing_nat_rule['display_name']
			rule_payload['_revision'] = existing_nat_rule['_revision']
			if rule_payload['rule_priority'] != existing_nat_rule['rule_priority']:
				changes_detected = True
				print('Updating just the priority of existing nat rule: {}'.format(rule_payload))
				update_api_endpint = '%s%s%s' % (api_endpoint, '/', existing_nat_rule['id'])
				resp = client.put(update_api_endpint, rule_payload )
		
	if changes_detected:
		print('Done adding/updating nat rules for T0Routers!!\n')
	else:
		print('Detected no change with nat rules for T0Routers!!\n')

def main():
	
	init()
	load_edge_clusters()
	load_transport_zones()
	load_logical_routers()
	#print_global_ip_map()

	# No support for switching profile in the ansible script yet
	# So create directly
	create_ha_switching_profile()

	# # Set the route redistribution
	set_t0_route_redistribution()

	# #print_t0_route_nat_rules()
	add_t0_route_nat_rules()

	# Generate self-signed cert
	generate_self_signed_cert()


if __name__ == '__main__':
	main()
