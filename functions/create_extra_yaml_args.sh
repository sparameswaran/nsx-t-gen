#!/bin/bash

function create_extra_yaml_args {
	
	# Start the extra yaml args
	echo "" > extra_yaml_args.yml

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

	count=1
	# Create an extra_args.yml file for additional yaml style parameters outside of host and answerfile.yml
	esxi_host_uplink_vmnics='[ '
	echo "esxi_uplink_vmnics:" >> extra_yaml_args.yml
	for vmnic in $( echo $NSX_T_ESXI_VMNICS | sed -e 's/,/ /g')
	do
	  echo "  - uplink-${count}: ${vmnic}" >> extra_yaml_args.yml
	  (( count++ ))
	done
	echo "" >> extra_yaml_args.yml


	# Going with single profile uplink ; so use uplink-1 for both vmnics for edge
	echo "edge_uplink_vmnics:" >> extra_yaml_args.yml
	echo "  - uplink-1: fp-eth1 # network3 used for overlay/tep" >> extra_yaml_args.yml
	echo "  - uplink-1: fp-eth0 # network2 used for vlan uplink" >> extra_yaml_args.yml
	echo "# network1 and network4 are for mgmt and not used for uplink" >> extra_yaml_args.yml
	echo "" >> extra_yaml_args.yml

}