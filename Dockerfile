###### QNIBTerminal images
FROM qnib/consul:fd22

# Refresh yum
ENV TERM=xterm \
    BOOTSTRAP_CONSUL=false \
    RUN_SERVER=false
RUN echo "2015-08-20"; dnf install -y bind-utils vim nmap

## install DIAMOND
RUN dnf install -y --nogpgcheck gcc python-devel  python-configobj lm_sensors python-pip && \
    pip install --upgrade pip && \
    pip install diamond pysensors && \
    rm -rf /etc/diamond && mkdir -p /var/log/diamond
ADD etc/diamond /etc/diamond
ADD etc/diamond/handlers/GraphiteHandler.conf /etc/diamond/handlers/GraphiteHandler.conf
ADD opt/qnib/bin/start_diamond.sh /opt/qnib/bin/start_diamond.sh
ADD etc/supervisord.d/diamond.ini /etc/supervisord.d/diamond.ini
ADD etc/consul.d/check_diamond.json /etc/consul.d/check_diamond.json

# dependencies needed by costum scripts (e.g. osquery)
RUN dnf install -y gcc python-pip libyaml-devel python-devel && \
    pip install --upgrade pip && \
    pip install envoy neo4jrestclient pyyaml docopt python-consul jinja2 && \
    pip install psutil graphitesend
ADD opt/qnib/bin/watch_psutil.py /opt/qnib/bin/
ADD etc/supervisord.d/watchpsutil.ini /etc/supervisord.d/

