// ===============================================================================
// Date: 2021-10-10
// Creator: Hu,Shiqing
// E-mail: shiqing_hu@apple.com
// Description: autogen by gentb.py
// ===============================================================================

`ifndef AHB_RAL_TEST_LIB_SV
`define AHB_RAL_TEST_LIB_SV

class test_ahb_ral_basic_seq extends ahb_ral_vseq;

    `uvm_object_utils(test_ahb_ral_basic_seq)
    `uvm_declare_p_sequencer(ahb_ral_vseqr)
    vc_ahb_xact         ahb_xact, ahb_rsp;
    vc_ahb_base_seq     ahb_seq;


    function new(string name="");
        super.new(name);
    endfunction : new

    task seq_body();
        super.seq_body();

        // memory write/read
        `uvm_do_on_with(ahb_xact, p_sequencer.p_cpu_a_m_seqr, {addr == 'h1000_0010; burst == vc_ahb_pkg::SINGLE; has_resp == 0;
                                                                  size == vc_ahb_pkg::WORD; direction == vc_ahb_pkg::WRITE;})

        `uvm_do_on_with(ahb_xact, p_sequencer.p_cpu_a_m_seqr, {addr == 'h1000_0010; burst == vc_ahb_pkg::SINGLE; 
                                                                  size == vc_ahb_pkg::WORD; direction == vc_ahb_pkg::READ; })
        get_response(rsp);$cast(ahb_rsp, rsp);
        $display("cpu_a_m ahb_rsp.data[0] = 0x%0x", ahb_rsp.data[0]);

        // register write/read
        `uvm_do_on_with(ahb_xact, p_sequencer.p_cpu_a_m_seqr, {addr == 'h1000_1000; burst == vc_ahb_pkg::SINGLE; has_resp == 0;
                                                                  size == vc_ahb_pkg::WORD; direction == vc_ahb_pkg::WRITE;})

        `uvm_do_on_with(ahb_xact, p_sequencer.p_cpu_a_m_seqr, {addr == 'h1000_1000; burst == vc_ahb_pkg::SINGLE; 
                                                                  size == vc_ahb_pkg::WORD; direction == vc_ahb_pkg::READ; })
        get_response(rsp);$cast(ahb_rsp, rsp);
        $display("cpu_a_m ahb_rsp.data[0] = 0x%0x", ahb_rsp.data[0]);

        `uvm_do_on_with(ahb_xact, p_sequencer.p_cpu_a_m_seqr, {addr == 'h1000_1004; burst == vc_ahb_pkg::SINGLE; has_resp == 0;
                                                                  size == vc_ahb_pkg::WORD; direction == vc_ahb_pkg::WRITE;})

        `uvm_do_on_with(ahb_xact, p_sequencer.p_cpu_a_m_seqr, {addr == 'h1000_1004; burst == vc_ahb_pkg::SINGLE; 
                                                                  size == vc_ahb_pkg::WORD; direction == vc_ahb_pkg::READ; })
        get_response(rsp);$cast(ahb_rsp, rsp);
        $display("cpu_a_m ahb_rsp.data[0] = 0x%0x", ahb_rsp.data[0]);

        #100ns;
    
        m_regmodel.default_map.set_check_on_read();
        m_regmodel.default_map.set_auto_predict();

        m_regmodel.ctl.cfg.ena.write (status, 'h1);
        m_regmodel.ctl.cfg.ena.write (status, 'h0);
        m_regmodel.ctl.cfg.cfg.write (status, 'hABC);
        m_regmodel.ram.write (status, 0, 'h80);
        m_regmodel.ram.burst_write (status, 0, {'h90, 'h91, 'h92, 'h93});
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

            $display("backdoor writ and frontdoor read");
            m_regmodel.ram.burst_write (status, 20, {'h90, 'h91, 'h92, 'h93}, UVM_BACKDOOR);
            m_regmodel.ram.burst_read  (status, 20, rdata);
            foreach(rdata[k]) $display("rdata[%0d] = %0x", k, rdata[k]);

            wdata.delete();
            rdata.delete();
            mrg.release_region();

        end

    endtask

endclass

class test_ahb_ral_basic extends ahb_ral_base_test;

    `uvm_component_utils(test_ahb_ral_basic)

    function new (string name="test_ahb_ral_basic", uvm_component parent);
        super.new (name, parent);
    endfunction : new 

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        uvm_config_db#(uvm_object_wrapper)::set(this, "m_env.m_vir_seqr.run_phase", "default_sequence", 
            factory.find_by_name("test_ahb_ral_basic_seq"));
    endfunction:build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
    endfunction:connect_phase

endclass

`endif // AHB_RAL_TEST_LIB_SV
