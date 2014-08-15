#!/bin/bash

CARBON_IP=${CARBON_PORT_2003_TCP_ADDR}
if [ "X${CARBON_IP}" == "X" ];then
   CARBON_IP=$(dig +short carbon)
   if [ "X${CARBON_IP}" == "X" ];then
       echo "ERROR: Carbon could not be resolved"
       exit 1
   fi
fi
sed -i -e "s/destination d_logmgmt =.*/destination d_logmgmt { tcp(\"${CARBON_IP}\" port(5514)); };/" /etc/syslog-ng/syslog-ng.conf

# start syslog
/usr/sbin/syslog-ng --foreground

