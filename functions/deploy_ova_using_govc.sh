#!/bin/bash

set -eu

#export GOVC_TLS_CA_CERTS=/tmp/vcenter-ca.pem
#echo "$GOVC_CA_CERT" > "$GOVC_TLS_CA_CERTS"

# function create_ova_payload() {
#   type_of_ova=$1
#   path_to_ova=$2
#
#   default_additional_options=" -u=$VCENTER_HOST \
#                               -dc=$VCENTER_DATACENTER \
#                               -k=false \
#                               -ds=$VCENTER_DATASTORE \
#                               -cluster=$VCENTER_CLUSTER \
#                               -username=$VCENTER_USR \
#                               -password=$VCENTER_PWD "
#
#   if [ "$type_of_ova" == "mgr" ]; then
#     ova_options=$(handle_nsx_mgr_ova_payload $path_to_ova)
#     deploy_ova $path_to_ova $ova_options "$VCENTER_RP" "$default_additional_options"
#
#   elif [ "$type_of_ova" == "edge" ]; then
#     if [ "$EDGE_VCENTER_HOST" == "" -o "$EDGE_VCENTER_HOST" == "null" ]; then
#       count=1
#       for nsx_edge_ip in $(echo $NSX_T_EDGE_IPS | sed -e 's/,/ /g')
#       do
#         ova_options=$(handle_nsx_edge_ova_payload $path_to_ova $nsx_edge_ip $count)
#         deploy_ova $path_to_ova $ova_options "$VCENTER_RP" "$default_additional_options"
#         (( count++ ))
#       done
#     else
#       count=1
#       edge_additional_options=" -u=$EDGE_VCENTER_HOST \
#                                   -dc=$EDGE_VCENTER_DATACENTER \
#                                   -k=false \
#                                   -ds=$EDGE_VCENTER_DATASTORE \
#                                   -cluster=$EDGE_VCENTER_CLUSTER \
#                                   -username=$EDGE_VCENTER_USR \
#                                   -password=$EDGE_VCENTER_PWD "
#
#       for nsx_edge_ip in $(echo $NSX_T_EDGE_IPS | sed -e 's/,/ /g')
#       do
#         ova_options=$(handle_custom_nsx_edge_ova_payload $path_to_ova $nsx_edge_ip $count)
#         deploy_ova $path_to_ova $ova_options "$EDGE_VCENTER_RP" "$edge_additional_options"
#         (( count++ ))
#       done
#     fi
#   else
#     if [ "$NSX_T_CONTROLLERS_CONFIG" == "" -o "$NSX_T_CONTROLLERS_CONFIG" == "null" ]; then
#       count=1
#       for nsx_ctrl_ip in $(echo $NSX_T_CONTROLLER_IPS | sed -e 's/,/ /g')
#       do
#         ova_options=$(handle_nsx_ctrl_ova_payload $path_to_ova $nsx_ctrl_ip $count)
#         deploy_ova $path_to_ova $ova_options "$VCENTER_RP" "$default_additional_options"
#         (( count++ ))
#       done
#     else
#       count=1
#
#       echo "$NSX_T_CONTROLLERS_CONFIG" > /tmp/controllers_config.yml
#       is_valid_yml=$(cat /tmp/controllers_config.yml  | shyaml get-values controllers || true)
#
#       # Check if the esxi_hosts config is not empty and is valid
#       if [ "$NSX_T_CONTROLLERS_CONFIG" != "" -a "$is_valid_yml" != "" ]; then
#
#         NSX_T_CONTROLLER_VM_NAME_PREFIX=$(cat /tmp/controllers_config.yml  | shyaml get-value controllers.vm_name_prefix)
#         NSX_T_CONTROLLER_HOST_PREFIX=$(cat /tmp/controllers_config.yml  | shyaml get-value controllers.host_prefix)
#         NSX_T_CONTROLLER_ROOT_PWD=$(cat /tmp/controllers_config.yml  | shyaml get-value controllers.root_pwd)
#         NSX_T_CONTROLLER_CLUSTER_PWD=$(cat /tmp/controllers_config.yml  | shyaml get-value controllers.cluster_pwd)
#
#         for index in $(seq 0 $length)
#         do
#           NSX_T_CONTROLLER_INSTANCE_IP=$(cat /tmp/controllers_config.yml  | shyaml get-value controllers.members.${index}.ip)
#           NSX_T_CONTROLLER_INSTANCE_CLUSTER=$(cat /tmp/controllers_config.yml  | shyaml get-value controllers.members.${index}.cluster)
#           NSX_T_CONTROLLER_INSTANCE_RP=$(cat /tmp/controllers_config.yml  | shyaml get-value controllers.members.${index}.resource_pool)
#           NSX_T_CONTROLLER_INSTANCE_DATASTORE=$(cat /tmp/controllers_config.yml  | shyaml get-value controllers.members.${index}.datastore)
#
#           ctrl_additional_options=" -u=$VCENTER_HOST \
#                                       -dc=$VCENTER_DATACENTER \
#                                       -k=false \
#                                       -ds=$NSX_T_CONTROLLER_INSTANCE_DATASTORE \
#                                       -cluster=$NSX_T_CONTROLLER_INSTANCE_CLUSTER \
#                                       -username=$EDGE_VCENTER_USR \
#                                       -password=$EDGE_VCENTER_PWD "
#
#           ova_options=$(handle_nsx_ctrl_ova_payload $path_to_ova $NSX_T_CONTROLLER_INSTANCE_IP $count)
#           deploy_ova $path_to_ova $ova_options "$NSX_T_CONTROLLER_INSTANCE_RP" "$ctrl_additional_options"
#           (( count++ ))
#         done
#       fi
#     fi
#   fi
#
#
# }

