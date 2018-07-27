
export ROOT_DIR=`pwd`

export TASKS_DIR=$(dirname $BASH_SOURCE)
export PIPELINE_DIR=$(cd $TASKS_DIR/../../ && pwd)
export FUNCTIONS_DIR=$(cd $PIPELINE_DIR/functions && pwd)
export PYTHON_LIB_DIR=$(cd $PIPELINE_DIR/python && pwd)
export SCRIPT_DIR=$(dirname $0)

source $FUNCTIONS_DIR/check_null_variables.sh
source $FUNCTIONS_DIR/delete_vm_using_govc.sh

# First wipe out all non-nsx vms deployed on the management plane or compute clusters
destroy_vms_not_matching_nsx

export ESXI_HOSTS_FILE="$SCRIPT_DIR/esxi_hosts"

# Make sure the NSX Mgr is up
timeout 15 bash -c "(echo > /dev/tcp/${NSX_T_MANAGER_IP}/22) >/dev/null 2>&1"
status=$?
if [ "$status" == "0" ]; then
  # Start wiping the NSX Configurations from NSX Mgr,
  # cleaning up the routers, switches, transport nodes and fabric nodes
  # Also, additionally create the esxi hosts file so we can do vib cleanup (in case things are sticking around)
  python $PYTHON_LIB_DIR/nsx_t_wipe.py $ESXI_HOSTS_FILE
  STATUS=$?
fi

if [ "$STATUS" != "0" ]; then
  echo "Problem in running cleanup of NSX components!!"
  STATUS=$?
  exit $STATUS
fi

delete_vm_using_govc "edge"
delete_vm_using_govc "ctrl"
delete_vm_using_govc "mgr"

if [ "$NSX_T_VERSION" == "2.2" ]; then
  cp uninstall-nsx-t-v2.2-vibs.sh ./uninstall-nsx-t-vibs.sh
else # [ "$NSX_T_VERSION" == "2.1" ]; then
  cp uninstall-nsx-t-v2.1-vibs.sh ./uninstall-nsx-t-vibs.sh
el

ansible-playbook -i $ESXI_HOSTS_FILE ./uninstall-nsx-t-vibs.sh
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
