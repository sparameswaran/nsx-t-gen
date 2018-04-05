#!/bin/bash
set -e

export ROOT_DIR=`pwd`
export SCRIPT_DIR=$(dirname $0)

export NSX_HOST=${NSX_T_MANAGER_IP}
export USER_CRED=${NSX_T_MANAGER_ADMIN_USER}:${NSX_T_MANAGER_ADMIN_PWD}

export ROOT_DIR=`pwd`
export SCRIPT_DIR=$(dirname $0)

python nsx_t_gen.py

STATUS=$?

sleep 20

popd  >/dev/null 2>&1

exit $STATUS
