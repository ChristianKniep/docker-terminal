###### QNIBTerminal images
FROM qnib/consul

# Refresh yum
ENV TERM=xterm
RUN yum install -y bind-utils vim nmap

## Diamond
RUN yum install -y --nogpgcheck python-configobj lm_sensors python-pysensors python-diamond && \
    rm -rf /etc/diamond && mkdir -p /var/log/diamond
ADD etc/diamond /etc/diamond
ADD etc/diamond/handlers/GraphiteHandler.conf /etc/diamond/handlers/GraphiteHandler.conf
ADD opt/qnib/bin/start_diamond.sh /opt/qnib/bin/start_diamond.sh
ADD etc/supervisord.d/diamond.ini /etc/supervisord.d/diamond.ini
ADD etc/consul.d/check_diamond.json /etc/consul.d/check_diamond.json
#

# dependencies needed by costum scripts (e.g. osquery)
RUN yum install -y gcc python-pip libyaml-devel python-devel && \
    pip install --upgrade pip && \
    pip install envoy neo4jrestclient pyyaml docopt python-consul jinja2 && \
    pip install psutil graphitesend
#ADD opt/qnib/bin/watch_psutil.py /opt/qnib/bin/
#ADD etc/supervisord.d/watchpsutil.ini /etc/supervisord.d/
# osqueryi
#ADD usr/local/bin/osqueryi /usr/local/bin/osqueryi
#ADD usr/local/bin/osqueryd /usr/local/bin/osqueryd
#RUN yum install -y http://ftp.wrz.de/pub/fedora-epel/7/x86_64/e/epel-release-7-5.noarch.rpm 
#RUN yum install -y https://osquery-packages.s3.amazonaws.com/centos7/osquery.rpm 
#RUN yum install -y osquery

