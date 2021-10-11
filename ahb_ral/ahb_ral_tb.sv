// ===============================================================================
// Date: 2021-10-10
// Creator: Hu,Shiqing
// E-mail: shiqing_hu@apple.com
// Description: autogen by gentb.py
// ===============================================================================

`timescale 1ns/1fs

import uvm_pkg::*; 
`include "uvm_macros.svh"

import vc_ahb_pkg::*;


`include "ahb_ral_slave.sv"
`include "ahb_ral_vseq.sv"
`include "ahb_ral_env.sv"
`include "ahb_ral_base_test.sv"
`include "ahb_ral_test_lib.sv"

module ahb_ral_tb();

    // clock & reset generation
    logic clk, rstn;
    task apply_reset(int cnt = 10);
        rstn = 0;
        repeat(cnt) @(posedge clk);
        rstn = 1;
    endtask

    initial begin
        apply_reset();
    end

    initial begin
        clk = 0;
        forever begin
            #5 clk = ~clk;
        end
    end

    // declare interface

    vc_ahb_if   cpu_a_m_intf(clk, rstn);


    // connect interface




    initial begin

        uvm_config_db#(virtual vc_ahb_if)::set(null, "uvm_test_top.m_env.m_cpu_a_m_agt", "intf", cpu_a_m_intf);
        uvm_config_db#(virtual vc_ahb_if)::set(null, "uvm_test_top.m_env.m_cpu_a_m_agt.monitor", "intf", cpu_a_m_intf);

    end 

    initial begin
        // used for time display in log file only
        // -9: 1e-9 meaning NS
        //  3: 3-bits fraction
        // ns: unit
        // 12: total 12-bits in display
        // e.g.: 334842.322ns
        $timeformat(-9, 3, "ns", 12);
        run_test ();
    end


    // AHB slave interface declaration
    vc_ahb_if   ahb_mem_a_intf(clk, rstn);

    // AHB slave interface connection
    assign ahb_mem_a_intf.haddr        = cpu_a_m_intf.haddr;
    assign ahb_mem_a_intf.hburst       = cpu_a_m_intf.hburst;
    assign ahb_mem_a_intf.htrans       = cpu_a_m_intf.htrans;
    assign ahb_mem_a_intf.hwrite       = cpu_a_m_intf.hwrite;
    assign ahb_mem_a_intf.hsize        = cpu_a_m_intf.hsize;
    assign ahb_mem_a_intf.hwdata       = cpu_a_m_intf.hwdata;
    assign ahb_mem_a_intf.hprot        = cpu_a_m_intf.hprot;
    assign ahb_mem_a_intf.hmasterlock  = cpu_a_m_intf.hmasterlock;
    assign ahb_mem_a_intf.hsel         = (cpu_a_m_intf.haddr >= 'h10000000) && (cpu_a_m_intf.haddr <= 'h10002000);
    assign ahb_mem_a_intf.hready_in    = '1;
    assign cpu_a_m_intf.hrdata  = ahb_mem_a_intf.hrdata;
    assign cpu_a_m_intf.hready  = ahb_mem_a_intf.hready;
    assign cpu_a_m_intf.hresp   = ahb_mem_a_intf.hresp;

    // AHB memory slave
    ahb_ral_ahb_mem u_ahb_mem_a (.intf(ahb_mem_a_intf));
    




endmodule
