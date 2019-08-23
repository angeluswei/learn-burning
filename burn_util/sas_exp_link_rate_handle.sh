#!/bin/bash
################Define################
DIAG_VER="V:0.1"
DIAG_PID="$$"
DIAG_TIME=3
DIAG_THRESHOLD=3
DIAG_LOG="/tmp/hdd_diag_log"
DIAG_LOG_MAX_LINE=10000
DIAG_LATER="/tmp/hdd_diag_later"
DIAG_DELAY=1
DIAG_REDO_DELAY=25
DIAG_COUNT=0
DIAG_REDO_MAX=5
DIAG_TARGET="NULL"
DIAG_EXE_TEMP="/tmp/hdd_exe_${DIAG_PID}"
DIAG_NOTIFY_LIST="/tmp/hdd_notify_${DIAG_PID}"
DIAG_NOTIFY_SIO="/tmp/hdd_notify_sio"
DIAG_MODEL=""
CBID=$(/nas/util/qenc_cli get cbid | grep cbid)

################Notify Event################
#Notify the link rate change ses info to management
#In $1 is the change list file
############################################
function f_notify_event {
    notify_list=$(cat $1)
    local IFS=$(echo -en " \n\b")
    local cnt=0
    for info_value in $notify_list
    do
        let "cnt += 1"
        if [ "${info_value}" = "====Diag====" ]; then
            if [ "${cnt}" -gt "1" ]; then
                return
            fi
        elif [ "${info_value:0:3}" = "ses" ]; then
            echo "(/nas/util/devd_proc hdd_link_rate_change ${info_value})"
            (/nas/util/devd_proc hdd_link_rate_change ${info_value})
        fi
    done    
}

################Check EXP Model################
#Only for ES1640dc v2  & EJ1600 v2 expander
#In $1 is the sysctl node's jbod no
#Out the model name to global DIAG_MODEL
#Out the cbid to global CBID
###############################################
function f_check_exp_model {
    DIAG_MODEL=$(sysctl qess.hw.jbod.${1}.'%'product |grep 'ES1640dc v2\|EJ1600 v2')
    if [ "${DIAG_MODEL}" = "qess.hw.jbod.${1}.'%'product: EJ1600 v2" ]; then
        jbod_cb=$(sysctl qess.hw.jbod.${1}.'%'cb_id |awk '{print $2}')
        CBID="cbid:${jbod_cb}" 
#echo "Get JBOD CB:${CBID}"
    else
        CBID=$(/nas/util/qenc_cli get cbid | grep cbid)
    fi        
}

################HDD Phy T1 Error################
#Get the HDD phy error count and store it to DIAG_EXE_TEMP
#In $1 one hdd information from qses query_drive
#Out the HDD phy eccor count to DIAG_EXE_TEMP file
################################################ 
function f_hdd_err {
    local IFS=" "
    cnt=0
    hdd_info=$1
    for hdd_value in $hdd_info
    do
        let "cnt += 1"
        if [ "${hdd_value:0:4}" = "drv=" ]; then
            hdd_da=${hdd_value:4}
        fi
        if [ "${hdd_value:0:5}" = "jbod=" ]; then
            hdd_ses=ses${hdd_value:5}
        fi
        if [ "${hdd_value:0:6}" = "speed=" ]; then
            hdd_rate=${hdd_value:6}
        fi
        if [ "${hdd_value:0:5}" = "slot=" ]; then
            hdd_slot=${hdd_value:5}
        fi
#echo "debug1:${cnt}: ${hdd_value}"
    done

#Get T1
    hdd_error_t1=$(/usr/local/sbin/smartctl -x ${hdd_da} |grep "Running disparity error count =")
    cnt=0
    phy1_err_t1=0
    phy2_err_t1=0
    local IFS=$(echo -en " \n\b")
    for hdd_count in $hdd_error_t1
    do
        let "cnt += 1"
        if [ "${cnt}" = "6" ]; then
            phy1_err_t1=${hdd_count}
        fi
        if [ "${cnt}" = "12" ]; then
            phy2_err_t1=${hdd_count}
        fi
#echo "debug2:${cnt}: ${hdd_count}"
    done
#echo ":${hdd_da:5}:${phy1_err_t1}"
#echo ":${hdd_da:5}:${phy2_err_t1}" 
    if [ "${CBID}" = "cbid:1" ]; then
        echo ":${hdd_da:5}: ${phy1_err_t1}" >> ${DIAG_EXE_TEMP}
    else
        echo ":${hdd_da:5}: ${phy2_err_t1}" >> ${DIAG_EXE_TEMP}
    fi
    
    let "DIAG_COUNT += 1"
}

