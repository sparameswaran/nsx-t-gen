#!/bin/bash

set -e

export ROOT_DIR=`pwd`

export TASKS_DIR=$(dirname $BASH_SOURCE)
export PIPELINE_DIR=$(cd $TASKS_DIR/../../ && pwd)
export FUNCTIONS_DIR=$(cd $PIPELINE_DIR/functions && pwd)

source $FUNCTIONS_DIR/create_ansible_cfg.sh
source $FUNCTIONS_DIR/create_answerfile.sh
source $FUNCTIONS_DIR/create_hosts.sh
source $FUNCTIONS_DIR/create_extra_yaml_args.sh

DEBUG=""
if [ "$ENABLE_ANSIBLE_DEBUG" == "true" ]; then
  DEBUG="-vvv"
fi

# Check if NSX MGR is up or not
nsx_mgr_up_status=$(curl -s -o /dev/null -I -w "%{http_code}" -k  https://${NSX_T_MANAGER_IP}:443/login.jsp || true)

# Deploy the ovas if its not up
if [ $nsx_mgr_up_status -ne 200 ]; then
  echo "NSX Mgr not up yet, please deploy the ovas before configuring routers!!" 
  exit -1
fi

create_hosts
create_answerfile
create_ansible_cfg
create_extra_yaml_args

cp hosts answerfile.yml ansible.cfg extra_yaml_args.yml nsxt-ansible/.
cd nsxt-ansible

echo ""



NO_OF_CONTROLLERS=$(curl -k -u "admin:$NSX_T_MANAGER_ADMIN_PWD" \
                    https://${NSX_T_MANAGER_IP}/api/v1/cluster/nodes \
                    | jq '.results[].controller_role.type' | wc -l )
if [ "$NO_OF_CONTROLLERS" -lt 2 ]; then
  echo "NSX Mgr and controller not configured yet, please cleanup incomplete vms and rerun base install before configuring routers!!" 
  exit -1
fi

ansible-playbook $DEBUG -i hosts configureNsx.yml -e @extra_yaml_args.yml
STATUS=$?


echo ""

exit $STATUS