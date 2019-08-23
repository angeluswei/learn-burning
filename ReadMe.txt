##############
# FP control #
##############
1. When fp = 2
   a. ScbA: smb, iperf(client), bbu
   b. ScbB: fio, iperf(server), ntb(slave), bbu

2. When fp = 4
   a. ScbA: fio, ntb(master), bbu
   b. ScbB: smb, ntb(slave), bbu


###################
# Burn-in redmine #
###################
1. nic if only burn ix0 (no ix1, ix2, ix3)
