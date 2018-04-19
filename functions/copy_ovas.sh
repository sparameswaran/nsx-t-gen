#!/bin/bash

export ROOT_DIR=`pwd`
export OVA_ISO_PATH='/root/ISOs/CHGA'
	
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

	NSX_T_MANAGER_OVA=$(ls $ROOT_DIR/nsx-mgr-ova)
	NSX_T_CONTROLLER_OVA=$(ls $ROOT_DIR/nsx-ctrl-ova)
	NSX_T_EDGE_OVA=$(ls $ROOT_DIR/nsx-edge-ova)

	mkdir -p $OVA_ISO_PATH
	cp $ROOT_DIR/nsx-mgr-ova/$NSX_T_MANAGER_OVA \
	   $ROOT_DIR/nsx-ctrl-ova/$NSX_T_CONTROLLER_OVA \
	   $ROOT_DIR/nsx-edge-ova/$NSX_T_EDGE_OVA \
	   $OVA_ISO_PATH

	echo "Done copying ova images into $OVA_ISO_PATH"
	echo ""
}

function create_customize_ova_params {

	NSX_T_MANAGER_OVA=$(ls $ROOT_DIR/nsx-mgr-ova)
	NSX_T_CONTROLLER_OVA=$(ls $ROOT_DIR/nsx-ctrl-ova)
	NSX_T_EDGE_OVA=$(ls $ROOT_DIR/nsx-edge-ova)

	cat > customize_ova_vars.yml <<-EOF
ovftool_path: '/usr/bin'
ova_file_path: "$OVA_ISO_PATH"
nsx_manager_filename: "$NSX_T_MANAGER_OVA"
nsx_controller_filename: "$NSX_T_CONTROLLER_OVA"
nsx_gw_filename: "$NSX_T_EDGE_OVA"
EOF

	echo "$NSX_T_SIZING_SPEC" >> customize_ova_vars.yml
}
