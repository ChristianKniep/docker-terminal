###### QNIBTerminal images
# A docker image that includes
# - init (supervisord)
# - syslog (syslog-ng)
# - profiling (diamond)
FROM qnib/fd20
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

## supervisord
ADD yum-cache/supervisor /tmp/yum-cache/supervisor
RUN yum install -y python-meld3 python-setuptools
### Old version w/o syslog
#RUN yum install -y supervisor 
### Workaround
RUN yum install -y /tmp/yum-cache/supervisor/supervisor-3.0*
RUN echo "3.0" > /usr/lib/python2.7/site-packages/supervisor/version.txt
ADD etc/supervisord.conf /etc/supervisord.conf
### \WORKAROUND
RUN rm -rf /tmp/yum-cache/supervisor
RUN mkdir -p /var/log/supervisor
RUN sed -i -e 's/nodaemon=false/nodaemon=true/' /etc/supervisord.conf
ADD root/bin/supervisor_daemonize.sh /root/bin/supervisor_daemonize.sh


CMD /bin/bash
