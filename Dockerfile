FROM qnib/diamond:cos7

# Install basics
RUN yum install -y bind-utils vim nmap

##### USER
# Set (very simple) password for root
ADD root/ssh /root/.ssh
RUN echo "root:root"|chpasswd && \
    chmod 600 /root/.ssh/authorized_keys /root/.ssh/id_rsa && \
    chown -R root:root /root/

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
# Performance Co-Pilot
RUN yum install -y pcp

# dependencies needed by costum scripts (e.g. osquery)
RUN yum install -y gcc python-pip libyaml-devel python-devel && \
    pip install --upgrade pip && \
    pip install envoy neo4jrestclient pyyaml docopt python-consul jinja2 && \
    pip install psutil graphitesend
ADD opt/qnib/bin/watch_psutil.py /opt/qnib/bin/
ADD etc/supervisord.d/watchpsutil.ini /etc/supervisord.d/

