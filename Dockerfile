###### QNIBTerminal images
FROM qnib/diamond:fd22

# Refresh yum
ENV TERM=xterm \
    BOOTSTRAP_CONSUL=false \
    RUN_SERVER=false
RUN echo "2015-08-20"; dnf install -y nmap

# dependencies needed by costum scripts (e.g. osquery)
RUN dnf install -y libyaml-devel && \
    pip install envoy neo4jrestclient pyyaml docopt python-consul jinja2 && \
    pip install psutil graphitesend
ADD opt/qnib/bin/watch_psutil.py /opt/qnib/bin/
ADD etc/supervisord.d/watchpsutil.ini /etc/supervisord.d/

