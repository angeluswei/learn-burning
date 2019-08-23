#!/bin/bash

function main {
  slot_num=1
  disk_list=$(sysctl qess.hw.jbod.0 | grep name| grep da | awk '{print $2}')

  for disk_name in ${disk_list}
  do
      echo "#############################################"
      echo "slot ${slot_num}, ${disk_name}"
      smartctl -x ${disk_name} | grep " disparity error"
      let "slot_num=slot_num+1"
  done
  echo "#############################################"
}

main
