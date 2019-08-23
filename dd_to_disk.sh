#!/bin/bash

function main {
  slot_num=1

  disk_count=$(sysctl -n qess.hw.hal.enc.0.cb.1.disk.count)

  sysctl kern.geom.debugflags=0x10
  while true 
  do
      echo "#############################################"
      disk_name=$(sysctl -n qess.hw.hal.enc.0.cb.1.disk.${slot_num}.name)
      echo "DD slot ${slot_num}, /dev/${disk_name}"
      dd if=/dev/zero of=/dev/${disk_name} bs=1M count=1024

      if [ "${slot_num}" = "$disk_count" ]; then
          return
      fi
      let "slot_num=slot_num+1"
  done
  echo "#############################################"
}

main
