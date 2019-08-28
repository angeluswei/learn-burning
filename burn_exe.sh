#!/bin/bash
########################
# FOR SIGNAL
########################
#name="trap.sh"
#log_path="/tmp/log/SIGNAL_histroy/"
#SIGNAL_list="SIGHUP SIGINT SIGQUIT SIGQUIT SIGILL SIGTRAP SIGABRT SIGABRT SIGFPE SIGKILL SIGBUS SIGSEGV SIGSYS SIGPIPE SIGALRM SIGTERM SIGURG SIGSTOP SIGTSTP SIGCONT SIGCHLD SIGTTIN SIGTTOU SIGIO SIGXCPU SIGXFSZ SIGVTALRM SIGPROF SIGWINCH SIGINFO"
#for x in ${SIGNAL_list}
#do
#  trap "echo TRAP : Got ${x}; echo ${name} > ${log_path}${x}.txt; date >> ${log_path}${x}.txt" ${x}
#done

########################
# Burn-in test item
########################
enable_test_ntb=1
enable_test_stress=0
enable_test_hdd=1
enable_test_smb=1
enable_test_net=1
enable_test_usage=0
enable_test_bbu=1
version="20190812"

########################
# Function
########################
function save_pcie_link_speed {
  ## Get NTB Link Speed
  local ntb_pcie_info=$(sysctl -n dev.ntb_hw.0.link_status)

  ## Save log
  echo "${ntb_pcie_info}" > /tmp/ntb_pcie_info.txt
}

function save_ntb_pcie_error_count {
  echo "## THERE NO NTB PCIE EEROR COUNT ##"
  ntb_err_count=$(sysctl hw.ntb.if | grep bad)
  echo "${ntb_err_count}" > /tmp/start_ntb_pcie_errorcount.txt
}

function burnin_act {
  local cmd_id=$(/nas/util/qenc_cli get cbid | grep cbid)
  local log_path=$(cat /tmp/log_path)

  echo "Scan Disk"
  (/nas/util/qses scan_jbod)

  echo "========================="
  echo "=====burnin start...====="
  echo "========================="

  echo "${version}" > ${log_path}/version
#start net
  if [ ${cmd_id:5:1} = 1 ]; then
    if [ $enable_test_net = 1 ]; then
      (/tmp/burn/burn_net_client.sh &)
    fi
  fi          
#start hd
  if [ $enable_test_hdd = 1 ]; then
    (/tmp/burn/burn_hd.sh &)
  fi
#start ntb
  if [ $enable_test_ntb = 1 ]; then
    (/tmp/burn/burn_ntb.sh &)
  fi
#start smb
  if [ $enable_test_smb = 1 ]; then
    (/tmp/burn/burn_smb.sh &)  
  fi
#start bbu
  if [ $enable_test_bbu = 1 ]; then
  (echo "done" > /tmp/bbu_start)
    (/tmp/burn/burn_bbu.sh &)
  fi
#start usg
  if [ $enable_test_usage = 1 ]; then
    (/tmp/burn/burn_usg.sh &)
  fi
  return
}

function set_ntb {
  # Get NTB start address
  ntb_offset=$(sysctl -n hw.ntb.local.nvdimm_offset)
  # Get NTB Size
  ntb_size=$(sysctl -n hw.ntb.local.nvdimm_size)
  let "ntb_size_half = ntb_size >> 1"
  # Get NTB Mirror address
  ntb_mirror_add=$(sysctl -n hw.ntb.local.nvdimm_peer_remap_offset)

  #transform to HEX
  ntb_offset_hex=$(echo "obase=16; ${ntb_offset}" | bc)
  ntb_size_half_hex=$(echo "obase=16; ${ntb_size_half}" | bc)
  ntb_mirror_add_hex=$(echo "obase=16; ${ntb_mirror_add}" | bc)

  #set ramdisk0 partition
  echo "NTB offset: ${ntb_offset_hex}, size: ${ntb_size_half_hex}, mirror_add:${ntb_mirror_add_hex}"
  echo "/nas/util/srdadm -a ${ntb_offset_hex} -s ${ntb_size_half_hex} -m ${ntb_mirror_add_hex}"
  /nas/util/srdadm -a ${ntb_offset_hex} -s ${ntb_size_half_hex} -m ${ntb_mirror_add_hex}

  #set ramdisk1 partition
  let "ntb_offset = ntb_offset + ntb_size_half"
  let "ntb_mirror_add = ntb_mirror_add + ntb_size_half"
  ntb_offset_hex=$(echo "obase=16; ${ntb_offset}" | bc)
  ntb_mirror_add_hex=$(echo "obase=16; ${ntb_mirror_add}" | bc)
  echo "/nas/util/srdadm -a ${ntb_offset_hex} -s ${ntb_size_half_hex} -m ${ntb_mirror_add_hex}"
  /nas/util/srdadm -a ${ntb_offset_hex} -s ${ntb_size_half_hex} -m ${ntb_mirror_add_hex}

  return
}


