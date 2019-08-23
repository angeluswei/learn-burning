#!/bin/bash
########################
# FOR SIGNAL           #
########################
name="trap.sh"
log_path="/tmp/log/SIGNAL_histroy/"
SIGNAL_list="SIGHUP SIGINT SIGQUIT SIGQUIT SIGILL SIGTRAP SIGABRT SIGABRT SIGFPE SIGKILL SIGBUS SIGSEGV SIGSYS SIGPIPE SIGALRM SIGTERM SIGURG SIGSTOP SIGTSTP SIGCONT SIGCHLD SIGTTIN SIGTTOU SIGIO SIGXCPU SIGXFSZ SIGVTALRM SIGPROF SIGWINCH SIGINFO"
for x in ${SIGNAL_list}
do
  trap "echo TRAP : Got ${x}; echo ${name} > ${log_path}${x}.txt; date >> ${log_path}${x}.txt" ${x}
done

##################################################
# Function                                       #
# If all disk are red light, turn to green light #
##################################################
function check_light_error {
  local ses_dev=$(ls /dev/ses*);
  for ses_no in $ses_dev
  do
    local ses_num=${dev_no:8:1}
    disk_num=$(/nas/util/qenc_cli get led ses ${ses_num} aline | grep -v cli | wc | awk '{print $1}')
    light_num=$(/nas/util/qenc_cli get led ses ${ses_num} aline | grep "led_mode:3" | wc | awk '{print $1}')

    if [ "$disk_num" = "$light_num" ]; then
      date >> /tmp/log/disk_light_msg/turn_off_light_ses${ses_num}.txt
      (/nas/util/qenc_cli set led ses ${ses_num} mode 1)
    fi
  done
}

####################################################
# Mirror will detect meta error automatically,     #
# If find it, light the disk and kick it from raid #
####################################################
#function metadata_error {
#  local error_msg=$(cat /tmp/log/dmesg_log/dmesg_diff.txt | grep "GEOM_MIRROR: Device" | awk '{print $3 $5}')
#  for dev_no in ${error_msg}
#  do
#    local ses_num=${dev_no:6:1}
#    local disk_num=${dev_no:10:2}
#    for((slot_no=0; slot_no<16; slot_no=slot_no+1))
#    do
#      slot=$(sysctl qess.hw.jbod.${ses_num} | grep name | grep "da${disk_num}" | grep "drive.${slot_no}")
#      if [ "${slot}" = "" ]; then
#        echo "metada pass"
#      else
#        echo "@@ Usg:ses${ses_num}, da${disk_num}, slot${slot_no}, Failed @@"
#        (echo "@@ Usg:Light the disk(ses${ses_num} slot${it_no}), by diff disk_num @@")
#        (/nas/util/qenc_cli set led ses ${ses_num} no ${slot_no} mode 3)
#        # Save log
#        date >> /tmp/log/disk_light_msg/ses${ses_num}no${slot_no}.txt
#        cat /tmp/log/dmesg_log/dmesg_diff.txt >> /tmp/log/disk_light_msg/ses${ses_num}no${slot_no}.txt
#        echo "" >> /tmp/log/disk_light_msg/ses${ses_num}no${slot_no}.txt
#      fi
#    done
#  done
#}

