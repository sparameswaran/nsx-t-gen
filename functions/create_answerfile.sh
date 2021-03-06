#!/bin/bash

function create_base_answerfile {
	export NSX_T_MANAGER_SHORT_HOSTNAME=$(echo $NSX_T_MANAGER_FQDN | awk -F '\.' '{print $1}')

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
deployVcIPAddress: "$VCENTER_HOST"
deployVcUser: $VCENTER_USR
deployVcPassword: "$VCENTER_PWD"
compute_manager: "$VCENTER_MANAGER"
cm_cluster: "$VCENTER_CLUSTER"
sshEnabled: True
allowSSHRootAccess: True
nsxInstaller: "$NSX_T_INSTALLER"

api_origin: 'localhost'

controllerClusterPass: $NSX_T_CONTROLLER_CLUSTER_PWD

compute_vcenter_host: "$COMPUTE_VCENTER_HOST"
compute_vcenter_user: "$COMPUTE_VCENTER_USR"
compute_vcenter_password: "$COMPUTE_VCENTER_PWD"
compute_vcenter_cluster: "$COMPUTE_VCENTER_CLUSTER"
compute_vcenter_manager: "$COMPUTE_VCENTER_MANAGER"

edge_vcenter_host: "$EDGE_VCENTER_HOST"
edge_vcenter_user: "$EDGE_VCENTER_USR"
edge_vcenter_password: "$EDGE_VCENTER_PWD"
edge_vcenter_cluster: "$EDGE_VCENTER_CLUSTER"
edge_dc: "$EDGE_VCENTER_DATACENTER"
edge_datastore: "$EDGE_VCENTER_DATASTORE"
edge_portgroup: "$EDGE_MGMT_PORTGROUP"
edge_dns_server: "$EDGE_DNSSERVER"
edge_dns_domain: "$EDGE_DNSDOMAIN"
edge_ntp_server: "$EDGE_NTPSERVERS"
edge_gw: "$EDGE_DEFAULTGATEWAY"
edge_mask: "$EDGE_NETMASK"

managers:
  nsxmanager:
    hostname: $NSX_T_MANAGER_SHORT_HOSTNAME
    vmName: $NSX_T_MANAGER_VM_NAME
    ipAddress: $NSX_T_MANAGER_IP
    ovaFile: $NSX_T_MANAGER_OVA

EOF

}

function create_answerfile {

	create_edge_config
	create_controller_config

	create_base_answerfile


	# Merge controller and edge config with answerfile
	cat controller_config.yml >> answerfile.yml
	echo "" >> answerfile.yml
	cat edge_config.yml >> answerfile.yml
	echo "" >> answerfile.yml
}

function create_controller_config {
	cat > controller_config.yml <<-EOF
controllers:
EOF

	count=1
	for controller_ip in $(echo $NSX_T_CONTROLLER_IPS | sed -e 's/,/ /g')
	do
	  cat >> controller_config.yml <<-EOF
$controller_config
  nsxController0${count}:
    hostname: "${NSX_T_CONTROLLER_HOST_PREFIX}-0${count}.${DNSDOMAIN}"
    vmName: "${NSX_T_CONTROLLER_VM_NAME_PREFIX}-0${count}"
    ipAddress: $controller_ip
    ovaFile: $NSX_T_CONTROLLER_OVA
		resource_pool: ""
EOF
	  (( count++ ))
	done

}

function create_edge_config {
	cat > edge_config.yml <<-EOF
edges:
EOF

	count=1
	for edge_ip in $(echo $NSX_T_EDGE_IPS | sed -e 's/,/ /g')
	do
	  cat >> edge_config.yml <<-EOF
$edge_config
  ${NSX_T_EDGE_HOST_PREFIX}-0${count}:
    hostname: "${NSX_T_EDGE_HOST_PREFIX}-0${count}"
    vmName: "${NSX_T_EDGE_VM_NAME_PREFIX}-0${count}"
    ipAddress: $edge_ip
    ovaFile: $NSX_T_EDGE_OVA
    portgroupExt: $NSX_T_EDGE_PORTGROUP_EXT
    portgroupTransport: $NSX_T_EDGE_PORTGROUP_TRANSPORT
EOF
	  (( count++ ))
	done
}
