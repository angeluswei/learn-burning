#!/bin/bash

usage ()
{
  echo "Usage : expander_io_error_report.sh [expander device] [RUN_TIME] [THRESHOLD]"
  echo 'RUN_TIME  : N senconds'
  echo 'THRESHOLD  : number of error count in RUN_TIME period'
  echo ' '
  exit
}

if [ "$#" -gt 3 ]; then
    usage
    exit 1
fi
if [ "x$1" = "x" ]; then
    usage
    exit 1
elif [ "x$2" = "x" ]; then
	TARGET=$1
    RUN_TIME=60
    THRESHOLD=10
elif [ "x$3" = "x" ]; then
	TARGET=$1
    RUN_TIME=$2
    if [ ${RUN_TIME} -gt "60" ]; then
        THRESHOLD=$((${RUN_TIME} * 10 / 60))
    else
        THRESHOLD=10
    fi
else
	TARGET=$1
    RUN_TIME=$2
    THRESHOLD=$3
fi

echo "RUN_TIME=${RUN_TIME}, THRESHOLD=${THRESHOLD}"

ENABLE_FIO=1
FIO_MODE=read


COUNT=0

DATA_OFFSET=8

EXP_DEVICE_TYPE=13
EXP_SG={}
EXP_MODEL={}

INTERNAL_PORT_START=0
INTERNAL_PORT_NUM=0
INTERNAL_PHY_NUM=0
EXTERNAL_PORT_START=0
EXTERNAL_PORT_NUM=0
EXTERNAL_PORT_PHY_NUM=0
HDD_PORT_NUM=0
HDD_PHY_NUM=1
MAX_ERROR_COUNT=$((0xFFFFFFFF))

EXP_COUNT=0

# check whether nas expander or not
is_nas_expander()
{
    case "$1" in
        TVS-1280U-RP | TVS-1680U-RP | TVS-2480U-RP | TVS-1285U-RP | TVS-2485U-RP)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

# check model config
check_model_config()
{
    MODEL=`sg_inq /dev/$1 | grep "Product identification" | awk '{print $3}'`
    case "${MODEL}" in
        TVS-1280U-RP | TVS-1680U-RP | TVS-2480U-RP)
            INTERNAL_PORT_START=0
            INTERNAL_PORT_NUM=1
            INTERNAL_PHY_NUM=8
            EXTERNAL_PORT_START=8
            EXTERNAL_PORT_NUM=1
            EXTERNAL_PORT_PHY_NUM=4
            ;;
        REXP-1220U-RP | REXP-1620U-RP | REXP-2420U-RP | EJ-1600-V2 | EJ-1602-RP | ES-1642U-DC | ES-1640DC-V2)
            INTERNAL_PORT_START=0
            INTERNAL_PORT_NUM=0
            INTERNAL_PHY_NUM=0
            EXTERNAL_PORT_START=0
            EXTERNAL_PORT_NUM=3
            EXTERNAL_PORT_PHY_NUM=4
            ;;
        TES-1885U-RP | TES-3085U-RP)
            INTERNAL_PORT_START=4
            INTERNAL_PORT_NUM=1
            INTERNAL_PHY_NUM=8
            EXTERNAL_PORT_START=0
            EXTERNAL_PORT_NUM=0
            EXTERNAL_PORT_PHY_NUM=0
            ;;
        * )
            INTERNAL_PORT_START=0
            INTERNAL_PORT_NUM=0
            INTERNAL_PHY_NUM=0
            EXTERNAL_PORT_START=0
            EXTERNAL_PORT_NUM=0
            EXTERNAL_PORT_PHY_NUM=0
            ;;
    esac
    case "${MODEL}" in
        TVS-1280U-RP | REXP-1220U-RP | TES-1885U-RP)
            HDD_PORT_NUM=12
            ;;
        TVS-1680U-RP | REXP-1620U-RP | EJ-1600-V2 | EJ-1602-RP | ES-1642U-DC | ES-1640DC-V2)
            HDD_PORT_NUM=16
            ;;
        TVS-2480U-RP | REXP-2420U-RP | TES-3085U-RP)
            HDD_PORT_NUM=24
            ;;
        * )
            echo "unknown model: ${MODEL}"
            return -1
            ;;
    esac
    return 0
}

