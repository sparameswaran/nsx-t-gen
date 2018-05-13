#!/bin/bash

function create_controller_hosts {  

  count=1
  echo "[nsxcontrollers]" > ctrl_vms
  for controller_ip in $(echo $NSX_T_CONTROLLER_IPS | sed -e 's/,/ /g')
  do
    cat >> ctrl_vms <<-EOF
nsx-controller0${count} \
  ansible_ssh_host=$controller_ip \
  ansible_ssh_user=root \
  ansible_ssh_pass=$NSX_T_CONTROLLER_ROOT_PWD \
  dc="$VCENTER_DATACENTER" \
  cluster="$VCENTER_CLUSTER" \
  datastore="$VCENTER_DATASTORE" \
  portgroup="$MGMT_PORTGROUP" \
  gw=$DEFAULTGATEWAY \
  mask=$NETMASK \
  vmname="${NSX_T_CONTROLLER_VM_NAME_PREFIX}-0${count}" \
  hostname="${NSX_T_CONTROLLER_HOST_PREFIX}-0${count}" 
EOF
    (( count++ ))
  done

}

function create_edge_hosts {
  count=1
  echo "[nsxedges]" > edge_vms
  for edge_ip in $(echo $NSX_T_EDGE_IPS | sed -e 's/,/ /g')
  do
    cat >> edge_vms <<-EOF
${NSX_T_EDGE_HOST_PREFIX}-0${count}  \
  ansible_ssh_host=$edge_ip \
  ansible_ssh_user=root \
  ansible_ssh_pass=$NSX_T_EDGE_ROOT_PWD \
  dc="$VCENTER_DATACENTER" \
  cluster="$VCENTER_CLUSTER" \
  datastore="$VCENTER_DATASTORE" \
  portgroup="$MGMT_PORTGROUP" \
  gw=$DEFAULTGATEWAY \
  mask=$NETMASK \
  vmname="${NSX_T_EDGE_VM_NAME_PREFIX}-0${count}" \
  hostname="${NSX_T_EDGE_HOST_PREFIX}-0${count}" \
  portgroupExt="$NSX_T_EDGE_PORTGROUP_EXT" \
  portgroupTransport="$NSX_T_EDGE_PORTGROUP_TRANSPORT" 
EOF
    (( count++ ))
  done
}


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

function create_hosts { 

export NSX_T_MANAGER_SHORT_HOSTNAME=$(echo $NSX_T_MANAGER_FQDN | awk -F '\.' '{print $1}')

cat > hosts <<-EOF
[localhost]
localhost       ansible_connection=local

[nsxmanagers]
nsx-manager  \
  ansible_ssh_host=$NSX_T_MANAGER_IP \
  ansible_ssh_user=root \
  ansible_ssh_pass=$NSX_T_MANAGER_ROOT_PWD \
  dc="$VCENTER_DATACENTER" \
  cluster="$VCENTER_CLUSTER" \
  datastore="$VCENTER_DATASTORE" \
  portgroup="$MGMT_PORTGROUP" \
  gw=$DEFAULTGATEWAY \
  mask=$NETMASK \
  vmname="$NSX_T_MANAGER_VM_NAME" \
  hostname="$NSX_T_MANAGER_SHORT_HOSTNAME"

[localhost:vars]

ovfToolPath='/usr/bin'
nsxOvaPath="$OVA_ISO_PATH"
sshEnabled='True'
allowSSHRootAccess='True'
managerOva=$NSX_T_MANAGER_OVA
controllerOva=$NSX_T_CONTROLLER_OVA
edgeOva=$NSX_T_EDGE_OVA

deployVcIPAddress="$VCENTER_HOST"
deployVcUser=$VCENTER_USR
deployVcPassword="$VCENTER_PWD"
compute_manager="$VCENTER_MANAGER"
cm_cluster="$VCENTER_CLUSTER"

compute_vcenter_host="$COMPUTE_VCENTER_HOST"
compute_vcenter_user="$COMPUTE_VCENTER_USR"
compute_vcenter_password="$COMPUTE_VCENTER_PWD"
compute_vcenter_cluster="$COMPUTE_VCENTER_CLUSTER"
compute_vcenter_manager="$COMPUTE_VCENTER_MANAGER"

nsxAdminPass="$NSX_T_MANAGER_ADMIN_PWD"
nsxCliPass="$NSX_T_MANAGER_ROOT_PWD"

dns_server="$DNSSERVER"
dns_domain="$DNSDOMAIN"
ntp_server="$NTPSERVERS"

# Sizing of vms for deployment
nsx_t_mgr_deploy_size="$NSX_T_MGR_DEPLOY_SIZE"
nsx_t_edge_deploy_size="$NSX_T_EDGE_DEPLOY_SIZE"

tag_scope="ncp/cluster"
tag=$NSX_T_PAS_NCP_CLUSTER_TAG
overlay_tz_name=$NSX_T_OVERLAY_TRANSPORT_ZONE
vlan_tz_name=$NSX_T_VLAN_TRANSPORT_ZONE
vlan_hostswitch=$NSX_T_VLAN_HOSTSWITCH
overlay_hostswitch=$NSX_T_OVERLAY_HOSTSWITCH

tep_pool_name=$NSX_T_TEP_POOL_NAME
tep_pool_cidr=$NSX_T_TEP_POOL_CIDR
tep_pool_range="${NSX_T_TEP_POOL_START}-${NSX_T_TEP_POOL_END}"
tep_pool_nameserver="$NSX_T_TEP_POOL_NAMESERVER"
tep_pool_suffix=$DNSDOMAIN
tep_pool_gw=$NSX_T_TEP_POOL_GATEWAY

edge_single_uplink_profile_name=$NSX_T_SINGLE_UPLINK_PROFILE_NAME
edge_single_uplink_profile_mtu=$NSX_T_SINGLE_UPLINK_PROFILE_MTU
edge_single_uplink_profile_vlan=$NSX_T_SINGLE_UPLINK_PROFILE_VLAN
edge_interface=$NSX_T_EDGE_OVERLAY_INTERFACE
edge_uplink_interface=$NSX_T_EDGE_UPLINK_INTERFACE

esxi_uplink_vmnics_arr="${esxi_host_uplink_vmnics}"
edge_uplink_vmnics_arr="${edge_host_uplink_vmnics}"

esxi_overlay_profile_name=$NSX_T_OVERLAY_PROFILE_NAME
esxi_overlay_profile_mtu=$NSX_T_OVERLAY_PROFILE_MTU
esxi_overlay_profile_vlan=$NSX_T_OVERLAY_PROFILE_VLAN

edge_cluster="$NSX_T_EDGE_CLUSTER"

EOF

  
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

