#!/bin/bash

function install_ovftool {

	# Install provided ovftool
	if [ ! -e "/usr/bin/ovftool" ]; then
		pushd $ROOT_DIR/ovftool
		ovftool_bundle=$(ls *)
		chmod +x $ovftool_bundle

		size_of_tool=$(ls -al $ovftool_bundle | awk '{print $5}')
		if [ $size_of_tool -lt 10000000 ]; then
			echo "ovftool downloaded is lesser than 10 MB!!"
			echo "Check the file name/paths. Exiting from ova copy and deploy!!"
			exit 1
		fi

		is_binary=$(file $ovftool_bundle | grep "executable" || true)
		if [ "$is_binary" == "" ]; then
			echo "ovftool downloaded was not a valid binary image!!"
			echo "Check the file name/paths. Exiting from ova copy and deploy!!"
			exit 1
		fi

		./${ovftool_bundle} --eulas-agreed
		popd
		echo "Done installing ovftool"
	else
		echo "ovftool already installed!!"
	fi
	echo ""
}

function check_ovas {

	for ova_file in "$ROOT_DIR/nsx-mgr-ova/$NSX_T_MANAGER_OVA \
	$ROOT_DIR/nsx-ctrl-ova/$NSX_T_CONTROLLER_OVA \
	$ROOT_DIR/nsx-edge-ova/$NSX_T_EDGE_OVA "
	do
		is_tar=$(file $ova_file | grep "tar archive" || true)
		if [ "$is_tar" == "" ]; then
			echo "File $ova_file downloaded was not a valid OVA image!!"
			echo "Check the file name/paths. Exiting from ova copy and deploy!!"
			exit 1
		fi
	done
}

function copy_ovas_to_OVA_ISO_PATH {

	mkdir -p $OVA_ISO_PATH
	check_ovas

	mv $ROOT_DIR/nsx-mgr-ova/$NSX_T_MANAGER_OVA \
	$ROOT_DIR/nsx-ctrl-ova/$NSX_T_CONTROLLER_OVA \
	$ROOT_DIR/nsx-edge-ova/$NSX_T_EDGE_OVA \
	$OVA_ISO_PATH

	echo "Done moving ova images into $OVA_ISO_PATH"
	echo ""
}

function create_customize_ova_params {

	cat > customize_ova_vars.yml <<-EOF
	ovftool_path: '/usr/bin'
	ova_file_path: "$OVA_ISO_PATH"
	nsx_gw_filename: "$NSX_T_EDGE_OVA"
	nsx_manager_filename: "$NSX_T_MANAGER_OVA"
	nsx_controller_filename: "$NSX_T_CONTROLLER_OVA"
	EOF

	if [ "$NSX_T_KEEP_RESERVATION" == "false" ]; then
		echo "nsx_t_keep_reservation: $NSX_T_KEEP_RESERVATION" >> customize_ova_vars.yml
	fi

	#echo "$NSX_T_SIZING_SPEC" >> customize_ova_vars.yml
}
