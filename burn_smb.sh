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

#Check log path
log_path=$(cat /tmp/log_path)
if [ "$log_path" = "" ]; then
  echo "Without Log Path!!!"
  exit
fi

echo "log_path:$log_path"
smb_log=${log_path}/smb
mkdir $smb_log
#test loop
cnt=0
run=0
cmd_id=$(/nas/util/qenc_cli get cbid | grep cbid)
cb_id=${cmd_id:5:1}

(/nas/util/qenc_cli set fan mode 1 80)
while true
do
  #burn VPD & SMB
  if [ $run = 0 ]; then
    (date >> ${smb_log}/vpd_${run}.log)
    echo "Burn SMB Run:${run}, Count:${cnt}" | tee -a ${smb_log}/vpd_${run}.log
    (/nas/util/qenc_vpd | grep Serial | tee -a ${smb_log}/vpd_${run}.log)
    sleep 1
  #hw monitor
  else
    (date >> ${smb_log}/monitor_${run}.log)
    (echo "Burn SMB Run:${run}, Count:${cnt}" | tee -a ${smb_log}/monitor_${run}.log)
    (/nas/util/qenc_cli get temp aline >> ${smb_log}/monitor_${run}.log)
    sleep 1
    (/nas/util/qenc_cli get volt aline >> ${smb_log}/monitor_${run}.log)
    sleep 1
    (/nas/util/qenc_cli get fan aline >> ${smb_log}/monitor_${run}.log)
    sleep 30  
  fi

  if [ $cnt = 500 ]; then
    let "run += 1"
    cnt=0
    echo "done" > /tmp/bbu_start
  elif [ $run = 10000 ]; then
    echo "Test Done!!!"
    exit
  else
    let "cnt += 1"
  fi

done
