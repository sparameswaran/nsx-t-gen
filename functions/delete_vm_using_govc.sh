#!/bin/bash

set -eu

export GOVC_DEBUG=$ENABLE_ANSIBLE_DEBUG

#export GOVC_TLS_CA_CERTS=/tmp/vcenter-ca.pem
#echo "$GOVC_CA_CERT" > "$GOVC_TLS_CA_CERTS"

function delete_vm_using_govc() {
  type_of_vm=$1

  if [ "$type_of_vm" == "mgr" ]; then
    delete_mgr_vm
  elif [ "$type_of_vm" == "edge" ]; then
    delete_edge_vm
  else
    delete_ctrl_vm
  fi
}

function destroy_vms_not_matching_nsx() {
  nsx_vm_name_pattern="${NSX_T_EDGE_VM_NAME_PREFIX}\|${NSX_T_MANAGER_VM_NAME}\|${NSX_T_CONTROLLER_VM_NAME_PREFIX}"

  default_options=" GOVC_URL=$VCENTER_HOST \
                    GOVC_DATACENTER=$VCENTER_DATACENTER \
                    GOVC_INSECURE=true \
                    GOVC_DATASTORE=$VCENTER_DATASTORE \
                    GOVC_CLUSTER=$VCENTER_CLUSTER \
                    GOVC_USERNAME=$VCENTER_USR \
                    GOVC_PASSWORD=$VCENTER_PWD "

  # Setup govc env variables coming via $default_options
  export $default_options

  # Shutdown and clean all non-nsx related vms in the management plane
  for vm_path  in $(govc find . -type m | grep -ve "$nsx_vm_name_pattern" || true)
  do
    echo govc vm.power -off "$vm_path"
    echo govc vm.destroy "$vm_path"
  done

  # Shutdown and clean all non-nsx related vms in the compute clusters plane
  if [ "$COMPUTE_MANAGER_CONFIGS" != "" -a "$COMPUTE_MANAGER_CONFIGS" != "null" ]; then

    compute_manager_json_config=$(echo "$COMPUTE_MANAGER_CONFIGS"  | python $PYTHON_LIB_DIR/yaml2json.py)

    total_count=$(echo $compute_manager_json_config | jq '.compute_managers | length')
    index=0
    while [ $index -lt $total_count ]
    do
      compute_vcenter=$( echo $compute_manager_json_config | jq --argjson index $index '.compute_managers[$index]' )
	    compute_vcenter_host=$(echo $compute_vcenter | jq -r '.vcenter_host' )
      #compute_vcenter_dc=$(echo $compute_vcenter | jq -r '.vcenter_datacenter' )
      compute_vcenter_usr=$(echo $compute_vcenter | jq -r '.vcenter_usr' )
      compute_vcenter_pwd=$(echo $compute_vcenter | jq -r '.vcenter_pwd' )

      inner_total=$(echo $compute_vcenter | jq '.clusters | length' )
      inner_index=0
      while [ $inner_index -lt $inner_total ]
      do
        compute_cluster=$( echo $compute_vcenter | jq --argjson inner_index $inner_index '.clusters[$inner_index]' )
        compute_vcenter_cluster=$(echo $compute_cluster | jq -r '.vcenter_cluster' )

        custom_options="GOVC_URL=$compute_vcenter_host \
                        GOVC_DATACENTER=$VCENTER_DATACENTER \
                        GOVC_INSECURE=true \
                        GOVC_CLUSTER=$compute_vcenter_cluster \
                        GOVC_USERNAME=$compute_vcenter_usr \
                        GOVC_PASSWORD=$compute_vcenter_pwd "

        # Setup govc env variables coming via the above options
        export $custom_options

        for vm_path in $(govc find . -type m | grep -ve "$nsx_vm_name_pattern" || true)
        do
          echo govc vm.power -off "$vm_path"
          echo govc vm.destroy "$vm_path"
        done
        inner_index=$(expr $inner_index + 1)
      done
      index=$(expr $index + 1)
    done
  fi
}

function destroy_vm_matching_name {
  vm_name=$1
  additional_options=$2

  # Setup govc env variables coming via $additional_options
  export $additional_options

  vm_path=$(govc find . -type m | grep "$vm_name" || true)
  if [ "$vm_path" != "" ]; then
    govc vm.power -off "$vm_path"
    govc vm.destroy "$vm_path"
  fi
}

function delete_mgr_vm() {
  vm_name=${NSX_T_MANAGER_VM_NAME}

  default_additional_options="GOVC_URL=$VCENTER_HOST \
                              GOVC_DATACENTER=$VCENTER_DATACENTER \
                              GOVC_INSECURE=true \
                              GOVC_DATASTORE=$VCENTER_DATASTORE \
                              GOVC_CLUSTER=$VCENTER_CLUSTER \
                              GOVC_USERNAME=$VCENTER_USR \
                              GOVC_PASSWORD=$VCENTER_PWD "

  destroy_vm_matching_name "$vm_name" "$default_additional_options"

}

