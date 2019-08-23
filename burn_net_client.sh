#!/bin/bash

###################
# Global Variable #
###################
#BURN_NET_PROC_PATH="./burn_net_iperf.sh"
BURN_NET_PROC_PATH="/tmp/burn/burn_net_iperf.sh"

#################
# Get target ID #
#################
cmd_id=$(/nas/util/qenc_cli get cbid | grep cbid)
if [ ${cmd_id:5:1} = 1 ]; then
  cb_id=2
else
  cb_id=1
fi

##################
# Check log path #
##################
log_path=$(cat /tmp/log_path)
net_log=$log_path/lan
mkdir $net_log
if [ "$log_path" = "" ]; then
  echo "Without Log Path!!!"
  echo "## Ang add work around ##"
  #exit
fi
echo "test_id:$cb_id"
echo "log_path:$log_path"

function main {

  pkill iperf 

  ##########
  # Set IP #
  ##########
  echo "=====set ixl0 IP: 192.168.0.1====="
  ifconfig ixl0 192.168.0.1 255.255.255.0
  echo "=====set ixl1 IP: 192.168.1.1====="
  ifconfig ixl1 192.168.1.1 255.255.255.0
  echo "=====set ixl2 IP: 192.168.2.1====="
  ifconfig ixl2 192.168.2.1 255.255.255.0
  echo "=====set ixl3 IP: 192.168.3.1====="
  ifconfig ixl3 192.168.3.1 255.255.255.0

  echo "=====set igb1 IP: 192.168.4.1====="
  ifconfig igb1 192.168.4.1 255.255.255.0
  echo "=====set igb2 IP: 192.168.6.1====="
  ifconfig igb2 192.168.6.1 255.255.255.0

  (sleep 5)

  # Execute
  ${BURN_NET_PROC_PATH} ixl0 0 &
  ${BURN_NET_PROC_PATH} ixl1 1 &
  ${BURN_NET_PROC_PATH} ixl2 2 &
  ${BURN_NET_PROC_PATH} ixl3 3 &
  ${BURN_NET_PROC_PATH} igb1 4 &
  ${BURN_NET_PROC_PATH} igb2 6 &
  ${BURN_NET_PROC_PATH} ntb0 5 &
}

main
