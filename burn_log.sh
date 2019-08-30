#!/bin/bash
########################
# FOR SIGNAL
########################
name="trap.sh"
log_path="/tmp/log/SIGNAL_histroy/"
SIGNAL_list="SIGHUP SIGINT SIGQUIT SIGQUIT SIGILL SIGTRAP SIGABRT SIGABRT SIGFPE SIGKILL SIGBUS SIGSEGV SIGSYS SIGPIPE SIGALRM SIGTERM SIGURG SIGSTOP SIGTSTP SIGCONT SIGCHLD SIGTTIN SIGTTOU SIGIO SIGXCPU SIGXFSZ SIGVTALRM SIGPROF SIGWINCH SIGINFO"
for x in ${SIGNAL_list}
do
  trap "echo TRAP : Got ${x}; echo ${name} > ${log_path}${x}.txt; date >> ${log_path}${x}.txt" ${x}
done

#######################################
# Initial parsing flag, and pass total
#######################################
scbA_pass_num=8
scbB_pass_num=6
cb_vpd_pass_flag=0
bp_vpd_pass_flag=0
bbu_learning_pass_flag=0
ntb_pass_flag=0
net_pass_flag=1 ## default pass, if a interface fail, mark fail
smb_pass_flag=0
fio_speed_pass_flag=1
disk_num_pass_flag=0


########################
# Start burn log
########################
OF="report.html"
CL="<br>"

