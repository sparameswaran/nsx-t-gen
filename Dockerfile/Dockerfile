FROM ubuntu:17.10
COPY ./ ./

#RUN apt-get update && apt-get install -y vim curl wget default-jdk maven gradle golang git jq python ruby-dev python-pip python-dev libffi-dev libssl-dev libxml2-dev libxslt1-dev zlib1g-dev sshpass 
RUN apt-get update && apt-get install -y vim curl wget git jq python ruby-dev python-pip python-dev libffi-dev libssl-dev libxml2-dev libxslt1-dev zlib1g-dev sshpass 
RUN pip install --upgrade pip && pip install vim pyvmomi six pyquery xmltodict ipcalc click Jinja2 shyaml dicttoxml pprint PyYAML requests

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
