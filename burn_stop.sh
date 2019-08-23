#!/bin/sh
#stop bash script
  (pkill bash)
#stop cpu
  (pkill stress)
#stop hd
  (pkill fio)
  (pkill dd)
#stop ntb
  (pkill diff) 
#clean wait
  (pkill sleep)              
