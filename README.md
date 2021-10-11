# RAL integration
register model integration for register and memory


## RAL access


## Basic RAL integration
What do you need:
- Register model(RAL)
- Adapter
- Predictor
<img width="577" alt="Screenshot 2021-10-11 at 8 12 50 AM" src="https://user-images.githubusercontent.com/35386741/136717666-76892e71-7318-41ac-a126-14c496fcf724.png">

### Example code:

```
    vc_apb_reg_adapter              adapter;
    uvm_reg_predictor#(vc_apb_xact) predictor;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        uvm_report_info(get_type_name(),$sformatf("build_phase"), UVM_LOW);
        adapter = vc_apb_reg_adapter::type_id::create ("adapter");
        predictor = uvm_reg_predictor#(vc_apb_xact)::type_id::create("predictor", this);
    endfunction:build_phase

    virtual function void connect_reg(uvm_reg_map map, vc_apb_sequencer sequencer, vc_apb_monitor monitor);
        // active mode
        if(sequencer != null) map.set_sequencer(sequencer, adapter);

        // passive mode
        predictor.map     = map;
        predictor.adapter = adapter;
        monitor.mon_ap.connect(predictor.bus_in);
    endfunction
```


```
        m_cpu_a_m_reg_env.connect_reg(.map          (m_regmodel.default_map     ),
                                      .sequencer    (m_cpu_a_m_agt.sequencer    ),
                                      .monitor      (m_cpu_a_m_agt.monitor      ));
```