# search for phy with specific slot
get_phy_by_slot()
{
    COUNT=0
    case "${2}" in
        HDD )
            sg_senddiag --pf --raw=80,00,00,04,09,06,00,00 /dev/$1
            for DATA in `sg_ses -r -p 0x83 /dev/$1`
            do
                if [ ${COUNT} -eq $((${DATA_OFFSET} + ${3} * 2 + 1)) ]; then
                    PHY=$((0x${DATA}))
                    break
                fi
                COUNT=$((${COUNT} + 1))
            done
            NUM_PHY=1
            ;;
        INT )
            if [ ${3} -gt 0 ]; then
                echo "There are only 1 internal port"
                return 1
            fi
            PHY=${INTERNAL_PORT_START}
            NUM_PHY=8
            ;;
        EXT )
            if [ ${3} -ge ${EXTERNAL_PORT_NUM} ]; then
                echo "There is only ${EXTERNAL_PORT_NUM} external port"
                return 1
            fi
            PHY=$((${3} * ${EXTERNAL_PORT_PHY_NUM} + ${EXTERNAL_PORT_START}))
            NUM_PHY=4
            ;;
        * )
            echo "unknown type"
            return 1
            ;;
    esac
}

get_error_count()
{
    COUNT=0
    PORT_PHY_PORBE=0
    PHY_DATA_LENGTH=4
    PHY_DATA_PROBE=0
    sg_senddiag --pf --raw=80,00,00,04,09,01,00,00 /dev/$1
    for DATA in `sg_ses -r -p 0x83 /dev/$1`
    do
        if [ ${COUNT} -ge $((${DATA_OFFSET} + ${PHY} * ${PHY_DATA_LENGTH})) ] && [ ${COUNT} -lt $((${DATA_OFFSET} + (${PHY} + 1) * ${PHY_DATA_LENGTH})) ]; then
            DATA=$((0x${DATA}))
            ERROR_CNT[${PORT_PHY_PORBE}]=$((${ERROR_CNT[${PORT_PHY_PORBE}]} + (${DATA} << ${PHY_DATA_PROBE})))
            PHY_DATA_PROBE=$((${PHY_DATA_PROBE} + 1))
            if [ ${PHY_DATA_PROBE} -ge ${PHY_DATA_LENGTH} ]; then
                PHY=$((${PHY} + 1))
                PORT_PHY_PORBE=$((${PORT_PHY_PORBE} + 1))
                PHY_DATA_PROBE=0
            fi
        fi
        if [ ${PORT_PHY_PORBE} -ge ${NUM_PHY} ]; then
            break
        fi
        COUNT=$((${COUNT} + 1))
    done
}

get_error_count_table()
{
    COUNT=0
    sg_senddiag --pf --raw=80,00,00,04,09,01,00,00 /dev/$1
    for DATA in `sg_ses -r -p 0x83 /dev/$1`
    do
        ERROR_CNT_RAW[${COUNT}]=${DATA}
        COUNT=$((${COUNT} + 1))
    done

}