################Diag HDD By T1 Diff################
#Diag the Expander link rate by HDD phy error count
#with the T1 error count from DIAG_EXE_TEMP file 
#In $1 is one HDD info from qses query_drive
###################################################
function f_hdd_diag_t {
    local IFS=" "
    cnt=0
    hdd_info=$1
    for hdd_value in $hdd_info
    do
        let "cnt += 1"
        if [ "${hdd_value:0:4}" = "drv=" ]; then
            hdd_da=${hdd_value:4}
        fi
        if [ "${hdd_value:0:5}" = "jbod=" ]; then
            hdd_ses=ses${hdd_value:5}
        fi
        if [ "${hdd_value:0:6}" = "speed=" ]; then
            hdd_rate=${hdd_value:6}
        fi
        if [ "${hdd_value:0:5}" = "slot=" ]; then
            hdd_slot=${hdd_value:5}
        fi
#echo "debug1:${cnt}: ${hdd_value}"
    done
echo "check ${hdd_info}"
    if [ "${hdd_rate}" = "6G" ]; then
        echo "skip"
        return
    fi

#Get T1
    hdd_error_t1=$(/usr/bin/grep ":${hdd_da:5}:" ${DIAG_EXE_TEMP} | awk '{print $2}')
#echo "T1:${hdd_error_t1}"

#Get T2
    hdd_error_t2=$(/usr/local/sbin/smartctl -x ${hdd_da} |grep "Running disparity error count =")
    cnt=0
    phy1_err_t2=0
    phy2_err_t2=0
    local IFS=$(echo -en " \n\b")
    for hdd_count in $hdd_error_t2
    do
        let "cnt += 1"
        if [ "${cnt}" = "6" ]; then
            phy1_err_t2=${hdd_count}
        fi
        if [ "${cnt}" = "12" ]; then
            phy2_err_t2=${hdd_count}
        fi
#echo "debug3:${cnt}: ${hdd_count}"
    done

#echo "${hdd_da:5}"
#echo "$hdd_ses"
#echo "$hdd_rate"

#Diag the Result
    phy_ng=0
    if [ "${CBID}" = "cbid:1" ]; then
        let "phy_diff=$phy1_err_t2-$hdd_error_t1"
        if [ "${phy_diff}" -gt "${DIAG_THRESHOLD}" ]; then
            phy_ng="${phy_diff}"
        fi
    else
        let "phy_diff=$phy2_err_t2-$hdd_error_t1"
        if [ "${phy_diff}" -gt "${DIAG_THRESHOLD}" ]; then
            phy_ng="${phy_diff}"
        fi
    fi
    echo "Phy Diff[${CBID}]: ${phy_diff}"
#Need to Downgrade Link Rate
    if [ "${phy_ng}" -gt "0" ]; then
        echo "/sbin/camcontrol smpphylist ${hdd_ses} |grep ',${hdd_da:5})\|(${hdd_da:5},'" > /tmp/hdd_diag
        phy_info=$(/bin/bash /tmp/hdd_diag)
        (rm -f /tmp/hdd_diag)
        cnt=0
        phy_no="0xFF"
        local IFS=$(echo -en " \n\b")
        for phy_value in $phy_info
        do
            let "cnt += 1"
            if [ "${cnt}" = "1" ]; then
                 phy_id="${phy_value}"
                 printf -v phy_no "%02X" "${phy_value}"
            fi
            if [ "${cnt}" = "2" ]; then
                 phy_add="${phy_value}"
            fi
#echo "debug4:${cnt}: ${phy_value}"
        done

#echo "phy:${phy_no}"

#Judge Link Rate
        if [ "${hdd_rate}" = "12G" ]; then
            max_rate="0xA0"
            down_rate="6G"
        elif [ "${hdd_rate}" = "6G" ]; then
            max_rate="0x90"
            down_rate="3G"
        else
            max_rate="0x80"
            down_rate="1.5G"
        fi
echo "Down Rate:${max_rate}"

#Exe Down Rate
        if [ "${phy_no}" != "0xFF" ]; then
            echo "/sbin/camcontrol smpcmd ${hdd_ses} -v -r 40 '0x40 0x91 0x00 0x09 0x00 0x00 0x00 0x00 0x00 0x${phy_no} 0x01 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x08 ${max_rate} 0x00 0x00 0x00 0x00 0x00 0x00' -R 4 '0x41 0x11 0x00 0x00'" > /tmp/hdd_diag_${hdd_da:5}
            ret=$(/bin/bash /tmp/hdd_diag_${hdd_da:5})
            echo "Link Rate Degrade:${hdd_ses}:${hdd_rate}->${down_rate}, Phy:${phy_id}, Slot:${hdd_slot}, Name:${hdd_da:5}, Add:${phy_add}, Err:${phy_ng}" >> ${DIAG_LOG}
            (rm -f /tmp/hdd_diag_${hdd_da:5})
            date >> ${DIAG_LATER}
            echo "${hdd_ses}" >> ${DIAG_NOTIFY_LIST}
        fi
    fi 
}

