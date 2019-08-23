#!/bin/bash

function wait_for_new_raid {
  local enc_dev=$(ls /dev/enc*);
  for dev_no in $enc_dev
  do
    enc_num=${dev_no:8:1}
    while true
    do
      if [ -f "/tmp/enc${enc_num}_hdd_list_new" ]; then
        echo "@@ enc${enc_num}_hdd_list_new exist! wait for new RAID @@"
        sleep 10
      else
        return
      fi
    done
  done
}

function kick_disk {
  local error_enc_num=$1
  local error_disk=$2

  if [ "${error_disk}" = "da1" ]; then
    cat /tmp/enc${error_enc_num}_hdd_list | sed 's/da1 / /' > /tmp/enc${error_enc_num}_hdd_list_new
  elif [ "${error_disk}" = "da2" ]; then
    cat /tmp/enc${error_enc_num}_hdd_list | sed 's/da2 / /' > /tmp/enc${error_enc_num}_hdd_list_new
  elif [ "${error_disk}" = "da3" ]; then
    cat /tmp/enc${error_enc_num}_hdd_list | sed 's/da3 / /' > /tmp/enc${error_enc_num}_hdd_list_new
  elif [ "${error_disk}" = "da4" ]; then
    cat /tmp/enc${error_enc_num}_hdd_list | sed 's/da4 / /' > /tmp/enc${error_enc_num}_hdd_list_new
  elif [ "${error_disk}" = "da5" ]; then
    cat /tmp/enc${error_enc_num}_hdd_list | sed 's/da5 / /' > /tmp/enc${error_enc_num}_hdd_list_new
  elif [ "${error_disk}" = "da6" ]; then
    cat /tmp/enc${error_enc_num}_hdd_list | sed 's/da6 / /' > /tmp/enc${error_enc_num}_hdd_list_new
  elif [ "${error_disk}" = "da7" ]; then
    cat /tmp/enc${error_enc_num}_hdd_list | sed 's/da7 / /' > /tmp/enc${error_enc_num}_hdd_list_new
  elif [ "${error_disk}" = "da8" ]; then
    cat /tmp/enc${error_enc_num}_hdd_list | sed 's/da8 / /' > /tmp/enc${error_enc_num}_hdd_list_new
  elif [ "${error_disk}" = "da9" ]; then
    cat /tmp/enc${error_enc_num}_hdd_list | sed 's/da9 / /' > /tmp/enc${error_enc_num}_hdd_list_new
  elif [ "${error_disk}" = "da10" ]; then
    cat /tmp/enc${error_enc_num}_hdd_list | sed 's/da10//' > /tmp/enc${error_enc_num}_hdd_list_new
  elif [ "${error_disk}" = "da11" ]; then
    cat /tmp/enc${error_enc_num}_hdd_list | sed 's/da11//' > /tmp/enc${error_enc_num}_hdd_list_new
  elif [ "${error_disk}" = "da12" ]; then
    cat /tmp/enc${error_enc_num}_hdd_list | sed 's/da12//' > /tmp/enc${error_enc_num}_hdd_list_new
  elif [ "${error_disk}" = "da13" ]; then
    cat /tmp/enc${error_enc_num}_hdd_list | sed 's/da13//' > /tmp/enc${error_enc_num}_hdd_list_new
  elif [ "${error_disk}" = "da14" ]; then
    cat /tmp/enc${error_enc_num}_hdd_list | sed 's/da14//' > /tmp/enc${error_enc_num}_hdd_list_new
  elif [ "${error_disk}" = "da15" ]; then
    cat /tmp/enc${error_enc_num}_hdd_list | sed 's/da15//' > /tmp/enc${error_enc_num}_hdd_list_new
  elif [ "${error_disk}" = "da16" ]; then
    cat /tmp/enc${error_enc_num}_hdd_list | sed 's/da16//' > /tmp/enc${error_enc_num}_hdd_list_new
  elif [ "${error_disk}" = "da17" ]; then
    cat /tmp/enc${error_enc_num}_hdd_list | sed 's/da17//' > /tmp/enc${error_enc_num}_hdd_list_new
  elif [ "${error_disk}" = "da18" ]; then
    cat /tmp/enc${error_enc_num}_hdd_list | sed 's/da18//' > /tmp/enc${error_enc_num}_hdd_list_new
  elif [ "${error_disk}" = "da19" ]; then
    cat /tmp/enc${error_enc_num}_hdd_list | sed 's/da19//' > /tmp/enc${error_enc_num}_hdd_list_new
  elif [ "${error_disk}" = "da20" ]; then
    cat /tmp/enc${error_enc_num}_hdd_list | sed 's/da20//' > /tmp/enc${error_enc_num}_hdd_list_new
  elif [ "${error_disk}" = "da21" ]; then
    cat /tmp/enc${error_enc_num}_hdd_list | sed 's/da21//' > /tmp/enc${error_enc_num}_hdd_list_new
  elif [ "${error_disk}" = "da22" ]; then
    cat /tmp/enc${error_enc_num}_hdd_list | sed 's/da22//' > /tmp/enc${error_enc_num}_hdd_list_new
  elif [ "${error_disk}" = "da23" ]; then
    cat /tmp/enc${error_enc_num}_hdd_list | sed 's/da23//' > /tmp/enc${error_enc_num}_hdd_list_new
  elif [ "${error_disk}" = "da24" ]; then
    cat /tmp/enc${error_enc_num}_hdd_list | sed 's/da24//' > /tmp/enc${error_enc_num}_hdd_list_new
  elif [ "${error_disk}" = "da25" ]; then
    cat /tmp/enc${error_enc_num}_hdd_list | sed 's/da25//' > /tmp/enc${error_enc_num}_hdd_list_new
  elif [ "${error_disk}" = "da26" ]; then
    cat /tmp/enc${error_enc_num}_hdd_list | sed 's/da26//' > /tmp/enc${error_enc_num}_hdd_list_new
  elif [ "${error_disk}" = "da27" ]; then
    cat /tmp/enc${error_enc_num}_hdd_list | sed 's/da27//' > /tmp/enc${error_enc_num}_hdd_list_new
  elif [ "${error_disk}" = "da28" ]; then
    cat /tmp/enc${error_enc_num}_hdd_list | sed 's/da28//' > /tmp/enc${error_enc_num}_hdd_list_new
  elif [ "${error_disk}" = "da29" ]; then
    cat /tmp/enc${error_enc_num}_hdd_list | sed 's/da29//' > /tmp/enc${error_enc_num}_hdd_list_new
  elif [ "${error_disk}" = "da30" ]; then
    cat /tmp/enc${error_enc_num}_hdd_list | sed 's/da30//' > /tmp/enc${error_enc_num}_hdd_list_new
  elif [ "${error_disk}" = "da31" ]; then
    cat /tmp/enc${error_enc_num}_hdd_list | sed 's/da31//' > /tmp/enc${error_enc_num}_hdd_list_new
  elif [ "${error_disk}" = "da32" ]; then
    cat /tmp/enc${error_enc_num}_hdd_list | sed 's/da32//' > /tmp/enc${error_enc_num}_hdd_list_new
  else
    echo "@@ error disk:${error_disk}, input error @@"
  fi
}