function create_fio_speed_table {
  log_path=$(cat /tmp/log_path)
  mkdir ${log_path}/fio_speed_table

  enc_dev=$(ls /dev/enc*);
  for enc_str in $enc_dev
  do
    filenum=1
    end_flag=true
    enc_num=${enc_str:8:1}
    echo "[fio_8M_read]" > ${log_path}/fio_speed_table/fio_8M_enc${enc_num}_read
    echo "[fio_1M_read]" > ${log_path}/fio_speed_table/fio_1M_enc${enc_num}_read
    echo "[fio_4K_read]" > ${log_path}/fio_speed_table/fio_4K_enc${enc_num}_read
    echo "[fio_8M_write]" > ${log_path}/fio_speed_table/fio_8M_enc${enc_num}_write
    echo "[fio_1M_write]" > ${log_path}/fio_speed_table/fio_1M_enc${enc_num}_write
    echo "[fio_4K_write]" > ${log_path}/fio_speed_table/fio_4K_enc${enc_num}_write

    while ${end_flag}
    do
      if [ -f /tmp/log/st_enc${enc_num}_log/${filenum}.log ]; then
        echo "In enc${enc_num}, ${filenum}.log"
      else
        echo "In enc${enc_num}, ${filenum}.log"
        echo "No file"
        end_flag=false
        #return
      fi

      i=1
      initial=$(cat /tmp/log/st_enc${enc_num}_log/${filenum}.log | grep READ | awk '{print $3}' | sed "s/KB.s,//" | sed "s/aggrb=//")
      for y in $initial
      do
        if [ "$i" = 1 ]; then
          echo "$y" >> ${log_path}/fio_speed_table/fio_8M_enc${enc_num}_read
        elif [ "$i" = 2 ]; then
          echo "$y" >> ${log_path}/fio_speed_table/fio_1M_enc${enc_num}_read
        elif [ "$i" = 3 ]; then
          echo "$y" >> ${log_path}/fio_speed_table/fio_4K_enc${enc_num}_read
          i=0
        fi
        i=$(( ${i}+1 ))
      done

      i=1
      initial=$(cat /tmp/log/st_enc${enc_num}_log/${filenum}.log | grep WRITE | awk '{print $3}' | sed "s/KB.s,//" | sed "s/aggrb=//")
      for z in $initial
      do
        if [ "$i" = 1 ]; then
          echo "$z" >> ${log_path}/fio_speed_table/fio_8M_enc${enc_num}_write
        elif [ "$i" = 2 ]; then
          echo "$z" >> ${log_path}/fio_speed_table/fio_1M_enc${enc_num}_write
        elif [ "$i" = 3 ]; then
          echo "$z" >> ${log_path}/fio_speed_table/fio_4K_enc${enc_num}_write
          i=0
        fi
        i=$(( ${i}+1 ))
      done

      filenum=$(( ${filenum}+1 ))
    done
  done
}
function burnin_cp_usb {
  prt_path=$(cat /tmp/prt_path)
  ufd=$(ls /dev/da* | grep s1)
  if [ $ufd = "" ]; then
    echo "No UFD!!!!!"
  else
    echo "Copy file..."
    (mkdir /tmp/usb)
    (mount -t msdos ${ufd} /tmp/usb)
    (cp ${prt_path}.tar.gz /tmp/usb)
    (umount -f /tmp/usb)
    (rm -rf /tmp/usb)
    echo "Copy Done"
  fi      
  return
}                   
function burnin_cp_log {
  #create_fio_speed_table)
  log_path=$(cat /tmp/log_path)
  log_time=$(date -j +%Y%m%d%M%S)
  prt_path="${log_path}-${log_time}"
  echo "$prt_path" > /tmp/prt_path
  (mkdir $prt_path)
  (cp /tmp/burn_notice ${prt_path}/)
  (cp -r /tmp/log/st_*_log ${prt_path}/)
  (cp ${log_path}/bbu_log ${prt_path}/)
  (cp -r ${log_path}/usage ${prt_path}/)
  (cp /var/log/message* ${prt_path}/)
  (cp ${log_path}/version ${prt_path}/)
  (cp -r ${log_path}/lan ${prt_path}/)
  (cp -r ${log_path}/smb ${prt_path}/)
  (cp ${log_path}/ntb_log ${prt_path}/)
  (cp -r ${log_path}/fio_speed_table ${prt_path}/)
  (cp -r /tmp/log/SIGNAL_histroy ${prt_path}/)
  (cp -r /tmp/log/disk_light_msg ${prt_path}/)
  (cp -r /tmp/hdd_diag_log ${prt_path}/)
  (cp -r /tmp/query_drive_info.txt ${prt_path}/)
  (cp -r /var/log/kern_crit.log* ${prt_path}/)
  (cp /tmp/log/burn_crit_log.txt ${prt_path}/)
  (tar -czvf ${prt_path}.tar.gz ${prt_path})    
  return
}
function burnin_tar_log {                         
  prt_path=$(cat /tmp/prt_path)
  (tar -czvf ${prt_path}.tar.gz ${prt_path})   
  return
}
function report_vpd_log {
  prt_path=$(cat /tmp/prt_path)
  cmd_id=$(/nas/util/qenc_cli get cbid | grep cbid)
  cb_id=${cmd_id:5:1}
  echo "====================Burnin Info====================${CL}" >> ${prt_path}/${OF}  
  ver_info=$(cat ${prt_path}/version)
  echo "Burnin Version:${ver_info}${CL}" >> ${prt_path}/${OF}
  hdd_trun=$(cat /tmp/burn_notice)
  echo "Burnin Run:${hdd_trun}${CL}" >> ${prt_path}/${OF}
 
  echo "start time: " >> ${prt_path}/${OF}
  cat /tmp/start_time.txt >> ${prt_path}/${OF}
  echo "${CL}" >> ${prt_path}/${OF}
 
  cb_vpd=$(/nas/util/qenc_cli get vpd aline |grep cb:${cb_id})
  echo "${cb_vpd}${CL}" >> ${prt_path}/${OF}
  cb_vpd_parsing_string=$(/nas/util/qenc_cli get vpd aline | grep "cb:${cb_id}"| grep SAS-6 | grep "serial:[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]" | grep "70-0QV400130")
  if [ "cb_vpd_parsing_string" = "" ]; then
    cb_vpd_pass_flag=0
  else
    cb_vpd_pass_flag=1
  fi

  bp_vpd=$(/nas/util/qenc_cli get vpd aline |grep cb:3)
  echo "${bp_vpd}${CL}" >> ${prt_path}/${OF}
  bp_vpd_parsing_string=$(/nas/util/qenc_cli get vpd aline | grep "cb:${cb_id}" | grep "VPD_Type:Backplane mfg:QNAP Systems model:LF-SAS-BP" | grep "serial:Q[0-9][0-9][0-9]I[0-9][0-9][0-9][0-9][0-9]" | grep "parts:70-1QV360130")
  if [ "bp_vpd_parsing_string" = "" ]; then
    bp_vpd_pass_flag=0
  else
    bp_vpd_pass_flag=1
  fi

  log_path=$(cat /tmp/log_path)
  sn=$(cat ${log_path}/smb/vpd_0.log |grep -A1 "Count:100" |grep "Number" |awk '{print $4}')
  echo "Serial Number : ${sn}" >> ${prt_path}/${OF}

  echo "pass_flag=${cb_vpd_pass_flag},${bp_vpd_pass_flag}${CL}"  >> ${prt_path}/${OF}

  return
}
function report_bbu_log {
  prt_path=$(cat /tmp/prt_path)
  cmd_id=$(/nas/util/qenc_cli get cbid | grep cbid)
  cb_id=${cmd_id:5:1}
  echo "====================BBU Device====================${CL}" >> ${prt_path}/${OF}  
  if [ "$(/nas/util/qenc_cli get bbu cb ${cb_id} |grep bbu_auth:1)" = "" ]; then
    echo "BBU...Learning Fail${CL}" >> ${prt_path}/${OF}
    bbu_learning_pass_flag=0
  else
    echo "BBU...Learning Pass${CL}" >> ${prt_path}/${OF}
    bbu_learning_pass_flag=1
  fi      
    bbu_info=$(/nas/util/qenc_cli get bbu cb ${cb_id} aline)
    echo "${bbu_info}${CL}" >> ${prt_path}/${OF}
    echo "pass_flag:${bbu_learning_pass_flag}${CL}" >> ${prt_path}/${OF}
  return
}
function report_ntb_log {
  cmd_id=$(/nas/util/qenc_cli get cbid | grep cbid)
  cb_id=${cmd_id:5:1}
  if [ "$cb_id" = "2" ]; then
    return
  fi

  dev=$1
  thr=$2
  cnt=0;  
  prt_path=$(cat /tmp/prt_path)       
  ntb_diff=$(cat ${prt_path}/ntb_log |grep diff)
  echo "====================NTB Device====================${CL}" >> ${prt_path}/${OF}
  if [ "$ntb_diff" = "" ]; then
    echo "NTB...Pass${CL}" >> ${prt_path}/${OF}
    ntb_info=$(cat ${prt_path}/ntb_log | grep run |wc -l |awk '{print $1}')
    echo "NTB run:${ntb_info}${CL}" >> ${prt_path}/${OF}
    ntb_pass_flag=1
  else
    ntb_fail_num=$(cat ${prt_path}/ntb_log | grep diff | wc | awk '{print $1}')
    ntb_info=$(cat ${prt_path}/ntb_log | grep run |wc -l |awk '{print $1}')
    echo "NTB...Data Fail, total run:${ntb_info}, fail:${ntb_fail_num}${CL}" >> ${prt_path}/${OF}
    ntb_pass_flag=0
  fi
  echo "pass_flag:${ntb_pass_flag}${CL}" >> ${prt_path}/${OF}

  ntb_pcie_info=$(sysctl -n dev.ntb_hw.0.link_status)
  echo "NTB Link Speed: ${ntb_pcie_info}${CL}" >> ${prt_path}/${OF}
  while true
  do
    let "cnt += 1"
    echo "cat ${prt_path}/lan/${dev}_${cnt}.log"
    #cat ${prt_path}/lan/${dev}_${cnt}.log
    if [ -f "${prt_path}/lan/${dev}_${cnt}.log" ]; then
        echo "exist" > /dev/null
    else
        break
    fi
    ntb_sum=$(cat ${prt_path}/lan/${dev}_${cnt}.log | grep SUM | tail -n 1 | awk '{print $6}')
    if [ "$ntb_sum" = "0" ]; then
      return
    else

         if [ "${ntb_sum}" -gt "${thr}" ]; then
            echo "${ntb_sum} > ${thr}"
            echo "Speed ${ntb_sum} Mb/s > ${thr} Mb/s, result:${net_pass_flag}${CL}"  >> ${prt_path}/${OF}
        else
            echo "${ntb_sum} < ${thr}"
            echo "Speed ${ntb_sum} Mb/s < ${thr} Mb/s, result:${net_pass_flag}!!${CL}"  >> ${prt_path}/${OF}
            net_pass_flag=0
        fi
 
    fi
    (cat ${prt_path}/lan/${dev}_${cnt}.log | grep "SUM" | grep " 0.0-180.0" >> ${prt_path}/lan/${dev}_short_${cnt}.log)     
  done                   
  return
}