################Diag################
#Diag the HDD link rate by phy error count
#In the $1 is one HDD info from qses query_drive
#Use the CBID to check the specified HDD's phy
####################################
function f_diag_hdd_link_rate {
    local IFS=" "
    cnt=0
    hdd_info=$1
    for hdd_value in $hdd_info
    do
        let "cnt += 1"
        if [ "${hdd_value:0:4}" = "drv=" ]; then
            hdd_da=${hdd_value:4}
        fi
        if [ "${hdd_value:0:5}" = "jbod=" ]; then
            hdd_ses=ses${hdd_value:5}
        fi
        if [ "${hdd_value:0:6}" = "speed=" ]; then
            hdd_rate=${hdd_value:6}
        fi
        if [ "${hdd_value:0:5}" = "slot=" ]; then
            hdd_slot=${hdd_value:5}
        fi
#echo "debug1:${cnt}: ${hdd_value}"
    done

echo "check ${hdd_info}"
    if [ "${hdd_rate}" = "6G" ]; then
        echo "skip"
        return
    fi

#Get T1
    hdd_error_t1=$(/usr/local/sbin/smartctl -x ${hdd_da} |grep "Running disparity error count =")
    cnt=0
    phy1_err_t1=0
    phy2_err_t1=0
    local IFS=$(echo -en " \n\b")
    for hdd_count in $hdd_error_t1
    do
        let "cnt += 1"
        if [ "${cnt}" = "6" ]; then
            phy1_err_t1=${hdd_count}
        fi
        if [ "${cnt}" = "12" ]; then
            phy2_err_t1=${hdd_count}
        fi
#echo "debug2:${cnt}: ${hdd_count}"
    done

    sleep ${DIAG_TIME}

#Get T2
    hdd_error_t2=$(/usr/local/sbin/smartctl -x ${hdd_da} |grep "Running disparity error count =")
    cnt=0
    phy1_err_t2=0
    phy2_err_t2=0
    local IFS=$(echo -en " \n\b")
    for hdd_count in $hdd_error_t2
    do
        let "cnt += 1"
        if [ "${cnt}" = "6" ]; then
            phy1_err_t2=${hdd_count}
        fi
        if [ "${cnt}" = "12" ]; then
            phy2_err_t2=${hdd_count}
        fi
#echo "debug3:${cnt}: ${hdd_count}"
    done

#echo "${hdd_da:5}"
#echo "$hdd_ses"
#echo "$hdd_rate"
#echo "T1P1:$phy1_err_t1"
#echo "T1P2:$phy2_err_t1"
#echo "T2P1:$phy1_err_t2"
#echo "T2P2:$phy2_err_t2"
    let "phy1_diff=$phy1_err_t2-$phy1_err_t1"
    let "phy2_diff=$phy2_err_t2-$phy2_err_t1"
    echo "Phy Diff: ${phy1_diff}, ${phy2_diff}"

#Diag the Result
    phy_ng=0
    if [ "${CBID}" = "cbid:1" ]; then
        if [ "${phy1_diff}" -gt "${DIAG_THRESHOLD}" ]; then
            phy_ng="${phy1_diff}"
        fi
    else
        if [ "${phy2_diff}" -gt "${DIAG_THRESHOLD}" ]; then
            phy_ng="${phy2_diff}"
        fi
    fi

#Need to Downgrade Link Rate
    if [ "${phy_ng}" -gt "0" ]; then
        echo "/sbin/camcontrol smpphylist ${hdd_ses} |grep ',${hdd_da:5})\|(${hdd_da:5},'" > /tmp/hdd_diag
        phy_info=$(/bin/bash /tmp/hdd_diag)

        (rm -f /tmp/hdd_diag)
        cnt=0
        phy_no="0xFF"
        local IFS=$(echo -en " \n\b")
        for phy_value in $phy_info
        do
            let "cnt += 1"
            if [ "${cnt}" = "1" ]; then
                 phy_id="${phy_value}"
                 printf -v phy_no "%02X" "${phy_value}"
            fi
            if [ "${cnt}" = "2" ]; then
                 phy_add="${phy_value}"
            fi
#echo "debug4:${cnt}: ${phy_value}"
        done

#echo "phy:${phy_no}"

#Judge Link Rate
        if [ "${hdd_rate}" = "12G" ]; then
            max_rate="0xA0"
            down_rate="6G"
        elif [ "${hdd_rate}" = "6G" ]; then
            max_rate="0x90"
            down_rate="3G"
        else
            max_rate="0x80"
            down_rate="1.5G"
        fi
echo "Down Rate:${max_rate}"

#Exe Down Rate
#echo "${hdd_ses}"
   
        if [ "${phy_no}" != "0xFF" ]; then
            echo "/sbin/camcontrol smpcmd ${hdd_ses} -v -r 40 '0x40 0x91 0x00 0x09 0x00 0x00 0x00 0x00 0x00 0x${phy_no} 0x01 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x08 ${max_rate} 0x00 0x00 0x00 0x00 0x00 0x00' -R 4 '0x41 0x11 0x00 0x00'" > /tmp/hdd_diag_${hdd_da:5}
            ret=$(/bin/bash /tmp/hdd_diag_${hdd_da:5})
            echo "Link Rate Degrade:${hdd_ses}:${hdd_rate}->${down_rate}, Phy:${phy_id}, Slot:${hdd_slot}, Name:${hdd_da:5}, Add:${phy_add}, Err:${phy_ng}" >> ${DIAG_LOG}
            (rm -f /tmp/hdd_diag_${hdd_da:5})
            DIAG_TARGET="${hdd_ses}"
            date >> ${DIAG_LATER}_${DIAG_PID}
            echo "${hdd_ses}" >> ${DIAG_NOTIFY_LIST} 
        fi
    fi  
}

