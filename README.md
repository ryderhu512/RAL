# RAL integration
register model integration for register and memory


## RAL access type
There are 4 values in RAL for each registers
- reset value
- value: real value?
- desired value
- miorred value: this is the mirrored value of DUT, it's like a model value

And there are different operations:
- get
    - get desired value
- set
    - set desired value
- predict
    - set desired value and mirrored value, not perform DUT write or read
- update
    - perform write operation when desired value != mirrored value, mirrored value wouldn't change automatically.
- mirror
    - perform read operation when desired value != mirrored value, mirrored value wouldn't change automatically.
- write
    - perform write operation, not update desired value or mirrored value
- read
    - perform read operation, not update desired value or mirrored value
    - when set_check_on_read() enabled, it compare read back value with mirrored value, raise error when mismatch found.

mirrored value(as well as desired value) update in a few ways:
- per value predictor collected.
- set_auto_predict() enabled and write/read call from frontdoor access.
- call predict().
- backdoor write and read?


## Basic RAL integration
What do you need:
- Register model(RAL)
- Adapter
- Predictor
<img width="577" alt="Screenshot 2021-10-11 at 8 12 50 AM" src="https://user-images.githubusercontent.com/35386741/136717666-76892e71-7318-41ac-a126-14c496fcf724.png">

### Example code:
Since adapter and predictor are closely coupled with VIP or Verification Component, they can be encapsulated together. Here we create a new class 'reg_env' to include them all and provide function connect_reg which can be called in upper level.


- Define adapter and predictor
    - Note: for pipe-line bus like AHB, the read data will be provided in response, in this case, need set provides_responses in adapter. Otherwise, for non-pipeline bus like APB, don't need set this variable.
