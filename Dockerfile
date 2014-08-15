###### QNIBTerminal images
# A docker image that includes
# - init (supervisord)
# - syslog (syslog-ng)
# - profiling (diamond)
FROM qnib/supervisor
MAINTAINER "Christian Kniep <christian@qnib.org>"

# setup
ADD root/bin/setup.sh /root/bin/
ONBUILD ADD root/dns.aliases root/dns.aliases
ADD etc/supervisord.d/setup.ini /etc/supervisord.d/setup.ini

# syslog
RUN yum install -y syslog-ng
ADD etc/syslog-ng/syslog-ng.conf /etc/syslog-ng/syslog-ng.conf
ADD etc/supervisord.d/syslog-ng.ini /etc/supervisord.d/
ADD root/bin/start_syslogng.sh /root/bin/start_syslogng.sh

# Diamond
RUN yum install -y --nogpgcheck python-configobj lm_sensors
ADD yum-cache/diamond /tmp/yum-cache/diamond
RUN yum install -y /tmp/yum-cache/diamond/python-pysensors-*
RUN yum install -y /tmp/yum-cache/diamond/python-diamond-*
RUN rm -rf /tmp/yum-cache/diamond
RUN rm -rf /etc/diamond
ADD etc/diamond /etc/diamond
RUN mkdir -p /var/log/diamond
ADD etc/supervisord.d/diamond.ini /etc/supervisord.d/diamond.ini
ADD root/bin/start_diamond.sh /root/bin/

# carboniface
RUN yum install -y python-docopt
ADD yum-cache/carboniface /tmp/yum-cache/carboniface
RUN yum install -y /tmp/yum-cache/carboniface/python-carboniface-*
RUN yum install -y /tmp/yum-cache/carboniface/python-schema-*

RUN rm -rf /tmp/yum-cache/carboniface

## confd
ADD usr/local/bin/confd /usr/local/bin/confd
RUN mkdir -p /etc/confd/{conf.d,templates}

# etcdctl
ADD usr/bin/etcdctl /usr/bin/etcdctl

# python-etcd
# python-etcd
ADD yum-cache/pyetcd/ /tmp/yum-cache/pyetcd/
RUN yum install -y /tmp/yum-cache/pyetcd/python-cryptography-0.2.2-1.x86_64.rpm
RUN yum install -y /tmp/yum-cache/pyetcd/python-pyopenssl-0.13.1-1.x86_64.rpm
RUN yum install -y python-urllib3-1.7-4.fc20.noarch
RUN yum install -y python-requests
RUN yum install -y /tmp/yum-cache/pyetcd/python-etcd-0.3.0-1.noarch.rpm
RUN rm -rf /tmp/yum-cache/pyetcd

ADD yum-cache/clustershell /tmp/yum-cache/clustershell
RUN yum install -y /tmp/yum-cache/clustershell/python-clustershell-1.6-1.noarch.rpm
RUN rm -rf /tmp/yum-cache/clustershell

ADD yum-cache/envoy /tmp/yum-cache/envoy
RUN yum install -y /tmp/yum-cache/envoy/python-envoy-0.0.2-1.noarch.rpm
RUN rm -rf /tmp/yum-cache/envoy

##### USER
# Set (very simple) password for root
RUN echo "root:root"|chpasswd
ADD root/ssh /root/.ssh
RUN chmod 600 /root/.ssh/authorized_keys
RUN chown -R root:root /root/*

### SSHD
RUN yum install -y openssh-server
RUN mkdir -p /var/run/sshd
RUN useradd -g sshd sshd
ADD root/bin/startup_sshd.sh /root/bin/startup_sshd.sh
RUN sed -i -e 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config
ADD etc/supervisord.d/sshd.ini /etc/supervisord.d/sshd.ini

# We do not care about the known_hosts-file and all the security
####### Highly unsecure... !1!! ###########
RUN echo "        StrictHostKeyChecking no" >> /etc/ssh/ssh_config
RUN echo "        UserKnownHostsFile=/dev/null" >> /etc/ssh/ssh_config
RUN echo "        AddressFamily inet" >> /etc/ssh/ssh_config

## TODO: Fix carboniface
ADD usr/lib/python2.7/site-packages/carboniface.py /usr/lib/python2.7/site-packages/carboniface.py

CMD /bin/bash
