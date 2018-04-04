#!/bin/bash
set -e

export ROOT_DIR=`pwd`
export SCRIPT_DIR=$(dirname $0)


# Install provided ovftool
if [ -e ovftool ]; then
  cd ovftool
  ovftool_bundle=$(ls *)
  chmod +x $ovftool_bundle
  ./$ovftool_bundle --eulas-agreed
  cd ..
fi

NSX_T_MANAGER_OVA=$(ls nsx-mgr-ova)
NSX_T_CONTROLLER_OVA=$(ls nsx-ctrl-ova)
NSX_T_EDGE_OVA=$(ls nsx-edge-ova)

export OVA_ISO_PATH='/root/ISOs/CHGA'
mkdir -p $OVA_ISO_PATH
cp nsx-mgr-ova/$NSX_T_MANAGER_OVA \
   nsx-ctrl-ova/$NSX_T_CONTROLLER_OVA \
   nsx-edge-ova/$NSX_T_EDGE_OVA \
   $OVA_ISO_PATH

echo "Done copying ova images into $OVA_ISO_PATH"

cat > answerfile.yml <<-EOF
ovfToolPath: '/usr/bin'
deployDataCenterName: "$VCENTER_DATACENTER"
deployMgmtDatastoreName: "$VCENTER_DATASTORE"
deployMgmtPortGroup: "$MGMT_PORTGROUP"
deployCluster: "$VCENTER_CLUSTER"
deployMgmtDnsServer: "$DNSSERVER"
deployNtpServers: "$NTPSERVERS"
deployMgmtDnsDomain: "$DNSDOMAIN"
deployMgmtDefaultGateway: $DEFAULTGATEWAY
deployMgmtNetmask: $NETMASK
nsxAdminPass: "$NSX_T_MANAGER_ADMIN_PWD"
nsxCliPass: "$NSX_T_MANAGER_ROOT_PWD"
nsxOvaPath: "$OVA_ISO_PATH"
deployVcIPAddress: $VCENTER_HOST
deployVcUser: $VCENTER_USR
deployVcPassword: "$VCENTER_PWD"
sshEnabled: True
allowSSHRootAccess: True

api_origin: 'localhost'

controllerClusterPass: $NSX_T_CONTROLLER_CLUSTER_PWD

managers:
  nsxmanager:
    hostname: $NSX_T_MANAGER_FQDN
    vmName: $NSX_T_MANAGER_VM_NAME
    ipAddress: $NSX_T_MANAGER_IP
    ovaFile: $NSX_T_MANAGER_OVA

EOF


cat > controller_config.yml <<-EOF
controllers:
EOF


count=1
for controller_ip in $(echo $NSX_T_CONTROLLER_IPS | sed -e 's/,/ /g')
do
  cat >> controller_config.yml <<-EOF
$controller_config
  nsxController0${count}:
    hostname: ${NSX_T_CONTROLLER_HOST_PREFIX}-0${count}.${DNSDOMAIN} 
    vmName: "${NSX_T_CONTROLLER_VM_NAME_PREFIX} 0${count}" 
    ipAddress: $controller_ip
    ovaFile: $NSX_T_CONTROLLER_OVA
EOF
  (( count++ ))
done


cat > edge_config.yml <<-EOF
edges:
EOF

count=1
for edge_ip in $(echo $NSX_T_EDGE_IPS | sed -e 's/,/ /g')
do
  cat >> edge_config.yml <<-EOF
$edge_config
  ${NSX_T_EDGE_HOST_PREFIX}-0${count}:
    hostname: ${NSX_T_EDGE_HOST_PREFIX}-0${count}  
    vmName: "${NSX_T_EDGE_VM_NAME_PREFIX} 0${count}" 
    ipAddress: $edge_ip
    ovaFile: $NSX_T_EDGE_OVA
    portgroupExt: $NSX_T_EDGE_PORTGROUP_EXT
    portgroupTransport: $NSX_T_EDGE_PORTGROUP_TRANSPORT
EOF
  (( count++ ))
done

cat controller_config.yml >> answerfile.yml
echo "" >> answerfile.yml
cat edge_config.yml >> answerfile.yml 

#echo "Final ansible answer config"
#cat answerfile.yml



count=1
echo "[nsxcontrollers]" > ctrl_vms
for controller_ip in $(echo $NSX_T_CONTROLLER_IPS | sed -e 's/,/ /g')
do
  cat >> ctrl_vms <<-EOF