######################
# Check mpslsi error #
######################
#function check_mpslsi {
#  (/nas/util/qses scan_jbod)
#  local ses_dev=$(ls /dev/ses*);
#  for dev_no in $ses_dev
#  do
#    ## Find error disk and light the disk
#      ses_no=${dev_no:8:1}
#      echo "@@ Usg:In check_hdd ses${ses_no} (Error disk) @@"
#      #get slot
#      local IFS=" "
#      ret_cnt=$(sysctl qess.hw.jbod.${ses_no}.drive.%count)
#      for temp_cnt in $ret_cnt
#      do
#        hdd_cnt=$temp_cnt
#      done
#      echo "HDD_Count:$hdd_cnt"
#      #do hdd act
#      local do_list=""
#      for((slot=0;slot<$hdd_cnt;slot=slot+1))
#      do
#        ret_dev=$(sysctl qess.hw.jbod.${ses_no}.drive.${slot}.name |awk '{print $2}')
#        echo "rev:${ret_dev}"
#        #set led
#        let it_no=slot+1
#
#        dmesg=$(cat /tmp/log/dmesg_log/dmesg_diff.txt |grep ${ret_dev:5}: |grep "mpslsi" | sed "s/:/ /" | sed "s/(//" | awk '{print $1}')
#        if [ "${dmesg}" = "" ]; then
#          echo "pass"
#        else
#          (/nas/util/qenc_cli set led ses ${ses_no} no ${it_no} mode 3)
#          echo "@@ Usg:Light the disk(ses${ses_no} slot${it_no}), by grep mpslsi error @@"
#          same_da=$(cat /tmp/broken_drive_${ses_no}_list.txt | grep ${it_no})
#          if [ "${same_da}" = "" ]; then
#            (echo "s${ses_no} ${it_no}" >> /tmp/burn_notice)
#            (echo "${it_no}" >> /tmp/broken_drive_${ses_no}_list.txt)
#          else
#            (echo "ses${ses_no} ${it_no} is already saved")
#          fi
#          echo "broken" > /tmp/broken_drive.txt
#          # Save log
#          date >> /tmp/log/disk_light_msg/ses${ses_no}no${it_no}.txt
#          cat /tmp/log/dmesg_log/dmesg_diff.txt >> /tmp/log/disk_light_msg/ses${ses_no}no${it_no}.txt
#          echo "" >> /tmp/log/disk_light_msg/ses${ses_no}no${it_no}.txt
#        fi
#      done
#    done
#}

#################################################################
# Check disks number of mirror_status between qess.hw.jbod,     #
# If num of qess.hw.jbod < num of mirror_status, light the disk #
#################################################################
function check_hdd_diff {
  (mkdir /tmp/log/check_hdd_folder)
  (/nas/util/qses scan_jbod)
  local ses_dev=$(ls /dev/ses*);
  for ses_no in $ses_dev
  do
    local ses_num=${dev_no:8:1}
    local qses_disk_num=$(sysctl qess.hw.jbod.${ses_num} | grep name | wc | awk '{print $1}')
    #local gmirror_disk_num=$(gmirror status st_ses${ses_num} | wc | awk '{print $1}')
    local gstripe_disk_num=$(gstripe status st_ses${ses_num} | wc | awk '{print $1}')

    #if [ "${qses_disk_num}" -lt "${gmirror_disk_num}" ]; then
    if [ "${qses_disk_num}" -lt "${gstripe_disk_num}" ]; then
      (echo "  @@ Usg:FAILED @@")
      #gmirror_disk_list=$(gmirror list st_ses${ses_num} | grep da | awk '{print $3}')
      #for dev_no in ${gmirror_disk_list}
      gstripe_disk_list=$(gstripe list st_ses${ses_num} | grep da | awk '{print $3}')
      for dev_no in ${gstripe_disk_list}
      do
        (sysctl qess.hw.jbod.${ses_num} | grep name | grep ${dev_no} > /tmp/log/check_hdd_folder/check_da_ses${ses_num}.txt)
        da_alive=$(cat /tmp/log/check_hdd_folder/check_da_ses${ses_num}.txt)
        if [ "${da_alive}" = "" ]; then
          (/nas/util/qenc_cli set led ses ${ses_no} no ${it_no} mode 3)
          (echo "@@ Usg:Light the disk(ses${ses_no} slot${it_no}), by diff disk_num @@")
          same_da=$(cat /tmp/broken_drive_${ses_no}_list.txt | grep ${it_no})
          if [ "${same_da}" = "" ]; then
            (echo "s${ses_num} ${dev_no}" >> /tmp/burn_notice)
            (echo "${it_no}" >> /tmp/broken_drive_${ses_no}_list.txt)
          else
            (echo "ses${ses_no} ${it_no} is already saved")
          fi
          (echo "broken" > /tmp/broken_drive.txt)
          # Save log
          date >> /tmp/log/disk_light_msg/ses${ses_no}no${it_no}.txt
          cat /tmp/log/dmesg_log/dmesg_diff.txt >> /tmp/log/disk_light_msg/ses${ses_no}no${it_no}.txt
          echo "" >> /tmp/log/disk_light_msg/ses${ses_no}no${it_no}.txt
        fi
      done
    else
      (echo "  @@ Usg:PASS @@")
    fi

  done
}