get_error_count_by_port()
{
    COUNT=0
    PORT_PHY_PROBE=0
    PHY_DATA_LENGTH=4
    PHY_DATA_PROBE=0
    unset ERROR_CNT
    PHY=$1
    for DATA in "${ERROR_CNT_RAW[@]}"
    do
        if [ ${COUNT} -ge $((${DATA_OFFSET} + ${PHY} * ${PHY_DATA_LENGTH})) ] && [ ${COUNT} -lt $((${DATA_OFFSET} + (${PHY} + 1) * ${PHY_DATA_LENGTH})) ]; then
            DATA_D=$((0x${DATA}))
            ERROR_CNT[${PORT_PHY_PROBE}]=$((${ERROR_CNT[${PORT_PHY_PROBE}]} + (${DATA_D} << (${PHY_DATA_PROBE} * 8))))
            PHY_DATA_PROBE=$((${PHY_DATA_PROBE} + 1))
            if [ ${PHY_DATA_PROBE} -ge ${PHY_DATA_LENGTH} ]; then
                PHY=$((${PHY} + 1))
                PORT_PHY_PROBE=$((${PORT_PHY_PROBE} + 1))
                PHY_DATA_PROBE=0
            fi
        fi
        if [ ${PORT_PHY_PROBE} -ge ${NUM_PHY} ]; then
            break
        fi
        COUNT=$((${COUNT} + 1))
    done
}
get_port_link()
{
    # get port link
    for (( i=0; i < ${#EXP_SG[@]}; ++i ))
    do
        COUNT=0
        POINTER=${DATA_OFFSET}
        EXP_PORT_LINK[$i]=0
        sg_senddiag --pf --raw=80,00,00,04,09,05,00,00 /dev/${EXP_SG[$i]}
        for DATA in `sg_ses -r -p 0x83 /dev/${EXP_SG[$i]}`
        do
            if [ ${COUNT} -ge ${POINTER} ]; then
                if [ ${DATA} -gt 0 ]; then
                    case ${POINTER} in
                        ${DATA_OFFSET})
                            EXP_PORT_LINK[$i]=1
                            ;;
                        $((${DATA_OFFSET} + 4)))
                            EXP_PORT_LINK[$i]=$((${EXP_PORT_LINK[$i]} + 2))
                            ;;
                        $((${DATA_OFFSET} + 8)))
                            EXP_PORT_LINK[$i]=$((${EXP_PORT_LINK[$i]} + 4))
                            ;;
                    esac

                fi
                POINTER=$((${POINTER} + 4))
            fi
                COUNT=$((${COUNT} + 1))
        done
    done
}

