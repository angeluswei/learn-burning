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
# burn_usg parameter
########################
run=0
test_time=300
test_run=3

########################
# Function
########################
function wait_vpd {
  while true
  do
    vpd_finish=$(cat /tmp/bbu_start)
    if [ "$vpd_finish" = "done" ]; then
      return
    fi
    sleep 60
  done
}      
function main {
#Check log path
  local log_path=$(cat /tmp/log_path)
  local cmd_id=$(/nas/util/qenc_cli get cbid | grep cbid)
  local cb_id=${cmd_id:5:1}
  local bbu_status=0
  if [ "$log_path" = "" ]; then
    echo "Without Log Path!!!"
    exit
  fi
  echo "log_path:$log_path"

  wait_vpd

  while true
  do
    echo "BBU:${bbu_status}"
    if [ $bbu_status = 0 ]; then   
      if [ "$(/nas/util/qenc_cli get bbu cb ${cb_id} | grep OK)" = "bbu_status:OK" ]; then
        bbu_status=1 
      fi
    elif [ $bbu_status = 1 ]; then 
      (/nas/util/qenc_cli set bbu cb ${cb_id} mode 1)
      if [ "$(/nas/util/qenc_cli get bbu cb ${cb_id} | grep LEARN)" = "bbu_status:LEARN_DISCHARGING" ]; then
        bbu_status=2
      fi
    elif [ $bbu_status = 2 ]; then
      if [ "$(/nas/util/qenc_cli get bbu cb ${cb_id} | grep OK)" = "bbu_status:OK" ]; then
        let "run += 1"
        set_date=$(date -j +%S%Y%m%d)
        (/nas/util/qenc_cli set bbu cb ${cb_id} vpd ${set_date})
        if [ ${run} -lt ${test_run} ]; then
          bbu_status=0
        else
          bbu_status=3  
        fi
      ####################
      # BBU special case #
      ####################
      # 1. bbu_status:NOT_INSTALL
      elif [ "$(/nas/util/qenc_cli get bbu cb ${cb_id} |grep bbu_status)" = "bbu_status:NOT_INSTALL" ]; then
        (/nas/util/qenc_cli set drive_led enc 0 mode 4)
        (bbu_status=0)
        (date >> /tmp/log/burn_crit_log.txt)
        (echo "BBU(cb ${cb_id}) is not install.." >> /tmp/log/burn_crit_log.txt)
      # 2. bbu_status:NOT_AVAILABLE
      elif [ "$(/nas/util/qenc_cli get bbu cb ${cb_id} |grep bbu_status)" = "bbu_status:NOT_AVAILABLE" ]; then
        (/nas/util/qenc_cli set drive_led enc 0 mode 4)
        (bbu_status=0)
        (date >> /tmp/log/burn_crit_log.txt)
        (echo "BBU(cb ${cb_id}) is not avaliable.." >> /tmp/log/burn_crit_log.txt)
      fi               
    fi
  
  ##################################################################
  # if bbu learning finished, and testrun is 3, learning finished! #
  # otherwise learning restart                                     #
  ##################################################################
  if [ "${run}" = "${test_run}" ]; then
    while true
    do
      echo "Check BBU...Learning Pass"
      (date >> $log_path/bbu_log)
      (echo "${run}" >> $log_path/bbu_log)
      (/nas/util/qenc_cli get bbu cb ${cb_id} >> $log_path/bbu_log)
      sleep ${test_time}
    done
  else
    echo "Check BBU...Learning Pass" 
  fi 

  ####################
  # BBU special case #
  ####################
  # 1. bbu_status:NOT_INSTALL
  if [ "$(/nas/util/qenc_cli get bbu cb ${cb_id} |grep bbu_status)" = "bbu_status:NOT_INSTALL" ]; then
    echo "bbu_status:NOT_INSTALL"
  fi
  # 2. bbu_status:NOT_AVAILABLE
  if [ "$(/nas/util/qenc_cli get bbu cb ${cb_id} |grep bbu_status)" = "bbu_status:NOT_AVAILABLE" ]; then
    echo "bbu_status:NOT_AVAILABLE"
  fi

  (date >> $log_path/bbu_log)
  (echo "${run}" >> $log_path/bbu_log)
  (/nas/util/qenc_cli get bbu cb ${cb_id} >> $log_path/bbu_log)
                     
  sleep ${test_time}       
  done
}
#start up
main
