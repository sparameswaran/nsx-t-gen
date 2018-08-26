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

import copy, sys, os
import json
import yaml
from pprint import pprint
import time
import client
from datetime import datetime

DEBUG=True

RETRY_INTERVAL               = 45
MAX_RETRY_CHECK              = 6

API_VERSION                  = '/api/v1'

EDGE_CLUSTERS_ENDPOINT       = '%s%s' % (API_VERSION, '/edge-clusters')
TRANSPORT_NODES_ENDPOINT     = '%s%s' % (API_VERSION, '/transport-nodes')
FABRIC_NODES_ENDPOINT        = '%s%s' % (API_VERSION, '/fabric/nodes')

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
    retries = 0
    failed_uninstalls = {}
    bailout = False
    install_failed = False

    fabric_nodes_api_endpoint = FABRIC_NODES_ENDPOINT
    fabric_nodes_resp = client.get(fabric_nodes_api_endpoint)
    # Check periodically for install status
    print 'Checking status of the NSX-T Fabric Nodes Addition!\n'

    while (retries < MAX_RETRY_CHECK and not bailout ):
        still_in_progress = False
        print '{} Checking Status <Try: {}>\n'.format(datetime.now(), retries + 1)

        for fabric_node in fabric_nodes_resp.json()['results']:
            #print 'Fabric Node: {}'.format(fabric_node)
            fabric_node_state_url = '%s/%s/status' % (fabric_nodes_api_endpoint, fabric_node['id'])
            fabric_node_state_resp = client.get(fabric_node_state_url)
            message = fabric_node_state_resp.json()
            print '  Node: {}, IP: {}, Type: {}, Status: {}'.format(
                                                                    fabric_node['display_name'],
                                                                    fabric_node['ip_addresses'][0],
                                                                    fabric_node['resource_type'],
                                                                    message['host_node_deployment_status']
                                                                )

            # Dont bail out when things are still in progress
            if message['host_node_deployment_status'] in ['INSTALL_IN_PROGRESS']:
                still_in_progress = True

            if message['host_node_deployment_status'] in [ 'INSTALL_FAILED', 'INSTALL_SUCCESSFUL']:
                bailout = True
                if message['host_node_deployment_status'] == 'INSTALL_FAILED':
                    install_failed = True
                    #print '\nERROR!! Install of NSX-T Modules on the ESXi Hosts failed!!'
                    #print 'Check the NSX Manager for reasons for the failure, Exiting!!\n'

        # If anything still in progress, let it continue, retry the check status
        # Ignore other failed or success states till all are completed
        if still_in_progress:
            bailout = False
            print ' Sleeping for {} seconds before checking status of installs!\n'.format(RETRY_INTERVAL)
            time.sleep(RETRY_INTERVAL)
        retries += 1

    if retries == MAX_RETRY_CHECK:
        print '\nWARNING!! Max retries reached for checking if hosts have been added to NSX-T.\n'
        install_failed = True

    if install_failed == True:
        print '\nERROR!! Install of NSX-T Modules on the ESXi Hosts failed!!'
        print 'Something wrong with configuring the Hosts as part of the NSX-T Fabric, check NSX-T Mgr Fabric -> Nodes status'
        print 'Check the NSX Manager for reasons for the failure, Exiting!!'
    else:
        print '\nAll the ESXi host addition as transport nodes successfull!!'

    print ''
    return install_failed

def main():
    init()
    install_failed = identify_edges_and_hosts()

    if install_failed:
        sys.exit(1)
    else:
        sys.exit(0)

if __name__ == '__main__':
  main()
