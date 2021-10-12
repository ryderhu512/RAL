// ===============================================================================
// Date: 2021-10-10
// Creator: Hu,Shiqing
// E-mail: schinghu@gmail.com
// Description: autogen by gentb.py
// ===============================================================================

`ifndef AHB_RAL_VSEQ_SV
`define AHB_RAL_VSEQ_SV

typedef class ahb_ral_vseqr;

class ahb_ral_vseq extends uvm_sequence #(uvm_sequence_item);

    `uvm_object_utils(ahb_ral_vseq)
    `uvm_declare_p_sequencer(ahb_ral_vseqr)

    uvm_status_e        status;
    ral_reg_block   m_regmodel;

    function new(string name=""); 
        super.new(name);
    endfunction : new

    virtual task pre_body();
        super.pre_body();
        uvm_report_info(get_type_name(), $sformatf("pre_body"), UVM_LOW);
        uvm_test_done.raise_objection(this);
    endtask

    virtual task seq_pre_body();
        uvm_report_info(get_type_name(), $sformatf("seq_pre_body"), UVM_LOW);
    endtask

    virtual task seq_body();
        uvm_report_info(get_type_name(), $sformatf("seq_body"), UVM_LOW);
    endtask

    virtual task seq_post_body();
        uvm_report_info(get_type_name(), $sformatf("seq_post_body"), UVM_LOW);
    endtask

    virtual task body();
        uvm_report_info(get_type_name(), $sformatf("body"), UVM_LOW);
        assert(uvm_config_db #(ral_reg_block)::get (null, "uvm_test_top", "m_regmodel", m_regmodel));
        seq_pre_body();
        seq_body();
        seq_post_body();
    endtask

    virtual task post_body();
        super.post_body();
        uvm_report_info(get_type_name(), $sformatf("post_body"), UVM_LOW);
        uvm_test_done.drop_objection(this);
    endtask

endclass:ahb_ral_vseq

class ahb_ral_vseqr extends uvm_sequencer;

    `uvm_component_utils(ahb_ral_vseqr)

    vc_ahb_sequencer p_cpu_a_m_seqr;

    function new(string name="", uvm_component parent=null); 
        super.new(name, parent);
    endfunction : new

endclass:ahb_ral_vseqr

`endif // AHB_RAL_VSEQ_SV
