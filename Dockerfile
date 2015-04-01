###### QNIBTerminal images
# A docker image that includes
# - init (supervisord)
# - syslog (syslog-ng)
# - profiling (diamond)
FROM qnib/consul
MAINTAINER "Christian Kniep <christian@qnib.org>"

# Refresh yum
RUN echo "2015-04-01";yum clean all && \
    yum install -y http://ftp-stud.hs-esslingen.de/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm && \
    yum install -y bind-utils vim nmap

##### USER
# Set (very simple) password for root
ADD root/ssh /root/.ssh
RUN echo "root:root"|chpasswd && \
    chmod 600 /root/.ssh/authorized_keys /root/.ssh/id_rsa && \
    chown -R root:root /root/*

### SSHD
RUN yum install -y openssh-server && \
    mkdir -p /var/run/sshd && \
    sed -i -e 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config
RUN getent passwd sshd || useradd -g sshd sshd
ADD opt/qnib/bin/startup_sshd.sh /opt/qnib//bin/startup_sshd.sh
ADD etc/supervisord.d/sshd.ini /etc/supervisord.d/sshd.ini
ADD etc/consul.d/check_sshd.json /etc/consul.d/check_sshd.json


# We do not care about the known_hosts-file and all the security
####### Highly unsecure... !1!! ###########
RUN echo "        StrictHostKeyChecking no" >> /etc/ssh/ssh_config && \
    echo "        UserKnownHostsFile=/dev/null" >> /etc/ssh/ssh_config && \
    echo "        AddressFamily inet" >> /etc/ssh/ssh_config

# Diamond
RUN yum clean all; yum install -y --nogpgcheck python-configobj lm_sensors python-pysensors python-diamond && \
    rm -rf /etc/diamond && mkdir -p /var/log/diamond
ADD etc/diamond /etc/diamond
ADD opt/qnib/bin/start_diamond.sh /opt/qnib/bin/start_diamond.sh
ADD etc/supervisord.d/diamond.ini /etc/supervisord.d/diamond.ini
ADD etc/consul.d/check_diamond.json /etc/consul.d/check_diamond.json

## logstash-forwarder certificates
ADD etc/pki/tls/ /etc/pki/tls/

## syslog-ng

RUN echo 'alias qsetup="PYTHONPATH=/data/usr/lib/python2.7/site-packages/ /data/usr/local/bin/qnib-setup.py"' >> /etc/bashrc
RUN echo "alias disable_setup='grep autostart /etc/supervisord.d/setup.ini||sed -i -e \"/command/a autostart=false\" /etc/supervisord.d/setup.ini'" >> /etc/bashrc

RUN yum install -y python-pip && \
    pip install envoy neo4jrestclient
RUN yum install -y git-core make golang && cd /tmp/ && \
    git clone https://github.com/hashicorp/consul-template.git && \
    cd /tmp/consul-template && \
    GOPATH=/root/ make && \
    mv /tmp/consul-template/bin/consul-template /usr/local/bin/ && \
    rm -rf /tmp/consul-template && \
    yum remove -y make golang git-core
# dependencies needed by costum scripts (e.g. osquery)
RUN yum install -y python-pip libyaml-devel python-devel && \
    pip install neo4jrestclient pyyaml docopt python-consul jinja2
# osqueryi
ADD usr/bin/osqueryi /usr/bin/osqueryi
ADD usr/bin/osqueryd /usr/bin/osqueryd
#RUN yum install -y http://ftp.wrz.de/pub/fedora-epel/7/x86_64/e/epel-release-7-5.noarch.rpm 
#RUN yum install -y https://osquery-packages.s3.amazonaws.com/centos7/osquery.rpm 
#RUN yum install -y osquery