################Diag All#############
#Execute the Diag CMD
#diag all the SAS3 expander link rate
#####################################
function f_cmd_diag {
    ses_list=$(/nas/util/qses display)
    for ses_dev in ${ses_list}
    do
        ses_no=$(echo "${ses_dev}" | awk -F":" '{print $1}' |grep "/dev/ses")
        if [ "${ses_no}" = "" ]; then
            continue
        else
echo "Check ${ses_no}"
            f_check_exp_model "${ses_no:8}"
            if [ "${DIAG_MODEL}" = "" ]; then
                continue
            else
echo "Scan ${DIAG_MODEL}"
                local IFS=$(echo -en "\n\b")

                echo "/nas/util/qses query_drive |grep 'jbod=${ses_no:8} s' |grep speed=12G" > ${DIAG_EXE_TEMP}
                hdd_list=$(/bin/bash ${DIAG_EXE_TEMP})
                (rm -f ${DIAG_EXE_TEMP})
                date > ${DIAG_EXE_TEMP}
                DIAG_COUNT=0
                for hdd_info in $hdd_list
                do
                    f_hdd_err "${hdd_info}"
                done
                sleep ${DIAG_TIME}
                for hdd_info in $hdd_list
                do
                    f_hdd_diag_t "${hdd_info}"
                done
                (rm -f ${DIAG_EXE_TEMP})
            fi
        fi
    done        
}

