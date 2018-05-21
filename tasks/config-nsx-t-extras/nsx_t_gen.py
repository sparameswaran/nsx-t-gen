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
LBR_SERVICES_ENDPOINT        = '%s%s' % (API_VERSION, '/loadbalancer/services')
LBR_VIRTUAL_SERVER_ENDPOINT  = '%s%s' % (API_VERSION, '/loadbalancer/virtual-servers')
LBR_POOLS_ENDPOINT           = '%s%s' % (API_VERSION, '/loadbalancer/pools')
LBR_MONITORS_ENDPOINT        = '%s%s' % (API_VERSION, '/loadbalancer/monitors')

LBR_APPLICATION_PROFILE_ENDPOINT = '%s%s' % (API_VERSION, '/loadbalancer/application-profiles')
LBR_PERSISTENCE_PROFILE_ENDPOINT = '%s%s' % (API_VERSION, '/loadbalancer/persistence-profiles')

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
      #'edge_cluster_member_index' : [ t0_router['edge_index'] ],
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
  ip_blocks_defn = os.getenv('NSX_T_CONTAINER_IP_BLOCK_SPEC', '').strip()
  if ip_blocks_defn == ''  or ip_blocks_defn == 'null':
    print('No yaml payload set for the NSX_T_CONTAINER_IP_BLOCK_SPEC, ignoring Container IP Block section!')
    return

  ip_blocks = yaml.load(ip_blocks_defn)
  for ip_block in ip_blocks['container_ip_blocks']:
    ip_block_name   = ip_block('name')
    ip_block_cidr   = ip_block('cidr')    
    container_ip_block_id = create_container_ip_block(ip_block_name, ip_block_cidr)
    update_tag(CONTAINER_IP_BLOCKS_ENDPOINT + '/' + container_ip_block_id, create_pas_tags())
    
def create_external_ip_pools():
  ip_pools_defn = os.getenv('NSX_T_EXTERNAL_IP_POOL_SPEC', '').strip()
  if ip_pools_defn == '' or ip_pools_defn == 'null' :
    print('No yaml payload set for the NSX_T_EXTERNAL_IP_POOL_SPEC, ignoring External IP Pool section!')
    return

  ip_pools    = yaml.load(ip_pools_defn)
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

  ha_switching_profiles_defn = os.getenv('NSX_T_HA_SWITCHING_PROFILE_SPEC', '').strip()
  if ha_switching_profiles_defn == '' or ha_switching_profiles_defn == 'null' :
    print('No yaml payload set for the NSX_T_HA_SWITCHING_PROFILE_SPEC, ignoring HASpoofguard profile section!')
    return

  ha_switching_profiles = yaml.load(ha_switching_profiles_defn)['ha_switching_profiles']
  if ha_switching_profiles is None:
    print('No valid yaml payload set for the NSX_T_HA_SWITCHING_PROFILE_SPEC, ignoring HASpoofguard profile section!')
    return
  
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
  csr_request_spec = os.getenv('NSX_T_CSR_REQUEST_SPEC', '').strip()
  if csr_request_spec == ''  or csr_request_spec == 'null' :
    return

  csr_request = yaml.load(csr_request_spec)['csr_request']
  
  api_endpoint = TRUST_MGMT_CSRS_ENDPOINT
  existing_csrs_response = client.get(api_endpoint).json()
  if existing_csrs_response['result_count'] > 0:
    for csr_entry in existing_csrs_response['results']:
      print('CSR Entry: {}'.format(csr_entry))
  print('Done listing CSRs\n')