#############################################################
# The function has two mode                                 #
# 1. disk_error: if grep "CAM status error", light the disk #
# 2. add_disk: if grep "new disk", light green              #
#############################################################
function check_hdd {
  (/nas/util/qses scan_jbod)
  local input=$1
  local ses_dev=$(ls /dev/ses*);
  for dev_no in $ses_dev
  do
    ## Find error disk and light the disk
    if [ "${input}" = "disk_error" ]; then
      ses_no=${dev_no:8:1}
      echo "@@ Usg:In check_hdd ses${ses_no} (Error disk) @@"
      #get slot
      local IFS=" "
      ret_cnt=$(sysctl qess.hw.jbod.${ses_no}.drive.%count)
      for temp_cnt in $ret_cnt
      do
        hdd_cnt=$temp_cnt
      done
      echo "HDD_Count:$hdd_cnt"
      #do hdd act
      local do_list=""
      for((slot=0;slot<$hdd_cnt;slot=slot+1))
      do
        ret_dev=$(sysctl qess.hw.jbod.${ses_no}.drive.${slot}.name |awk '{print $2}')
        echo "rev:${ret_dev}"
        #set led
        let it_no=slot+1

        dmesg=$(cat /tmp/log/dmesg_log/dmesg_diff.txt |grep ${ret_dev:5}: |grep "CAM status")
        if [ "${dmesg}" = "" ]; then
          echo "pass"
        else
          (/nas/util/qenc_cli set led ses ${ses_no} no ${it_no} mode 3)
          echo "@@ Usg:Light the disk(ses${ses_no} slot${it_no}), by CAM status error @@"
          echo "s${ses_no} ${it_no}" >> /tmp/burn_notice
          echo "${it_no}" >> /tmp/broken_drive_${ses_no}_list.txt
          echo "broken" > /tmp/broken_drive.txt
          # Save log
          date >> /tmp/log/disk_light_msg/ses${ses_no}no${it_no}.txt
          cat /tmp/log/dmesg_log/dmesg_diff.txt >> /tmp/log/disk_light_msg/ses${ses_no}no${it_no}.txt
          echo "" >> /tmp/log/disk_light_msg/ses${ses_no}no${it_no}.txt

        fi
      done
    ## Find new disk
    elif [ "${input}" = "add_disk" ]; then
      ses_no=${dev_no:8:1}
      echo "@@ Usg:In check_hdd ses${ses_no} (New disk) @@"
      new_drive=$(cat /tmp/log/dmesg_log/dmesg_diff.txt | grep "new disk" | awk '{print $5}')
      for dri_da in $new_drive
      do
        (/nas/util/qses scan_jbod)
        (sleep 1)
        ses_match=$(sysctl qess.hw.jbod.${ses_no} | grep name | grep ${dri_da})
        echo "add" > /tmp/add_drive.txt
        if [ "$ses_match" = "" ]; then
          echo "@@ Usg:ses${ses_no}, ${dri_da} pass @@"
        else
          echo "@@ Usg:ses${ses_no}, ${dri_da} New Disk!! @@"
          for((slot=0; slot<16; slot=slot+1))
          do
            dev_list=$(sysctl qess.hw.jbod.${ses_no}.drive.${slot} |grep name | grep "${dri_da}" | grep -v "${dri_da}.")
            if [ "${dev_list}" = "" ]; then
              echo "pass"
              #pass
            else
               let "slot += 1"
              echo "@@ Usg:Light ses${ses_no}, ${dri_da}, slot${slot} @@"
              (/nas/util/qenc_cli set led ses ${ses_no} no ${slot} mode 1)
               let "slot -= 1"
            fi
          done
          echo "${dri_da}" >> /tmp/add_to_ses${ses_no}.txt
        fi
      done
    fi
  done
}