################Diag HDD#############
#Execute the Diag HDD CMD
#In the $1 is the select HDD
#####################################
function f_cmd_diag_hdd {
    da_name=$1
    echo "/nas/util/qses query_drive |grep '${da_name} j'" > ${DIAG_EXE_TEMP}
    hdd_info=$(/bin/bash ${DIAG_EXE_TEMP})
    (rm -f ${DIAG_EXE_TEMP})
    ses_no=$(echo "${hdd_info}" |awk '{print $2}')
    if [ "ses_no" = "" ]; then
        echo "Not a sas expander device!"
        return
    fi
    local IFS=$(echo -en "\n\b")
   
#echo "${DIAG_TARGET}"
    f_check_exp_model "${ses_no:5}"
    if [ "${DIAG_MODEL}" = "" ]; then
        echo "Not support model!"
        return
    else
#echo "${hdd_info}"
        f_diag_hdd_link_rate ${hdd_info}
        (rm -f ${DIAG_EXE_TEMP})
    fi
}

################Diag SES#############
#Execute the Diag SES CMD
#In the $1 is the select ses
#####################################
function f_cmd_diag_ses {
    ses_name="$1"
    f_check_exp_model "${ses_name:3}"
    if [ "${DIAG_MODEL}" = "" ]; then
        echo "Not support model!"
        return
    fi

    local IFS=$(echo -en "\n\b")
    echo "/nas/util/qses query_drive |grep 'jbod=${ses_name:3} s' |grep speed=12G" > ${DIAG_EXE_TEMP}
    hdd_list=$(/bin/bash ${DIAG_EXE_TEMP})
    (rm -f ${DIAG_EXE_TEMP})
    if [ "${hdd_list}" = "" ]; then
        echo "No avaliable HDD!"
        return
    fi

    date > ${DIAG_EXE_TEMP}
    for hdd_info in $hdd_list
    do
        f_hdd_err "${hdd_info}"
    done
    sleep ${DIAG_TIME}
    for hdd_info in $hdd_list
    do
        f_hdd_diag_t "${hdd_info}"
    done
    (rm -f ${DIAG_EXE_TEMP})
}

################Diag SIO#############
#diag the expander link rate by cam flag
#In $1 is one hdd_info from qses query_drive
#####################################
function f_sio_diag {
    local IFS=" "
    cnt=0
    hdd_info=$1
    for hdd_value in $hdd_info
    do
        let "cnt += 1"
        if [ "${hdd_value:0:4}" = "drv=" ]; then
            hdd_da=${hdd_value:4}
        fi
        if [ "${hdd_value:0:5}" = "jbod=" ]; then
            hdd_ses=ses${hdd_value:5}
        fi
        if [ "${hdd_value:0:6}" = "speed=" ]; then
            hdd_rate=${hdd_value:6}
        fi
        if [ "${hdd_value:0:5}" = "slot=" ]; then
            hdd_slot=${hdd_value:5}
        fi
#echo "debug1:${cnt}: ${hdd_value}"
    done
echo "check ${hdd_info}"
    if [ "${hdd_rate}" = "6G" ]; then
        echo "skip"
        return
    fi

    diag_value=$(sysctl kern.cam.da.${hdd_da:7}.link_rate_diag)

echo "${diag_value}"
#Diag the Result
    if [ "${diag_value}" = "kern.cam.da.${hdd_da:7}.link_rate_diag: 0" ]; then
        phy_ng=0
    elif [ "${diag_value}" = "" ]; then
        phy_ng=0
    else
        phy_ng=1       
    fi
echo "er:${phy_ng}"
#Need to Downgrade Link Rate
    if [ "${phy_ng}" -gt "0" ]; then
        echo "/sbin/camcontrol smpphylist ${hdd_ses} |grep ',${hdd_da:5})\|(${hdd_da:5},'" > /tmp/hdd_diag
        phy_info=$(/bin/bash /tmp/hdd_diag)
        (rm -f /tmp/hdd_diag)
        cnt=0
        phy_no="0xFF"
        local IFS=$(echo -en " \n\b")
        for phy_value in $phy_info
        do
            let "cnt += 1"
            if [ "${cnt}" = "1" ]; then
                 phy_id="${phy_value}"
                 printf -v phy_no "%02X" "${phy_value}"
            fi
            if [ "${cnt}" = "2" ]; then
                 phy_add="${phy_value}"
            fi
#echo "debug4:${cnt}: ${phy_value}"
        done

#echo "phy:${phy_no}"

#Judge Link Rate
        if [ "${hdd_rate}" = "12G" ]; then
            max_rate="0xA0"
            down_rate="6G"
        else
            phy_no="0xFF"
        fi

#echo "Down Rate:${max_rate}"

#Exe Down Rate        
        if [ "${phy_no}" != "0xFF" ]; then
            echo "/sbin/camcontrol smpcmd ${hdd_ses} -v -r 40 '0x40 0x91 0x00 0x09 0x00 0x00 0x00 0x00 0x00 0x${phy_no} 0x01 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x08 ${max_rate} 0x00 0x00 0x00 0x00 0x00 0x00' -R 4 '0x41 0x11 0x00 0x00'" > /tmp/hdd_diag_${hdd_da:5}
            ret=$(/bin/bash /tmp/hdd_diag_${hdd_da:5})
            echo "Link Rate Degrade:${hdd_ses}:${hdd_rate}->${down_rate}, Phy:${phy_id}, Slot:${hdd_slot}, Name:${hdd_da:5}, Add:${phy_add}, Err:${phy_ng}" >> ${DIAG_LOG}
            (rm -f /tmp/hdd_diag_${hdd_da:5})
            echo "${hdd_ses}" >> ${DIAG_NOTIFY_SIO}
        fi
    fi

}

