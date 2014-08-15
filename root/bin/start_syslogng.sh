#!/bin/bash

ELK_IP=${ELK_PORT_5514_TCP_ADDR}
if [ "X${ELK_IP}" == "X" ];then
   ELK_IP=$(dig +short elk)
   if [ "X${ELK_IP}" == "X" ];then
       echo "ELK could not be resolved, using localhost"
       ELK_IP="127.0.0.1"
   fi
fi
sed -i -e "s/destination d_logmgmt .*/destination d_logmgmt { tcp(\"${ELK_IP}\" port(5514)); };/" /etc/syslog-ng/syslog-ng.conf

# start syslog
/usr/sbin/syslog-ng --foreground

