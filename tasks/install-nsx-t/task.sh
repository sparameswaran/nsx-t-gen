#!/bin/bash
set -e

export ROOT_DIR=`pwd`
export SCRIPT_DIR=$(dirname $0)

sleep 200

STATUS=$?
popd  >/dev/null 2>&1

exit $STATUS
