# RAL integration
register model integration for register and memory


## RAL register value and access type
There are 4 values in RAL for each registers
- reset value
- value: real value
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
    - perform write operation when desired value != mirrored value, it will:
      - copy desired_value to mirrored_value first
      - then perform write.
- mirror
    - perform read operation when desired value != mirrored value, it will:
      - copy desired_value to mirrored_value first
      - then perform read, and compare read value with mirrored_value if enabled.
- write
    - perform write operation.
    - only if predict enabled, it will update both desired value and mirrored value.
- read
    - perform read operation
    - when set_check_on_read() enabled, it compare read back value with mirrored value, raise error when mismatch found.
    - only if predict enabled, it will update both desired value and mirrored value.

mirrored value(as well as desired value) update in a few ways:
- write/read operation predictor collected.
- set_auto_predict() enabled and write/read operation from frontdoor access.
- backdoor write and read
- call predict().

### When and what to compare?
- When read/mirror happen, it compares read back value with mirrored_value. And then update mirrored_value in register model.
- Comapare only enabled when:
  - set_check_on_read()
  - predict enable by either:
    - set_auto_predict() -> explicit
    - predictor component exists -> implicit

### Built-in register sequence

<img width="923" alt="Screenshot 2021-10-12 at 9 40 39 PM" src="https://user-images.githubusercontent.com/35386741/136967123-5e9776c6-f216-4bb7-878c-230147b76b21.png">

e.g.
```
        uvm_reg_hw_reset_seq reg_seq = new();
        reg_seq.model = m_regmodel;
        reg_seq.start(m_env.m_agent.m_seqr);
```

### Register backdoor access

<img width="990" alt="Screenshot 2021-10-12 at 9 40 59 PM" src="https://user-images.githubusercontent.com/35386741/136967173-4ce23288-e297-4f75-be34-374d95d15a0a.png">

- add hdl path for dedicated field using add_hdl_path_slice
```
    virtual function void build();
        this.default_map = create_map(.name             ("default_map"      ), 
                                      .base_addr        (0                  ),
                                      .n_bytes          (4                  ),
                                      .endian           (UVM_LITTLE_ENDIAN  ), 
                                      .byte_addressing  (0                  ));

        this.cfg = ral_cfg_type::type_id::create("cfg",,get_full_name());
        this.cfg.configure(this);
        this.cfg.build();
        this.default_map.add_reg(.rg        (this.cfg   ), 
                                 .offset    ('h0        ), 
                                 .rights    ("RW"       ), 
                                 .unmapped  (0          ), 
                                 .frontdoor (null       ));
        this.cfg.add_hdl_path_slice(.name("reg0_ena"), .offset(0), .size(1));
        this.cfg.add_hdl_path_slice(.name("reg0_cfg"), .offset(1), .size(31));

        this.sta = ral_sta_type::type_id::create("sta",,get_full_name());
        this.sta.configure(this);
        this.sta.build();
        this.default_map.add_reg(.rg        (this.sta   ), 
                                 .offset    ('h4        ), 
                                 .rights    ("RO"       ), 
                                 .unmapped  (0          ), 
                                 .frontdoor (null       ));
        this.cfg.add_hdl_path_slice(.name("reg1_sta"), .offset(0), .size(32));

    endfunction : build
```
- Add reg_block top level hdl path and register bank hdl path.

```
    function void build();
        this.add_hdl_path("apb_ral_tb");

        this.ram = ral_ram::type_id::create("ram",, get_full_name());
        this.ram.configure(.parent(this), .hdl_path(""));

        this.ctl = ral_block_ctl_type::type_id::create("ctl",, get_full_name());
        this.ctl.configure(.parent(this), .hdl_path("u_apb_mem_a"));
        this.ctl.build();
```
- Use backdoor access in tests
    - Backdoor access happens in no time. In the case of DUT under reset, it updates DUT value but the value will reset again by the design. The backdoor write will be just like ignored.
    - One the other hand, for frontdoor access, as master will normally wait reset release first, so it will stuck there and start write/read till reset released.

```
        m_regmodel.ctl.cfg.ena.set(1);
        m_regmodel.ctl.cfg.update(status, UVM_BACKDOOR);
        
        m_regmodel.ctl.cfg.write(status, 1, UVM_BACKDOOR);
```


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
### Optimised structure

Since frontdoor sequence is connecting to register map and memory model only, why not just move it into reg_map?

<img width="695" alt="Screenshot 2021-10-13 at 10 25 56 AM" src="https://user-images.githubusercontent.com/35386741/137056437-c97c3425-e48b-4e81-882d-5fdef23f8be9.png">

