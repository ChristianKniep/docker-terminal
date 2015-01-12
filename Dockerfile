###### QNIBTerminal images
# A docker image that includes
# - init (supervisord)
# - syslog (syslog-ng)
# - profiling (diamond)
FROM qnib/consul
MAINTAINER "Christian Kniep <christian@qnib.org>"

# Refresh yum
RUN echo "2014-08-24";yum clean all

# misc
RUN yum install -y bind-utils vim nmap

##### USER
# Set (very simple) password for root
RUN echo "root:root"|chpasswd
ADD root/ssh /root/.ssh
RUN chmod 600 /root/.ssh/authorized_keys /root/.ssh/id_rsa
RUN chown -R root:root /root/*

### SSHD
RUN yum install -y openssh-server
RUN mkdir -p /var/run/sshd
ADD root/bin/startup_sshd.sh /root/bin/startup_sshd.sh
RUN sed -i -e 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config
ADD etc/supervisord.d/sshd.ini /etc/supervisord.d/sshd.ini
ADD etc/consul.d/check_sshd.json /etc/consul.d/check_sshd.json


# We do not care about the known_hosts-file and all the security
####### Highly unsecure... !1!! ###########
RUN echo "        StrictHostKeyChecking no" >> /etc/ssh/ssh_config
RUN echo "        UserKnownHostsFile=/dev/null" >> /etc/ssh/ssh_config
RUN echo "        AddressFamily inet" >> /etc/ssh/ssh_config

# carboniface
RUN yum install -y python-docopt
ADD yum-cache/carboniface /tmp/yum-cache/carboniface
RUN yum install -y /tmp/yum-cache/carboniface/python-carboniface-*
RUN yum install -y /tmp/yum-cache/carboniface/python-schema-*
RUN rm -rf /tmp/yum-cache/carboniface
## TODO: Fix carboniface
ADD usr/lib/python2.7/site-packages/carboniface.py /usr/lib/python2.7/site-packages/carboniface.py

# syslog
RUN yum install -y syslog-ng
RUN getent passwd sshd || useradd -g sshd sshd
ADD etc/syslog-ng/syslog-ng.conf /etc/syslog-ng/syslog-ng.conf
ADD etc/supervisord.d/syslog-ng.ini /etc/supervisord.d/
#ADD root/bin/start_syslogng.sh /root/bin/start_syslogng.sh
ADD etc/consul.d/check_syslog-ng.json /etc/consul.d/check_syslog-ng.json

# Diamond
RUN yum clean all
RUN yum install -y --nogpgcheck python-configobj lm_sensors
RUN yum install -y --nogpgcheck python-pysensors python-diamond
RUN rm -rf /etc/diamond
ADD etc/diamond /etc/diamond
RUN mkdir -p /var/log/diamond
ADD etc/diamond/handlers/GraphiteHandler.conf /etc/diamond/handlers/GraphiteHandler.conf
ADD etc/supervisord.d/diamond.ini /etc/supervisord.d/diamond.ini
ADD etc/consul.d/check_diamond.json /etc/consul.d/check_diamond.json
ADD etc/diamond/collectors/NginxCollector.conf /etc/diamond/collectors/NginxCollector.conf


ADD yum-cache/clustershell /tmp/yum-cache/clustershell
RUN yum install -y /tmp/yum-cache/clustershell/python-clustershell-*
RUN rm -rf /tmp/yum-cache/clustershell

RUN yum install -y python-envoy

# setup
RUN yum install -y python-netifaces 
ADD etc/qnib-setup.cfg /etc/
ADD etc/supervisord.d/setup.ini /etc/supervisord.d/setup.ini

## confd
ADD usr/local/bin/confd /usr/local/bin/confd
RUN mkdir -p /etc/confd/{conf.d,templates}

RUN yum install -y python-qnibsetup

RUN echo 'alias qsetup="PYTHONPATH=/data/usr/lib/python2.7/site-packages/ /data/usr/local/bin/qnib-setup.py"' >> /etc/bashrc
RUN echo "alias disable_setup='grep autostart /etc/supervisord.d/setup.ini||sed -i -e \"/command/a autostart=false\" /etc/supervisord.d/setup.ini'" >> /etc/bashrc

CMD /bin/supervisord -c /etc/supervisord.conf