def generate_self_signed_cert():
  
  nsx_t_manager_fqdn = os.getenv('NSX_T_MANAGER_FQDN', '')
  if nsx_t_manager_fqdn is None or nsx_t_manager_fqdn is '':
    nsx_t_manager_fqdn = os.getenv('NSX_T_MANAGER_HOST_NAME')

  if nsx_t_manager_fqdn is None or nsx_t_manager_fqdn is '':
    print('Value not set for the NSX_T_MANAGER_HOST_NAME, cannot create self-signed cert')
    return    

  csr_request_spec = os.getenv('NSX_T_CSR_REQUEST_SPEC', '').strip()
  if csr_request_spec == ''  or csr_request_spec == 'null' :
    return

  csr_request = yaml.load(csr_request_spec)['csr_request']
  if csr_request is None:
    print('No valid yaml payload set for the NSX_T_CSR_REQUEST_SPEC, ignoring CSR self-signed cert section!')
    return

  api_endpoint = TRUST_MGMT_CSRS_ENDPOINT
  existing_csrs_response = client.get(api_endpoint).json()
  # if existing_csrs_response['result_count'] > 0:
  #   print('Error! CSR already exists!!,\n\t count of csrs:{}'.format( existing_csrs_response['result_count']))
  #   for csr_entry in existing_csrs_response['results']:
  #     print('\t CSR Entry: {}'.format(csr_entry))
  #   return

  #tokens = csr_request['common_name'].split('.')
  tokens = nsx_t_manager_fqdn.split('.')
  if len(tokens) < 3:
    print('Error!! CSR common name is not a full qualified domain name (provided as nsx mgr FQDN): {}!!'.format(nsx_t_manager_fqdn))
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
        + '\n    Update response code:{}'.format(update_csr_response.status_code))

def build_routers():
  init()
  load_edge_clusters()
  load_transport_zones()
  
  t0_router_content  = os.getenv('NSX_T_T0ROUTER_SPEC').strip()
  t0_router         = yaml.load(t0_router_content)['t0_router']
  if t0_router is None:
    print 'No valid T0Router content NSX_T_T0ROUTER_SPEC passed'
    return

  t0_router_id      = create_t0_logical_router_and_port(t0_router)

  t1_router_content = os.getenv('NSX_T_T1ROUTER_LOGICAL_SWITCHES_SPEC')
  t1_routers        = yaml.load(t1_router_content)['t1_routers']
  if t1_routers is None:
    print 'No valid T1Router content NSX_T_T1ROUTER_LOGICAL_SWITCHES_SPEC passed'
    return
  

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
  print('Done enabling route redistribution for T0Routers\n')

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

  nat_rules_defn = os.getenv('NSX_T_NAT_RULES_SPEC', '').strip()
  if nat_rules_defn == ''  or nat_rules_defn == 'null' :
    print('No yaml payload set for the NSX_T_NAT_RULES_SPEC, ignoring nat rules section!')
    return

  nat_rules_defns = yaml.load(nat_rules_defn)['nat_rules']
  if nat_rules_defns is None or len(nat_rules_defns) <= 0:
    print('No nat rule entries in the NSX_T_NAT_RULES_SPEC, nothing to add/update!')    
    return

  t0_router_id = global_id_map['ROUTER:TIER0:' + nat_rules_defns[0]['t0_router']]
  if t0_router_id is None:
    print('Error!! No T0Router found with name: {}'.format(nat_rules_defns[0]['t0_router']))
    exit -1

  api_endpoint = '%s/%s/%s' % (ROUTERS_ENDPOINT, t0_router_id, 'nat/rules')

  changes_detected = False
  existing_nat_rules = client.get(api_endpoint ).json()['results']
  for nat_rule in nat_rules_defns:
    
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

def load_loadbalancer_monitors():
  api_endpoint = LBR_MONITORS_ENDPOINT
  resp = client.get(api_endpoint).json()
  for monitor in resp['results']:
    monitor_name = monitor['display_name']
    monitor_id = monitor['id']
    global_id_map['MONITOR:'+monitor_name] = monitor_id

def load_loadbalancer_app_profiles():
  api_endpoint = LBR_APPLICATION_PROFILE_ENDPOINT
  resp = client.get(api_endpoint).json()
  for app_profile in resp['results']:
    app_profile_name = app_profile['display_name']
    app_profile_id = app_profile['id']
    global_id_map['APP_PROFILE:'+app_profile_name] = app_profile_id

def load_loadbalancer_persistence_profiles():
  api_endpoint = LBR_PERSISTENCE_PROFILE_ENDPOINT
  resp = client.get(api_endpoint).json()
  for persistence_profile in resp['results']:
    persistence_profile_name = persistence_profile['display_name']
    persistence_profile_id = persistence_profile['id']
    global_id_map['PERSISTENCE_PROFILE:'+ persistence_profile_name] = persistence_profile_id

