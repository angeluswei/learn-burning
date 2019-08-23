#!/bin/bash
ses_dev=$(ls /dev/ses*);       
for dev_no in $ses_dev
do
  ses_no=${dev_no:8:1}
  if [ "$(sg_inq /dev/ses${ses_no} |grep ES)" = "" ]; then
  (/nas/util/qses pwctl ses${ses_no} 0 2)  
  fi
  init 0  
done                    

