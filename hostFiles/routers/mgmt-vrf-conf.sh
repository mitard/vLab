#!/bin/bash
sed -i 's/ExecStart=\/usr/ExecStart=\/bin\/ip vrf exec mgmt-vrf \/usr/' /lib/systemd/system/ssh.service

res=`grep mgmt-vrf /etc/netplan/50-cloud-init.yaml`

if [ -z $res ]; then
  cat /usr/local/src/mgmt-vrf-interfaces.yaml >> /etc/netplan/50-cloud-init.yaml
fi
