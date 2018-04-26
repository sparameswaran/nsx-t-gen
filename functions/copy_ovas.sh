#!/bin/bash

function install_ovftool {

	# Install provided ovftool
	if [ ! -e "/usr/bin/ovftool" ]; then
	  pushd $ROOT_DIR/ovftool
	  ovftool_bundle=$(ls *)
	  chmod +x $ovftool_bundle
	  ./${ovftool_bundle} --eulas-agreed
	  popd
	  echo "Done installing ovftool"
	else
	  echo "ovftool already installed!!"
	fi
	echo ""	
}

function copy_ovas_to_OVA_ISO_PATH {

	mkdir -p $OVA_ISO_PATH
	cp $ROOT_DIR/nsx-mgr-ova/$NSX_T_MANAGER_OVA \
	   $ROOT_DIR/nsx-ctrl-ova/$NSX_T_CONTROLLER_OVA \
	   $ROOT_DIR/nsx-edge-ova/$NSX_T_EDGE_OVA \
	   $OVA_ISO_PATH

	echo "Done copying ova images into $OVA_ISO_PATH"
	echo ""
}

function create_customize_ova_params {

	cat > customize_ova_vars.yml <<-EOF
ovftool_path: '/usr/bin'
ova_file_path: "$OVA_ISO_PATH"
nsx_manager_filename: "$NSX_T_MANAGER_OVA"
nsx_controller_filename: "$NSX_T_CONTROLLER_OVA"
nsx_gw_filename: "$NSX_T_EDGE_OVA"
EOF

	if [ "$NSX_T_KEEP_RESERVATION" == "false" ]; then
		echo "nsx_t_keep_reservation: $NSX_T_KEEP_RESERVATION" >> customize_ova_vars.yml
	fi

	#echo "$NSX_T_SIZING_SPEC" >> customize_ova_vars.yml
}
