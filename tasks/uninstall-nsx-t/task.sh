#!/bin/bash

export ROOT_DIR=`pwd`

export TASKS_DIR=$(dirname $BASH_SOURCE)
export PIPELINE_DIR=$(cd $TASKS_DIR/../../ && pwd)
export FUNCTIONS_DIR=$(cd $PIPELINE_DIR/functions && pwd)
export PYTHON_LIB_DIR=$(cd $PIPELINE_DIR/python && pwd)
export SCRIPT_DIR=$(dirname $0)

source $FUNCTIONS_DIR/check_null_variables.sh
source $FUNCTIONS_DIR/delete_vm_using_govc.sh

# First wipe out all non-nsx vms deployed on the management plane or compute clusters
echo "Need to delete the non-NSX Vms that are running in the computer cluster or Management cluster, before proceeding wtih clean of NSX Mgmt Plane!!"
echo "Now deleting the non NSX vms"
destroy_vms_not_matching_nsx

export ESXI_HOSTS_FILE="$ROOT_DIR/esxi_hosts"

# Make sure the NSX Mgr is up
timeout 15 bash -c "(echo > /dev/tcp/${NSX_T_MANAGER_IP}/22) >/dev/null 2>&1"
status=$?
if [ "$status" == "0" ]; then
  # Start wiping the NSX Configurations from NSX Mgr,
  # cleaning up the routers, switches, transport nodes and fabric nodes
  # Also, additionally create the esxi hosts file so we can do vib cleanup (in case things are sticking around)
  python $PYTHON_LIB_DIR/nsx_t_wipe.py $ESXI_HOSTS_FILE
  STATUS=$?

  if [ "$STATUS" != "0" ]; then
    echo "Problem in running cleanup of NSX components!!"
    echo "The deletion of the NSX VMs  up as well as removal of vibs from Esxi hosts needs to be done manually!!"
    exit $STATUS
  fi
  echo "The resources used within NSX Management plane have been cleaned up!!"
else
  echo "NSX Manager VM not responding, so cannot delete any related resources within the NSX Management plane"
fi

echo "Now deleting the NSX vms"

delete_vm_using_govc "edge"
delete_vm_using_govc "ctrl"
delete_vm_using_govc "mgr"

cp $FUNCTIONS_DIR/uninstall-nsx-vibs.yml $ROOT_DIR/
if [ "$NSX_T_VERSION" == "2.2" ]; then
  cp $FUNCTIONS_DIR/uninstall-nsx-t-v2.2-vibs.sh $ROOT_DIR//uninstall-nsx-t-vibs.sh
else # [ "$NSX_T_VERSION" == "2.1" ]; then
  cp $FUNCTIONS_DIR/uninstall-nsx-t-v2.1-vibs.sh $ROOT_DIR//uninstall-nsx-t-vibs.sh
fi

cat > $ROOT_DIR/ansible.cfg << EOF
[defaults]
host_key_checking = false
EOF

echo "Now removing the NSX-T related vibs from the Esxi Hosts"
ansible-playbook -i $ESXI_HOSTS_FILE $ROOT_DIR/uninstall-nsx-vibs.yml
STATUS=$?

echo "NSX-T vibs removed from the Esxi hosts"
echo "Related Esxi Hosts:"
echo "-------------------"
cat $ESXI_HOSTS_FILE | grep ansible_ssh_host | awk '{print $2}'
echo ""
echo "The Esxi hosts should be rebooted for nsx-t vib removal to be effective!"
echo ""
echo "NSX-T Wipe Complete!!"

exit $STATUS
