#!/bin/bash

FIO_PATH="/tmp/burn/fio"
#FIO_PATH="./fio"
FIO_RUNTIME=21600  #1day=86400s
#FIO_RUNTIME=10  #1day=86400s
FIO_NUMJOBS=4
FIO_IODEPTH=32
FIO_IOENGINE="posixaio"
FIO_BS="1M"
FIO_SIZE="1G"  # The valu will be setted again by func_fio_to_stripe
FIO_RW="rw"
FIO_NAME="name=1M_seqrw"
FIO_COUNT=0

DD_SINGLE_BS="1M"
DD_SINGLE_COUNT="1024"
DD_SINGLE_SLEEP_SECONDS="10"

####################################################################################
# DD to the disk, and check execute time,                                          #
# Saving log in /tmp/log/first_disk_status/first_find_broken_disk_enc${enc_no}.txt #
####################################################################################
function func_check_enc_disk_by_dd {
    local slot_num=0
    local enc_num=$1
    local amount_of_disk=0

    amount_of_disk=$(sysctl -n qess.hw.hal.enc.${enc_num}.cb.1.disk.count)
    echo "Enc ${enc_num}, total disk:${amount_of_disk}"

    # List all disk on enclusure
    for((slot_num=1;slot_num<=amount_of_disk;slot_num=slot_num+1))
    do
        disk_name=$(sysctl -n qess.hw.hal.enc.${enc_num}.cb.1.disk.${slot_num}.name)

        # Checking none present disk
        if [ ${disk_name} = "none" ]; then
            echo "## Can't detected disk on enc${enc_num}, slot:${slot_num}... ##"
            echo "## Can't detected disk on enc${enc_num}, slot:${slot_num}... ##" >> /tmp/log/st_enc${enc_num}_log/dd_single.log
            continue
        fi

        echo "## dd zero to enc${enc_num}, slot:${slot_num}, ${disk_name}... ##"
        echo "## dd zero to enc${enc_num}, slot:${slot_num}, ${disk_name}... ##" >> /tmp/log/st_enc${enc_num}_log/dd_single.log
        echo "dd if=/dev/zero of=/dev/${disk_name} bs=${DD_SINGLE_BS} count=${DD_SINGLE_COUNT}"
        dd if=/dev/zero of=/dev/${disk_name} bs=${DD_SINGLE_BS} count=${DD_SINGLE_COUNT} &
        sleep ${DD_SINGLE_SLEEP_SECONDS}
        get_fail_pid=$(ps ax | grep dd | grep "${disk_name} "| awk '{print $1}')
        if [ "${get_fail_pid}" = "" ]; then
            echo "## dd zero to enc${enc_num}, slot:${slot_num}, ${disk_name} PASS... ##" >> /tmp/log/st_enc${enc_num}_log/dd_single.log
        else
            echo "## dd zero to ${disk_name} timeout ##"
            echo "## dd zero to enc${enc_num}, slot:${slot_num}, ${disk_name} FAIL... ##" >> /tmp/log/st_enc${enc_num}_log/dd_single.log
            kill ${get_fail_pid}
        fi
    done
}

function func_clear_enc_stripe_metadata {

    local enc_num=$1

    list=$(sysctl qess.hw.hal.enc.${enc_num}.cb.1.disk | grep name | grep -v mn | awk '{print $2}')
    for disk_name in ${list}
    do
        let "slot_num += 1"

        # Checking none present disk
        if [ ${disk_name} = "none" ]; then
            echo "## Can't detected disk on enc${enc_num}, slot:${slot_num}... ##"
            continue
        fi

        echo "## Clear Stripe Meta date on enc${enc_num}, slot:${slot_num}, ${disk_name}... ##"
        gstripe clear ${disk_name}
    done
}

function func_group_enc_disk {
    local enc_num=$1
    local disk_list=""

    list=$(sysctl qess.hw.hal.enc.${enc_num}.cb.1.disk | grep name | grep -v mn | awk '{print $2}')
    for disk_name in ${list}
    do
        let "slot_num += 1"

        # Checking none present disk
        if [ ${disk_name} = "none" ]; then
            echo "## Can't detected disk on enc${enc_num}, slot:${slot_num}... ##"
            continue
        fi

        disk_list=$(echo "${disk_list} ${disk_name}")

    done

    echo "Disk List:${disk_list}"
    echo "${disk_list}" > /tmp/log/st_enc${enc_num}_log/disk_list.txt
}