################Diag SIO################
#Run the SIO CMD from kernel signal
#####################################
function f_cmd_diag_sio {
    local IFS=$(echo -en "\n\b")
    DIAG_TARGET="ses${ses_id:14}"
    hdd_list=$(/nas/util/qses query_drive |grep 'speed=12G')

    for hdd_info in $hdd_list
    do
#echo "Diag:${hdd_info}"
    f_sio_diag "${hdd_info}"
    done
}

################Clear################
#Reset the specified expander slot link rate to 12G
#if it avaliable in diag_log 
#In $1 is the sesN name
#In $2 is the hdd slot No
#####################################
function f_cmd_clear {
    hdd_ses=$1
    hdd_info=$(/bin/cat ${DIAG_LOG} |grep Degrade |grep ${hdd_ses}: |grep Slot:${2}, | tail -n1)
#echo "$hdd_info"
    local IFS=" ,"
    cnt=0
    phy_no="0xFF"
    for hdd_value in $hdd_info
    do
        let "cnt += 1"
        if [ "${hdd_value:0:4}" = "Phy:" ]; then
            printf -v phy_no "%02X" "${hdd_value:4}"
        fi
#echo "debug5:${cnt}: ${hdd_value}"
    done

#Reset Link Rate
    if [ "${phy_no}" != "0xFF" ]; then
        max_rate="0xB0"
        echo "/sbin/camcontrol smpcmd ${hdd_ses} -v -r 40 '0x40 0x91 0x00 0x09 0x00 0x00 0x00 0x00 0x00 0x${phy_no} 0x01 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x08 ${max_rate} 0x00 0x00 0x00 0x00 0x00 0x00' -R 4 '0x41 0x11 0x00 0x00'" > /tmp/hdd_diag_${phy_no}
        ret=$(/bin/bash /tmp/hdd_diag_${phy_no})
        echo "Clear Done" >> ${DIAG_LOG}
        echo "Clear Done"
        (rm -f /tmp/hdd_diag_${phy_no})
    else
        echo "Skip Done" >> ${DIAG_LOG}
        echo "Skip Done"
    fi
}