function handle_ova() {
  type_of_ova=$1
  path_to_ova=$2

  if [ "$type_of_ova" == "mgr" ]; then
    deploy_mgr_ova $path_to_ova
  elif [ "$type_of_ova" == "edge" ]; then
    deploy_edge_ova $path_to_ova
  else
    deploy_ctrl_ova $path_to_ova
  fi
}

function deploy_ova {
  path_to_ova=$1
  ova_options=$2
  resource_pool=$3
  additional_options=$4

  # Setup govc env variables coming via $additional_options
  export "$additional_options"

  if [ "$VCENTER_RP" == "" -o -z "$VCENTER_RP" ]; then
    govc import.ova -options=$ova_options "$path_to_ova"
  else
    if [ "$(govc folder.info "$VCENTER_RP" 2>&1 | grep "$VCENTER_RP" | awk '{print $2}')" != "$VCENTER_RP" ]; then
      govc folder.create "$VCENTER_RP"
    fi
    govc import.ova -folder="$VCENTER_RP" -options=$ova_options "$path_to_ova"
  fi
}

function deploy_mgr_ova() {
  path_to_ova=$1

  default_additional_options="GOVC_URL=$VCENTER_HOST \
                              GOVC_DATACENTER=$VCENTER_DATACENTER \
                              GOVC_INSECURE=false \
                              GOVC_DATASTORE=$VCENTER_DATASTORE \
                              GOVC_CLUSTER=$VCENTER_CLUSTER \
                              GOVC_USERNAME=$VCENTER_USR \
                              GOVC_PASSWORD=$VCENTER_PWD "

  ova_options=$(handle_nsx_mgr_ova_options $path_to_ova)
  deploy_ova $path_to_ova $ova_options "$VCENTER_RP" "$default_additional_options"

}

function deploy_edge_ova() {
  path_to_ova=$1

  default_additional_options="GOVC_URL=$VCENTER_HOST \
                              GOVC_DATACENTER=$VCENTER_DATACENTER \
                              GOVC_INSECURE=false \
                              GOVC_DATASTORE=$VCENTER_DATASTORE \
                              GOVC_CLUSTER=$VCENTER_CLUSTER \
                              GOVC_USERNAME=$VCENTER_USR \
                              GOVC_PASSWORD=$VCENTER_PWD "

  if [ "$EDGE_VCENTER_HOST" == "" -o "$EDGE_VCENTER_HOST" == "null" ]; then
    count=1
    for nsx_edge_ip in $(echo $NSX_T_EDGE_IPS | sed -e 's/,/ /g')
    do
      ova_options=$(handle_nsx_edge_ova_options $path_to_ova $nsx_edge_ip $count)
      deploy_ova $path_to_ova $ova_options "$VCENTER_RP" "$default_additional_options"
      (( count++ ))
    done
    return
  fi

  count=1
  edge_additional_options=" GOVC_URL=$EDGE_VCENTER_HOST \
                            GOVC_DATACENTER=$EDGE_VCENTER_DATACENTER \
                            GOVC_INSECURE=false \
                            GOVC_DATASTORE=$EDGE_VCENTER_DATASTORE \
                            GOVC_CLUSTER=$EDGE_VCENTER_CLUSTER \
                            GOVC_USERNAME=$EDGE_VCENTER_USR \
                            GOVC_PASSWORD=$EDGE_VCENTER_PWD "

  for nsx_edge_ip in $(echo $NSX_T_EDGE_IPS | sed -e 's/,/ /g')
  do
    ova_options=$(handle_custom_nsx_edge_ova_options $path_to_ova $nsx_edge_ip $count)
    deploy_ova $path_to_ova $ova_options "$EDGE_VCENTER_RP" "$edge_additional_options"
    (( count++ ))
  done

}

