#!/bin/bash
export PAS_NCP_CLUSTER_TAG='ncp/cluster'


# function check_pas_cluster_tag {
#     env_variable=$1

#     # Search for the cluster tag and get the value stripping off any quotes around it
#     tag_value=$(echo "${!env_variable}" | grep $PAS_NCP_CLUSTER_TAG | awk '{print $2}' | sed -e "s/'//g" | sed -e 's/"//g' )

#     if [ "$tag_value" == "$NSX_T_PAS_NCP_CLUSTER_TAG" ]; then
#       echo "true"
#     else
#       echo "false"
#     fi
# }

# Check for existence of tag matching given value
# Handle both array items (like external ip pool) and single item (like T0Router)
function check_existence_of_tag {
    env_variable=$1
    tag_name=$2
    tag_value=$3

    top_key=$(echo "${!env_variable}" | shyaml keys)
    length=$(expr $(echo "${!env_variable}" | shyaml get-values $top_key | grep "^name:" | wc -l) - 1 || true )

 	count=0
    if [ $length -ge 0 ]; then
      for index in $(seq 0 $length)
      do
        tmpfile=$(mktemp /tmp/temp-yaml.XXXXX)
        echo "${!env_variable}" | shyaml get-value ${top_key}.${index} > $tmpfile
        given_tag_value=$(cat $tmpfile | grep $tag_name | awk '{print $2}' | sed -e "s/'//g" | sed -e 's/"//g' )
        if [ "$given_tag_value" == "$tag_value" ]; then
          count=$(expr $count + 1)
       	fi
        rm $tmpfile
      done
    else
        given_tag_value=$(echo "${!env_variable}" | grep $tag_name | awk '{print $2}' | sed -e "s/'//g" | sed -e 's/"//g' )
        if [ "$given_tag_value" == "$tag_value" ]; then
          count=$(expr $count + 1)
       fi
    fi

    # Length would be 0 for single items but count would be 1
    # For arrays, count should greater than length (as we subtracted 1 before)
    if [ $count -gt $length ]; then
    	echo "true"
    fi
}


function handle_external_ip_pool_spec {
  if [ "$NSX_T_EXTERNAL_IP_POOL_SPEC" == "null" -o "$NSX_T_EXTERNAL_IP_POOL_SPEC" == "" ]; then
    return
  fi

  # Has root element
	echo "$NSX_T_EXTERNAL_IP_POOL_SPEC" >> extra_yaml_args.yml
	match=$(check_existence_of_tag NSX_T_EXTERNAL_IP_POOL_SPEC 'ncp/cluster' $NSX_T_PAS_NCP_CLUSTER_TAG )
	if [  "$NSX_T_EXTERNAL_IP_POOL_SPEC" != "" -a "$match" == "" ]; then
		# There can be multiple entries and we can fail to add tag for previous ones
		echo "[Warning] Missing matching ncp/cluster tag in the External IP Pool defn, unsure if its for PAS or PKS"
		#exit 1
		#echo "    ncp/cluster:$NSX_T_PAS_NCP_CLUSTER_TAG" >> extra_yaml_args.yml
	fi
	match=$(check_existence_of_tag NSX_T_EXTERNAL_IP_POOL_SPEC 'ncp/external' 'true' )
	if [  "$NSX_T_EXTERNAL_IP_POOL_SPEC" != "" -a "$match" == "" ]; then
		# There can be multiple entries and we can fail to add tag for previous ones
		echo "[Warning] Missing matching ncp/external tag in the External IP Pool defn, unsure if its for PAS or PKS"
		#exit 1
		#echo "    ncp/cluster:$NSX_T_PAS_NCP_CLUSTER_TAG" >> extra_yaml_args.yml
	fi
	echo "" >> extra_yaml_args.yml

}

function handle_container_ip_block_spec {
  if [ "$NSX_T_CONTAINER_IP_BLOCK_SPEC" == "null" -o "$NSX_T_CONTAINER_IP_BLOCK_SPEC" == "" ]; then
    return
  fi

	# Has root element
	echo "$NSX_T_CONTAINER_IP_BLOCK_SPEC" >> extra_yaml_args.yml
	match=$(check_existence_of_tag NSX_T_CONTAINER_IP_BLOCK_SPEC 'ncp/cluster' $NSX_T_PAS_NCP_CLUSTER_TAG )
	if [  "$NSX_T_CONTAINER_IP_BLOCK_SPEC" != "" -a "$match" == "" ]; then
		echo "[Warning] Missing matching 'ncp/cluster' tag in the Container IP Block defn"
		#exit 1
		#echo "    ncp/cluster:$NSX_T_PAS_NCP_CLUSTER_TAG" >> extra_yaml_args.yml
	fi
	echo "" >> extra_yaml_args.yml
}

