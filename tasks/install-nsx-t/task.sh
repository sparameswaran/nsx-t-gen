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
echo "Done installing ovftool"
echo ""

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
echo ""

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

echo "$ESXI_HOSTS_CONFIG" > /tmp/esxi_hosts_config.yml
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

# Start the extra yaml args
echo "" > extra_yaml_args.yml

count=1
# Create an extra_args.yml file for additional yaml style parameters outside of host and answerfile.yml
esxi_host_uplink_vmnics='[ '
echo "esxi_uplink_vmnics:" >> extra_yaml_args.yml
for vmnic in $( echo $NSX_T_ESXI_VMNICS | sed -e 's/,/ /g')
do
  if [ $count -gt 1 ]; then
    esxi_host_uplink_vmnics="${esxi_host_uplink_vmnics},"
  fi
  echo "  - uplink-${count}: ${vmnic}" >> extra_yaml_args.yml
  esxi_host_uplink_vmnics="${esxi_host_uplink_vmnics} uplink-${count}: ${vmnic}"
  (( count++ ))
done
esxi_host_uplink_vmnics="${esxi_host_uplink_vmnics} ]"
echo "" >> extra_yaml_args.yml


# Going with single profile uplink ; so use uplink-1 for both vmnics for edge
echo "edge_uplink_vmnics:" >> extra_yaml_args.yml
echo "  - uplink-1: fp-eth1 # network3 used for overlay/tep" >> extra_yaml_args.yml
echo "  - uplink-1: fp-eth0 # network2 used for vlan uplink" >> extra_yaml_args.yml
echo "# network1 and network4 are for mgmt and not used for uplink"
echo "" >> extra_yaml_args.yml


# Has root element
echo "$NSX_T_EXTERNAL_IP_POOL_SPEC" >> extra_yaml_args.yml
echo "" >> extra_yaml_args.yml

# Has root element
echo "$NSX_T_CONTAINER_IP_BLOCK_SPEC" >> extra_yaml_args.yml
echo "" >> extra_yaml_args.yml

# Single line entry - just value
echo "ha_switching_profile: $NSX_T_HA_SWITCHING_PROFILE" >> extra_yaml_args.yml
echo "" >> extra_yaml_args.yml

# Has root element
echo "$NSX_T_T0ROUTER_SPEC" >> extra_yaml_args.yml
echo "" >> extra_yaml_args.yml

# Has root element
echo "$NSX_T_T1ROUTER_LOGICAL_SWITCHES_SPEC" >> extra_yaml_args.yml
echo "" >> extra_yaml_args.yml


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

esxi_uplink_vmnics_arr="${esxi_host_uplink_vmnics}"
edge_uplink_vmnics_arr="${edge_host_uplink_vmnics}"

esxi_overlay_profile_name=$NSX_T_OVERLAY_PROFILE_NAME
esxi_overlay_profile_mtu=$NSX_T_OVERLAY_PROFILE_MTU
esxi_overlay_profile_vlan=$NSX_T_OVERLAY_PROFILE_VLAN

edge_cluster="$NSX_T_EDGE_CLUSTER"

t0_name="$NSX_T_T0ROUTER"
t0_ha_mode="ACTIVE_STANDBY"

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


# Check if NSX MGR is up or not
nsx_mgr_up_status=$(curl -s -o /dev/null -I -w "%{http_code}"  https://${NSX_T_MANAGER_IP}:443 || true)

# Deploy the ovas if its not up
if [ $nsx_mgr_up_status -ne 200 ]; then
  echo "NSX Mgr not up yet, deploying the ovas followed by configuration of the NSX-T Mgr!!" 
  echo 'deploy_ova: True' >> answerfile.yml
  
else
  echo "NSX Mgr up already, skipping deploying of the ovas!!"
  echo 'deploy_ova: False' >> answerfile.yml
fi

if [ -z "$SUPPORT_NSX_VMOTION" -o "$SUPPORT_NSX_VMOTION" == "false" ]; then
  echo "Skipping vmks configuration for NSX-T Mgr!!" 
  echo 'configure_vmks: False' >> answerfile.yml
  
else
  echo "Allowing vmks configuration for NSX-T Mgr!!" 
  echo 'configure_vmks: True' >> answerfile.yml
fi

echo ""

cp hosts answerfile.yml ansible.cfg extra_yaml_args.yml nsxt-ansible/.
cd nsxt-ansible

echo ""

echo "Starting install and configuration of the NSX-T Mgr!!"
echo ""
ansible-playbook -vvv -i hosts deployNsx.yml -e @extra_yaml_args.yml
echo ""

STATUS=$?
popd  >/dev/null 2>&1

exit $STATUS