def check_for_existing_lbr(existing_lbr_name):
  api_endpoint = LBR_SERVICES_ENDPOINT
  resp = client.get(api_endpoint).json()
  if resp is None or resp['result_count'] == 0:
    return None

  for lbr_member in resp['results']:
    if lbr_member['display_name'] == existing_lbr_name:
      return lbr_member

  return None

def check_for_existing_lbr_virtual_server(existing_lbr_vs_name):
  api_endpoint = LBR_VIRTUAL_SERVER_ENDPOINT
  resp = client.get(api_endpoint).json()
  if resp is None or resp['result_count'] == 0:
    return None

  for vs_member in resp['results']:
    if vs_member['display_name'] == existing_lbr_vs_name:
      return vs_member

  return None

def check_for_existing_lbr_pool(existing_lbr_pool_name):
  api_endpoint = LBR_POOLS_ENDPOINT
  resp = client.get(api_endpoint).json()
  if resp is None or resp['result_count'] == 0:
    return None

  for lbr_pool_member in resp['results']:
    if lbr_pool_member['display_name'] == existing_lbr_pool_name:
      return lbr_pool_member

  return None

def add_lbr_pool(virtual_server_defn):
  virtual_server_name = virtual_server_defn['name']

  existing_pool = check_for_existing_lbr_pool('%s%s' % (virtual_server_name, 'ServerPool'))

  pool_api_endpoint = LBR_POOLS_ENDPOINT
  lbActiveTcpMonitor = global_id_map['MONITOR:nsx-default-tcp-monitor']
  lbPassiveMonitor = global_id_map['MONITOR:nsx-default-passive-monitor']

  index = 1
  members = []

  pool_payload = {
    'resource_type': 'LbPool',
    'display_name': ( '%s%s' % (virtual_server_name, 'ServerPool') ),
    'tcp_multiplexing_number': 6,
    'min_active_members': 1,
    'tcp_multiplexing_enabled': False,
    'passive_monitor_id': lbPassiveMonitor,
    'active_monitor_ids': [ lbActiveTcpMonitor ],
    'snat_translation': {
        'port_overload': 1,
        'type': 'LbSnatAutoMap'
    }, 'algorithm': 'ROUND_ROBIN' }

  for member in virtual_server_defn['members']:
    member_name = ( '%s-%s-%d' % (virtual_server_name, 'member', index))
    member = {
              'max_concurrent_connections': 10000,
              'port': member['port'],
              'weight': 1,
              'admin_state': 'ENABLED',
              'ip_address': member['ip'],
              'display_name': member_name,
              'backup_member': False
            }
    members.append(member)
    index += 1
  pool_payload['members'] = members

  print 'Payload for Server Pool: {}'.format(pool_payload)

  if existing_pool is None:
    resp = client.post(pool_api_endpoint, pool_payload ).json()
    print 'Created Server Pool: {}'.format(virtual_server_name)
    print ''
    return resp['id']

  # Update existing server pool
  pool_payload['_revision'] = existing_pool['_revision']
  pool_payload['id'] = existing_pool['id']
  pool_update_api_endpoint = '%s/%s' % (pool_api_endpoint, existing_pool['id'])
  resp = client.put( pool_update_api_endpoint, pool_payload, check=False )
  print 'Updated Server Pool: {}'.format(virtual_server_name)
  print ''
  return existing_pool['id']

