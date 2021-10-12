// ===============================================================================
// Date: 2021-10-10
// Creator: Hu,Shiqing
// E-mail: schinghu@gmail.com
// Description: autogen by gentb.py
// ===============================================================================

`ifndef APB_RAL_BASE_TEST_SV
`define APB_RAL_BASE_TEST_SV

class apb_ral_base_test extends uvm_test;

    `uvm_component_utils(apb_ral_base_test)

    apb_ral_env  m_env;

    function new (string name="apb_ral_base_test", uvm_component parent);
        super.new (name, parent);
    endfunction : new 

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        uvm_report_info(get_type_name(),$sformatf("build_phase"), UVM_LOW);

        m_env = apb_ral_env::type_id::create("m_env",this);

    endfunction:build_phase

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        uvm_report_info(get_type_name(),$sformatf("connect_phase"), UVM_LOW);
     endfunction:connect_phase

     function void report_phase(uvm_phase phase);
         super.report_phase(phase);
     endfunction : report_phase

endclass:apb_ral_base_test

`endif // APB_RAL_BASE_TEST_SV