function deploy_ctrl_ova() {
  path_to_ova=$1

  default_additional_options="GOVC_URL=$VCENTER_HOST \
                              GOVC_DATACENTER=$VCENTER_DATACENTER \
                              GOVC_INSECURE=false \
                              GOVC_DATASTORE=$VCENTER_DATASTORE \
                              GOVC_CLUSTER=$VCENTER_CLUSTER \
                              GOVC_USERNAME=$VCENTER_USR \
                              GOVC_PASSWORD=$VCENTER_PWD "

  if [ "$NSX_T_CONTROLLERS_CONFIG" == "" -o "$NSX_T_CONTROLLERS_CONFIG" == "null" ]; then
    count=1
    for nsx_ctrl_ip in $(echo $NSX_T_CONTROLLER_IPS | sed -e 's/,/ /g')
    do
      ova_options=$(handle_nsx_ctrl_ova_options $path_to_ova $nsx_ctrl_ip $count)
      deploy_ova $path_to_ova $ova_options "$VCENTER_RP" "$default_additional_options"
      (( count++ ))
    done
    return
  fi

  echo "$NSX_T_CONTROLLERS_CONFIG" > /tmp/controllers_config.yml
  is_valid_yml=$(cat /tmp/controllers_config.yml  | shyaml get-values controllers || true)

  # Check if the esxi_hosts config is not empty and is valid
  if [ "$NSX_T_CONTROLLERS_CONFIG" != "" -a "$is_valid_yml" != "" ]; then

    NSX_T_CONTROLLER_VM_NAME_PREFIX=$(cat /tmp/controllers_config.yml  | shyaml get-value controllers.vm_name_prefix)
    NSX_T_CONTROLLER_HOST_PREFIX=$(cat /tmp/controllers_config.yml  | shyaml get-value controllers.host_prefix)
    NSX_T_CONTROLLER_ROOT_PWD=$(cat /tmp/controllers_config.yml  | shyaml get-value controllers.root_pwd)
    NSX_T_CONTROLLER_CLUSTER_PWD=$(cat /tmp/controllers_config.yml  | shyaml get-value controllers.cluster_pwd)

    count=1
    for index in $(seq 0 $length)
    do
      NSX_T_CONTROLLER_INSTANCE_IP=$(cat /tmp/controllers_config.yml  | shyaml get-value controllers.members.${index}.ip)
      NSX_T_CONTROLLER_INSTANCE_CLUSTER=$(cat /tmp/controllers_config.yml  | shyaml get-value controllers.members.${index}.cluster)
      NSX_T_CONTROLLER_INSTANCE_RP=$(cat /tmp/controllers_config.yml  | shyaml get-value controllers.members.${index}.resource_pool)
      NSX_T_CONTROLLER_INSTANCE_DATASTORE=$(cat /tmp/controllers_config.yml  | shyaml get-value controllers.members.${index}.datastore)

        ctrl_additional_options=" GOVC_URL=$VCENTER_HOST \
                                  GOVC_DATACENTER=$VCENTER_DATACENTER \
                                  GOVC_INSECURE=false \
                                  GOVC_DATASTORE=$NSX_T_CONTROLLER_INSTANCE_DATASTORE \
                                  GOVC_CLUSTER=$NSX_T_CONTROLLER_INSTANCE_CLUSTER \
                                  GOVC_USERNAME=$VCENTER_USR \
                                  GOVC_PASSWORD=$VCENTER_PWD "

      ova_options=$(handle_nsx_ctrl_ova_options $path_to_ova $NSX_T_CONTROLLER_INSTANCE_IP $count)
      deploy_ova $path_to_ova $ova_options "$NSX_T_CONTROLLER_INSTANCE_RP" "$ctrl_additional_options"
      (( count++ ))
    done
  fi
}


