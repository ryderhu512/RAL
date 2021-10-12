# ================================================================================
# Date: 2021-10-10
# Creator: Hu,Shiqing
# E-mail: schinghu@gmail.com
# Description: autogen by gentb.py
# ================================================================================


TC      = test_apb_ral_basic 
TC_LIBS = test_apb_ral_basic

VC_AHB_DIR = $(trunk)/acm_gnss/tb/common/lib/GNSS_VIP/vc_ahb
VC_APB_DIR = $(trunk)/acm_gnss/tb/common/lib/GNSS_VIP/vc_apb
XRUN_OPTS  = -uvm -uvmhome $(shell ncroot)/tools/methodology/UVM/CDNS-1.2/sv
XRUN_OPTS += -64 -access +r+w+c
XRUN_OPTS += +UVM_TESTNAME=$(TC) +UVM_VERBOSITY=UVM_LOW
XRUN_OPTS += +incdir+$(VC_AHB_DIR)/sv $(VC_AHB_DIR)/sv/vc_ahb_pkg.sv 
XRUN_OPTS += +incdir+$(VC_APB_DIR)/sv $(VC_APB_DIR)/sv/vc_apb_pkg.sv 
XRUN_OPTS += +incdir+$(trunk)/acm_gnss/tb/common/lib/GNSS_VIP/vc_mem/sv
XRUN_OPTS += +incdir+./
XRUN_OPTS += apb_ral.sv 
XRUN_OPTS += apb_ral_tb.sv
XRUN_OPTS += -input batch.tcl


GUI   	  ?= 0
ifeq ($(GUI),1)
XRUN_OPTS += -gui
else
XRUN_OPTS += -run
endif

BSUB      ?=0
ifeq ($(BSUB),1)
XRUN       = nc run -nolog -wl xrun
else
XRUN       = xrun
endif


default: help

run:
	$(XRUN) $(XRUN_OPTS)

clean: 
	@echo Cleaning...
	-rm -fr *.log
	-rm -fr *.key
	-rm -fr INCA_libs waves.shm vnc_logs
	-rm -fr .simvision xcelium.d *.history
	-rm -fr irun.history ncsim_*.err *.diag
help:
	@echo ==============================================================
	@echo " 1. make run TC=<xxx>    ----------- batch mode"
	@echo " 2. make run_gui         ----------- gui mode with wave by default"
	@echo " 3. make clean           ----------- clean temporary files"
	@echo --------------------------------------------------------------
	@echo " Test cases: $(TC_LIBS)"
	@echo ==============================================================
