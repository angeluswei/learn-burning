#!/bin/bash

###################
# Global Variable #
###################
RUN=1
FAIL_COUNT=0
MAX_FAIL_COUNT=10
#IPERF_PATH="./iperf"
IPERF_PATH="/tmp/burn/iperf"
IPERF_TIME=21600 #1day=86400s
IPERF_INTERVAL=3600
#IPERF_TIME=3600 #1day=86400s
#IPERF_INTERVAL=180

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

function check_iperf_connection {

  local net_name=$1
  local net_num=$2

  while true
  do
    echo "=====IPERF ${net_name} IP: 192.168.${net_num}.${cb_id}====="
    ${IPERF_PATH} -c 192.168.${net_num}.$cb_id -w 320K -i 1 -t 2 >> /tmp/iperf_${net_num}.log
    iperf_result=$(cat /tmp/iperf_${net_num}.log)

    if [ "${iperf_result}" != "" ]; then
      echo "=====peer iperf server is connected====="
      FAIL_COUNT=0
      return
    else
      echo "=====${net_name} is disconnected, Save log====="
      let "FAIL_COUNT=FAIL_COUNT+1"
      if [ "${FAIL_COUNT}" -ge "${MAX_FAIL_COUNT}" ]; then
        (echo "NET:$ {net_name} Iperf server is not ready..." >> /tmp/log/burn_crit_log.txt)
      fi
    fi

    sleep 5
  done
}

function check_connection {

  local net_name=$1
  local net_num=$2

  echo "=====Check ${net_name} Status====="

  while true
  do
    interface_status=$(ifconfig ${net_name} | grep status )

    check_interface_status=$(echo "${interface_status}" | grep "no carrier")

    if [ "${check_interface_status}" = "" ]; then
      echo "=====Interface ${net_name} is active====="
      return
    else
      echo "=====Interface ${net_name} is no carrier====="
    fi

    sleep 5
  done
}

function check_ping_connection {

  local net_name=$1
  local net_num=$2
  PING_FAIL_COUNT=0

  while true
  do
    echo "=====Check ${net_name} connection====="
    echo "=====ping ${net_name} IP: 192.168.${net_num}.${cb_id}====="
    ping_result=$(ping -c 2 192.168.${net_num}.$cb_id | grep transmitted | awk '{print $7}')

    if [ "${ping_result}" = "0.0%" ]; then
      echo "=====net is connected====="
      PING_FAIL_COUNT=0
      return
    else
      echo "=====${net_name} is disconnected, Save log====="
      if [ "${PING_FAIL_COUNT}" = 0 ]; then
        ## Only Save one times
        (date >> /tmp/log/burn_crit_log.txt)
        (echo "NET: ${net_name} IP fail..." >> /tmp/log/burn_crit_log.txt)
        let "PING_FAIL_COUNT=PING_FAIL_COUNT+1"
      fi
    fi

    sleep 5
  done
}

function check_NTB_flag {
  local ntb_start=""
  ntb_start=$(cat /tmp/NTB_iperf_start.flag)

  while true
  do
      if [ "${ntb_start}" = "1" ]; then
          echo "NTB iperf start"
          return
      fi

      sleep 300
      ntb_start=$(cat /tmp/NTB_iperf_start.flag)
  done
}

function main {

  local net_name=$1
  local net_num=$2
  local check_ntb=""

  check_ntb=$(echo "${net_name}" | grep ntb)

  if [ "${check_ntb}" != "" ]; then
    ## this is NTB device
    check_NTB_flag    
  fi

  echo "net_name:${net_name}, net_num:${net_num}"
  #############################
  # Check server is connected #
  #############################
  (check_connection ${net_name} ${net_num})

  (check_ping_connection ${net_name} ${net_num})

  ###############
  # Start iperf #
  ###############
  while true
  do
    (echo "=====Burn ${net_name}=====")
    (date >> $net_log/${net_name}_$RUN.log)
    (${IPERF_PATH} -c 192.168.${net_num}.$cb_id -w 320K -i ${IPERF_INTERVAL} -t ${IPERF_TIME} -f m -P 3 >> $net_log/${net_name}_${RUN}.log )
    echo "DONE" >> $net_log/${net_name}_${RUN}.log
    (sleep 1)
    let "RUN=RUN+1"

    (check_connection ${net_name} ${net_num})
  done
}

main $1 $2