EXP_SG[0]=${TARGET}
EXP_MODEL[0]=`sg_inq "/dev/${TARGET}" | grep "Product identification" | awk '{print $3}'`
get_port_link
# get error count for each machine
INTERAL_ARRAY_POINTER=0
EXTERAL_ARRAY_POINTER=0
HDD_ARRAY_POINTER=0
for (( i=0; i < ${#EXP_SG[@]}; ++i ))
do
    check_model_config ${EXP_SG[$i]}
    if [ $? -ne 0 ]; then
        continue
    fi
    # get error count table
    get_error_count_table ${EXP_SG[$i]}
    # get internal port error count
    unset ERROR_CNT_PORT
    for (( j=0; j < ${INTERNAL_PORT_NUM}; ++j ))
    do
        get_phy_by_slot ${EXP_SG[$i]} "INT" $j
        get_error_count_by_port ${PHY}
        for ((k=0; k < ${#ERROR_CNT[@]}; ++k))
        do
            ERROR_CNT_PORT[$(($j * ${INTERNAL_PHY_NUM} + $k))]=${ERROR_CNT[$k]}
        done
    done
    if [ ${INTERNAL_PORT_NUM} -gt 0 ]; then
        for (( j=0; j < ${INTERNAL_PORT_NUM}; ++j ))
        do
            for ((k=0; k < ${INTERNAL_PHY_NUM}; ++k))
            do
                ERROR_CNT_INTERNAL_1[$((${INTERAL_ARRAY_POINTER} + $j * ${INTERNAL_PHY_NUM} + $k))]=${ERROR_CNT_PORT[$(($j * ${INTERNAL_PHY_NUM} + $k))]}
            done
        done
    fi
    INTERAL_ARRAY_POINTER=$((${INTERAL_ARRAY_POINTER} + ${INTERNAL_PORT_NUM} * ${INTERNAL_PHY_NUM}))
    # get external port error count
    unset ERROR_CNT_PORT
    for (( j=0; j < ${EXTERNAL_PORT_NUM}; ++j ))
    do
        get_phy_by_slot ${EXP_SG[$i]} "EXT" $j
        get_error_count_by_port ${PHY}
        for (( k=0; k < ${#ERROR_CNT[@]}; ++k ))
        do
            ERROR_CNT_PORT[$(($j * ${EXTERNAL_PORT_PHY_NUM} + $k))]=${ERROR_CNT[$k]}
        done
    done
    if [ ${EXTERNAL_PORT_NUM} -gt 0 ]; then
        for (( j=0; j < ${EXTERNAL_PORT_NUM}; ++j ))
        do
            for (( k=0; k < ${EXTERNAL_PORT_PHY_NUM}; ++k ))
            do
                ERROR_CNT_EXTERNAL_1[$((${EXTERAL_ARRAY_POINTER} + $j * ${EXTERNAL_PORT_PHY_NUM} + $k))]=${ERROR_CNT_PORT[$(($j * ${EXTERNAL_PORT_PHY_NUM} + $k))]}
            done
        done
    fi
    EXTERAL_ARRAY_POINTER=$((${EXTERAL_ARRAY_POINTER} + ${EXTERNAL_PORT_NUM} * ${EXTERNAL_PORT_PHY_NUM}))
    # get hdd port error count
    unset ERROR_CNT_PORT
    for (( j=0; j < ${HDD_PORT_NUM}; ++j ))
    do
        get_phy_by_slot ${EXP_SG[$i]} "HDD" $j
        get_error_count_by_port ${PHY}
        for ((k=0; k < ${#ERROR_CNT[@]}; ++k))
        do
            ERROR_CNT_PORT[$(($j * ${HDD_PHY_NUM} + $k))]=${ERROR_CNT[$k]}
        done
    done
    if [ ${HDD_PORT_NUM} -gt 0 ]; then
        for (( j=0; j < ${HDD_PORT_NUM}; ++j ))
        do
            for ((k=0; k < ${HDD_PHY_NUM}; ++k))
            do
                ERROR_CNT_HDD_1[$((${HDD_ARRAY_POINTER} + $j * ${HDD_PHY_NUM} + $k))]=${ERROR_CNT_PORT[$(($j * ${HDD_PHY_NUM} + $k))]}
            done
        done
    fi
    HDD_ARRAY_POINTER=$(( ${HDD_ARRAY_POINTER} + ${HDD_PORT_NUM} * ${HDD_PHY_NUM}))
done
# wait time
for (( i=0; i < ${RUN_TIME}; ++i ))
do
    printf "*"
    sleep 1
done
printf "\n"
# get error count for each machine
INTERAL_ARRAY_POINTER=0
EXTERAL_ARRAY_POINTER=0
HDD_ARRAY_POINTER=0
for (( i=0; i < ${#EXP_SG[@]}; ++i ))
do
    check_model_config ${EXP_SG[$i]}
    if [ $? -ne 0 ]; then
        continue
    fi
    # get error count table
    get_error_count_table ${EXP_SG[$i]}
    # get internal port error count
    unset ERROR_CNT_PORT
    for (( j=0; j < ${INTERNAL_PORT_NUM}; ++j ))
    do
        get_phy_by_slot ${EXP_SG[$i]} "INT" $j
        get_error_count_by_port ${PHY}
        for ((k=0; k < ${#ERROR_CNT[@]}; ++k))
        do
            ERROR_CNT_PORT[$(($j * ${INTERNAL_PHY_NUM} + $k))]=${ERROR_CNT[$k]}
        done
    done
    if [ ${INTERNAL_PORT_NUM} -gt 0 ]; then
        for (( j=0; j < ${INTERNAL_PORT_NUM}; ++j ))
        do
            for ((k=0; k < ${INTERNAL_PHY_NUM}; ++k))
            do
                ERROR_CNT_INTERNAL_2[$((${INTERAL_ARRAY_POINTER} + $j * ${INTERNAL_PHY_NUM} + $k))]=${ERROR_CNT_PORT[$(($j * ${INTERNAL_PHY_NUM} + $k))]}
            done
        done
    fi
    INTERAL_ARRAY_POINTER=$((${INTERAL_ARRAY_POINTER} + ${INTERNAL_PORT_NUM} * ${INTERNAL_PHY_NUM}))
    # get external port error count
    unset ERROR_CNT_PORT
    for (( j=0; j < ${EXTERNAL_PORT_NUM}; ++j ))
    do
        get_phy_by_slot ${EXP_SG[$i]} "EXT" $j
        get_error_count_by_port ${PHY}
        for (( k=0; k < ${#ERROR_CNT[@]}; ++k ))
        do
            ERROR_CNT_PORT[$(($j * ${EXTERNAL_PORT_PHY_NUM} + $k))]=${ERROR_CNT[$k]}
        done
    done
    if [ ${EXTERNAL_PORT_NUM} -gt 0 ]; then
        for (( j=0; j < ${EXTERNAL_PORT_NUM}; ++j ))
        do
            for (( k=0; k < ${EXTERNAL_PORT_PHY_NUM}; ++k ))
            do
                ERROR_CNT_EXTERNAL_2[$((${EXTERAL_ARRAY_POINTER} + $j * ${EXTERNAL_PORT_PHY_NUM} + $k))]=${ERROR_CNT_PORT[$(($j * ${EXTERNAL_PORT_PHY_NUM} + $k))]}
            done
        done
    fi
    EXTERAL_ARRAY_POINTER=$(( ${EXTERAL_ARRAY_POINTER} + ${EXTERNAL_PORT_NUM} * ${EXTERNAL_PORT_PHY_NUM}))
    # get hdd port error count
    unset ERROR_CNT_PORT
    for (( j=0; j < ${HDD_PORT_NUM}; ++j ))
    do
        get_phy_by_slot ${EXP_SG[$i]} "HDD" $j
        get_error_count_by_port ${PHY}
        for ((k=0; k < ${#ERROR_CNT[@]}; ++k))
        do
            ERROR_CNT_PORT[$(($j * ${HDD_PHY_NUM} + $k))]=${ERROR_CNT[$k]}
        done
    done
    if [ ${HDD_PORT_NUM} -gt 0 ]; then
        for (( j=0; j < ${HDD_PORT_NUM}; ++j ))
        do
            for ((k=0; k < ${HDD_PHY_NUM}; ++k))
            do
                ERROR_CNT_HDD_2[$((${HDD_ARRAY_POINTER} + $j * ${HDD_PHY_NUM} + $k))]=${ERROR_CNT_PORT[$(($j * ${HDD_PHY_NUM} + $k))]}
            done
        done
    fi
    HDD_ARRAY_POINTER=$(( ${HDD_ARRAY_POINTER} + ${HDD_PORT_NUM} * ${HDD_PHY_NUM}))
done
# compute error count increment
#for i in "${EXP_SG[@]}"
INTERAL_ARRAY_POINTER=0
EXTERAL_ARRAY_POINTER=0
HDD_ARRAY_POINTER=0
for (( i=0; i < ${#EXP_SG[@]}; ++i ))
do
    check_model_config ${EXP_SG[$i]}
    if [ $? -ne 0 ]; then
        continue
    fi
    # get internal port error count
    for (( j=0; j < ${INTERNAL_PORT_NUM}; ++j ))
    do
        for (( k=0; k < ${INTERNAL_PHY_NUM}; ++k ))
        do
            if [ ${ERROR_CNT_INTERNAL_2[$((${INTERAL_ARRAY_POINTER} + $j * ${INTERNAL_PHY_NUM} + $k))]} -ge ${ERROR_CNT_INTERNAL_1[$((${INTERAL_ARRAY_POINTER} + $j * ${INTERNAL_PHY_NUM} + $k))]} ]; then
                ERROR_CNT_INTERNAL_INC[$((${INTERAL_ARRAY_POINTER} + $j * ${INTERNAL_PHY_NUM} + $k))]=$((${ERROR_CNT_INTERNAL_2[$((${INTERAL_ARRAY_POINTER}$j * ${INTERNAL_PHY_NUM} + $k))]} - ${ERROR_CNT_INTERNAL_1[$((${INTERAL_ARRAY_POINTER}$j * ${INTERNAL_PHY_NUM} + $k))]}))
            else
                ERROR_CNT_INTERNAL_INC[$((${INTERAL_ARRAY_POINTER} + $j * ${INTERNAL_PHY_NUM} + $k))]=$((${MAX_ERROR_COUNT} - ${ERROR_CNT_INTERNAL_1[$((${INTERAL_ARRAY_POINTER} + $j * ${INTERNAL_PHY_NUM} + $k))]} + ${ERROR_CNT_INTERNAL_2[$((${INTERAL_ARRAY_POINTER} + $j * ${INTERNAL_PHY_NUM} + $k))]}))
            fi
        done
    done
    INTERAL_ARRAY_POINTER=$((${INTERAL_ARRAY_POINTER} + ${INTERNAL_PORT_NUM} * ${INTERNAL_PHY_NUM}))
    # get external port error count
    for (( j=0; j < ${EXTERNAL_PORT_NUM}; ++j ))
    do
        for (( k=0; k < ${EXTERNAL_PORT_PHY_NUM}; ++k ))
        do
            if [ ${ERROR_CNT_EXTERNAL_2[$((${EXTERAL_ARRAY_POINTER} + $j * ${EXTERNAL_PORT_PHY_NUM} + $k))]} -ge ${ERROR_CNT_EXTERNAL_1[$((${EXTERAL_ARRAY_POINTER} + $j * ${EXTERNAL_PORT_PHY_NUM} + $k))]} ]; then
                ERROR_CNT_EXTERNAL_INC[$((${EXTERAL_ARRAY_POINTER} + $j * ${EXTERNAL_PORT_PHY_NUM} + $k))]=$((${ERROR_CNT_EXTERNAL_2[$((${EXTERAL_ARRAY_POINTER} + $j * ${EXTERNAL_PORT_PHY_NUM} + $k))]} - ${ERROR_CNT_EXTERNAL_1[$((${EXTERAL_ARRAY_POINTER} + $j * ${EXTERNAL_PORT_PHY_NUM} + $k))]}))
            else
                ERROR_CNT_EXTERNAL_INC[$((${EXTERAL_ARRAY_POINTER} + $j * ${EXTERNAL_PORT_PHY_NUM} + $k))]=$((${MAX_ERROR_COUNT} - ${ERROR_CNT_EXTERNAL_1[$((${EXTERAL_ARRAY_POINTER} + $j * ${EXTERNAL_PORT_PHY_NUM} + $k))]} + ${ERROR_CNT_EXTERNAL_2[$((${EXTERAL_ARRAY_POINTER} + $j * ${EXTERNAL_PORT_PHY_NUM} + $k))]}))
            fi
        done
    done
    EXTERAL_ARRAY_POINTER=$((${EXTERAL_ARRAY_POINTER} + ${EXTERNAL_PORT_NUM} * ${EXTERNAL_PORT_PHY_NUM}))
    # get hdd port error count
    for (( j=0; j < ${HDD_PORT_NUM}; ++j ))
    do
        for (( k=0; k < ${HDD_PHY_NUM}; ++k ))
        do
            if [ ${ERROR_CNT_HDD_2[$((${HDD_ARRAY_POINTER} + $j * ${HDD_PHY_NUM} + $k))]} -ge ${ERROR_CNT_HDD_1[$((${HDD_ARRAY_POINTER} + $j * ${HDD_PHY_NUM} + $k))]} ]; then
                ERROR_CNT_HDD_INC[$((${HDD_ARRAY_POINTER} + $j * ${HDD_PHY_NUM} + $k))]=$((${ERROR_CNT_HDD_2[$((${HDD_ARRAY_POINTER} + $j * ${HDD_PHY_NUM} + $k))]} - ${ERROR_CNT_HDD_1[$((${HDD_ARRAY_POINTER} + $j * ${HDD_PHY_NUM} + $k))]}))
            else
                ERROR_CNT_HDD_INC[$((${HDD_ARRAY_POINTER} + $j * ${HDD_PHY_NUM} + $k))]=$(((${MAX_ERROR_COUNT} - ${ERROR_CNT_HDD_1[$((${HDD_ARRAY_POINTER} + $j * ${HDD_PHY_NUM} + $k))]}) + ${ERROR_CNT_HDD_2[$((${HDD_ARRAY_POINTER} + $j * ${HDD_PHY_NUM} + $k))]}))
            fi
        done
    done
    HDD_ARRAY_POINTER=$((${HDD_ARRAY_POINTER} + ${HDD_PORT_NUM} * ${HDD_PHY_NUM}))
done

# do summary and exit
printf "=================================================\n"
printf "*                     Summary                   *\n"
printf "=================================================\n"
printf "Error Count for %s seconds\n" "${RUN_TIME}"
INTERAL_ARRAY_POINTER=0
EXTERAL_ARRAY_POINTER=0
HDD_ARRAY_POINTER=0
for (( i=0; i < ${#EXP_SG[@]}; ++i ))
do
    check_model_config ${EXP_SG[$i]}
    if [ $? -ne 0 ]; then
        continue
    fi
    printf "=================================================\n"
	# find enclouse id
	is_nas_expander ${EXP_MODEL[$i]}
    printf "Model: %s (%s)(id=%s)\n" "${EXP_MODEL[$i]}" "${EXP_SG[$i]}"
    printf "Internal port:\n"
    for (( j=0; j < ${INTERNAL_PORT_NUM}; ++j ))
    do
        VALUE="Port $(($j + 1))($(($j + ${INTERNAL_PORT_START} + 1))st ~ $(($j + ${INTERNAL_PORT_START} + 8))th phys): "
        for (( k=0; k < ${INTERNAL_PHY_NUM}; ++k ))
        do
            VALUE=${VALUE}"${ERROR_CNT_INTERNAL_INC[$((${INTERAL_ARRAY_POINTER} + $j * ${INTERNAL_PHY_NUM} + $k))]}  "
        done
        echo ${VALUE}
    done
    INTERAL_ARRAY_POINTER=$((${INTERAL_ARRAY_POINTER} + ${INTERNAL_PORT_NUM} * ${INTERNAL_PHY_NUM}))
    # get external port error count
    printf "External port:\n"
    for (( j=0; j < ${EXTERNAL_PORT_NUM}; ++j ))
    do
        if [ $((${EXP_PORT_LINK[$i]} & (1<<$j))) -eq $((1<<$j)) ]; then
            VALUE="Port $(($j + 1))($(($j + ${EXTERNAL_PORT_START} + 1))st ~ $(($j + ${EXTERNAL_PORT_START} + 8))th phys) plug: "
        else
            VALUE="Port $(($j + 1))($(($j + ${EXTERNAL_PORT_START} + 1))st ~ $(($j + ${EXTERNAL_PORT_START} + 8))th phys) unplug: "
        fi

        for (( k=0; k < ${EXTERNAL_PORT_PHY_NUM}; ++k ))
        do
            VALUE=${VALUE}"${ERROR_CNT_EXTERNAL_INC[$((${EXTERAL_ARRAY_POINTER} + $j * ${EXTERNAL_PORT_PHY_NUM} + $k))]}  "
        done
        echo ${VALUE}
    done
    EXTERAL_ARRAY_POINTER=$((${EXTERAL_ARRAY_POINTER} + ${EXTERNAL_PORT_NUM} * ${EXTERNAL_PORT_PHY_NUM}))
    # get hdd port error count
    printf "HDD port:\n"
    for (( j=0; j < ${HDD_PORT_NUM}; ++j ))
    do
        VALUE="Port $(($j + 1)): "
        for (( k=0; k < ${HDD_PHY_NUM}; ++k ))
        do
            VALUE=${VALUE}"${ERROR_CNT_HDD_INC[$((${HDD_ARRAY_POINTER} + $j * ${HDD_PHY_NUM} + $k))]}  "
        done
        echo ${VALUE}
    done
    HDD_ARRAY_POINTER=$((${HDD_ARRAY_POINTER} + ${HDD_PORT_NUM} * ${HDD_PHY_NUM}))
done
printf "\n"
printf "\n"
printf "\n"
printf "=================================================\n"
printf "*            Problem port detection             *\n"
printf "=================================================\n"
ERROR_FLAG=0
INTERAL_ARRAY_POINTER=0
EXTERAL_ARRAY_POINTER=0
HDD_ARRAY_POINTER=0
for (( i=0; i < ${#EXP_SG[@]}; ++i ))
do
    check_model_config ${EXP_SG[$i]}
    if [ $? -ne 0 ]; then
        continue
    fi
    printf "=================================================\n"
	# find enclouse id
	is_nas_expander ${EXP_MODEL[$i]}
    printf "Model: %s (%s)(id=%s)\n" "${EXP_MODEL[$i]}" "${EXP_SG[$i]}"	
    printf "Internal port:\n"
    for (( j=0; j < ${INTERNAL_PORT_NUM}; ++j ))
    do
        ERROR_FLAG=0
        for (( k=0; k < ${INTERNAL_PHY_NUM}; ++k ))
        do
            if [ ${ERROR_CNT_INTERNAL_INC[$((${INTERAL_ARRAY_POINTER} + $j * ${INTERNAL_PHY_NUM} + $k))]} -ge ${THRESHOLD} ]; then
                ERROR_FLAG=1
            fi
        done
        if [ ${ERROR_FLAG} -eq 1 ]; then
            printf "Port $(($j + 1))"
            printf "\n"
        fi
    done
    INTERAL_ARRAY_POINTER=$((${INTERAL_ARRAY_POINTER} + ${INTERNAL_PORT_NUM} * ${INTERNAL_PHY_NUM}))
    # get external port error count
    printf "External port:\n"
    for (( j=0; j < ${EXTERNAL_PORT_NUM}; ++j ))
    do
        ERROR_FLAG=0
        for (( k=0; k < ${EXTERNAL_PORT_PHY_NUM}; ++k ))
        do
            if [ ${ERROR_CNT_EXTERNAL_INC[$((${EXTERAL_ARRAY_POINTER} + $j * ${EXTERNAL_PORT_PHY_NUM} + $k))]} -ge ${THRESHOLD} ]; then
                ERROR_FLAG=1
            fi
        done
        if [ ${ERROR_FLAG} -eq 1 ]; then
            printf "Port $(($j + 1))"
            printf "\n"
        fi
    done
    EXTERAL_ARRAY_POINTER=$((${EXTERAL_ARRAY_POINTER} + ${EXTERNAL_PORT_NUM} * ${EXTERNAL_PORT_PHY_NUM}))
    # get hdd port error count
    printf "HDD port:\n"
    for (( j=0; j < ${HDD_PORT_NUM}; ++j ))
    do
        ERROR_FLAG=0
        for (( k=0; k < ${HDD_PHY_NUM}; ++k ))
        do
            if [ ${ERROR_CNT_HDD_INC[$((${HDD_ARRAY_POINTER} + $j * ${HDD_PHY_NUM} + $k))]} -ge ${THRESHOLD} ]; then
                ERROR_FLAG=1
            fi
        done
        if [ ${ERROR_FLAG} -eq 1 ]; then
            printf "Port $(($j + 1))"
            printf "\n"
        fi
    done
    HDD_ARRAY_POINTER=$((${HDD_ARRAY_POINTER} + ${HDD_PORT_NUM} * ${HDD_PHY_NUM}))
done
