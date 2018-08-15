# Meant for support nsx-t v2.2
FROM ubuntu:17.10
COPY ./ ./

#RUN apt-get update && apt-get install -y vim curl wget default-jdk maven gradle golang git jq python ruby-dev python-pip python-dev libffi-dev libssl-dev libxml2-dev libxslt1-dev zlib1g-dev sshpass

RUN apt-get update \
	&& apt-get install -y \
			vim \
			curl \
			wget \
			golang \
			git \
			jq \
			python \
			ruby-dev \
			python-pip \
			python-dev \
			libffi-dev \
			libssl-dev \
			libxml2 \
			libxml2-dev \
			libxslt1-dev \
			zlib1g-dev \
			sshpass \
			openssl \
			libssl-dev \
			libffi-dev \
			python-dev \
			build-essential

RUN pip install --upgrade pip
RUN pip install \
			pyVim \
			pyvmomi \
			six \
			pyquery \
			xmltodict \
			ipcalc \
			click \
			Jinja2 \
			shyaml \
			dicttoxml \
			pprint \
			PyYAML \
			requests \
	&& pip install --upgrade \
					wheel \
					setuptools \
					lxml \
					enum \
					cffi \
					cryptography \
					enum34 \
					pyasn1==0.4.1 \
	&& pip uninstall -y enum

# Add ansible support
RUN apt-get update \
  && apt-get install -y software-properties-common \
  && apt-add-repository -y ppa:ansible/ansible \
  && apt-get update \
  && apt-get install -y ansible

# Add nsx-t python sdk and runtime libraries
COPY ./nsx_python_sdk-2.2.0.0.0.8680797-py2.py3-none-any.whl .
COPY ./vapi_runtime-2.9.0-py2.py3-none-any.whl .
COPY ./vapi_common-2.9.0-py2.py3-none-any.whl .
COPY ./vapi_common_client-2.9.0-py2.py3-none-any.whl .
RUN pip install nsx_python_sdk-*.whl \
        vapi_runtime-*.whl \
        vapi_common-*.whl \
        vapi_common_client-*.whl

# Overwrite the pyopenssl 0.15.1 with 17.5.0 as ansible breaks otherwise
RUN pip install -U pyopenssl==17.5.0

# Include govc, build using golang-1.8
RUN mkdir -p /root/go/src /root/go/bin /root/go/pkg
ENV GOPATH "/root/go"
ENV PATH "$PATH:$GOPATH/bin"
RUN go get -u github.com/vmware/govmomi/govc
