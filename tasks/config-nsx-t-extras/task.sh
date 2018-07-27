#!/bin/bash
set -e


export ROOT_DIR=`pwd`

export TASKS_DIR=$(dirname $BASH_SOURCE)
export PIPELINE_DIR=$(cd $TASKS_DIR/../../ && pwd)
export FUNCTIONS_DIR=$(cd $PIPELINE_DIR/functions && pwd)
export PYTHON_LIB_DIR=$(cd $PIPELINE_DIR/python && pwd)
export SCRIPT_DIR=$(dirname $0)

source $FUNCTIONS_DIR/check_null_variables.sh

python $PYTHON_LIB_DIR/nsx_t_gen.py

STATUS=$?

exit $STATUS
