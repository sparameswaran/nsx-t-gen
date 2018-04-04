FROM ubuntu:17.10
COPY ./ ./

#RUN apt-get update && apt-get install -y vim curl wget default-jdk maven gradle golang git jq python ruby-dev python-pip python-dev libffi-dev libssl-dev libxml2-dev libxslt1-dev zlib1g-dev sshpass 
RUN apt-get update && apt-get install -y vim curl wget git jq python ruby-dev python-pip python-dev libffi-dev libssl-dev libxml2 libxml2-dev libxslt1-dev zlib1g-dev sshpass openssl libssl-dev libffi-dev python-dev build-essential

RUN pip install --upgrade pip && pip install pyVim pyvmomi six pyquery xmltodict ipcalc click Jinja2 shyaml dicttoxml pprint PyYAML requests

RUN pip install --upgrade pip wheel setuptools
RUN pip install --upgrade lxml enum cffi
RUN pip install --upgrade cryptography pyopenssl enum34
RUN pip uninstall -y enum

# Add ansible support
RUN apt-get update
RUN apt-get install -y software-properties-common
RUN apt-add-repository -y ppa:ansible/ansible
RUN apt-get update
RUN apt-get install -y ansible

# Add ovftool
#COPY ./VMware-ovftool-4.2.0-5965791-lin.x86_64.bundle .
#RUN chmod +x ./VMware-ovftool-4.2.0-5965791-lin.x86_64.bundle
#RUN ./VMware-ovftool-4.2.0-5965791-lin.x86_64.bundle  --eulas-agreed


# Add nsx-t python sdk and runtime libraries
#COPY ./nsx_python_sdk-*.whl .
#COPY ./vapi_runtime-*.whl .
#COPY ./vapi_common-*.whl .
#COPY ./vapi_common_client-*.whl .
RUN pip install nsx_python_sdk-*.whl
RUN pip install vapi_runtime-*.whl
RUN pip install vapi_common-*.whl
RUN pip install vapi_common_client-*.whl