function report_net_log {
  cmd_id=$(/nas/util/qenc_cli get cbid | grep cbid)
  cb_id=${cmd_id:5:1}
  dev=$1
  thr=$2

  ## Saving mac address
  echo "====================NET Device: ${dev}====================${CL}" >> ${prt_path}/${OF}
  mac_address=$(ifconfig ${dev} | grep ether | awk '{print $2}')
  echo "MAC address: ${mac_address}${CL}" >> ${prt_path}/${OF}

  if [ "$cb_id" = "2" ]; then
    return
  fi

  if [ "$dev" = "igb0" ]; then
    # Management Port, Only Show the MAC address
    return
  fi
  
  prt_path=$(cat /tmp/prt_path)
  cnt=0;       
  dev_chose=${dev:2:1}
  if [ "${dev_chose}" = "l" ]; then # meaning ixl<0,1,2...>
    ixl_num=${dev:3:1}
    sysctl dev.ixl.${ixl_num}.mac.crc_errors >> ${prt_path}/${OF}
    echo "${CL}" >> ${prt_path}/${OF}
    sysctl dev.ixl.${ixl_num}.mac.rx_length_errors >> ${prt_path}/${OF}
    echo "${CL}" >> ${prt_path}/${OF}
    sysctl dev.ixl.${ixl_num}.mac.checksum_errors >> ${prt_path}/${OF}
    echo "${CL}" >> ${prt_path}/${OF}
  fi

  while true
  do
    net_log_list=$(ls ${prt_path}/lan/* | grep "${dev}_" | grep  -v short)
    echo "net log list:${net_log_list}"
    if [ "${net_log_list}" = "" ]; then
        return
    fi

    for net_log in ${net_log_list}
    do
      #cnt=${net_log:5:1}
      echo "net log:${net_log}"
      net_sum=$(cat ${net_log} | grep SUM | tail -n 1 | awk '{print $6}')
      if [ "$net_sum" = "0" ]; then
        return
      else

        if [ "${net_sum}" -gt "${thr}" ]; then
            echo "${net_sum} > ${thr}"
            echo "Speed ${net_sum} Mb/s > ${thr} Mb/s, result:${net_pass_flag}${CL}"  >> ${prt_path}/${OF}
        else
            net_pass_flag=0
            echo "${net_sum} < ${thr}"
            echo "Speed ${net_sum} Mb/s < ${thr} Mb/s, result:${net_pass_flag}!!${CL}"  >> ${prt_path}/${OF}
        fi

        #cat ${prt_path}/lan/${dev}_${cnt}.log | grep "SUM" | grep " 0.0-180.0" >> ${prt_path}/lan/${dev}_short_${cnt}.log
        cat ${net_log} | grep -B1 "DONE" | grep "SUM" >> ${prt_path}/lan/${dev}_short_${cnt}.log
        let "cnt=cnt+1"
      fi
    done
    return
  done 
  return
}
function report_smb_log {
  cmd_id=$(/nas/util/qenc_cli get cbid | grep cbid)
  cb_id=${cmd_id:5:1}
  
  dev=$1
  thr=$2
  zero=0
  prt_path=$(cat /tmp/prt_path)
  log_path=$(cat /tmp/log_path)
  cnt=0;
  total_pass=0
  total_fail=0
  Pfail=0

  if [ "${dev}" = "monitor" ]; then
    cnt=1
    condition="[0-9][0-9]:"
  fi
  if [ "${dev}" = "vpd" ]; then
    condition="Run"
  fi
  if [ "${dev}" = "smb0" ] || [ "${dev}" = "smb1" ]; then
    cnt=1
    condition="Probing"
  fi
  echo "====================SMB Device====================${CL}" >> ${prt_path}/${OF}
  while true
  do
    smb_sum=$(cat ${log_path}/smb/${dev}_${cnt}.log |grep ${condition} |wc -l |awk '{print $1}')

    if [ "$smb_sum" = "0" ]; then
      return
    else
      smb_fail=$(cat ${log_path}/smb/${dev}_${cnt}.log |grep SUM |grep ${thr} |wc -l |awk '{print $1}')
      if [ "$smb_fail" = "$zero" ]; then
        echo "SMB ${dev}_${cnt}...check Pass - ${smb_sum}${CL}" >> ${prt_path}/${OF}
      else
        echo "**SMB ${dev}_${cnt}...check ${thr} - run:${smb_sum}, fail:${smb_fail}**${CL}" >> ${prt_path}/${OF}
        let "total_fail += smb_fail"
      fi
      let "total_pass += smb_sum"
    fi
    #####################################
    # Special search, find fan_pwm != 80
    #####################################
    if [ "${dev}" = "monitor" ]; then
      smb_sum=$(cat ${log_path}/smb/${dev}_${cnt}.log | grep fan_pwm | awk '{print $ 5}' | grep -v 80 | wc |awk '{print $1}')
      if [ "${smb_sum}" = "0" ]; then
        echo "    ${dev}_${cnt}...check fan_pwm_80 Pass${CL}" >> ${prt_path}/${OF}
      else
        echo "    **${dev}_${cnt}...check fan_pwm_80 Fail - fail_num:${smb_sum}**${CL}" >> ${prt_path}/${OF}
        let "total_fail += smb_sum"
      fi
      let "total_pass += smb_sum"
    fi

    let "Pfail = total_fail*100/total_pass"
    echo "P:${Pfail}, total_fail:${total_fail}, total_pass:${total_pass}"
    if [ "$Pfail" -gt "5" ]; then
      smb_pass_flag=0
    else
      smb_pass_flag=1
    fi

    echo "pass_flag:${smb_pass_flag}${CL}"  >> ${prt_path}/${OF}
    ##############
    # End
    ##############
    let "cnt += 1"
  done
  return
}
function report_hdd_log {
  dev=$1
  prt_path=$(cat /tmp/prt_path)
  cnt=0;       

  while true
  do
  echo "--------------------${CL}" >> ${prt_path}/${OF}
    let "cnt += 1"
    hdd_read=$(cat ${prt_path}/st_enc${dev}_log/${cnt}.log |grep " read" |wc -l |awk '{print $1}')
    if [ "$hdd_read" = "0" ]; then
      return
    fi

    hdd_write=$(cat ${prt_path}/st_enc${dev}_log/${cnt}.log |grep " write" |wc -l |awk '{print $1}')
    if [ "$hdd_write" = "0" ]; then
      return
    fi
    echo "${cnt}.log...Pass - R${hdd_read} W${hdd_write}${CL}" >> ${prt_path}/${OF}
  done  
  return
}

function report_enc_log {
  prt_path=$(cat /tmp/prt_path)
  local pass_flag=1
  local enc_num=0
  local disk_num=0
  local disk_node=""
  local disk_name=""
  local amount_of_enc=0
  local amount_of_disk=0
  echo "====================Enclosure Device====================${CL}" >> ${prt_path}/${OF}
 
  amount_of_enc=$(sysctl -n qess.hw.hal.enc.count)

  for((enc_num=0;enc_num<${amount_of_enc};enc_num=enc_num+1))
  do
     amount_of_disk=$(sysctl -n qess.hw.hal.enc.${enc_num}.cb.1.disk.count)

     echo "Enclosure ${enc_num}${CL}" >> ${prt_path}/${OF}

     for((disk_num=1;disk_num<=${amount_of_disk};disk_num=disk_num+1))
     do
         disk_node=$(sysctl qess.hw.hal.enc.${enc_num}.cb.1.disk.${disk_num}.name)
         echo "${disk_node}${CL}" >> ${prt_path}/${OF}

         disk_name=$(echo "${disk_node}" | awk '{print $2}')

         if [ "${disk_name}" = "none" ]; then
           pass_flag=0
         fi
     done
  done

  echo "pass_flag:${pass_flag}${CL}" >> ${prt_path}/${OF}

  return
}

function report_dd_speed {
  prt_path=$(cat /tmp/prt_path)
  log_path=$(cat /tmp/log_path)

  local enc_num=0
  local amount_of_enc=0
  local stress_num=0
  local amount_of_stress=0

  amount_of_enc=$(sysctl -n qess.hw.hal.enc.count)

  echo "====================FIO Speed=====================${CL}" >> ${prt_path}/${OF}
  for((enc_num=0;enc_num<${amount_of_enc};enc_num=enc_num+1))
  do
    # Checking fio
    amount_of_stress=$(cat /tmp/log/st_enc${enc_num}_log/stress_count.log)
    let "amount_of_stress += 1"
    for((stress_num=0;stress_num<${amount_of_stress};stress_num=stress_num+1))
    do
      read_speed=$(cat /tmp/log/st_enc${enc_num}_log/stress_${stress_num}.log | grep READ | awk '{print $3}' | sed 's/aggrb=//' | sed 's/,//')
      write_speed=$(cat /tmp/log/st_enc${enc_num}_log/stress_${stress_num}.log | grep WRITE | awk '{print $3}' | sed 's/aggrb=//' | sed 's/,//')
      echo "Enc${enc_num}, run:${stress_num}, read: ${read_speed}, write: ${write_speed}${CL}" >> ${prt_path}/${OF}
    done

    # Get dd Log
    (cat /tmp/log/st_enc${enc_num}_log/dd_single.log | grep -i fail > /tmp/log/st_enc${enc_num}_log/dd_single_fail.log)
    dd_fail_num=$(cat /tmp/log/st_enc${enc_num}_log/dd_single.log | grep -i fail | wc | awk '{print $1}')

    if [ "${dd_fail_num}" = "0" ]; then
      echo "DD to single disk is pass!${CL}"  >> ${prt_path}/${OF}
    else
      for ((i=1; i<=${dd_fail_num}; i++))
      do
        err_str=$(head -n ${i} /tmp/log/st_enc${enc_num}_log/dd_single_fail.log | tail -n 1)
        echo "${err_str}${CL}" >> ${prt_path}/${OF}
      done
    fi

  echo "pass_flag:${fio_speed_pass_flag}${CL}"  >> ${prt_path}/${OF}
  done
}

function report_camcontrol_devlist {
  prt_path=$(cat /tmp/prt_path)
  echo "====================Camcontrol Devlist====================${CL}" >> ${prt_path}/${OF}
  disk_num=$(camcontrol devlist | grep da | grep -v USB | grep -v ada | wc | awk '{print $1}')
  echo "DISK NUM: ${disk_num}${CL}" >> ${prt_path}/${OF}
  enc_num=$(sysctl -n qess.hw.hal.enc.count)
  echo "ENC NUM: ${enc_num}${CL}" >> ${prt_path}/${OF}

  correct_disk_num=$(sysctl -n sysctl qess.hw.hal.enc.0.cb.1.disk.count)

  if [ "${correct_disk_num}" = "${disk_num}" ]; then
    disk_num_pass_flag=1
  fi
  echo "pass_flag:${disk_num_pass_flag}${CL}"  >> ${prt_path}/${OF}

}

function report_ntb_pcie_error {
  echo "====================NTB Error Count====================${CL}" >> ${prt_path}/${OF}
  start_VBD=$(cat /tmp/start_ntb_pcie_errorcount.txt | grep "virt_bad_DLLP" | awk '{print $2}')
  start_VBT=$(cat /tmp/start_ntb_pcie_errorcount.txt | grep "virt_bad_TLP" | awk '{print $2}')
  start_LBD=$(cat /tmp/start_ntb_pcie_errorcount.txt | grep "link_bad_DLLP" | awk '{print $2}')
  start_LBT=$(cat /tmp/start_ntb_pcie_errorcount.txt | grep "link_bad_TLP" | awk '{print $2}')

  virt_bad_DLLP=$(sysctl hw.ntb.if.virt_bad_DLLP | awk '{print $2}')
  virt_bad_TLP=$(sysctl hw.ntb.if.virt_bad_TLP | awk '{print $2}')
  link_bad_DLLP=$(sysctl hw.ntb.if.link_bad_DLLP | awk '{print $2}')
  link_bad_TLP=$(sysctl hw.ntb.if.link_bad_TLP | awk '{print $2}')

  echo "start virt_bad_DLLP=${start_VBD}${CL}" >> ${prt_path}/${OF}
  echo "start virt_bad_TLP=${start_VBT}${CL}" >> ${prt_path}/${OF}
  echo "start link_bad_DLLP=${start_LBD}${CL}" >> ${prt_path}/${OF}
  echo "start link_bad_TLP=${start_LBT}${CL}" >> ${prt_path}/${OF}

  echo "${CL}" >> ${prt_path}/${OF}

  echo "end virt_bad_DLLP=${virt_bad_DLLP}${CL}" >> ${prt_path}/${OF}
  echo "end virt_bad_TLP=${virt_bad_TLP}${CL}" >> ${prt_path}/${OF}
  echo "end link_bad_DLLP=${link_bad_DLLP}${CL}" >> ${prt_path}/${OF}
  echo "end link_bad_TLP=${link_bad_TLP}${CL}" >> ${prt_path}/${OF}
}

function report_pcie_link_speed {
  ## Get NTB info
  local ntb_speed=$(cat /tmp/ntb_pcie_info.txt | grep -i "lnksta:" | awk '{print $3}')
  ## Get XL710 info
  local xl710_0_speed=$(cat /tmp/xl710_pcie_info_0.txt | grep -i "lnksta:" | awk '{print $3}')
  local xl710_1_speed=$(cat /tmp/xl710_pcie_info_1.txt | grep -i "lnksta:" | awk '{print $3}')
  local xl710_2_speed=$(cat /tmp/xl710_pcie_info_2.txt | grep -i "lnksta:" | awk '{print $3}')
  local xl710_3_speed=$(cat /tmp/xl710_pcie_info_3.txt | grep -i "lnksta:" | awk '{print $3}')

  ## Save Log
  echo "====================PCIE Link Speed====================${CL}" >> ${prt_path}/${OF}
  echo "NTB Link Speed=${ntb_speed}${CL}" >> ${prt_path}/${OF}
  echo "XL710-0 Link Speed=${xl710_0_speed}${CL}" >> ${prt_path}/${OF}
  echo "XL710-1 Link Speed=${xl710_1_speed}${CL}" >> ${prt_path}/${OF}
  echo "XL710-2 Link Speed=${xl710_2_speed}${CL}" >> ${prt_path}/${OF}
  echo "XL710-3 Link Speed=${xl710_3_speed}${CL}" >> ${prt_path}/${OF}

}

function report_summary {
  cmd_id=$(/nas/util/qenc_cli get cbid | grep cbid)
  cb_id=${cmd_id:5:1}
  prt_path=$(cat /tmp/prt_path)
  pass=0
  echo "====================Summary====================${CL}" >> ${prt_path}/${OF}
  let "pass=cb_vpd_pass_flag+bp_vpd_pass_flag+bbu_learning_pass_flag+ntb_pass_flag+net_pass_flag+smb_pass_flag+fio_speed_pass_flag+disk_num_pass_flag"

  pass_condition=0
  if [ "$cb_id" = "2" ]; then
    let "pass_condition=scbB_pass_num+0"
  else
    let "pass_condition=scbA_pass_num+0"
  fi

  if [ "${pass}" = "${pass_condition}" ]; then
    echo "Result:Pass${CL}" >> ${prt_path}/${OF}
  else
    echo "Result:Fail${CL}" >> ${prt_path}/${OF}
  fi
}


function main {
  burnin_cp_log  
  report_vpd_log
  report_bbu_log
  report_ntb_log ntb0 "10000"
  report_net_log ixl0 "6000"
  report_net_log ixl1 "6000"
  report_net_log ixl2 "6000"
  report_net_log ixl3 "6000"
  report_net_log igb0 ""
  report_net_log igb1 "600"
  report_net_log igb2 "600"
  report_smb_log vpd "-i fail"
  report_smb_log monitor "NOT_AVAILABLE"
  report_dd_speed
  report_enc_log
  report_camcontrol_devlist
  #report_ntb_pcie_error
  #report_pcie_link_speed
  report_summary
  burnin_tar_log
#  burnin_cp_usb
  return
}
#////////Start/////////
main
