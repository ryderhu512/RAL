// ===============================================================================
// Date: 2021-10-10
// Creator: Hu,Shiqing
// E-mail: shiqing_hu@apple.com
// Description: autogen by gentb.py
// ===============================================================================

`ifndef AHB_RAL_ENV_SV
`define AHB_RAL_ENV_SV

class warning_catcher extends uvm_report_catcher;
   `uvm_object_utils(warning_catcher)
   
   function new(string name = "warning_catcher");
    super.new(name);
   endfunction: new
 
   function action_e catch();
    if((get_severity() == UVM_WARNING) && (!uvm_re_match("Individual field access not available for field", get_message()))) begin
      set_severity(UVM_INFO);
    end
    if((get_severity() == UVM_WARNING) && (!uvm_re_match("is not contained within map 'Backdoor'", get_message()))) begin
      set_severity(UVM_INFO);
    end

    return THROW; 
  endfunction: catch
endclass: warning_catcher

class ahb_ral_env extends uvm_env;

    `uvm_component_utils(ahb_ral_env)

    warning_catcher  m_warning_catcher;

    // virtual sequencer
    ahb_ral_vseqr    m_vir_seqr;

    // register model
    ral_reg_block  m_regmodel;

    // ahb agent
    vc_ahb_agent                    m_cpu_a_m_agt;
    vc_ahb_config                   m_cpu_a_m_cfg;
    vc_ahb_reg_env                  m_cpu_a_m_reg_env;

    function new (string name="ahb_ral_env", uvm_component parent);
        super.new (name, parent);
        m_cpu_a_m_cfg = new();
    endfunction : new 

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        uvm_report_info(get_type_name(),$sformatf("build_phase"), UVM_LOW);

        m_warning_catcher = warning_catcher::type_id::create("m_warning_catcher",this);
        uvm_report_cb::add(null, m_warning_catcher);

        // virtual sequencer
        m_vir_seqr = ahb_ral_vseqr::type_id::create("m_vir_seqr",this);

        // register model
        m_regmodel = ral_reg_block::type_id::create ("m_regmodel", this);
        m_regmodel.build();
        void'(uvm_config_db #(ral_reg_block)::set (null, "uvm_test_top", "m_regmodel", m_regmodel));

        // ahb agent
        m_cpu_a_m_agt = vc_ahb_agent::type_id::create("m_cpu_a_m_agt",this);
        assert(m_cpu_a_m_cfg.randomize() with {is_active == UVM_ACTIVE; agent_type == vc_ahb_pkg::MASTER; });
        uvm_config_db#(uvm_object)::set(this, "m_cpu_a_m_agt", "ahb_cfg", m_cpu_a_m_cfg);
        m_cpu_a_m_reg_env = vc_ahb_reg_env::type_id::create ("m_cpu_a_m_reg_env", this);

    endfunction:build_phase

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        uvm_report_info(get_type_name(),$sformatf("connect_phase"), UVM_LOW);

        m_vir_seqr.p_cpu_a_m_seqr = m_cpu_a_m_agt.sequencer;

        m_cpu_a_m_reg_env.connect_reg(.map          (m_regmodel.default_map     ),
                                      .sequencer    (m_cpu_a_m_agt.sequencer    ),
                                      .monitor      (m_cpu_a_m_agt.monitor      ));
        m_regmodel.ram.set_frontdoor(m_cpu_a_m_reg_env.frontdoor, m_regmodel.default_map);
     endfunction:connect_phase

     function void report_phase(uvm_phase phase);
         super.report_phase(phase);
     endfunction : report_phase

endclass:ahb_ral_env

`endif // AHB_RAL_ENV_SV