```
class vc_mem_map#(type FRONTDOOR=vc_reg_frontdoor) extends uvm_reg_map;

   `uvm_object_utils(vc_mem_map#(FRONTDOOR))

    FRONTDOOR       m_frontdoor;

    function new(string name = "vc_mem_map");
        super.new(name);
        m_frontdoor = new({name,"_fd"});
    endfunction

    virtual function void add_mem(uvm_mem           mem,
                                  uvm_reg_addr_t    offset,
                                  string            rights = "RW",
                                  bit               unmapped=0,
                                  uvm_reg_frontdoor frontdoor=null);
        if(frontdoor != null) begin
            super.add_mem(mem, offset, rights, unmapped, frontdoor);
        end else begin
            super.add_mem(mem, offset, rights, unmapped, m_frontdoor);
        end
    endfunction:add_mem

endclass:vc_mem_map
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
    
## UVM register extension
In normal register operation using RAL, there are only three variables we can pass from test to driver:
    
- Direction: write or read
- Address
- Data

In some cases, we need pass more information to driver for register operations. Say in AHB, we need tell if the operation is privilege or not? if it's bufferable or not?
    
<img width="769" alt="Screenshot 2021-10-12 at 1 44 12 PM" src="https://user-images.githubusercontent.com/35386741/136898333-60cca2b8-b93d-4224-b689-1a282c3eb2d1.png">

UVM RAL provides extension to solve above scenario.

```
   virtual task read(output    uvm_status_e      status,        
                      input    uvm_reg_addr_t    offset,        
                     output    uvm_reg_data_t    value,        
                      input    uvm_path_e        path      = UVM_DEFAULT_PATH,
                      input    uvm_reg_map       map       = null,
                      input    uvm_sequence_base parent    = null,
                      input    int               prior     = -1,
                      input    uvm_object        extension = null,
                      input    string            fname     = "",
                      input    int               lineno    = 0 )
```
    
#### Step-1
Define reg_ext per bus protocol and master VIP.
    
```
class vc_ahb_reg_ext extends uvm_object;

    rand io_mode_t          io_mode;    // OPCODE, DATA, ...
    rand priv_mode_t        priv_mode;  // USER, PRIVILEGED, ...
    rand bit                bufferable;
    rand bit                cacheable;
    rand bit                lock;

    `uvm_object_utils_begin(vc_ahb_reg_ext)
        `uvm_field_enum(io_mode_t,io_mode,UVM_ALL_ON)
        `uvm_field_enum(priv_mode_t,priv_mode,UVM_ALL_ON)
        `uvm_field_int (bufferable, UVM_ALL_ON|UVM_HEX)
        `uvm_field_int (cacheable, UVM_ALL_ON|UVM_HEX)
        `uvm_field_int (lock, UVM_ALL_ON|UVM_HEX)
    `uvm_object_utils_end

    function new(string name = "vc_ahb_reg_ext");
        super.new(name);
    endfunction : new
    
    constraint c_def {
        soft io_mode == OPCODE;
        soft priv_mode == USER;
        soft bufferable == 0;
        soft cacheable == 0;
        soft lock == 0;
    }

endclass : vc_ahb_reg_ext
```
    
#### Step-2
Get extension in adapter and frontdoor sequence, assign the fields in xact.
```
    virtual function uvm_sequence_item reg2bus (const ref uvm_reg_bus_op rw);
        vc_ahb_xact xact;

        vc_ahb_reg_ext reg_ext;
        uvm_reg_item item;
        item = this.get_item();
        void'($cast(reg_ext, item.extension));
        if(reg_ext == null) reg_ext = new();

        xact = new();
        assert(xact.randomize() with {direction == ((rw.kind == UVM_WRITE) ? WRITE : READ);
                                      size      == WORD;
                                      burst     == SINGLE;
                                      addr      == rw.addr;
                                      data[0]   == rw.data;

                                      io_mode   == reg_ext.io_mode;
                                      priv_mode == reg_ext.priv_mode;
                                      bufferable== reg_ext.bufferable;
                                      cacheable == reg_ext.cacheable;
                                      lock      == reg_ext.lock;

                                      }) else
            uvm_report_error(get_type_name(), "randomize failed");
        return xact;
    endfunction
```
    
```
        vc_ahb_reg_ext reg_ext;
        void'($cast(reg_ext, rw_info.extension));
        if(reg_ext == null) reg_ext = new();

        assert(xact.randomize() with {direction     == READ;
                                      size          == WORD;
                                      burst         == INCR;
                                      addr          == base_addr;
                                      data.size()   == rw_info.value.size();
                                      io_mode       == reg_ext.io_mode;
                                      priv_mode     == reg_ext.priv_mode;
                                      bufferable    == reg_ext.bufferable;
                                      cacheable     == reg_ext.cacheable;
                                      lock          == reg_ext.lock;
                                      });
```
    
#### Step-3
Add reg_ext as extension when doing register read/write.
```
        vc_ahb_reg_ext reg_ext = new();
        assert(reg_ext.randomize() with{priv_mode == PRIVILEGED;});
        m_regmodel.ctl.cfg.ena.write (status, 'h1, .extension(reg_ext));
    
        m_regmodel.ram.burst_write (status, 0, {'h90, 'h91, 'h92, 'h93}, .extension(reg_ext));
```
    
## Register map application in multiple master system
    
Say we have a multiple master system like below.
    
<img width="633" alt="Screenshot 2021-10-12 at 4 01 26 PM" src="https://user-images.githubusercontent.com/35386741/136916355-a2548225-4e44-41b5-a6a3-78788f65a1b9.png">

Both master #0 and master #1 can access the same register block and memory block, but through different address of cause.
    
#### Step-1
Define UVM register file with two reg_map.
```
class ral_reg_block extends uvm_reg_block;

    uvm_reg_map        mst0_map;
    uvm_reg_map        mst1_map;

    rand ral_ram            ram;
    rand ral_block_ctl_type ctl;

    `uvm_object_utils(ral_reg_block)
    function new(string name = "ral_reg_block");
        super.new(name);
    endfunction

    function void build();
        this.add_hdl_path("apb_ral_tb");

        this.ram = ral_ram::type_id::create("ram",, get_full_name());
        this.ram.configure(.parent(this), .hdl_path(""));

        this.ctl = ral_block_ctl_type::type_id::create("ctl",, get_full_name());
        this.ctl.configure(.parent(this), .hdl_path("u_apb_mem_a"));
        this.ctl.build();

        this.mst0_map = create_map(.name             ("mst0_map"         ), 
                                   .base_addr        (0                  ), 
                                   .n_bytes          (4                  ), 
                                   .endian           (UVM_LITTLE_ENDIAN  ),
                                   .byte_addressing  (0                  ));
        this.mst0_map.add_mem   (this.ram,          32'h1000_0000, "RW");
        this.mst0_map.add_submap(this.ctl.mst0_map, 32'h1000_1000);

        this.mst1_map = create_map(.name             ("mst1_map"         ), 
                                   .base_addr        (0                  ), 
                                   .n_bytes          (4                  ), 
                                   .endian           (UVM_LITTLE_ENDIAN  ),
                                   .byte_addressing  (0                  ));
        this.mst1_map.add_mem   (this.ram,          32'h2000_0000, "RW");
        this.mst1_map.add_submap(this.ctl.mst1_map, 32'h2000_1000);

        this.set_mst0_map(this.mst0_map);
        this.lock_model();

    endfunction:build

endclass:ral_reg_block

```
    
#### Step-2
Connect reg_map to dedicated master
```
        m_mst0_reg_env.connect_reg(.map          (m_regmodel.mst0_map     ),
                                   .sequencer    (m_mst0_agt.sequencer    ),
                                   .monitor      (m_mst0_agt.monitor      ));
        m_regmodel.ram.set_frontdoor(m_mst0_reg_env.frontdoor, m_regmodel.mst0_map);

        m_mst1_reg_env.connect_reg(.map          (m_regmodel.mst1_map     ),
                                   .sequencer    (m_mst1_agt.sequencer    ),
                                   .monitor      (m_mst1_agt.monitor      ));
        m_regmodel.ram.set_frontdoor(m_mst1_reg_env.frontdoor, m_regmodel.mst1_map);
```
    
#### Step-3
Access register and memory in test. There are a few advantages compare to directly use VIP transaction:
    
- There is no hard-coded address in tests, no code need change if register or memory relocated in future.
- There is no VIP call in test, no code need change if master changed in future, say change from AHB to APB.
- Unified and easy access from different masters, just specify different map.
    
```
        m_regmodel.ctl.cfg.cfg.write (status, 'hABC);
        m_regmodel.ram.write (status, 0, 'h80);
        m_regmodel.ram.burst_write (status,  0, {'h90, 'h91, 'h92, 'h93});
        m_regmodel.ram.burst_write (status, 10, {'h90, 'h91, 'h92, 'h93}, UVM_BACKDOOR);
    
        m_regmodel.ctl.cfg.cfg.write (status, 'hABC, .map(m_regmodel.mst1_map));
        m_regmodel.ram.write (status, 0, 'h80, .map(m_regmodel.mst1_map));
        m_regmodel.ram.burst_write (status,  0, {'h90, 'h91, 'h92, 'h93}, .map(m_regmodel.mst1_map));
        m_regmodel.ram.burst_write (status, 10, {'h90, 'h91, 'h92, 'h93}, UVM_BACKDOOR, .map(m_regmodel.mst1_map));
```
More examples:
    
- Easy to request any random memory area/locations to access for any master.
- Support multiple masters access same memory but access different area to avoid access conflict.
```
    virtual task test_mem(int pattern, int burst_size, uvm_reg_map map=null);
        uvm_status_e status;
        uvm_reg_data_t wdata[], rdata[];
        uvm_mem_region mrg;

        wdata = new[burst_size];
        rdata = new[burst_size];
        std::randomize(wdata) with { wdata.size() == burst_size; foreach(wdata[k]) wdata[k][31:28] == pattern;};

        mrg = m_regmodel.ram.request_region(burst_size, policy);

        m_regmodel.ram.burst_write(status, mrg.get_start_offset(), wdata, UVM_FRONTDOOR, map);
        m_regmodel.ram.burst_read (status, mrg.get_start_offset(), rdata, UVM_FRONTDOOR, map);

        wdata.delete();
        rdata.delete();
        mrg.release_region();
    endtask
    
    repeat(100) begin
    fork
        test_mem('hA, 100, m_regmodel.mst0_map)
        test_mem('hB, 100, m_regmodel.mst1_map)
    join
    end
    
```
