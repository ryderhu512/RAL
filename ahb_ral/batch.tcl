# ================================================================================
# Date: 2021-10-10
# Creator: Hu,Shiqing
# E-mail: schinghu@gmail.com
# Description: autogen by gentb.py
# ================================================================================

database -open waves -into waves.shm -default

probe -create ahb_ral_tb  -database waves
probe -create ahb_ral_tb  -depth all -all
