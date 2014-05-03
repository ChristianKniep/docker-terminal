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

# Diamond
RUN yum install -y python-configobj lm_sensors
ADD yum-cache/diamond /tmp/yum-cache/diamond
RUN yum install -y /tmp/yum-cache/diamond/python-pysensors-*
RUN yum install -y /tmp/yum-cache/diamond/python-diamond-*
RUN rm -rf /tmp/yum-cache/diamond
RUN rm -rf /etc/diamond
ADD etc/diamond /etc/diamond
RUN mkdir -p /var/log/diamond
ADD etc/supervisord.d/diamond.ini /etc/supervisord.d/diamond.ini

# carboniface
RUN yum install -y python-docopt
ADD yum-cache/carboniface /tmp/yum-cache/carboniface
RUN yum install -y /tmp/yum-cache/carboniface/python-carboniface-*
RUN rm -rf /tmp/yum-cache/carboniface

## confd
ADD usr/local/bin/confd /usr/local/bin/confd
RUN mkdir -p /etc/confd/{conf.d,templates}

# etcdctl
ADD usr/bin/etcdctl /usr/bin/etcdctl

CMD /bin/bash
