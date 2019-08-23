#!/bin/bash

NTB_ETHER_NAME="ntb0"

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

function main {

    local cmd_id=$(/nas/util/qenc_cli get cbid | grep cbid)
    local cb_id=${cmd_id:5:1}

    # init NTB
    init_ntb ${cb_id}
}

main

