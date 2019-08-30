#!/bin/bash

IPERF_PATH="/tmp/burn/iperf3"

function main {

  pkill iperf

  ##########
  # Set IP #
  ##########
  echo "=====set ixl0 IP: 192.168.0.2====="
  ifconfig ixl0 192.168.0.2 255.255.255.0
  echo "=====set ixl1 IP: 192.168.1.2====="
  ifconfig ixl1 192.168.1.2 255.255.255.0
  echo "=====set ixl2 IP: 192.168.2.2====="
  ifconfig ixl2 192.168.2.2 255.255.255.0
  echo "=====set ixl3 IP: 192.168.3.2====="
  ifconfig ixl3 192.168.3.2 255.255.255.0

  echo "=====set igb1 IP: 192.168.4.2====="
  ifconfig igb1 192.168.4.2 255.255.255.0
  echo "=====set igb2 IP: 192.168.6.2====="
  ifconfig igb2 192.168.6.2 255.255.255.0

  (sleep 5)

  ######################
  # Start Iperf server #
  ######################
  echo "=====Start iperf server====="
  ${IPERF_PATH} -s -i 60 -B 192.168.0.2 &
  ${IPERF_PATH} -s -i 60 -B 192.168.1.2 &
  ${IPERF_PATH} -s -i 60 -B 192.168.2.2 &
  ${IPERF_PATH} -s -i 60 -B 192.168.3.2 &
  ${IPERF_PATH} -s -i 60 -B 192.168.4.2 &
  ${IPERF_PATH} -s -i 60 -B 192.168.5.2 &
  ${IPERF_PATH} -s -i 60 -B 192.168.6.2 &
  (sleep 5)

}

main
