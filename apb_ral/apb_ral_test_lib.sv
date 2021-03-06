// ===============================================================================
// Date: 2021-10-10
// Creator: Hu,Shiqing
// E-mail: schinghu@gmail.com
// Description: autogen by gentb.py
// ===============================================================================

`ifndef APB_RAL_TEST_LIB_SV
`define APB_RAL_TEST_LIB_SV

class test_apb_ral_basic_seq extends apb_ral_vseq;

    `uvm_object_utils(test_apb_ral_basic_seq)
    `uvm_declare_p_sequencer(apb_ral_vseqr)
    vc_apb_xact         apb_xact, apb_rsp;
    vc_apb_base_seq     apb_seq;


    function new(string name="");
        super.new(name);
    endfunction : new

    int data;
    task seq_body();
        super.seq_body();

        m_regmodel.default_map.set_check_on_read();
        m_regmodel.default_map.set_auto_predict();

        #150ns;
        $display("[%0t] start", $time);
        $display("write from backdoor");
        m_regmodel.ctl.cfg.ena.set(1);
        m_regmodel.ctl.cfg.update(status, UVM_BACKDOOR);
        m_regmodel.ctl.cfg.write(status, 1, UVM_BACKDOOR);

        $display("read from frontdoor");
        m_regmodel.ctl.cfg.read(status, data, UVM_FRONTDOOR);
        $display("[%0t] done", $time);

        m_regmodel.ctl.cfg.ena.write (status, 'h0);
        m_regmodel.ctl.cfg.cfg.write (status, 'hABC);
        m_regmodel.ram.write (status, 0, 'h80);
        m_regmodel.ram.burst_write (status,  0, {'h90, 'h91, 'h92, 'h93});
        m_regmodel.ram.burst_write (status, 10, {'h90, 'h91, 'h92, 'h93}, UVM_BACKDOOR);
        #100ns;

        begin
            int burst_size = 4;
            int pattern = 'hA;
            uvm_status_e status;
            uvm_reg_data_t wdata[], rdata[];
            uvm_mem_region mrg;

            wdata = new[burst_size];
            rdata = new[burst_size];
            assert(std::randomize(wdata) with { wdata.size() == burst_size; 
                                                foreach(wdata[k]) wdata[k][31:28] == pattern;});

            mrg = m_regmodel.ram.request_region(burst_size);

            m_regmodel.ram.burst_write(status, mrg.get_start_offset(), wdata);
            m_regmodel.ram.burst_read (status, mrg.get_start_offset(), rdata);
            foreach(rdata[k]) $display("rdata[%0d] = %0x", k, rdata[k]);

            $display("backdoor write and frontdoor read");
            m_regmodel.ram.burst_write (status, 20, {'h90, 'h91, 'h92, 'h93}, UVM_BACKDOOR);
            m_regmodel.ram.burst_read  (status, 20, rdata);
            foreach(rdata[k]) $display("rdata[%0d] = %0x", k, rdata[k]);

            wdata.delete();
            rdata.delete();
            mrg.release_region();

        end

    endtask

endclass

class test_apb_ral_basic extends apb_ral_base_test;

    `uvm_component_utils(test_apb_ral_basic)

    function new (string name="test_apb_ral_basic", uvm_component parent);
        super.new (name, parent);
    endfunction : new 

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        uvm_config_db#(uvm_object_wrapper)::set(this, "m_env.m_vir_seqr.run_phase", "default_sequence", 
            test_apb_ral_basic_seq::type_id::get());
    endfunction:build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
    endfunction:connect_phase

endclass

`endif // APB_RAL_TEST_LIB_SV