function check_disk_lose_1 {
  check_msg=$(cat /tmp/log/dmesg_log_5s/msg_diff.txt | grep "g_vfs_done():mpslsi" | grep da | sed 's/:/ /' | sed 's/st_enc/ /' | sed 's/(//' )
  if [ "${check_msg}" != "" ]; then
    cat /tmp/log/dmesg_log_5s/msg_diff.txt | grep "g_vfs_done():mpslsi" | grep da | sed 's/:/ /' | sed 's/st_enc/ /' | sed 's/(//' > /tmp/log/dmesg_log_5s/err_msg.txt

    error_enc_str=$(cat /tmp/log/dmesg_log_5s/err_msg.txt | awk '{print $4}')
    error_enc_num=${error_enc_str:0:1}
    error_disk_list=$(cat /tmp/log/dmesg_log_5s/err_msg.txt | awk '{print $2}')

    echo "error_enc_str:${error_enc_str}"
    echo "error_enc_num:${error_enc_num}"
    echo "error_disk_list:${error_disk_list}"

    old_disk=""
    new_disk=""
    for error_disk in ${error_disk_list}
    do
      new_disk=${error_disk}
      if [ "${old_disk}" != "${new_disk}" ]; then
        kick_disk ${error_enc_num} ${error_disk}
      fi
      old_disk=${error_disk}
    done
  fi
}

