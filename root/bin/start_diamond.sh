#!/bin/bash

CARBON_IP=${CARBON_PORT_2003_TCP_ADDR}
if [ "X${CARBON_IP}" == "X" ];then
   CARBON_IP=$(dig +short carbon)
   if [ "X${CARBON_IP}" == "X" ];then
       echo "ERROR: Carbon could not be resolved"
       exit 1
   fi
fi
sed -i -e "s/host =.*/host = ${CARBON_IP}/" /etc/diamond/handlers/GraphiteHandler.conf 

# start diamond
/bin/diamond -f

