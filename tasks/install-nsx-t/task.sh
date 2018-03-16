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
cp $NSX_T_MANAGER_OVA $NSX_T_CONTROLLER_OVA $NSX_T_EDGE_OVA $OVA_ISO_PATH

ansible_answer_configuration=$(cat <<-EOF
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
nsxCliPass: $NSX_T_MANAGER_CLI_PWD
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
)

controller_config=$(cat <<-EOF
controllerClusterPass: $NSX_T_CONTROLLER_CLUSTER_PWD

controllers:
EOF
)

count=1
for controller_ip in ($NSX_T_CONTROLLER_IPS | sed -e 's/,/ /g')
do
  controller_config=$(cat <<-EOF
$controller_config
  nsxController0${count}:
    hostname: $NSX_T_CONTROLLER_HOST_PREFIX0${count}.$DNSDOMAIN 
    vmName: "${NSX_T_CONTROLLER_VM_NAME_PREFIX} 0${count}" 
    ipAddress: $controller_ip
    ovaFile: $NSX_T_CONTROLLER_OVA  
EOF
)
  (( count++ ))
done


edge_config=$(cat <<-EOF
edges:
EOF
)

count=1
for edge_ip in ($NSX_T_EDGE_IPS | sed -e 's/,/ /g')
do
  edge_config=$(cat <<-EOF
$edge_config
  nsxEdge0${count}:
    hostname: $NSX_T_EDGE_HOST_PREFIX0${count}.$DNSDOMAIN 
    vmName: "${NSX_T_EDGE_VM_NAME_PREFIX} 0${count}" 
    ipAddress: $edge_ip
    ovaFile: $NSX_T_EDGE_OVA
    portgroupExt: NSX_T_EDGE_PORTGROUP_EXT
    portgroupTransport: $NSX_T_EDGE_PORTGROUP_TRANSPORT  
EOF
)
  (( count++ ))
done

final_ansible_answer_configuration=$(cat <<-EOF
$ansible_answer_configuration

$controller_config

$edge_config
EOF
)

echo $final_ansible_answer_configuration > answerfile.yml
echo "Final ansible answer config"
cat answerfile.yml
sleep 200

STATUS=$?
popd  >/dev/null 2>&1

exit $STATUS
