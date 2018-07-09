#!/bin/bash

function create_controller_hosts {
  count=1
  echo "[controllers]" > ctrl_vms
  for controller_ip in $(echo $NSX_T_CONTROLLER_IPS | sed -e 's/,/ /g')
  do
    cat >> ctrl_vms <<-EOF
  controller-${count} hostname=${CONTROLLER_HOSTNAME}-${count} default_gateway=${DEFAULT_GATEWAY} prefix_length=$prefix_length
EOF
    (( count++ ))
  done
  cat >> ctrl_vms <<-EOF
[controllers:vars]
controller_cli_password="Admin!23Admin"
controller_root_password="Admin!23Admin"
deployment_size="MEDIUM"
# ManagedObjectRef IDs
compute_id="domain-c25"
storage_id="datastore-30"
shared_secret="Admin!23Admin"
EOF

}

# TODO: update this with params from https://github.com/yasensim/nsxt-ansible/blob/master/answerfile.yml
function create_edge_hosts {
  count=1
  echo "[edge_nodes]" > edge_vms
  for edge_ip in $(echo $NSX_T_EDGE_IPS | sed -e 's/,/ /g')
  do
    cat >> edge_vms <<-EOF
edge1 ip=10.40.0.24 hostname=nsx-edge-1 default_gateway=10.40.1.253 prefix_length=23 edge_fabric_node_name=EdegeNode1 transport_node_name=edge-transp-node1
# ${NSX_T_EDGE_HOST_PREFIX}-0${count}  \
#   ansible_ssh_host=$edge_ip \
#   ansible_ssh_user=root \
#   ansible_ssh_pass=$NSX_T_EDGE_ROOT_PWD \
#   vcenter_host="$VCENTER_HOST" \
#   vcenter_user="$VCENTER_USR" \
#   vcenter_pwd="$VCENTER_PWD" \
#   dc="$VCENTER_DATACENTER" \
#   datastore="$VCENTER_DATASTORE" \
#   cluster="$VCENTER_CLUSTER" \
#   resource_pool="$VCENTER_RP" \
#   dns_server="$DNSSERVER" \
#   dns_domain="$DNSDOMAIN" \
#   ntp_server="$NTPSERVERS" \
#   gw=$DEFAULTGATEWAY \
#   mask=$NETMASK \
#   vmname="${NSX_T_EDGE_VM_NAME_PREFIX}-0${count}" \
#   hostname="${NSX_T_EDGE_HOST_PREFIX}-0${count}" \
#   portgroup="$MGMT_PORTGROUP" \
#   portgroupExt="$NSX_T_EDGE_PORTGROUP_EXT" \
#   portgroupTransport="$NSX_T_EDGE_PORTGROUP_TRANSPORT"
EOF
    (( count++ ))
  done

  cat >> edge_vms <<-EOF
[edge_nodes:vars]
deployment_size="SMALL"
edge_cli_password="Admin!23Admin"
edge_root_password="Admin!23Admin"
# ManagedObjectRef IDs
compute_id="domain-c25"
storage_id="datastore-30"
data_network_id="network-33"
management_network_id="network-33"
EOF
}

### TODO: where are transport node config params
function create_esxi_hosts {
  echo "$ESXI_HOSTS_CONFIG" > /tmp/esxi_hosts_config.yml
  touch esxi_hosts

  is_valid_yml=$(cat /tmp/esxi_hosts_config.yml  | shyaml get-values esxi_hosts || true)

  # Check if the esxi_hosts config is not empty and is valid
  if [ "$ESXI_HOSTS_CONFIG" != "" -a "$is_valid_yml" != "" ]; then

    echo "[nsxtransportnodes]" > esxi_hosts

    length=$(expr $(cat /tmp/esxi_hosts_config.yml  | shyaml get-values esxi_hosts | grep name: | wc -l) - 1 || true )
    for index in $(seq 0 $length)
    do
      ESXI_INSTANCE_HOST=$(cat /tmp/esxi_hosts_config.yml  | shyaml get-value esxi_hosts.${index}.name)
      ESXI_INSTANCE_IP=$(cat /tmp/esxi_hosts_config.yml  | shyaml get-value esxi_hosts.${index}.ip)
      ESXI_INSTANCE_PWD=$(cat /tmp/esxi_hosts_config.yml  | shyaml get-value esxi_hosts.${index}.root_pwd)
      if [ "$ESXI_INSTANCE_PWD" == "" ]; then
        ESXI_INSTANCE_PWD=$ESXI_HOSTS_ROOT_PWD
      fi

      cat >> esxi_hosts <<-EOF
$ESXI_INSTANCE_HOST  ansible_ssh_host=$ESXI_INSTANCE_IP   ansible_ssh_user=root ansible_ssh_pass=$ESXI_INSTANCE_PWD
EOF
    done
  else
    echo "esxi_hosts_config not set to valid yaml, so ignoring it"
    echo "Would use computer manager configs to add hosts!!"
    echo "" >> esxi_hosts
  fi
}

