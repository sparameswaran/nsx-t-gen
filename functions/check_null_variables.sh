#!/bin/bash

function check_null_variables {

  for token in $(env | grep '=' | grep "^[A-Z]*" | grep '=null$' | sed -e 's/=.*//g')
  do
    export ${token}=""
  done
}

if [ "$NSX_T_VERSION" == "" -o "$NSX_T_VERSION" == "" ]; then
  export NSX_T_VERSION=2.1
fi

check_null_variables