function handle_nsx_mgr_ova_options {

  nsx_mgr_ova_file_path=$1
  govc import.spec "$nsx_mgr_ova_file_path" | python -m json.tool > /tmp/nsx-mgr-import.json

  export NSX_T_MANAGER_SHORT_HOSTNAME=$(echo $NSX_T_MANAGER_FQDN | awk -F '\.' '{print $1}')

  cat > /tmp/nsx_mgr_filters <<'EOF'
.Name = $vmName |
.NetworkMapping[].Network = $mgmt_network |
.IPAllocationPolicy = "fixedPolicy" |
.PowerOn = true |
.WaitForIP = true |
.Deployment = $deployment_size |
(.PropertyMapping[] | select(.Key == "nsx_hostname")).Value = $hostname |
(.PropertyMapping[] | select(.Key == "nsx_dns1_0")).Value = $dnsServer |
(.PropertyMapping[] | select(.Key == "nsx_domain_0")).Value = $dnsdomain |
(.PropertyMapping[] | select(.Key == "nsx_ntp_0")).Value = $ntpServer |
(.PropertyMapping[] | select(.Key == "nsx_gateway_0")).Value = $gateway |
(.PropertyMapping[] | select(.Key == "nsx_ip_0")).Value = $ip |
(.PropertyMapping[] | select(.Key == "netmask_0")).Value = $netmask |
(.PropertyMapping[] | select(.Key == "nsx_cli_username")).Value = $adminName |
(.PropertyMapping[] | select(.Key == "nsx_passwd_0")).Value = $adminPassword |
(.PropertyMapping[] | select(.Key == "nsx_cli_passwd_0")).Value = $cliPassword |
(.PropertyMapping[] | select(.Key == "nsx_isSSHEnabled")).Value = "True" |
(.PropertyMapping[] | select(.Key == "nsx_allowSSHRootLogin")).Value = "True"
EOF

  jq \
    --arg vmName "$NSX_T_MANAGER_VM_NAME" \
    --arg mgmt_network "$MGMT_PORTGROUP" \
    --arg deployment_size "$NSX_T_MGR_DEPLOY_SIZE" \
    --arg hostname "$NSX_T_MANAGER_SHORT_HOSTNAME" \
    --arg dnsServer "$DNSSERVER" \
    --arg dnsdomain "$DNSDOMAIN" \
    --arg ntpServer "$NTPSERVERS" \
    --arg gateway "$DEFAULTGATEWAY" \
    --arg ip "$NSX_T_MANAGER_IP" \
    --arg netmask "$NETMASK" \
    --arg adminName "admin" \
    --arg adminPassword "$NSX_T_MANAGER_ADMIN_PWD" \
    --arg cliPassword "$NSX_T_MANAGER_ROOT_PWD" \
    --from-file /tmp/nsx_mgr_filters \
    /tmp/nsx-mgr-import.json > /tmp/nsx-mgr-ova-options.json

  #cat /tmp/nsx-mgr-ova-options.json
  echo "/tmp/nsx-mgr-ova-options.json"
}