nsx-controller0${count}  ansible_ssh_host=$controller_ip   ansible_ssh_user=root ansible_ssh_pass=$NSX_T_CONTROLLER_ROOT_PWD
EOF
  (( count++ ))
done

count=1
echo "[nsxedges]" > edge_vms
for edge_ip in $(echo $NSX_T_EDGE_IPS | sed -e 's/,/ /g')
do
cat >> edge_vms <<-EOF
${NSX_T_EDGE_HOST_PREFIX}-0${count}  ansible_ssh_host=$edge_ip   ansible_ssh_user=root ansible_ssh_pass=$NSX_T_EDGE_ROOT_PWD
EOF
  (( count++ ))
done

count=1
echo "[nsxtransportnodes]" > esxi_hosts
for esxi_host_ip_passwd in $(echo $ESXI_HOST_IP_PWDS | sed -e 's/,/ /g')
do
  ESXI_INSTANCE_IP=$(echo $esxi_host_ip_passwd | awk -F ':' '{print $1}' )  
  ESXI_INSTANCE_PWD=$(echo $esxi_host_ip_passwd | awk -F ':' '{print $2}' )
  if [ "$ESXI_INSTANCE_PWD" == "" ]; then
    ESXI_INSTANCE_PWD=$ESXI_HOST_PWD
  fi  

  cat >> esxi_hosts <<-EOF
esxi-0${count}  ansible_ssh_host=$ESXI_INSTANCE_IP   ansible_ssh_user=root ansible_ssh_pass=$ESXI_INSTANCE_PWD
EOF
  (( count++ ))
done


cat > hosts <<-EOF
[localhost]
localhost       ansible_connection=local

[nsxmanagers]
nsx-manager     ansible_ssh_host=$NSX_T_MANAGER_IP    ansible_ssh_user=root ansible_ssh_pass=$NSX_T_MANAGER_ROOT_PWD

[localhost:vars]

tag_scope="ncp/cluster"
tag=$NSX_T_PAS_NCP_CLUSTER_TAG
overlay_tz_name=$NSX_T_OVERLAY_TRANSPORT_ZONE
vlan_tz_name=$NSX_T_VLAN_TRANSPORT_ZONE
hostswitch=$NSX_T_HOSTSWITCH

tep_pool_name=$NSX_T_TEP_POOL_NAME
tep_pool_cidr=$NSX_T_TEP_POOL_CIDR
tep_pool_range="${NSX_T_TEP_POOL_START}-${NSX_T_TEP_POOL_END}"
tep_pool_nameserver="$NSX_T_TEP_POOL_NAMESERVER"
tep_pool_suffix=$DNSDOMAIN
tep_pool_gw=$NSX_T_TEP_POOL_GATEWAY

edge_uplink_profile_name=$NSX_T_EDGE_UPLINK_PROFILE_NAME
edge_uplink_profile_mtu=$NSX_T_EDGE_UPLINK_PROFILE_MTU
edge_uplink_profile_vlan=$NSX_T_EDGE_UPLINK_PROFILE_VLAN
edge_interface=$NSX_T_EDGE_INTERFACE

esxi_uplink_profile_name=$NSX_T_ESXI_UPLINK_PROFILE_NAME
esxi_uplink_profile_mtu=$NSX_T_ESXI_UPLINK_PROFILE_MTU
esxi_uplink_profile_vlan=$NSX_T_ESXI_UPLINK_PROFILE_VLAN

edge_cluster="$NSX_T_EDGE_CLUSTER"

t0_name="$NSX_T_T0ROUTER"
t0_ha_mode="$NSX_T_T0ROUTER_HA_MODE"

vlan_ls_mgmt="$VLAN_MGMT"
vlan_ls_vmotion="$VLAN_VMOTION"
vlan_ls_vsan="$VLAN_VSAN"

EOF

cat ctrl_vms >> hosts
echo "" >> hosts
cat edge_vms >> hosts
echo "" >> hosts
cat esxi_hosts >> hosts
echo "" >> hosts

cat > ansible.cfg <<-EOF
[defaults]
host_key_checking = false
EOF

cp hosts answerfile ansible.cfg nsxt-ansible/.
cd nsxt-ansible

ansible-playbook -i hosts deployNsx.yml

STATUS=$?
popd  >/dev/null 2>&1

exit $STATUS
