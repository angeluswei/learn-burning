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

MANAGEMENT_ETHER_NAME="igb0"
NTB_ETHER_NAME="ntb0"

########################
# Burn-init parameter
########################
cnt=0
end_value=10

########################
# Function
########################
function init_qses {

  ## pkill qses daemon
  echo "Kill qses daemon"
  pkill qses
  pkill hwtst_mgt

  ## start qses daemon
  echo "Restart qses daemon"
  /nas/util/qses daemon -t 60

  ## sleep
  sleep 5

}

function init_SIGNAL_folder {
  mkdir /tmp/log/SIGNAL_histroy
}

function init_create_random_data {
  echo "## Creating random data... ##"
  dd if=/dev/random of=/tmp/log/random.bin bs=8M count=1024
  echo "## Creating random data finished ##"
}

function init_usbdom {
  root_device=$(/sbin/glabel status | grep BOOT | awk '{print $3}' | sed "s/p1//")
  if [ "$root_device" = "" ]; then
        root_device=$(/sbin/glabel status | grep rootfs1 | awk '{print $3}' | sed "s/p1//")
  fi
  echo "USB DOM:${root_device}"
  (/sbin/gpart recover ${root_device})
  return
}

function init_ntb {

  local cbid=$1
  (echo "=====load ntb_intel.ko=====")
  (kldload /boot/kernel/ntb_intel.ko)
  (echo "=====load ntb_intel_hw.ko=====")
  (kldload /boot/kernel/ntb_intel_hw.ko)
  (echo "=====load ntb_intel_transport.ko=====")
  (kldload /boot/kernel/ntb_intel_transport.ko)
  (echo "=====load if_ntb_intel.ko=====")
  (kldload /boot/kernel/if_ntb_intel.ko)
  (echo "=====load ramdisk.ko=====")
  (kldload /boot/kernel/ramdisk.ko)

  (echo "=====local ntb driver ready=====")

  (echo "=====set ${NTB_ETHER_NAME}=====")
  (echo "=====ifconfig ${NTB_ETHER_NAME} 192.168.5.${cb_id}/24=====")
  (ifconfig ${NTB_ETHER_NAME} 192.168.5.${cb_id}/24)

  return
}

############################################
# Make log folder, ex: /tmp/log/Q16I000001 #
############################################
function ada_act {
  local opt=$1
  echo "Execute:$opt"
  if [ $opt = "ada0_init" ]; then
    (umount -f /tmp/log)
    (rm -rf /tmp/log)
    (dd if=/dev/zero of=/dev/ada0 bs=1m count=1)
    (newfs -i 4096 ada0)
    (mkdir /tmp/log)
    (mount /dev/ada0 /tmp/log)
  elif [ $opt = "ada0_mount" ]; then
    (mount /dev/ada0 /tmp/log)
  else
    (umount -f /tmp/log)
  fi
  
  #create log folder
  /nas/util/qenc_vpd
  bp_vpd=$(sysctl qess.hw.hal.enc.0.vpd.0.serial_sn | awk '{print $2}')
  cbid=$(/nas/util/qenc_cli get cbid | grep cbid)
  em_mac=$(ifconfig ${MANAGEMENT_ETHER_NAME} |grep ether)
  log_folder="/tmp/log/${bp_vpd}-${cbid:5:1}${em_mac:16:2}${em_mac:19:2}${em_mac:22:2}"
  echo "${log_folder}" > /tmp/log_path
  (mkdir ${log_folder})
  (cp -r /var/log/message* ${log_folder})  
  
  return
}

function main {
  (pkill bash)
  (pkill hwtst_mgt)
  (pkill dhclient)
  (rm /tmp/burn_init)
  (rm -r /tmp/burn/exp_fw)
  (/nas/util/qenc_cli set signal mode 1)
  (init_qses)
  local cmd_id=$(/nas/util/qenc_cli get cbid | grep cbid)
  local cb_id=${cmd_id:5:1}
  (init_usbdom)
  (init_ntb ${cb_id})
  (ada_act "ada0_init")
  (init_SIGNAL_folder)
  #(init_create_random_data)
  sleep 2
  (echo "## Saving initial flag ##")
  (echo "done" > /tmp/burn_init)

  echo "=====startup iperf====="
  if [ "$cb_id" = "1" ]; then
    echo "In ScbA, don't execute iperf server"
  elif [ "$cb_id" = "2" ]; then
    (/tmp/burn/burn_net_server.sh &)
  fi

  logpath=$(cat /tmp/log_path)
  echo "LogPath:${logpath}"
  echo "=====init finished====="
  return
}
#start up
main