function run_qenc_mgt {
  local cb_id=$1
  (pkill qenc_mgt)
  (rm /var/run/qenc_mgt.pid)

  ## avoid mgmt error message
  (echo "## Set localtime ##")
  (echo "UTF-8" > /etc/localtime)

  (echo "=====startup qenc_mgt=====")
  if [ $cb_id = 1 ]; then
    ( /usr/local/sbin/qenc_mgt 192.168.5.2)
  else
    ( /usr/local/sbin/qenc_mgt 192.168.5.1)
  fi

  echo "=====wait for 60 secs====="
  sleep 60
  (echo "=====check mgt daemon alive=====")
  (ps ax | grep mgt)

  /nas/util/qenc_cli set signal mode 1

  return
}

function set_fp {
  local cmd_id=$(/nas/util/qenc_cli get cbid | grep cbid)
  local cb_id=${cmd_id:5:1}
  
  if [ "$cb_id" = "2" ]; then
    (/nas/util/qenc_cli set fp num 10)
  fi
}

function check_peer_connection {

  local net_name=$1
  local net_num=$2
  local cbid=$3
  local peer_cbid=0

  if [ "${cbid}" = 1 ]; then
      peer_cbid=2
  else
      peer_cbid=1
  fi

  while true
  do
    echo "=====Check net connection====="
    echo "=====ping ${net_name} IP: 192.168.${net_num}.${peer_cbid}====="
    ping_result=$(ping -c 2 192.168.${net_num}.${peer_cbid} | grep transmitted | awk '{print $7}')

    if [ "${ping_result}" = "0.0%" ]; then
      echo "=====peer is connected====="
      FAIL_COUNT=0
      return
    else
      echo "=====peer is NOT ready====="
      let "FAIL_COUNT=FAIL_COUNT+1"
    fi

    sleep 5
  done
}

function main {
  local cmd_id=$(/nas/util/qenc_cli get cbid | grep cbid)
  local cb_id=${cmd_id:5:1}
  local_ready=$(cat /tmp/burn_init)
  if [ "$local_ready" = "done" ]; then
    (echo "=====local_ready=====")
  else
    (echo "=====local not ready, execute burn_init=====")
    (/tmp/burn/burn_init.sh)
  fi

  check_peer_connection "ntb0" "5" ${cb_id}

  (echo "=====peer ntb ready=====")
  (echo "=====set ntb parameter=====")
  (set_ntb)

  (echo "=====save ntb pcie error count=====")
  (save_ntb_pcie_error_count)
  (echo "=====save PCIE up and down stream speed=====")
  (save_pcie_link_speed)

  (/nas/util/qenc_cli set signal mode 1)

  (run_qenc_mgt ${cb_id})

  (echo "=====set fp=====")
  (set_fp)
  
  (echo "=====close hardware watchdog timer=====")
  (/nas/util/qenc_cli set wdt mode 0)    
  
  (echo "====================")
  (echo "=====Peer ready=====")
  (echo "====================")
  burnin_act  
  return
}
#////////Start/////////
(sysctl kern.geom.debugflags=0x10)
date > /tmp/start_time.txt
main
