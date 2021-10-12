// ===============================================================================
// Date: 2021-10-10
// Creator: Hu,Shiqing
// E-mail: schinghu@gmail.com
// Description: autogen by gentb.py
// ===============================================================================

`ifndef AHB_RAL_BASE_TEST_SV
`define AHB_RAL_BASE_TEST_SV

class ahb_ral_base_test extends uvm_test;

    `uvm_component_utils(ahb_ral_base_test)

    ahb_ral_env  m_env;

    function new (string name="ahb_ral_base_test", uvm_component parent);
        super.new (name, parent);
    endfunction : new 

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        uvm_report_info(get_type_name(),$sformatf("build_phase"), UVM_LOW);

        m_env = ahb_ral_env::type_id::create("m_env",this);

    endfunction:build_phase

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        uvm_report_info(get_type_name(),$sformatf("connect_phase"), UVM_LOW);
     endfunction:connect_phase

     function void report_phase(uvm_phase phase);
         super.report_phase(phase);
     endfunction : report_phase

    function void final_phase(uvm_phase phase);
        uvm_report_server svr;
        super.final_phase(phase);
        svr = uvm_report_server::get_server();

        if((svr.get_severity_count(UVM_FATAL) +
            svr.get_severity_count(UVM_ERROR) == 0)) begin

            $display("************************************");
            $display("*                                  *");
            $display("*  PPPPP     AA     SSSS    SSSS   *");
            $display("*  PP  PP   AAAA   SS  SS  SS  SS  *");
            $display("*  PP  PP  AA  AA  SS      SS      *");
            $display("*  PPPPP   AA  AA   SSSS    SSSS   *");
            $display("*  PP      AAAAAA      SS      SS  *");
            $display("*  PP      AA  AA  SS  SS  SS  SS  *");
            $display("*  PP      AA  AA   SSSS    SSSS   *");
            $display("*                                  *");
            $display("************************************");

        end else begin
            $display("************************************");
            $display("*                                  *");
            $display("*  FFFFFF    AA     II   LL        *");
            $display("*  FF       AAAA    II   LL        *");
            $display("*  FF      AA  AA   II   LL        *");
            $display("*  FFFFFF  AA  AA   II   LL        *");
            $display("*  FF      AAAAAA   II   LL        *");
            $display("*  FF      AA  AA   II   LL        *");
            $display("*  FF      AA  AA   II   LLLLLL    *");
            $display("*                                  *");
            $display("************************************");
        end

    endfunction: final_phase

endclass:ahb_ral_base_test

`endif // AHB_RAL_BASE_TEST_SV