################Execuate CMD Reinit################
#Reset all the avaliable sas3 expander to 12G link rate
###################################################
function f_cmd_reinit {
    ses_list=$(/nas/util/qses display)
    for ses_dev in ${ses_list}
    do
        ses_no=$(echo "${ses_dev}" | awk -F":" '{print $1}' |grep "/dev/ses")
        if [ "${ses_no}" = "" ]; then
            continue
        else
echo "Check ${ses_no:5}"
            f_check_exp_model "${ses_no:8}"
            if [ "${DIAG_MODEL}" = "" ]; then
                continue
            else
echo "Reinit ${DIAG_MODEL}"
            echo "/sbin/camcontrol smpphylist ${ses_no:5} |grep '(${ses_no:5},\|,${ses_no:5})'" > /tmp/hdd_rinit
            phy_max=$(/bin/bash /tmp/hdd_rinit |awk '{print $1}')
            (rm -f /tmp/hdd_rinit)
            hdd_ses=${ses_no:5}
            phy_id=12
            max_rate="0xB0"
            while [ "${phy_id}" -lt "${phy_max}" ]; do
                printf -v phy_no "%02X" "${phy_id}"
                echo "/sbin/camcontrol smpcmd ${hdd_ses} -v -r 40 '0x40 0x91 0x00 0x09 0x00 0x00 0x00 0x00 0x00 0x${phy_no} 0x01 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x08 ${max_rate} 0x00 0x00 0x00 0x00 0x00 0x00' -R 4 '0x41 0x11 0x00 0x00'" > /tmp/hdd_diag_rinit
                ret=$(/bin/bash /tmp/hdd_diag_rinit)
                echo "Link Rate Rinit:${hdd_ses}:Phy:${phy_id}" >> ${DIAG_LOG}
                (rm -f /tmp/hdd_diag_rinit)
                let "phy_id += 1"
                sleep ${DIAG_DELAY}
            done
            fi
        fi
    done  
}