function handle_nsx_ctrl_ova_options {

  nsx_ctrl_ova_file_path=$1
  instance_ip=$2
  instance_index=$3

  govc import.spec "$nsx_ctrl_ova_file_path" | python -m json.tool > /tmp/nsx-ctrl-import.json

  cat > /tmp/nsx_ctrl_filters <<'EOF'
.Name = $vmName |
.IPAllocationPolicy = "fixedPolicy" |
.NetworkMapping[].Network = $mgmt_network |
.PowerOn = true |
.WaitForIP = true |
(.PropertyMapping[] | select(.Key == "nsx_hostname")).Value = $hostname |
(.PropertyMapping[] | select(.Key == "nsx_dns1_0")).Value = $dnsServer |
(.PropertyMapping[] | select(.Key == "nsx_domain_0")).Value = $dnsdomain |
(.PropertyMapping[] | select(.Key == "nsx_ntp_0")).Value = $ntpServer |
(.PropertyMapping[] | select(.Key == "nsx_gateway_0")).Value = $gateway |
(.PropertyMapping[] | select(.Key == "nsx_ip_0")).Value = $ip |
(.PropertyMapping[] | select(.Key == "netmask_0")).Value = $netmask |
(.PropertyMapping[] | select(.Key == "nsx_cli_username")).Value = $adminName |
(.PropertyMapping[] | select(.Key == "nsx_passwd_0")).Value = $adminPassword |
(.PropertyMapping[] | select(.Key == "nsx_cli_passwd_0")).Value = $cliPassword |
(.PropertyMapping[] | select(.Key == "nsx_isSSHEnabled")).Value = "True" |
(.PropertyMapping[] | select(.Key == "nsx_allowSSHRootLogin")).Value = "True"
EOF

  jq \
    --arg vmName "${NSX_T_CONTROLLER_VM_NAME_PREFIX}-0${instance_index}" \
    --arg mgmt_network "$MGMT_PORTGROUP" \
    --arg hostname "${NSX_T_CONTROLLER_HOST_PREFIX}-0${instance_index}" \
    --arg dnsServer "$DNSSERVER" \
    --arg dnsdomain "$DNSDOMAIN" \
    --arg ntpServer "$NTPSERVERS" \
    --arg gateway "$DEFAULTGATEWAY" \
    --arg ip "$instance_ip" \
    --arg netmask "$NETMASK" \
    --arg adminName "admin" \
    --arg adminPassword "$NSX_T_CONTROLLER_ROOT_PWD" \
    --arg cliPassword "$NSX_T_CONTROLLER_ROOT_PWD" \
    --from-file /tmp/nsx_ctrl_filters \
    /tmp/nsx-ctrl-import.json > /tmp/nsx-ctrl-0${count}-ova-options.json

  #cat /tmp/nsx-mgr-ova-options.json
  echo "/tmp/nsx-ctrl-0${count}-ova-options.json"
}


function handle_nsx_edge_ova_options {

  nsx_edge_ova_file_path=$1
  instance_ip=$2
  instance_index=$3

  govc import.spec "$nsx_edge_ova_file_path" | python -m json.tool > /tmp/nsx-edge-import.json

  cat > /tmp/nsx_edge_filters <<'EOF'
.Name = $vmName |
.IPAllocationPolicy = "fixedPolicy" |
.NetworkMapping[0].Network = $mgmt_network |
.NetworkMapping[1].Network = $portgroup_ext |
.NetworkMapping[2].Network = $portgroup_transport |
.PowerOn = true |
.WaitForIP = true |
.Deployment = $deployment_size |
(.PropertyMapping[] | select(.Key == "nsx_hostname")).Value = $hostname |
(.PropertyMapping[] | select(.Key == "nsx_dns1_0")).Value = $dnsServer |
(.PropertyMapping[] | select(.Key == "nsx_domain_0")).Value = $dnsdomain |
(.PropertyMapping[] | select(.Key == "nsx_ntp_0")).Value = $ntpServer |
(.PropertyMapping[] | select(.Key == "nsx_gateway_0")).Value = $gateway |
(.PropertyMapping[] | select(.Key == "nsx_ip_0")).Value = $ip |
(.PropertyMapping[] | select(.Key == "netmask_0")).Value = $netmask |
(.PropertyMapping[] | select(.Key == "nsx_cli_username")).Value = $adminName |
(.PropertyMapping[] | select(.Key == "nsx_passwd_0")).Value = $adminPassword |
(.PropertyMapping[] | select(.Key == "nsx_cli_passwd_0")).Value = $cliPassword |
(.PropertyMapping[] | select(.Key == "nsx_isSSHEnabled")).Value = "True" |
(.PropertyMapping[] | select(.Key == "nsx_allowSSHRootLogin")).Value = "True"
EOF

  jq \
    --arg vmName "${NSX_T_EDGE_VM_NAME_PREFIX}-0${instance_index}" \
    --arg mgmt_network "$MGMT_PORTGROUP" \
    --arg portgroup_ext "$NSX_T_EDGE_PORTGROUP_EXT" \
    --arg portgroup_transport "$NSX_T_EDGE_PORTGROUP_TRANSPORT" \
    --arg deployment_size "$NSX_T_EDGE_DEPLOY_SIZE" \
    --arg hostname "${NSX_T_EDGE_HOST_PREFIX}-0${instance_index}" \
    --arg dnsServer "$DNSSERVER" \
    --arg dnsdomain "$DNSDOMAIN" \
    --arg ntpServer "$NTPSERVERS" \
    --arg gateway "$DEFAULTGATEWAY" \
    --arg ip "$instance_ip" \
    --arg netmask "$NETMASK" \
    --arg adminName "admin" \
    --arg adminPassword "$NSX_T_EDGE_ROOT_PWD" \
    --arg cliPassword "$NSX_T_EDGE_ROOT_PWD" \
    --from-file /tmp/nsx_edge_filters \
    /tmp/nsx-edge-import.json > /tmp/nsx-edge-0${count}-ova-options.json

  #cat /tmp/nsx-edge-ova-options.json
  echo "/tmp/nsx-edge-0${count}-ova-options.json"
}

