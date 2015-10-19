#!/bin/bash

if [ "X${COLLECT_METRICS}" != "Xtrue" ];then
    echo "Do not start metrics collector (COLLECT_METRICS != true)"
    rm -f /etc/consul.d/check_diamond.json
    sleep 1
    consul reload
    exit 0
fi

PIDFILE=/var/run/diamond.pid

## Wait for consul to start
sleep 10
## Check if eth0 already exists
ADDR=eth0
ip addr show ${ADDR} > /dev/null
EC=$?
if [ ${EC} -eq 1 ];then
    echo "## Wait for pipework to attach device 'eth0'"
    pipework --wait
fi

HANDLER=${DIAMOND_HANDLER}
# if consul in env, join
INFLX_HOST=$(dig @localhost -p 8600 +time=5 +tries=1 influxdb.service.dc1.consul ANY +short)
if [ "X${INFLX_HOST}" != "X" ];then
    HANDLER="${HANDLER} diamond.handler.influxdbHandler.InfluxdbHandler"
fi
CARBON_HOST=$(dig @localhost -p 8600 +time=5 +tries=1 carbon.service.dc1.consul ANY +short)
if [ "X${CARBON_HOST}" != "X" ];then
    HANDLER="${HANDLER} diamond.handler.graphite.GraphiteHandler"
fi
if [ "X${HANDLER}" == "X" ];then
    echo "Do not start metrics collector (no HANDLER found)"
    exit 0
fi
# Change handler
HANDLER="${HANDLER}/"
sed -i -e "s/handlers =.*/handlers = $(echo ${HANDLER}|sed -e 's/^ //'|sed -e 's/ /,/g')" /etc/diamond/diamond.conf

diamond -f -l
