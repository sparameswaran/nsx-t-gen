#!/bin/bash

function create_ansible_cfg {

	cat > ansible.cfg <<-EOF
[defaults]
host_key_checking = false
EOF
}