function handle_ha_switching_profile_spec {
  if [ "$NSX_T_HA_SWITCHING_PROFILE_SPEC" == "null" -o "$NSX_T_HA_SWITCHING_PROFILE_SPEC" == "" ]; then
    return
  fi

	# Has root element and we expect only one HA switching profile
	echo "$NSX_T_HA_SWITCHING_PROFILE_SPEC" >> extra_yaml_args.yml
	match=$(check_existence_of_tag NSX_T_HA_SWITCHING_PROFILE_SPEC 'ncp/cluster' $NSX_T_PAS_NCP_CLUSTER_TAG )
	# if [ "$NSX_T_HA_SWITCHING_PROFILE_SPEC" != "" -a "$match" == "" ]; then
	# 	echo "    ncp/cluster: $NSX_T_PAS_NCP_CLUSTER_TAG" >> extra_yaml_args.yml
	# fi
	# match=$(check_existence_of_tag NSX_T_HA_SWITCHING_PROFILE_SPEC 'ncp/ha' 'true' )
	# if [ "$match" == "" ]; then
	# 	echo "    ncp/ha: true" >> extra_yaml_args.yml
	# fi
	echo "" >> extra_yaml_args.yml

}

function handle_routers_spec {
  if [ "$NSX_T_T0ROUTER_SPEC" == "null" -o "$NSX_T_T0ROUTER_SPEC" == "" ]; then
    return
  fi

	# Has root element
	echo "$NSX_T_T0ROUTER_SPEC" >> extra_yaml_args.yml
	match=$(check_existence_of_tag NSX_T_T0ROUTER_SPEC 'ncp/cluster' $NSX_T_PAS_NCP_CLUSTER_TAG )
	if [  "$NSX_T_T0ROUTER_SPEC" != "" -a "$match" == "" ]; then
		echo "[Warning] Missing matching 'ncp/cluster' tag in the T0 Router defn, check tags once T0Router is up!!"
		#exit 1
	fi
	echo "" >> extra_yaml_args.yml

  if [ "$NSX_T_T1ROUTER_LOGICAL_SWITCHES_SPEC" == "null" -o "$NSX_T_T1ROUTER_LOGICAL_SWITCHES_SPEC" == "" ]; then
    return
  fi

	# Has root element
	echo "$NSX_T_T1ROUTER_LOGICAL_SWITCHES_SPEC" >> extra_yaml_args.yml
	echo "" >> extra_yaml_args.yml
}

function handle_exsi_vnics {
  if [ "$NSX_T_ESXI_VMNICS" == "null" -o "$NSX_T_ESXI_VMNICS" == "" ]; then
    return
  fi

	count=1
	# Create an extra_args.yml file for additional yaml style parameters outside of host and answerfile.yml
	echo "esxi_uplink_vmnics:" >> extra_yaml_args.yml
	for vmnic in $( echo $NSX_T_ESXI_VMNICS | sed -e 's/,/ /g')
	do
	  #echo "  - uplink-${count}: ${vmnic}" >> extra_yaml_args.yml
	  echo "  uplink-${count}: ${vmnic}" >> extra_yaml_args.yml
	  (( count++ ))
	done
	echo "" >> extra_yaml_args.yml
}

function handle_vcenter_configs {
  if [ "$COMPUTE_VCENTER_CONFIGS" == "null" -o "$COMPUTE_VCENTER_CONFIGS" == "" ]; then
    return
  fi

  echo "$COMPUTE_VCENTER_CONFIGS" >> extra_yaml_args.yml

}


function create_extra_yaml_args {
	# Start the extra yaml args
	echo "" > extra_yaml_args.yml
  handle_external_ip_pool_spec
  handle_container_ip_block_spec
  handle_ha_switching_profile_spec
  handle_routers_spec
  handle_exsi_vnics
  handle_vcenter_configs

	# Going with single profile uplink ; so use uplink-1 for both vmnics for edge
	echo "edge_uplink_vmnics:" >> extra_yaml_args.yml
	echo "  - uplink-1: ${NSX_T_EDGE_OVERLAY_INTERFACE} # network3 used for overlay/tep" >> extra_yaml_args.yml
  echo "  - uplink-1: ${NSX_T_EDGE_UPLINK_INTERFACE}  # network2 used for vlan uplink" >> extra_yaml_args.yml
	echo "# network1 and network4 are for mgmt and not used for uplink" >> extra_yaml_args.yml
	echo "" >> extra_yaml_args.yml
}
