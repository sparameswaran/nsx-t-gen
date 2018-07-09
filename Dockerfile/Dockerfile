FROM ubuntu:17.10

ADD VMware-ovftool*.bundle /tmp/VMware-ovftool.bundle

RUN chmod +x /tmp/VMware-ovftool.bundle && \
    sync && \
    /tmp/VMware-ovftool.bundle --eulas-agreed && \
    rm /tmp/VMware-ovftool.bundle && \
    apt-get update && \
    apt-get install -y vim curl wget git jq python ruby-dev python-pip python-dev libffi-dev libssl-dev libxml2 libxml2-dev libxslt1-dev zlib1g-dev sshpass openssl libssl-dev libffi-dev python-dev build-essential && \
    # pip install --upgrade pip && \
    pip install pyVim pyvmomi six pyquery xmltodict ipcalc click Jinja2 shyaml dicttoxml pprint PyYAML requests && \
    pip install --upgrade wheel setuptools lxml enum cffi cryptography enum34 pyasn1==0.4.1 && \
    pip uninstall -y enum && \
    # apt-get update && \
    apt-get install -y software-properties-common && \
    apt-add-repository -y ppa:ansible/ansible && \
    # apt-get update && \
    apt-get install -y ansible && \
# Overwrite the pyopenssl 0.15.1 with 17.5.0 as ansible breaks otherwise
    pip install -U pyopenssl==17.5.0