function func_create_stripe {

    local enc_num=$1
    local disk_list=""

    disk_list=$(cat /tmp/log/st_enc${enc_num}_log/disk_list.txt)

    echo "gstripe create -v st_enc${enc_num} ${disk_list}" > /tmp/log/st_enc${enc_num}_log/create_stripe.txt
    gstripe create -v st_enc${enc_num} ${disk_list}
}

function func_Initial_stripe {

    local enc_num=$1

    echo "==== Create File System on st_enc${enc_num} ===="
    newfs -U /dev/stripe/st_enc${enc_num}
}

function func_umount_stripe {

    local enc_num=$1

    echo "==== Umount /tmp/log/st_enc${enc_num} ===="
    umount -f /tmp/log/st_enc${enc_num}
}

function func_mount_stripe {

    local enc_num=$1

    # Check Mount point which is already mounted ?
    check_mount=$(mount | grep st_enc${enc_num})
    if [ "${check_mount}" != "" ]; then
        echo "==== Mount point had already mountd ===="
        echo "==== ${check_mount} ===="
        return
    fi

    echo "==== Mount /dev/stripe/st_enc${enc_num} on /tmp/log/st_enc${enc_num} ===="
    mount /dev/stripe/st_enc${enc_num} /tmp/log/st_enc${enc_num}
}

function func_fio_to_stripe {

    local enc_num=$1

    echo -n "DATE:" >> /tmp/log/st_enc${enc_num}_log/stress_${FIO_COUNT}.log
    date >> /tmp/log/st_enc${enc_num}_log/stress_${FIO_COUNT}.log
    ${FIO_PATH} --group_reporting --runtime=${FIO_RUNTIME} --direct=1 --time_based --ramp_time=0 --numjobs=${FIO_NUMJOBS} --iodepth=${FIO_IODEPTH} --ioengine=${FIO_IOENGINE} --bs=${FIO_BS} --size=${FIO_SIZE} --rw=${FIO_RW} --name=${FIO_NAME} --thread --fallocate=none --filename=/tmp/log/st_enc${enc_num}/fio.bin >> /tmp/log/st_enc${enc_num}_log/stress_${FIO_COUNT}.log
    echo "" >> /tmp/log/st_enc${enc_num}_log/stress_${FIO_COUNT}.log

    # Save the command
    echo "${FIO_PATH} --group_reporting --runtime=${FIO_RUNTIME} --direct=1 --time_based --ramp_time=0 --numjobs=${FIO_NUMJOBS} --iodepth=${FIO_IODEPTH} --ioengine=${FIO_IOENGINE} --bs=${FIO_BS} --size=${FIO_SIZE} --rw=${FIO_RW} --name=${FIO_NAME} --thread --fallocate=none --filename=/tmp/log/st_enc${enc_num}/fio.bin" > /tmp/log/st_enc${enc_num}_log/stress_${FIO_COUNT}_command.log

    # Save the FIO count
    echo "${FIO_COUNT}" > /tmp/log/st_enc${enc_num}_log/stress_count.log
    
    # Delete FIO bin
    rm /tmp/log/st_enc${enc_num}/fio.bin

    let "FIO_COUNT += 1"
}

function func_disk_stress_enc {

    local enc_num=$1
    local fio_count=0

    # Create folder
    mkdir /tmp/log/st_enc${enc_num}_log   #for log
    mkdir /tmp/log/st_enc${enc_num}       #for mount point

    # Initial
    umount -f /tmp/log/st_enc${enc_num} 
    gstripe stop -f st_enc${enc_num}

    # Clear meta data on each disk
    func_clear_enc_stripe_metadata ${enc_num}

    # DD each disk
    func_check_enc_disk_by_dd ${enc_num}

    # Group disk on enclosure
    func_group_enc_disk ${enc_num}

    # Create Stripe
    func_create_stripe ${enc_num}

    # Initial Script
    func_Initial_stripe ${enc_num}

    # Mount
    func_mount_stripe ${enc_num}

    # Fio to Stripe
    while true
    do
        func_fio_to_stripe ${enc_num}
        let "fio_count += 1"

        if [ "${fio_count}" = 8 ]; then
            ## Umount
            func_umount_stripe ${enc_num}

            ## Stop stripe
            gstripe stop -f st_enc${enc_num}

            ## FIO times is 8, meaning 2 days, return
            return
        fi
    done

}

function main {

    local enc_num=$1

    if [ "enc_num" = "" ]; then
        return
    fi

    fecho "==== Enclosure number:${enc_num} ===="
    func_disk_stress_enc ${enc_num}
}

main $1