function handle_custom_nsx_edge_ova_payload {

  nsx_edge_ova_file_path=$1
  instance_ip=$2
  instance_index=$3

  govc import.spec "$nsx_edge_ova_file_path" | python -m json.tool > /tmp/nsx-edge-import.json

  cat > /tmp/nsx_edge_filters <<'EOF'
.Name = $vmName |
.IPAllocationPolicy = "fixedPolicy" |
.NetworkMapping[0].Network = $mgmt_network |
.NetworkMapping[1].Network = $portgroup_ext |
.NetworkMapping[2].Network = $portgroup_transport |
.PowerOn = true |
.WaitForIP = true |
.Deployment = $deployment_size |
(.PropertyMapping[] | select(.Key == "nsx_hostname")).Value = $hostname |
(.PropertyMapping[] | select(.Key == "nsx_dns1_0")).Value = $dnsServer |
(.PropertyMapping[] | select(.Key == "nsx_domain_0")).Value = $dnsdomain |
(.PropertyMapping[] | select(.Key == "nsx_ntp_0")).Value = $ntpServer |
(.PropertyMapping[] | select(.Key == "nsx_gateway_0")).Value = $gateway |
(.PropertyMapping[] | select(.Key == "nsx_ip_0")).Value = $ip |
(.PropertyMapping[] | select(.Key == "netmask_0")).Value = $netmask |
(.PropertyMapping[] | select(.Key == "nsx_cli_username")).Value = $adminName |
(.PropertyMapping[] | select(.Key == "nsx_passwd_0")).Value = $adminPassword |
(.PropertyMapping[] | select(.Key == "nsx_cli_passwd_0")).Value = $cliPassword |
(.PropertyMapping[] | select(.Key == "nsx_isSSHEnabled")).Value = "True" |
(.PropertyMapping[] | select(.Key == "nsx_allowSSHRootLogin")).Value = "True"
EOF

  jq \
    --arg vmName "${NSX_T_EDGE_VM_NAME_PREFIX}-0${instance_index}" \
    --arg mgmt_network "$MGMT_PORTGROUP" \
    --arg portgroup_ext "$NSX_T_EDGE_PORTGROUP_EXT" \
    --arg portgroup_transport "$NSX_T_EDGE_PORTGROUP_TRANSPORT" \
    --arg deployment_size "$NSX_T_EDGE_DEPLOY_SIZE" \
    --arg hostname "${NSX_T_EDGE_HOST_PREFIX}-0${instance_index}" \
    --arg dnsServer "$EDGE_DNSSERVER" \
    --arg dnsdomain "$EDGE_DNSDOMAIN" \
    --arg ntpServer "$EDGE_NTPSERVERS" \
    --arg gateway "$EDGE_DEFAULTGATEWAY" \
    --arg ip "$instance_ip" \
    --arg netmask "$EDGE_NETMASK" \
    --arg adminName "admin" \
    --arg cliPassword "$NSX_T_EDGE_ROOT_PWD" \
    --arg adminPassword "$NSX_T_EDGE_ROOT_PWD" \
    --from-file /tmp/nsx_edge_filters \
    /tmp/nsx-edge-import.json > /tmp/nsx-edge-0${count}-ova-options.json

  #cat /tmp/nsx-edge-ova-options.json
  echo "/tmp/nsx-edge-0${count}-ova-options.json"
}