function check_disk_lose_2 {
  check_msg=$(cat /tmp/log/dmesg_log_5s/msg_diff.txt | grep "GEOM_STRIPEmpslsi" | grep "removed")
  if [ "${check_msg}" != "" ]; then
    cat /tmp/log/dmesg_log_5s/msg_diff.txt |grep "GEOM_STRIPEmpslsi" | grep "removed" > /tmp/log/dmesg_log_5s/err_msg.txt

    error_enc_str=$(cat /tmp/log/dmesg_log_5s/err_msg.txt | awk '{print $7}')
    error_enc_num=${error_enc_str:0:6}
    error_disk_list=$(cat /tmp/log/dmesg_log_5s/err_msg.txt | awk '{print $4}')

    echo "error_enc_str:${error_enc_str}"
    echo "error_enc_num:${error_enc_num}"
    echo "error_disk_list:${error_disk_list}"

    old_disk=""
    new_disk=""
    for error_disk in ${error_disk_list}
    do
      new_disk=${error_disk}
      if [ "${old_disk}" != "${new_disk}" ]; then
        kick_disk ${error_enc_num} ${error_disk}
      fi
      old_disk=${error_disk}
    done
  fi
}

function check_mpslsi_error {
  mpslsi_error_msg=$(cat /tmp/log/dmesg_log_5s/msg_diff.txt | grep mpslsi | grep terminated)
  if [ "${mpslsi_error_msg}" != "" ]; then
    error_disk_list=$(cat /tmp/log/dmesg_log_5s/msg_diff.txt | grep mpslsi | grep terminated | sed 's/(//' | sed 's/:/ /' | awk '{print $2}')

    old_disk=""
    new_disk=""

    for error_disk in ${error_disk_list}
    do
      new_disk=${error_disk}
      error_enc_num=$(sysctl qess.hw.hal.enc. |grep name | grep -v mn |grep disk | sed 's/enc./ /' | sed 's/.disk/ /' | grep "${error_disk}" | grep -v "${error_disk}." | awk '{print $2}')
 
      if [ "${old_disk}" != "${new_disk}" ]; then
        kick_disk ${error_enc_num} ${error_disk}
      fi
      old_disk=${error_disk}
    done
  fi
}

function main {
  mkdir /tmp/log/dmesg_log_5s
  echo "" /tmp/log/dmesg_log_5s/msg_diff.txt

  while true
  do
    dmesg > /tmp/log/dmesg_log_5s/old_msg.txt
    ###########################################
    (check_disk_lose_1)
    (wait_for_new_raid)

    (check_disk_lose_2)
    (wait_for_new_raid)

    (check_mpslsi_error)
    (wait_for_new_raid)
    ###########################################
    (sleep 5)
    dmesg > /tmp/log/dmesg_log_5s/new_msg.txt
    diff /tmp/log/dmesg_log_5s/old_msg.txt /tmp/log/dmesg_log_5s/new_msg.txt > /tmp/log/dmesg_log_5s/msg_diff.txt
  done
}

main
