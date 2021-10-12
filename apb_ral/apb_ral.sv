`ifndef APB_RAL_SV
`define APB_RAL_SV

import uvm_pkg::*;

`include "vc_mem_base.svh"
`include "vc_mem_backdoor.svh"

class ral_cfg_type extends uvm_reg;
    rand uvm_reg_field ena;
    rand uvm_reg_field cfg;

    `uvm_object_utils(ral_cfg_type)

    function new(string name = "ral_cfg");
        super.new(name, 32, build_coverage(UVM_NO_COVERAGE));
    endfunction: new

    virtual function void build();
        this.ena = uvm_reg_field::type_id::create("ena",, get_full_name()); 
        this.cfg = uvm_reg_field::type_id::create("cfg",, get_full_name()); 

        this.ena.configure(.parent                  (this   ), 
                           .size                    (1      ), 
                           .lsb_pos                 (0      ),
                           .access                  ("RW"   ), 
                           .volatile                (0      ), 
                           .reset                   (1'h0   ), 
                           .has_reset               (1      ), 
                           .is_rand                 (0      ), 
                           .individually_accessible (0      ));
        this.cfg.configure(.parent                  (this   ), 
                           .size                    (31     ), 
                           .lsb_pos                 (1      ),
                           .access                  ("RW"   ), 
                           .volatile                (0      ), 
                           .reset                   (1'h0   ), 
                           .has_reset               (1      ), 
                           .is_rand                 (0      ), 
                           .individually_accessible (0      ));
    endfunction : build

endclass : ral_cfg_type


class ral_sta_type extends uvm_reg;
    rand uvm_reg_field sta;

    `uvm_object_utils(ral_sta_type)

    function new(string name = "ral_stat");
        super.new(name, 32, build_coverage(UVM_NO_COVERAGE));
    endfunction: new

    virtual function void build();
        this.sta = uvm_reg_field::type_id::create("sta",, get_full_name()); 

        this.sta.configure(.parent                  (this   ), 
                           .size                    (32     ), 
                           .lsb_pos                 (0      ),
                           .access                  ("RO"   ), 
                           .volatile                (0      ), 
                           .reset                   (1'h0   ), 
                           .has_reset               (1      ), 
                           .is_rand                 (0      ), 
                           .individually_accessible (0      ));
    endfunction : build
endclass : ral_sta_type


class ral_block_ctl_type extends uvm_reg_block;

    rand ral_cfg_type   cfg;
    rand ral_sta_type   sta;

    `uvm_object_utils(ral_block_ctl_type)

    function new(string name = "ral_block_cfg");
        super.new(name, build_coverage(UVM_NO_COVERAGE));
    endfunction

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

endclass : ral_block_ctl_type


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


class ral_reg_block extends uvm_reg_block;

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


        this.default_map = create_map(.name             ("default_map"      ), 
                                      .base_addr        (0                  ), 
                                      .n_bytes          (4                  ), 
                                      .endian           (UVM_LITTLE_ENDIAN  ),
                                      .byte_addressing  (0                  ));
        this.default_map.add_mem   (this.ram,             32'h1000_0000, "RW");
        this.default_map.add_submap(this.ctl.default_map, 32'h1000_1000);


        this.set_default_map(this.default_map);
        this.lock_model();

    endfunction:build

endclass:ral_reg_block

`endif // APB_RAL_SV
