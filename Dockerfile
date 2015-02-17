###### QNIBTerminal images
# A docker image that includes
# - init (supervisord)
# - syslog (syslog-ng)
# - profiling (diamond)
FROM qnib/consul
MAINTAINER "Christian Kniep <christian@qnib.org>"

# Refresh yum
RUN echo "2014-08-24";yum clean all && \
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

# carboniface
ADD yum-cache/carboniface /tmp/yum-cache/carboniface
RUN yum install -y python-docopt /tmp/yum-cache/carboniface/python-carboniface-* /tmp/yum-cache/carboniface/python-schema-* && \
    rm -rf /tmp/yum-cache/carboniface
## TODO: Fix carboniface
ADD usr/lib/python2.7/site-packages/carboniface.py /usr/lib/python2.7/site-packages/carboniface.py

# Diamond
RUN yum clean all; yum install -y --nogpgcheck python-configobj lm_sensors python-pysensors python-diamond && \
    rm -rf /etc/diamond && mkdir -p /var/log/diamond
ADD etc/diamond /etc/diamond
ADD etc/diamond/handlers/GraphiteHandler.conf /etc/diamond/handlers/GraphiteHandler.conf
ADD opt/qnib/bin/start_diamond.sh /opt/qnib/bin/start_diamond.sh
ADD etc/supervisord.d/diamond.ini /etc/supervisord.d/diamond.ini
ADD etc/consul.d/check_diamond.json /etc/consul.d/check_diamond.json


ADD yum-cache/clustershell /tmp/yum-cache/clustershell
RUN yum install -y /tmp/yum-cache/clustershell/python-clustershell-* && \
    rm -rf /tmp/yum-cache/clustershell

# setup
#RUN yum install -y python-netifaces python-envoy
#ADD etc/qnib-setup.cfg /etc/
#ADD etc/supervisord.d/setup.ini /etc/supervisord.d/setup.ini

## confd
ADD usr/local/bin/confd /usr/local/bin/confd
RUN mkdir -p /etc/confd/{conf.d,templates} && \
    yum install -y python-qnibsetup

## logstash-forwarder certificates
ADD etc/pki/tls/ /etc/pki/tls/

RUN echo 'alias qsetup="PYTHONPATH=/data/usr/lib/python2.7/site-packages/ /data/usr/local/bin/qnib-setup.py"' >> /etc/bashrc
RUN echo "alias disable_setup='grep autostart /etc/supervisord.d/setup.ini||sed -i -e \"/command/a autostart=false\" /etc/supervisord.d/setup.ini'" >> /etc/bashrc