```
class vc_apb_reg_adapter extends uvm_reg_adapter;
     `uvm_object_utils (vc_apb_reg_adapter)
    function new (string name = "vc_apb_reg_adapter");
        super.new (name);
    ////provides_responses = 1;
    endfunction

    virtual function uvm_sequence_item reg2bus (const ref uvm_reg_bus_op rw);
        vc_apb_xact xact = new();
        assert(xact.randomize() with {direction == ((rw.kind == UVM_WRITE) ? WRITE : READ);
                                      addr      == rw.addr;
                                      data      == rw.data;});
        return xact;
    endfunction
    
    virtual function void bus2reg (uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
        vc_apb_xact xact;
        if (! $cast (xact, bus_item)) begin
            `uvm_fatal ("vc_apb_reg_adapter", "Failed to cast bus_item to xact")
        end
        rw.kind = (xact.direction == WRITE) ? UVM_WRITE : UVM_READ;
        rw.addr =  xact.addr;
        rw.data =  xact.data;
        if(xact.resp != OKAY) rw.status = UVM_NOT_OK;
   endfunction
endclass:vc_apb_reg_adapter
```
```
class vc_apb_reg_env extends uvm_env;
    vc_apb_reg_adapter              adapter;
    uvm_reg_predictor#(vc_apb_xact) predictor;

    virtual function void build_phase(uvm_phase phase);
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

- connect adapter, predictor, register map and VIP/VC sequencer.
```
    virtual function void build_phase(uvm_phase phase);
        // register model
        m_regmodel = ral_reg_block::type_id::create ("m_regmodel", this);
        m_regmodel.build();
        void'(uvm_config_db #(ral_reg_block)::set (null, "uvm_test_top", "m_regmodel", m_regmodel));

        // apb agent
        m_cpu_a_m_reg_env = vc_apb_reg_env::type_id::create ("m_cpu_a_m_reg_env", this);
        ... ...
        
    virtual function void connect_phase(uvm_phase phase);
        m_cpu_a_m_reg_env.connect_reg(.map          (m_regmodel.default_map     ),
                                      .sequencer    (m_cpu_a_m_agt.sequencer    ),
                                      .monitor      (m_cpu_a_m_agt.monitor      ));
```

- Call RAL for register and memory access
    - Note: for memory access, the address is offset within the memory.
```
        m_regmodel.ctl.cfg.ena.write (status, 'h1);
        m_regmodel.ctl.cfg.ena.write (status, 'h0);
        m_regmodel.ctl.cfg.cfg.write (status, 'hABC);
        m_regmodel.ram.write (status, 0, 'h80);
```

## Frontdoor sequence for memory burst access
In above basic RAL access, both register and memory operations are converted by adapter, and only single operations supported. How about burst operation in some bus like AHB? We can use frontdoor sequence to address this.

<img width="639" alt="Screenshot 2021-10-11 at 8 53 59 AM" src="https://user-images.githubusercontent.com/35386741/136719404-8617d2e4-f7ea-4c3b-9510-c12c789b25ef.png">

### Example code:
- Define frontdoor sequence
```
class vc_apb_reg_frontdoor extends uvm_reg_frontdoor;

    bit verbose;

    `uvm_declare_p_sequencer(vc_apb_sequencer)

    function new(string name);
        super.new(name);
    endfunction

    task body();
        uvm_mem mem;  
        uvm_reg_addr_t base_addr;
  
        if (!$cast(mem, rw_info.element)) begin
            `uvm_fatal(get_type_name(), "Could not cast rw_info.element to uvm_mem");
        end
        base_addr = mem.get_offset(0, rw_info.local_map) + rw_info.offset*4;
        if(verbose)
            `uvm_info ({"vc_apb_reg_frontdoor_", rw_info.map.get_name()}, $sformatf("[body][%s] base_addr = 0x%0x, size = %0d", 
                rw_info.kind.name(), base_addr, rw_info.value.size()), UVM_LOW) 
    
        rw_info.status = UVM_IS_OK;
        if (rw_info.kind == UVM_WRITE || rw_info.kind == UVM_BURST_WRITE) begin
            send_write(base_addr);
        end else begin
            send_read(base_addr);
        end

        if(verbose)
            `uvm_info ({"vc_apb_reg_frontdoor_", rw_info.map.get_name()}, $sformatf("[body] complete"), UVM_LOW) 
    endtask

    virtual task send_write(uvm_reg_addr_t base_addr);
        vc_apb_xact  xact = new();

        foreach(rw_info.value[k]) begin
            assert(xact.randomize() with {direction     == WRITE;
                                          addr          == base_addr + 4*k;
                                          data          == rw_info.value[k];});
            `uvm_send(xact)
            // get_response(rsp); 
            // assert($cast(xact, rsp));

            if(xact.resp != OKAY) rw_info.status = UVM_NOT_OK;
            if(verbose)
                `uvm_info ({"vc_apb_reg_frontdoor_", rw_info.map.get_name()}, $sformatf("[body][%s] #%0d, addr = 0x%0x, data = 0x%0x", 
                    rw_info.kind.name(), k, base_addr+4*k, rw_info.value[k]), UVM_LOW) 
        end

    endtask

    virtual task send_read(uvm_reg_addr_t base_addr);
        vc_apb_xact  xact = new();

        foreach(rw_info.value[k]) begin
            assert(xact.randomize() with {direction     == WRITE;
                                          addr          == base_addr + 4*k;
                                          data          == rw_info.value[k];});
            `uvm_send(xact)
            // get_response(rsp); 
            // assert($cast(xact, rsp));

            if(xact.resp != OKAY) rw_info.status = UVM_NOT_OK;
            rw_info.value[k] = xact.data;
            if(verbose)
                `uvm_info ({"vc_apb_reg_frontdoor_", rw_info.map.get_name()}, $sformatf("[body][%s] #%0d, addr = 0x%0x, data = 0x%0x", 
                    rw_info.kind.name(), k, base_addr+4*k, rw_info.value[k]), UVM_LOW) 
        end

    endtask

endclass:vc_apb_reg_frontdoor
```

- add frontdoor into 'reg_env'
```
class vc_apb_reg_env extends uvm_env;
    vc_apb_reg_frontdoor            frontdoor;
    function new (string name="vc_apb_reg_env", uvm_component parent);
        super.new (name, parent);
        frontdoor = new({name, "_fd"});
    endfunction : new 
```

- connect frontdoor sequence to register map and memory model
```
        m_regmodel.ram.set_frontdoor(m_cpu_a_m_reg_env.frontdoor, m_regmodel.default_map);
```

- Memory burst access
```
        m_regmodel.ram.burst_write (status, 0, {'h90, 'h91, 'h92, 'h93});
```

## Memory Allocation Manager
Refer [here](https://verificationacademy.com/verification-methodology-reference/uvm/docs_1.1a/html/files/reg/uvm_mem_mam-svh.html#uvm_mem_mam.get_memory).

<img width="661" alt="Screenshot 2021-10-11 at 1 06 36 PM" src="https://user-images.githubusercontent.com/35386741/136736116-9b9cd2bf-1e7a-4f20-9159-22090031b744.png">

- Note: create class vc_mem_base which has mam/cfg/policy declared inside.

```
    uvm_mem_mam mam;
    uvm_mem_mam_cfg cfg;
    uvm_mem_mam_policy policy;
    function void create_mam(string name="mam", int start_offset='0, int end_offset=-1);
        cfg = new();
        cfg.n_bytes = this.get_n_bytes();
        cfg.start_offset = start_offset;
        cfg.end_offset = end_offset;
        if(end_offset == -1) cfg.end_offset = this.get_size();
        mam = new(name, cfg, this);
    endfunction

    function uvm_mem_mam get_mam();
        if(mam == null) create_mam();
        return mam;
    endfunction

    function uvm_mem_region request_region(int unsigned n_words, uvm_mem_mam_policy alloc = null);
        if(mam == null) create_mam();
        if(alloc == null) alloc = policy;
        // uvm_report_info(get_type_name(), "called request_region!", UVM_LOW);
        return mam.request_region(.n_bytes(4*n_words), .alloc(alloc));
    endfunction

    function void release_region(uvm_mem_region region);
        mam.release_region(region);
    endfunction

    function void release_all_regions();
        if(mam != null) begin
            mam.release_all_regions();
            uvm_report_info(get_type_name(), "called release_all_regions!", UVM_LOW);
        end
    endfunction
```


```
    virtual task test_mem(int pattern, int burst_size, uvm_reg_map map=null);
        uvm_status_e status;
        uvm_reg_data_t wdata[], rdata[];
        uvm_mem_region mrg;

        wdata = new[burst_size];
        rdata = new[burst_size];
        std::randomize(wdata) with { wdata.size() == burst_size; foreach(wdata[k]) wdata[k][31:28] == pattern;};

        mrg = m_reg_block.u_gnss_me_sram.request_region(burst_size, policy);

        m_reg_block.u_gnss_me_sram.burst_write(status, mrg.get_start_offset(), wdata, UVM_FRONTDOOR, map);
        m_reg_block.u_gnss_me_sram.burst_read (status, mrg.get_start_offset(), rdata, UVM_FRONTDOOR, map);

        wdata.delete();
        rdata.delete();
        mrg.release_region();
    endtask
```

### Potential bug in UVM library
Currently I am using uvm_mem_mam and uvm_mem_region to perforce some memory tests and found one potential bug in uvm_mem_region::burst_read. It’s defined in file: <uvm library path>/sv/src/reg/uvm_mem_mam.svh

My test is something like this:
```
        mrg = m_regmodel.mem_1.request_region(32);
        mrg.burst_write(status, 0, wdata);
        rdata = new[4];
        mrg.burst_read (status, 0, rdata);
```
it turns out that burst_write is okay while burst_read always return 0, and when I check my frontdoor sequence, the value rw_info.value.size() is always 0.
When I tried uvm_mem::burst_read, it works fine. Then I come to check the difference in both classes.
```
task uvm_mem_region::burst_read(output uvm_status_e       status,
                                input  uvm_reg_addr_t     offset,
                                output uvm_reg_data_t     value[], // Shiqing: should use ref rather than output here.
                                input  uvm_path_e         path = UVM_DEFAULT_PATH,
                                input  uvm_reg_map        map    = null,
                                input  uvm_sequence_base  parent = null,
                                input  int                prior = -1,
                                input  uvm_object         extension = null,
                                input  string             fname = "",
                                input  int                lineno = 0);

task uvm_mem::burst_read(output uvm_status_e       status,
                         input  uvm_reg_addr_t     offset,
                         ref    uvm_reg_data_t     value[],
                         input  uvm_path_e         path = UVM_DEFAULT_PATH,
                         input  uvm_reg_map        map = null,
                         input  uvm_sequence_base  parent = null,
                         input  int                prior = -1,
                         input  uvm_object         extension = null,
                         input  string             fname = "",
                         input  int                lineno = 0);
```
We can see the value[] is defined as ref in uvm_mem while it's output in uvm_mem_region.

In this context, since we need pass burst size implicitly through the size of value, so it should be ref rather than output in uvm_mem_region::burst_read as well.

When I change uvm_mem_region::burst_read value type to ref locally, it works then.



## Memory backdoor access

<img width="681" alt="Screenshot 2021-10-11 at 1 08 11 PM" src="https://user-images.githubusercontent.com/35386741/136736254-72a0c793-0693-43ed-ae46-537a52e509be.png">


- Define backdoor access class and implement task write and read.
```
class vc_mem_backdoor extends uvm_reg_backdoor;
    // hdl path to memory cells
    string hdl_path;
    // memory access is always word based, here it's number of words
    int mem_line_num;
    // number of bit in memory physical line
    int mem_line_width;

    bit verbose;

    function new(string name);
        super.new(name);
    endfunction

    virtual function configure(string hdl_path, int unsigned mem_line_num, 
                               int unsigned mem_line_width=32, bit verbose=0);
        this.hdl_path = hdl_path;
        this.mem_line_num = mem_line_num;
        this.mem_line_width = mem_line_width;
        this.verbose = verbose;
    endfunction

    // For memory which has multiple cuts, as each cuts has different hdl path
    // so need override function get_word_path accordingly.
    virtual function string get_word_path(int word_idx);
        int line_idx, word_offset;
        string word_path;
        line_idx = word_idx/(mem_line_width/32);
        word_offset = word_idx%(mem_line_width/32);
        word_path  = $sformatf("%s[%0d][%0d:%0d]", hdl_path, line_idx, word_offset*32+31, word_offset*32);
        return word_path;
    endfunction

    virtual task write(uvm_reg_item rw);
        rw.status = UVM_IS_OK;
        for (int unsigned k = 0; k < rw.value.size(); k ++) begin
            string word_path = get_word_path(rw.offset + k);

            if(uvm_hdl_deposit(word_path, rw.value[k])) begin
                if(verbose)
                    `uvm_info ("mem_backdoor", $sformatf("[write] %s = 0x%0x", word_path, rw.value[k]), UVM_LOW) 
            end else begin
                rw.status = UVM_NOT_OK;
                `uvm_error("mem_backdoor", $sformatf("[write] %s failed!", word_path)) 
            end
        end
    endtask

    virtual task read(uvm_reg_item rw);
        rw.status = UVM_IS_OK;
        for (int unsigned k = 0; k < rw.value.size(); k++) begin
            string word_path = get_word_path(rw.offset + k);

            if(uvm_hdl_read(word_path, rw.value[k])) begin
                if(verbose)
                    `uvm_info ("mem_backdoor", $sformatf("[read] %s = 0x%0x", word_path, rw.value[k]), UVM_LOW) 
            end else begin 
                rw.status = UVM_NOT_OK;
                `uvm_error("mem_backdoor", $sformatf("[read] %s failed!", word_path)) 
            end

        end
  endtask

endclass:vc_mem_backdoor
```
- Attach backdoor class to memory model
```
class ral_ram extends vc_mem_base; // uvm_mem;
    vc_mem_backdoor         ram_bd;
    `uvm_object_utils(ral_ram)
    function new(string name="ram");
        super.new(.name         (name           ), 
                  .size         ('h1000         ), // number of bytes
                  .n_bits       (32             ), // number of bits per item/line, not physically line
                  .access       ("RW"           ),
                  .has_coverage (UVM_NO_COVERAGE));

        ram_bd = new({name, "_bd"});
        ram_bd.configure(.hdl_path("apb_ral_tb.u_apb_mem_a.ram"), .mem_line_num('h1000/4));
        this.set_backdoor(ram_bd);
    endfunction:new
endclass:ral_ram
```
- Access memory from backdoor in tests
```
m_regmodel.ram.burst_write (status, 10, {'h90, 'h91, 'h92, 'h93}, UVM_BACKDOOR);
```
    