## TODO: convert = notation to : notation when specifiying variables
function create_hosts {

# TODO: set nsx manager fqdn
export NSX_T_MANAGER_SHORT_HOSTNAME=$(echo $NSX_T_MANAGER_FQDN | awk -F '\.' '{print $1}')

cat > hosts <<-EOF
[localhost]
localhost       ansible_connection=local

# [nsxmanagers]
# nsx-manager  \
#   ansible_ssh_host=$NSX_T_MANAGER_IP \
#   ansible_ssh_user=root \
#   ansible_ssh_pass=$NSX_T_MANAGER_ROOT_PWD \
#   dc="$VCENTER_DATACENTER" \
#   cluster="$VCENTER_CLUSTER" \
#   resource_pool="$VCENTER_RP" \
#   datastore="$VCENTER_DATASTORE" \
#   portgroup="$MGMT_PORTGROUP" \
#   gw=$DEFAULTGATEWAY \
#   mask=$NETMASK \
#   vmname="$NSX_T_MANAGER_VM_NAME" \
#   hostname="$NSX_T_MANAGER_SHORT_HOSTNAME"

[localhost:vars]
sshEnabled='True'
allowSSHRootAccess='True'

vcenter_ip="$VCENTER_HOST"
vcenter_username=$VCENTER_USR
vcenter_password="$VCENTER_PWD"
vcenter_folder=1-folder-1080
vcenter_datacenter=1-datacenter-1080
vcenter_cluster=1-cluster-729
vcenter_datastore=vdnetSharedStorage

mgmt_portgroup="VM Network"
dns_server=10.13.12.2
dns_domain=eng.vmware.com
ntp_servers=10.166.17.90
default_gateway=10.40.1.253
netmask=255.255.254.0
path_to_ova="http://build-squid.eng.vmware.com/build/mts/release/bora-8968195/publish/nsx-unified-appliance/exports/ova/"
ova_file_name="nsx-unified-appliance-2.2.0.0.1.8968271.ova"
ovftool_bin_path="/usr/bin"

nsx_manager_ip=10.40.0.20
nsx_manager_username=admin
nsx_manager_password=Admin!23Admin
nsx_manager_assigned_hostname="nsxt-manager-10"
manager_deployment_size=small

compute_manager_username="Administrator@vsphere.local"
compute_manager_password="Admin!23"

edge_uplink_profile_vlan=0
esxi_uplink_profile_vlan=20

vtep_ip_pool_name=tep-ip-pool
vtep_ip_pool_cidr=192.168.213.0/24
vtep_ip_pool_gateway=192.168.213.1
vtep_ip_pool_start=192.168.213.10
vtep_ip_pool_end=192.168.213.200

######## OLD
# compute_manager="$VCENTER_MANAGER"
# cm_cluster="$VCENTER_CLUSTER"

# mgmt_portgroup="VM Network"
# dns_server=10.13.12.2
# dns_domain=eng.vmware.com
# ntp_servers=10.166.17.90
# default_gateway=10.40.1.253
# netmask=255.255.254.0
# path_to_ova="http://build-squid.eng.vmware.com/build/mts/release/bora-8968195/publish/nsx-unified-appliance/exports/ova/"
# ova_file_name="nsx-unified-appliance-2.2.0.0.1.8968271.ova"
# ovftool_bin_path="/usr/bin"

# ovfToolPath='/usr/bin'
# nsxOvaPath="$OVA_ISO_PATH"

# managerOva=$NSX_T_MANAGER_OVA

# compute_vcenter_host="$COMPUTE_VCENTER_HOST"
# compute_vcenter_user="$COMPUTE_VCENTER_USR"
# compute_vcenter_password="$COMPUTE_VCENTER_PWD"
# compute_vcenter_cluster="$COMPUTE_VCENTER_CLUSTER"
# compute_vcenter_manager="$COMPUTE_VCENTER_MANAGER"

# edge_vcenter_host="$EDGE_VCENTER_HOST"
# edge_vcenter_user="$EDGE_VCENTER_USR"
# edge_vcenter_password="$EDGE_VCENTER_PWD"
# edge_vcenter_cluster="$EDGE_VCENTER_CLUSTER"
# edge_dc="$EDGE_VCENTER_DATACENTER"
# edge_datastore="$EDGE_VCENTER_DATASTORE"
# edge_portgroup="$EDGE_MGMT_PORTGROUP"
# edge_dns_server="$EDGE_DNSSERVER"
# edge_dns_domain="$EDGE_DNSDOMAIN"
# edge_ntp_server="$EDGE_NTPSERVERS"
# edge_gw="$EDGE_DEFAULTGATEWAY"
# edge_mask="$EDGE_NETMASK"

# nsxInstaller="$NSX_T_INSTALLER"
# nsxAdminPass="$NSX_T_MANAGER_ADMIN_PWD"
# nsxCliPass="$NSX_T_MANAGER_ROOT_PWD"

# dns_server="$DNSSERVER"
# dns_domain="$DNSDOMAIN"
# ntp_server="$NTPSERVERS"

# # Sizing of vms for deployment
# nsx_t_mgr_deploy_size="$NSX_T_MGR_DEPLOY_SIZE"
# nsx_t_edge_deploy_size="$NSX_T_EDGE_DEPLOY_SIZE"

# tag_scope="ncp/cluster"
# tag=$NSX_T_PAS_NCP_CLUSTER_TAG
# overlay_tz_name=$NSX_T_OVERLAY_TRANSPORT_ZONE
# vlan_tz_name=$NSX_T_VLAN_TRANSPORT_ZONE
# vlan_hostswitch=$NSX_T_VLAN_HOSTSWITCH
# overlay_hostswitch=$NSX_T_OVERLAY_HOSTSWITCH

# tep_pool_name=$NSX_T_TEP_POOL_NAME
# tep_pool_cidr=$NSX_T_TEP_POOL_CIDR
# tep_pool_range="${NSX_T_TEP_POOL_START}-${NSX_T_TEP_POOL_END}"
# tep_pool_gw=$NSX_T_TEP_POOL_GATEWAY

# edge_single_uplink_profile_name=$NSX_T_SINGLE_UPLINK_PROFILE_NAME
# edge_single_uplink_profile_mtu=$NSX_T_SINGLE_UPLINK_PROFILE_MTU
# edge_single_uplink_profile_vlan=$NSX_T_SINGLE_UPLINK_PROFILE_VLAN
# edge_interface=$NSX_T_EDGE_OVERLAY_INTERFACE
# edge_uplink_interface=$NSX_T_EDGE_UPLINK_INTERFACE

# esxi_uplink_vmnics_arr="${esxi_host_uplink_vmnics}"
# edge_uplink_vmnics_arr="${edge_host_uplink_vmnics}"

# esxi_overlay_profile_name=$NSX_T_OVERLAY_PROFILE_NAME
# esxi_overlay_profile_mtu=$NSX_T_OVERLAY_PROFILE_MTU
# esxi_overlay_profile_vlan=$NSX_T_OVERLAY_PROFILE_VLAN

# edge_cluster="$NSX_T_EDGE_CLUSTER"

EOF

  if [ "$VCENTER_RP" == "null" ]; then
    export VCENTER_RP=""
  fi

  create_edge_hosts
  create_controller_hosts

  cat ctrl_vms >> hosts
  echo "" >> hosts
  cat edge_vms >> hosts
  echo "" >> hosts

  if  [ ! -z "$ESXI_HOSTS_CONFIG" ]; then
    create_esxi_hosts
    cat esxi_hosts >> hosts
    echo "" >> hosts
  fi

}