#Check log path
test_time=60
test_cnt=180
test_run=-1
fan_dev="0 1 2 3 4 5 6 7"
cnt=1
run=1
cmd_id=$(/nas/util/qenc_cli get cbid | grep cbid)
cb_id=${cmd_id:5:1}
log_path=$(cat /tmp/log_path)
if [ "$log_path" = "" ]; then
  echo "Without Log Path!!!"
  exit
fi

echo "log_path:$log_path"
usg_log=${log_path}/usage
mkdir $usg_log
mkdir /tmp/log/dmesg_log
mkdir /tmp/log/disk_light_msg

#test loop
while true
do
###################
# Check fp number #
###################
  (/nas/util/qenc_cli get fp | grep fp_num > /tmp/fp_str.txt)
  fp_str=$(cat /tmp/fp_str.txt)
  if [ "${fp_str}" = "fp_num:10" ]; then
    (/nas/util/qenc_cli set fp num 2)
    (/nas/util/qenc_cli get fp | grep fp_num > /tmp/fp_str.txt)
  fi
  first_exe=$(file -s /tmp/log/dmesg_log/old_tmp.txt | grep ERROR)
  if [ "${first_exe}" = "" ]; then
    (rm /tmp/log/dmesg_log/old.txt)
    (mv /tmp/log/dmesg_log/old_tmp.txt /tmp/log/dmesg_log/old.txt)
  else
    (dmesg > /tmp/log/dmesg_log/old.txt)
  fi

  (echo "====================" >> ${usg_log}/usage_${run}.log)
  (date >> ${usg_log}/usage_${run}.log)
########################################
# Monitor CPU, virtual memory, process #
########################################
  (echo "=========================================" >> ${usg_log}/rmonitor_${run}.log)
  (echo "=====vmstat=====" >> ${usg_log}/rmonitor_${run}.log)
  (echo "================" >> ${usg_log}/rmonitor_${run}.log)
  (vmstat >> ${usg_log}/rmonitor_${run}.log)
  (echo "=============" >> ${usg_log}/rmonitor_${run}.log)
  (echo "=====top=====" >> ${usg_log}/rmonitor_${run}.log)
  (echo "=============" >> ${usg_log}/rmonitor_${run}.log)
  (top >> ${usg_log}/rmonitor_${run}.log)

##################################################
# Checking enc_mgmt, if failed, restart qenc_mgt #
##################################################
  if [ "$(/nas/util/qenc_cli get volt aline)" = "cli:CONNECTION_FAIL:4" ]; then
    (echo "restart qenc_mgmt" >> ${usg_log}/usage_${run}.log)
    (pkill qenc_mgt)
    (rm /var/run/qenc_mgt.pid)
    if [ $cb_id = 1 ]; then
      (/usr/local/sbin/qenc_mgt 192.168.5.2)
      #( /tmp/burn/qenc_mgt 192.168.3.2)
    else
      (/usr/local/sbin/qenc_mgt 192.168.5.1)
      #( /tmp/burn/qenc_mgt 192.168.3.1)
    fi
    sleep 20
    (/nas/util/qenc_cli set fan mode 1 80)
  fi
########################################################
# Checking the content of qenc_mgt, if failed, print it
########################################################
  if [ "$(/nas/util/qenc_cli get temp aline |grep OK |wc -l |awk '{print $1}')" = "6" ]; then
    echo "temp pass"
  else
    echo "temp fail"
    (/nas/util/qenc_cli get temp aline >> ${usg_log}/usage_${run}.log)
    (/nas/util/qenc_cli get fan aline >> ${usg_log}/usage_${run}.log)
  fi

