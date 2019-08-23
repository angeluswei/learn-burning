#!/bin/bash
########################
# FOR SIGNAL
########################
#name="trap.sh"
#log_path="/tmp/log/SIGNAL_histroy/"
#SIGNAL_list="SIGHUP SIGINT SIGQUIT SIGQUIT SIGILL SIGTRAP SIGABRT SIGABRT SIGFPE SIGKILL SIGBUS SIGSEGV SIGSYS SIGPIPE SIGALRM SIGTERM SIGURG SIGSTOP SIGTSTP SIGCONT SIGCHLD SIGTTIN SIGTTOU SIGIO SIGXCPU SIGXFSZ SIGVTALRM SIGPROF SIGWINCH SIGINFO"
#or x in ${SIGNAL_list}
#do
#  trap "echo TRAP : Got ${x}; echo ${name} > ${log_path}${x}.txt; date >> ${log_path}${x}.txt" ${x}
#done

########################
# Burn_ntb parameter
########################
run=1
ntb_mem1="/dev/ramdisk0"
ntb_mem2="/dev/ramdisk1"
test_act="0_ready 1_write 2_wdone 3_copy 4_cdone 5_verify"
cur_status="init"

NTB_TEST_TIMES=300
NTB_MIRROR_DONE_FLAG=0

########################
# Function
########################
function make_pattern {
  for pattern in $test_act
  do
    echo "## Make ntb pattern, pattern_${pattern} ##"
    (dd if=/dev/zero bs=4k count=1 conv=sync | tr '\0' "${pattern}" > /tmp/pattern_${pattern})
  done
  return
}
function get_status {
  local t_dev=$1
  echo "cur:${cur_status}"

  echo "## Get ntb status from ramdisk ##"
  (dd if=/dev/${t_dev} of=/tmp/opt_${t_dev} bs=4k count=1 conv=sync)
  
  for pattern in $test_act
  do
    ret=$(diff /tmp/opt_${t_dev} /tmp/pattern_${pattern})
#    echo $ret
#    sleep 10
    if [ "$ret" = "" ]; then
      cur_status=$pattern
      return
    fi
  done
  cur_status="init"

  return
}
function do_server {
  local log_path=$1
  get_status ${ntb_mem1:5}
  echo "cur:${cur_status}"

  case "${cur_status}" in
  '0_ready')
    echo "## do_write ##"
    (dd if=/tmp/pattern_1_write of=${ntb_mem1} bs=4k conv=sync) 
    (dd if=/dev/random of=${ntb_mem1} bs=4k seek=1 conv=sync)
    (dd if=/tmp/pattern_2_wdone of=${ntb_mem1} bs=4k conv=sync)
    echo "## do_write_done ##"
sleep 10
    ;;
  '1_write')
    echo "## 1_write? ##"
sleep 10
    ;;
  '2_wdone')
    echo "## waite...3_copy ##"
sleep 10
    ;;
  '3_copy')
    echo "## waite...3_copy ##"
sleep 10
    ;;
  '4_cdone')
    echo "## do_verify ##"
    (echo "run:${run}" >> $log_path/ntb_log)
    (date >> $log_path/ntb_log)  
#    (diff $ntb_mem1 $ntb_mem2 >> $log_path/ntb_log)
    (dd if=${ntb_mem1} of=${log_path}/dif1 bs=65536k count=64)
    (dd if=${ntb_mem2} of=${log_path}/dif2 bs=65536k count=64)
    (diff ${log_path}/dif1 ${log_path}/dif2 >> $log_path/ntb_log)
    (rm ${log_path}/dif1)
    (rm ${log_path}/dif2)
    (dd if=/tmp/pattern_0_ready of=${ntb_mem1} bs=4k conv=sync)
    echo "## do_verify_done ##"
    let "run += 1"
    if [ "${run}" -gt "${NTB_TEST_TIMES}" ]; then
        NTB_MIRROR_DONE_FLAG=1
    fi
sleep 10
    ;;
  '5_verify')
    echo "## 5_verify? ##"
sleep 10
    ;;
  esac      
   
  return
}
function do_client {
  get_status ${ntb_mem1:5}
  echo "cur:${cur_status}"

  case "${cur_status}" in
  '0_ready')
    echo "dd patern to ramdisk"
    (dd if=/tmp/pattern_0_ready of=${ntb_mem2} bs=4k conv=sync)
sleep 10
    ;;
  '1_write')
    echo "## wait...1_write ##"
sleep 10
    ;;
  '2_wdone')
    echo "## do_copy ##"
    (dd if=/tmp/pattern_3_copy of=${ntb_mem2} bs=4k conv=sync)
    (dd if=${ntb_mem1} of=${ntb_mem2} bs=65536k conv=sync)
    (dd if=/tmp/pattern_4_cdone of=${ntb_mem2} bs=4k conv=sync)
    (dd if=/tmp/pattern_4_cdone of=${ntb_mem1} bs=4k conv=sync)
    echo "## do_copy_down ##"
sleep 120
    ;;
  '3_copy')
    echo "## 3_copy? ##"
sleep 10
    ;;
  '4_cdone')
    echo "## wait...5_verify ##"
sleep 10
    ;;
  '5_verify')
    echo "## wait...5_verify ##"
sleep 10
    ;;
  esac   
  
  return
}
function main {
#Check log path
  local log_path=$(cat /tmp/log_path)
  local cmd_id=$(/nas/util/qenc_cli get cbid | grep cbid)
  local cb_id=${cmd_id:5:1}
  if [ "$log_path" = "" ]; then
    echo "Without Log Path!!!"
    exit
  fi
  echo "log_path:$log_path"
  
  local cnt=0
  local run=0

  echo "0" > /tmp/NTB_iperf_start.flag

  make_pattern

  if [ $cb_id = 1 ]; then
    (dd if=/dev/zero of=${ntb_mem1} bs=65536k conv=sync) 
    (dd if=/tmp/pattern_0_ready of=${ntb_mem1} bs=4k conv=sync)
  else
    (dd if=/dev/zero of=${ntb_mem2} bs=65536k conv=sync) 
    (dd if=/tmp/pattern_0_ready of=${ntb_mem2} bs=4k conv=sync)
  fi

  while true
  do
    if [ $cb_id = 1 ]; then
      do_server "$log_path"
    else
      do_client "$log_path"
    fi

    if [ "${NTB_MIRROR_DONE_FLAG}" = 1 ]; then
      echo "1" > /tmp/NTB_iperf_start.flag
      return
    fi
  sleep 10       
  done
}
#start up
main
