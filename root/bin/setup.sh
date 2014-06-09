#!/bin/bash

ALIASES=$(cat /root/dns.aliases)

echo "### Fetch MASTER_IP"
MASTER_IP=$(cat /etc/resolv.conf |grep nameserver|head -n1|awk '{print $2}')
echo "MASTER_IP=${MASTER_IP}"
export no_proxy=${MASTER_IP}
echo "### Fetch MY_IP"
MY_IP4=$(ip -o -4 addr|grep eth0|awk '{print $4}'|awk -F/ '{print $1}')
MY_IP6=$(ip -o -6 addr|grep eth0|awk '{print $4}'|awk -F/ '{print $1}')

echo "MY_IP4=${MY_IP4} | MY_IP6=${MY_IP6}"
echo "### Send IP to etcd"
for HOST in $(hostname) ${ALIASES};do
    echo "# curl -s -XPUT http://${MASTER_IP}:4001/v2/keys/helix/${HOST}/A -d value=${MY_IP4}"
    curl -s -XPUT http://${MASTER_IP}:4001/v2/keys/helix/${HOST}/A -d value="${MY_IP4}"
    echo "# curl -s -XPUT http://${MASTER_IP}:4001/v2/keys/helix/${HOST}/AAAA -d value=${MY_IP6}"
    curl -s -XPUT http://${MASTER_IP}:4001/v2/keys/helix/${HOST}/AAAA -d value="${MY_IP6}"
done
echo "### Send PTR to etcd"
MY_PTR=$(echo ${MY_IP}|sed -e 's#\.#/#g')
echo "# curl -s -XPUT http://${MASTER_IP}:4001/v2/keys/helix/arpa/in-addr/${MY_PTR}/PTR -d value=$(hostname)."
curl -s -XPUT http://${MASTER_IP}:4001/v2/keys/helix/arpa/in-addr/${MY_PTR}/PTR -d value="$(hostname)."

if [[ $(hostname) == compute* ]];then
   curl -s -XPUT http://${MASTER_IP}:4001/v2/keys/slurm/conf/last_update -d value="$(date +%s)"
fi

sleep 2
exit 0
