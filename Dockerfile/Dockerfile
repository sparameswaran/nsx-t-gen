FROM ubuntu:17.10

RUN apt-get update && apt-get install -y vim curl wget default-jdk maven gradle golang git jq python ruby-dev python-pip python-dev libffi-dev libssl-dev libxml2-dev libxslt1-dev zlib1g-dev sshpass 
RUN pip install --upgrade pip && pip install pyvmomi six pyquery xmltodict ipcalc click Jinja2 shyaml dicttoxml pprint PyYAML requests
RUN ls -al $HOME && mkdir $HOME/go
ENV GOPATH $HOME/go/
ENV GOBIN $GOPATH/bin
ENV PATH $PATH:$GOBIN
RUN go get github.com/pivotal-cf/om
RUN go get github.com/pivotal-cf/pivnet-cli
RUN go get github.com/vmware/govmomi/govc
RUN gem install cf-uaac
RUN apt-get update
# Add ansible support
RUN apt-get install -y software-properties-common
RUN apt-add-repository -y ppa:ansible/ansible
RUN apt-get update
RUN apt-get install -y ansible
# Add ovftool
COPY ../VMware-ovftool-*-lin.x86_64.bundle .
RUN ./VMware-ovftool-*-lin.x86_64.bundle