################Main################
#Execute the CLI input CMD
#Util usage
####################################
function main {
#Do Diag
    if [ "$1" = "diag" ]; then
        echo "Scan SAS Expander Diagnostic"
        #Check Diag If Running
        check_exe=$(/bin/ps -ax |grep sas_exp_link_rate_handle |grep diag |wc |awk '{print $1}')
        #echo $check_exe
        if [ "${check_exe}" -gt "3" ]; then
            date >> ${DIAG_LATER}
            echo "Will Do Diag Later!"
            return
        fi

        #Check log lines
        if [ -f ${DIAG_LOG} ]; then
            log_line=$(wc -l ${DIAG_LOG} |awk '{print $1}')
            if [ ${log_line} -gt ${DIAG_LOG_MAX_LINE} ]; then
                (rm -f ${DIAG_LOG})
            fi
        fi

        do_diag=1
        do_times=0
        while [ "${do_diag}" = "1" ]; do
            echo "Do SAS Expander Diag" >> ${DIAG_LOG}
            date >> ${DIAG_LOG}
            let "do_times += 1"
            echo "====Diag====" >> ${DIAG_NOTIFY_LIST}
            f_cmd_diag

            if [ -f ${DIAG_LATER} ]; then
                if [ "${DIAG_REDO_DELAY}" -gt "${DIAG_COUNT}" ]; then
                    let "do_sleep = DIAG_REDO_DELAY - DIAG_COUNT"
                    echo "sleep ${do_sleep} sec"
                    sleep ${do_sleep}
                fi                
                (/nas/util/qses scan_jbod)
                (rm -f ${DIAG_LATER})
                do_diag=1
                if [ "${do_times}" -gt "${DIAG_REDO_MAX}" ]; then
                    echo "Max Redo" >> ${DIAG_LOG}
                    return
                fi                 
            else
                do_diag=0
            fi
        done

        #Event to Mgmt
        f_notify_event ${DIAG_NOTIFY_LIST}
        (rm -f ${DIAG_NOTIFY_LIST})

#Do DIAG HDD
    elif [[ "$1" = "diag_hdd" && "$2" != "" ]]; then
        local target_name=$2
        echo "Do Expander HDD Diagnostic"
        #Check Diag If Running
        check_exe=$(/bin/ps -ax |grep bash |grep $1 |grep $2 |wc |awk '{print $1}')
        #echo $check_exe
#echo "RUN:${check_exe}"
        if [ "${check_exe}" -gt "2" ]; then
            echo "Diag ${2} already running!"
            return
        fi

        do_diag=1
        do_times=0
        while [ "${do_diag}" = "1" ]; do
            echo "Do Expander HDD Diag" >> ${DIAG_LOG}
            date >> ${DIAG_LOG}
            let "do_times += 1"
            echo "====Diag====" >> ${DIAG_NOTIFY_LIST}
            f_cmd_diag_hdd $2

            if [ -f ${DIAG_LATER}_${DIAG_PID} ]; then
                (rm -f ${DIAG_LATER}_${DIAG_PID})
                let "do_sleep = DIAG_REDO_DELAY - DIAG_COUNT"
                echo "sleep ${do_sleep} sec"
                while [ "${do_sleep}" -gt "0" ]; do
                    if [ -e "/dev/${target_name}" ]; then 
                        let "do_sleep -= 1"
                        sleep 1
                    else
                        echo "/dev/${target_name} is gone!"
                        return
                    fi            
                done
                (/nas/util/qses scan_jbod)
                do_diag=1
                if [ "${do_times}" -gt "${DIAG_REDO_MAX}" ]; then
                    echo "Max Redo" >> ${DIAG_LOG}
                    return
                fi                 
            else
                do_diag=0
            fi
        done
        #Event to Mgmt
        f_notify_event ${DIAG_NOTIFY_LIST}
        (rm -f ${DIAG_NOTIFY_LIST})

#Do DIAG SES
    elif [[ "$1" = "diag_ses" && "$2" != "" ]]; then
        local target_name=$2
        echo "Do ses Diagnostic"
        #Check Diag If Running
        check_exe=$(/bin/ps -ax |grep sas_exp_link_rate_handle |grep diag_ses |grep $2 |wc |awk '{print $1}')
        #echo $check_exe
        if [ "${check_exe}" -gt "2" ]; then
            date >> ${DIAG_LATER}
            echo "Will Do Diag Later!"
            return
        fi
        do_diag=1
        do_times=0
        while [ "${do_diag}" = "1" ]; do
            echo "Do ses Diag" >> ${DIAG_LOG}
            date >> ${DIAG_LOG}
            let "do_times += 1"
            echo "====Diag====" >> ${DIAG_NOTIFY_LIST}
            f_cmd_diag_ses $2

            if [ -f ${DIAG_LATER} ]; then
                if [ "${DIAG_REDO_DELAY}" -gt "${DIAG_COUNT}" ]; then
                    let "do_sleep = DIAG_REDO_DELAY - DIAG_COUNT"
                    echo "sleep ${do_sleep} sec"
                    while [ "${do_sleep}" -gt "0" ]; do
                        if [ -e "/dev/${target_name}" ]; then 
                            let "do_sleep -= 1"
                            sleep 1
                        else
                            echo "/dev/${target_name} is gone!"
                            return
                        fi            
                    done
                fi                
                (/nas/util/qses scan_jbod)
                (rm -f ${DIAG_LATER})
                do_diag=1
                if [ "${do_times}" -gt "${DIAG_REDO_MAX}" ]; then
                    echo "Max Redo" >> ${DIAG_LOG}
                    return
                fi                 
            else
                do_diag=0
            fi
        done
        #Event to Mgmt
        f_notify_event ${DIAG_NOTIFY_LIST}
        (rm -f ${DIAG_NOTIFY_LIST})

###Do DIAG SIO##
    elif [ "$1" = "diag_sio" ]; then
        echo "Scan SAS Expander SIO Diagnostic"
        echo "Do SAS Expander SIO Diag" >> ${DIAG_LOG}
        date >> ${DIAG_LOG}
        f_cmd_diag_sio

###Do Clear###
    elif [[ "$1" = "clear" && "$2" != "" && $3 != "" ]]; then
        echo "Link Rate Clear:${2}, Slot:${3}"
        echo "Do SAS Expander Clear" >> ${DIAG_LOG}
        date >> ${DIAG_LOG}
        echo "Link Rate Clear:${2}, Slot:${3}" >> ${DIAG_LOG}
        f_cmd_clear $2 $3

###Reinit###
    elif [ "$1" = "reinit" ]; then
        echo "Link Rate Reinit"
        echo "Do SAS Expander Reinit" >> ${DIAG_LOG}
        date >> ${DIAG_LOG}
        f_cmd_reinit

###Usage###
    else
        echo "sas_exp_link_rate_handle.sh (${DIAG_VER})"
        echo "Usage:"
        echo "sas_exp_link_rate_handle.sh diag"
        echo "sas_exp_link_rate_handle.sh diag_hdd <da_name>" 
        echo "sas_exp_link_rate_handle.sh diag_ses <ses_name>" 
        echo "sas_exp_link_rate_handle.sh diag_sio"
        echo "sas_exp_link_rate_handle.sh clear <ses_no> <slot_no>"
        echo "sas_exp_link_rate_handle.sh reinit"
    fi

    return
}

#start up
main $1 $2 $3