def add_lbr_virtual_server(virtual_server_defn):
  virtual_server_name = virtual_server_defn['name']

  existing_vip_name = ( '%s%s' % (virtual_server_defn['name'], 'Vip') )
  existing_virtual_server = check_for_existing_lbr_virtual_server(existing_vip_name)

  virtual_server_api_endpoint = LBR_VIRTUAL_SERVER_ENDPOINT
  pool_id = add_lbr_pool(virtual_server_defn)

  # Go with TCP App profile and source-ip persistence profile
  lbFastTcpAppProfile = global_id_map['APP_PROFILE:nsx-default-lb-fast-tcp-profile']
  lbSourceIpPersistenceProfile = global_id_map['PERSISTENCE_PROFILE:nsx-default-source-ip-persistence-profile']

  vs_payload = {
          'resource_type': 'LbVirtualServer',
          'display_name': ( '%s%s' % (virtual_server_defn['name'], 'Vip') ),
            'max_concurrent_connections': 10000,
            'max_new_connection_rate': 1000,
            'persistence_profile_id': lbSourceIpPersistenceProfile,
            'application_profile_id': lbFastTcpAppProfile,
            'ip_address': virtual_server_defn['vip'],
            'pool_id': pool_id,
            'enabled': True,
            'ip_protocol': 'TCP',
            'port': virtual_server_defn['port']     
  } 
    
  if existing_virtual_server is None:
    resp = client.post(virtual_server_api_endpoint, vs_payload ).json()
    print 'Created Virtual Server: {}'.format(virtual_server_name)
    return resp['id']

  # Update existing virtual server
  vs_payload['_revision'] = existing_virtual_server['_revision']
  vs_payload['id'] = existing_virtual_server['id']
  vs_update_api_endpoint = '%s/%s' % (virtual_server_api_endpoint, existing_virtual_server['id'])
  
  resp = client.put(vs_update_api_endpoint, vs_payload, check=False )
  print 'Updated Virtual Server: {}'.format(virtual_server_name)
  print ''  
  return existing_virtual_server['id']

def add_loadbalancers():

  lbr_spec_defn = os.getenv('NSX_T_LBR_SPEC', '').strip()
  if lbr_spec_defn == '' or lbr_spec_defn == 'null':
    print('No yaml payload set for the NSX_T_LBR_SPEC, ignoring loadbalancer section!')
    return

  lbrs_defn = yaml.load(lbr_spec_defn)['loadbalancers']
  if lbrs_defn is None or len(lbrs_defn) <= 0:
    print('No valid yaml passed in the NSX_T_LBR_SPEC, nothing to add/update for LBR!')    
    return

  for lbr in lbrs_defn:
    t1_router_id = global_id_map['ROUTER:TIER1:' + lbr['t1_router']]
    if t1_router_id is None:
      print('Error!! No T1Router found with name: {} referred against LBR: {}'.format(lbr['t1_router'], lbr['name']))
      exit -1

    lbr_api_endpoint = LBR_SERVICES_ENDPOINT
    lbr_service_payload = {
        'resource_type': 'LbService',
        'size' : lbr['size'].upper(),
        'error_log_level' : 'INFO',
        'display_name' : lbr['name'],
        'attachment': {
            'target_display_name': lbr['t1_router'],
            'target_type': 'LogicalRouter',
            'target_id': t1_router_id
        }     
    }

    virtual_servers = []
    for virtual_server_defn in lbr['virtual_servers']:
      virtual_server_id = add_lbr_virtual_server(virtual_server_defn)
      virtual_servers.append(virtual_server_id)

    lbr_service_payload['virtual_server_ids'] = virtual_servers

    existing_lbr = check_for_existing_lbr(lbr['name'])
    if existing_lbr is None:
      resp = client.post(lbr_api_endpoint, lbr_service_payload ).json()
      lbr_id = resp['id']
      print 'Created LBR: {}'.format(lbr['name'])
      print ''
    else:
      # Update existing LBR
      lbr_id = existing_lbr['id']

      lbr_service_payload['_revision'] = existing_lbr['_revision']
      lbr_service_payload['id'] = existing_lbr['id']    

      lbr_update_api_endpoint = '%s/%s' % (lbr_api_endpoint, lbr_id)
      resp = client.put(lbr_update_api_endpoint, lbr_service_payload, check=False )
      print 'Updated LBR: {}'.format(lbr['name'])
      print ''

def main():
  
  init()
  load_edge_clusters()
  load_transport_zones()
  load_logical_routers()
  load_loadbalancer_monitors()
  load_loadbalancer_app_profiles()
  load_loadbalancer_persistence_profiles()

  #print_global_ip_map()

  # No support for switching profile in the ansible script yet
  # So create directly
  create_ha_switching_profile()

  # # Set the route redistribution
  set_t0_route_redistribution()

  # #print_t0_route_nat_rules()
  add_t0_route_nat_rules()

  # Add Loadbalancers, update if already existing
  add_loadbalancers()

  # Push this to the last step as the login gets kicked off
  # Generate self-signed cert
  generate_self_signed_cert()
  
if __name__ == '__main__':
  main()
