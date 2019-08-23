#!/bin/bash

#Sleep 2 day first
SLEEP_WAIT_PEER=178200

BURN_HDD_PROC_PATH="/tmp/burn/burn_hd_fio.sh"
#BURN_HDD_PROC_PATH="./burn_hd_fio.sh"

function func_disk_stress {

    local enc_num=0
    local slot_id=0
    local assign_cbid=$1

    slot_id=$(sysctl -n hw.enc.slotid)
    if [ "${slot_id}" != "${assign_cbid}" ]; then
        # Don't burn HDD
        echo "Slot ID ${slot_id} Don't burn HDD"
        return
    fi

    # get amount of enclosure
    local amount_of_enc=$(sysctl -n qess.hw.hal.enc.count)

    for((enc_num=0;enc_num<$amount_of_enc;enc_num=enc_num+1))
    do
        echo "==== Execute Stress on Enclosure ${enc_num} ===="
        ${BURN_HDD_PROC_PATH} ${enc_num} &
    done
}

function func_sca_waiting_stress_done {

    local slot_id=0
    local fio_ps=""

    slot_id=$(sysctl -n hw.enc.slotid)

    if [ "${slot_id}" = "0" ]; then
        # SCA
        # Sleep 2 day first
        sleep ${SLEEP_WAIT_PEER}

        pkill fio

        # Waiting for fio done
        while true
        do
            fio_ps=$(ps ax | grep fio | grep -v "grep")

            if [ "${fio_ps}" != "" ]; then
                # Still have fio process
                sleep 10
            else
                # There are no fio process, fio done
                /nas/util/qenc_cli set fp icon no 2 mode 2
                return
            fi
        done
    fi
}

function func_scb_waiting_fp {

    local slot_id=0
    local fp_str=""

    slot_id=$(sysctl -n hw.enc.slotid)

    if [ "${slot_id}" = "1" ]; then
        # SCB
        # Sleep 2 day first
        sleep ${SLEEP_WAIT_PEER}

        # Waiting for peer fio done
        while true
        do
            fp_str=$(/nas/util/qenc_cli get fp icon aline | grep "no:2" | grep "mode:2")

            if [ "${fp_str}" = "" ]; then
                # Peer still stressing
                sleep 10
            else
                # Peer fio done
                /nas/util/qenc_cli set fp icon mode 1
                return
            fi
        done
    fi
}

function main {

    sysctl kern.geom.debugflags=0x10

    ## Execute HDD stress on SCA
    func_disk_stress 0

    ## SCA Waiting for HDD stress finished and set fp
    func_sca_waiting_stress_done

    ## SCB waiting for fp change
    func_scb_waiting_fp

    ## Execute HDD stress on SCB
    func_disk_stress 1

}

main