############################
# Set Jbod fan speed
############################
  ses_dev=$(ls /dev/ses*);       
  for dev_no in $ses_dev
  do
    ses_no=${dev_no:8:1}
    if [ "$(sg_inq /dev/ses${ses_no} |grep ES)" = "" ]; then
      for fan_no in $fan_dev
      do
        (/nas/util/qses fan ses${ses_no} ${fan_no} 6)
      done 
      (echo "ses${ses_no}" >> ${usg_log}/usage_${run}.log)
      ses_fan_info=$(/nas/util/qses fan ses${ses_no})
      (echo "${ses_fan_info}" >> ${usg_log}/usage_${run}.log)
      ses_temp_info=$(/nas/util/qses tsensor ses${ses_no})
      (echo "${ses_temp_info}" >> ${usg_log}/usage_${run}.log)
    fi
  
  done                    

  (dmesg > /tmp/log/dmesg_log/new.txt)
  (dmesg > /tmp/log/dmesg_log/old_tmp.txt)
#RUN
  hdd_run=$(cat /tmp/log/st_ses0_log/run)
#######################
# Check kernel log
#######################
    (diff /tmp/log/dmesg_log/new.txt /tmp/log/dmesg_log/old.txt > /tmp/log/dmesg_log/dmesg_diff.txt)
#########################
# Check plug in message #
#########################
    echo "@@ Check dmesg_diff(whether it have new disk?) @@"
    dmesg_diff_new_disk_msg=$(cat /tmp/log/dmesg_log/dmesg_diff.txt |grep da |grep "new disk")
    if [ "${dmesg_diff_new_disk_msg}" = "" ]; then
      echo "  @@ Usg:No new disk @@"
    else
      echo "  @@ Usg:Find new disk @@"
      check_hdd "add_disk"
    fi
#######################################
# Chech disk error message (mtehod 1) #
#######################################
#    echo "@@ Usg:Check dmesg_diff(check CAM status error) @@"
#    if [ "$(dmesg |grep da |grep "CAM status")" = "" ]; then
#      echo "  @@ Usg:PASS @@"
#      echo "HDD:${hdd_run}" > /tmp/burn_notice
#    else2
#      echo "  @@ Usg:FAILED @@"
#      echo "HDD:${hdd_run}...FAIL" > /tmp/burn_notice
#      check_hdd "disk_error"
#    fi

###########################################################################
# Check disk error between "sysctl qess.hw.jbod" and "camcontrol devlist" #
###########################################################################
    echo "@@ Usg:Check disk status between raid and kernel status  @@"
    check_hdd_diff
###################################################################################################################################
# Disk error log in 1640v2                                                                                                        #
# (da15:mpslsi30:0:43:0): WRITE(10). CDB: 2a 0 0 7b b4 0 0 0 40 0 length 32768 SMID 150 terminated ioc 804b scsi 0 state c xfer 0 #
###################################################################################################################################
#    echo "@@ Usg:Check mpslis error @@"
#    mpslsi_error=$(cat /tmp/log/dmesg_log/dmesg_diff.txt | grep mpslsi)
#    if [ "${mpslsi_error}" = "" ]; then
#      echo "  @@ Usg:PASS @@"
#    else
#      echo "  @@ Usg:FAILED @@"
#      check_mpslsi
#    fi

####################
# Check error disk #
####################
    #echo "@@ Usg:Check dmesg(can't write metadate) @@"
    #dmesg_cant_write_metadata=$(cat /tmp/log/dmesg_log/dmesg_diff.txt | grep "GEOM_MIRROR" | grep "provider da" | grep "disconnected")
    #if [ "${dmesg_cant_write_metadata}" = "" ]; then
    #  echo "@@ Usg:Metadata OK @@"
    #else
    #  echo "@@ Usg:Find error disk @@"
    #  metadata_error
    #fi
#####################
# Check light error #
#####################
    check_light_error

##################
# Stop contition #
##################
  if [ $cnt = $test_cnt ]; then
    let "run += 1"
    cnt=1
  elif [ $run = $test_run ]; then
    echo "Test Done!!!" > /tmp/burn/done_file
  else
    let "cnt += 1"
  fi
  sleep $test_time

done