function delete_edge_vm() {
  default_additional_options="GOVC_URL=$VCENTER_HOST \
                              GOVC_DATACENTER=$VCENTER_DATACENTER \
                              GOVC_INSECURE=true \
                              GOVC_DATASTORE=$VCENTER_DATASTORE \
                              GOVC_CLUSTER=$VCENTER_CLUSTER \
                              GOVC_USERNAME=$VCENTER_USR \
                              GOVC_PASSWORD=$VCENTER_PWD "

  if [ "$EDGE_VCENTER_HOST" == "" -o "$EDGE_VCENTER_HOST" == "null" ]; then
    count=1
    for nsx_edge_ip in $(echo $NSX_T_EDGE_IPS | sed -e 's/,/ /g')
    do
      destroy_vm_matching_name "${NSX_T_EDGE_VM_NAME_PREFIX}-0${count}" "$default_additional_options"
      (( count++ ))
    done
    return
  fi

  count=1
  edge_additional_options=" GOVC_URL=$EDGE_VCENTER_HOST \
                            GOVC_DATACENTER=$EDGE_VCENTER_DATACENTER \
                            GOVC_INSECURE=true \
                            GOVC_DATASTORE=$EDGE_VCENTER_DATASTORE \
                            GOVC_CLUSTER=$EDGE_VCENTER_CLUSTER \
                            GOVC_USERNAME=$EDGE_VCENTER_USR \
                            GOVC_PASSWORD=$EDGE_VCENTER_PWD "

  for nsx_edge_ip in $(echo $NSX_T_EDGE_IPS | sed -e 's/,/ /g')
  do
    destroy_vm_matching_name "${NSX_T_EDGE_VM_NAME_PREFIX}-0${count}" "$edge_additional_options"
    (( count++ ))
  done
}

function delete_ctrl_vm() {
  default_additional_options="GOVC_URL=$VCENTER_HOST \
                              GOVC_DATACENTER=$VCENTER_DATACENTER \
                              GOVC_INSECURE=true \
                              GOVC_DATASTORE=$VCENTER_DATASTORE \
                              GOVC_CLUSTER=$VCENTER_CLUSTER \
                              GOVC_USERNAME=$VCENTER_USR \
                              GOVC_PASSWORD=$VCENTER_PWD "

  if [ "$NSX_T_CONTROLLERS_CONFIG" == "" -o "$NSX_T_CONTROLLERS_CONFIG" == "null" ]; then
    count=1
    for nsx_ctrl_ip in $(echo $NSX_T_CONTROLLER_IPS | sed -e 's/,/ /g')
    do
      destroy_vm_matching_name "${NSX_T_CONTROLLER_VM_NAME_PREFIX}-0${count}" "$default_additional_options"
      (( count++ ))
    done
    return
  fi

  echo "$NSX_T_CONTROLLERS_CONFIG" > /tmp/controllers_config.yml
  is_valid_yml=$(cat /tmp/controllers_config.yml  | shyaml get-values controllers || true)

  # Check if the esxi_hosts config is not empty and is valid
  if [ "$NSX_T_CONTROLLERS_CONFIG" != "" -a "$is_valid_yml" != "" ]; then

    NSX_T_CONTROLLER_VM_NAME_PREFIX=$(cat /tmp/controllers_config.yml  | shyaml get-value controllers.vm_name_prefix)

    count=1
    for index in $(seq 0 $length)
    do
      NSX_T_CONTROLLER_INSTANCE_CLUSTER=$(cat /tmp/controllers_config.yml  | shyaml get-value controllers.members.${index}.cluster)
      NSX_T_CONTROLLER_INSTANCE_RP=$(cat /tmp/controllers_config.yml  | shyaml get-value controllers.members.${index}.resource_pool)
      NSX_T_CONTROLLER_INSTANCE_DATASTORE=$(cat /tmp/controllers_config.yml  | shyaml get-value controllers.members.${index}.datastore)

        ctrl_additional_options=" GOVC_URL=$VCENTER_HOST \
                                  GOVC_DATACENTER=$VCENTER_DATACENTER \
                                  GOVC_INSECURE=true \
                                  GOVC_DATASTORE=$NSX_T_CONTROLLER_INSTANCE_DATASTORE \
                                  GOVC_CLUSTER=$NSX_T_CONTROLLER_INSTANCE_CLUSTER \
                                  GOVC_USERNAME=$VCENTER_USR \
                                  GOVC_PASSWORD=$VCENTER_PWD "

      destroy_vm_matching_name "${NSX_T_CONTROLLER_VM_NAME_PREFIX}-0${count}" "$ctrl_additional_options"
      (( count++ ))
    done
  fi
}
