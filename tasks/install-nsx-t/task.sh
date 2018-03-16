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
deployDataCenterName: $VCENTER_DATACENTER
deployMgmtDatastoreName: $VCENTER_DATASTORE
deployMgmtPortGroup: $PORTGROUP
deployCluster: $VCENTER_CLUSTER
deployMgmtDnsServer: $DNSSERVER
deployNtpServers: $NTPSERVERS
deployMgmtDnsDomain: $DNSDOMAIN
deployMgmtDefaultGateway: $DEFAULTGATEWAY
deployMgmtNetmask: $NETMASK
nsxAdminPass: $NSX_T_MANAGER_ADMIN_PWD
nsxCliPass: $NSX_T_MANAGER_ROOT_PWD
nsxOvaPath: $OVA_ISO_PATH
deployVcIPAddress: $VCENTER_HOST
deployVcUser: $VCENTER_USR
deployVcPassword: $VCENTER_PWD
sshEnabled: True
allowSSHRootAccess: True

api_origin: 'jumphost'

ippool:
  name: $NSX_T_TEP_POOL_NAME
  cidr: $NSX_T_TEP_POOL_CIDR
  gw: $NSX_T_TEP_POOL_GATEWAY
  start: $NSX_T_TEP_POOL_START
  end: $NSX_T_TEP_POOL_END

transportZoneName: $NSX_T_TRANSPORT_ZONE
hostSwitchName: $NSX_T_HOSTSWITCH
tzType: 'OVERLAY'
transport_vlan: $NSX_T_TRANSPORT_VLAN
t0:
  name: $NSX_T_T0ROUTER
  ha: 'ACTIVE_STANDBY'

managers:
  nsxmanager:
    hostname: $NSX_T_MANAGER_FQDN
    vmName: $NSX_T_MANAGER_VM_NAME
    ipAddress: $NSX_T_MANAGER_IP
    ovaFile: $NSX_T_MANAGER_OVA

EOF


cat > controller_config.yml <<-EOF
controllerClusterPass: $NSX_T_CONTROLLER_CLUSTER_PWD

controllers:
EOF


count=1
for controller_ip in $(echo $NSX_T_CONTROLLER_IPS | sed -e 's/,/ /g')
do
  cat >> controller_config.yml <<-EOF
$controller_config
  nsxController0${count}:
    hostname: $NSX_T_CONTROLLER_HOST_PREFIX0${count}.$DNSDOMAIN 
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
  nsxEdge0${count}:
    hostname: $NSX_T_EDGE_HOST_PREFIX0${count}.$DNSDOMAIN 
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
$NSX_T_CONTROLLER_HOST_PREFIX0${count}  ansible_ssh_host=$controller_ip   ansible_ssh_user=root ansible_ssh_pass=$NSX_T_CONTROLLER_ROOT_PWD
EOF

count=1
echo "[nsxedges]" > edge_vms
for edge_ip in $(echo $NSX_T_EDGE_IPS | sed -e 's/,/ /g')
do
cat >> edge_vms <<-EOF
$NSX_T_EDGE_HOST_PREFIX0${count}  ansible_ssh_host=$edge_ip   ansible_ssh_user=root ansible_ssh_pass=$NSX_T_EDGE_ROOT_PWD
EOF

count=1
echo "[nsxtransportnodes]" > esxi_hosts
for esxi_host_ip_passwd in $(echo $ESXI_HOST_IP_PWDS | sed -e 's/,/ /g')
do
  ESXI_INSTANCE_IP=$(echo esxi_host_ip_passwd | awk -F ':' '{print $1}' )  
  ESXI_INSTANCE_PWD=$(echo esxi_host_ip_passwd | awk -F ':' '{print $2}' )
  if [ "$ESXI_INSTANCE_PWD" == "" ]; then
    ESXI_INSTANCE_PWD=$ESXI_HOST_PWD
  fi  

  cat >> esxi_hosts <<-EOF
esxi-0${count}  ansible_ssh_host=$ESXI_INSTANCE_IP   ansible_ssh_user=root ansible_ssh_pass=$ESXI_INSTANCE_PWD
EOF
done


cat > hosts <<-EOF
[localhost]
localhost       ansible_connection=local

[jumphost]
$JUMPBOX_IP    ansible_ssh_host=$JUMPBOX_IP   ansible_ssh_user=root ansible_ssh_pass=$JUMPBOX_ROOT_PWD

[nsxmanagers]
$NSX_T_MANAGER_IP     ansible_ssh_host=$NSX_T_MANAGER_IP    ansible_ssh_user=root ansible_ssh_pass=$NSX_T_MANAGER_ROOT_PWD

EOF

cat ctrl_vms >> hosts
cat edge_vms >> hosts
cat esxi_hosts >> hosts


sleep 200

STATUS=$?
popd  >/dev/null 2>&1

exit $STATUS
