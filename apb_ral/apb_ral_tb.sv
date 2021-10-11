// ===============================================================================
// Date: 2021-10-10
// Creator: Hu,Shiqing
// E-mail: shiqing_hu@apple.com
// Description: autogen by gentb.py
// ===============================================================================

`timescale 1ns/1fs

import uvm_pkg::*; 
`include "uvm_macros.svh"

import vc_apb_pkg::*;


`include "apb_ral_slave.sv"
`include "apb_ral_vseq.sv"
`include "apb_ral_env.sv"
`include "apb_ral_base_test.sv"
`include "apb_ral_test_lib.sv"

module apb_ral_tb();

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

    vc_apb_if   cpu_a_m_intf(clk, rstn);


    // connect interface




    initial begin

        uvm_config_db#(virtual vc_apb_if)::set(null, "uvm_test_top.m_env.m_cpu_a_m_agt", "intf", cpu_a_m_intf);
        uvm_config_db#(virtual vc_apb_if)::set(null, "uvm_test_top.m_env.m_cpu_a_m_agt.monitor", "intf", cpu_a_m_intf);

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


    // APB slave interface declaration
    vc_apb_if   apb_mem_a_intf(clk, rstn);

    // APB slave interface connection
    assign apb_mem_a_intf.paddr        = cpu_a_m_intf.paddr;
    assign apb_mem_a_intf.pwrite       = cpu_a_m_intf.pwrite;
    assign apb_mem_a_intf.pwdata       = cpu_a_m_intf.pwdata;
    assign apb_mem_a_intf.penable      = cpu_a_m_intf.penable;
    assign apb_mem_a_intf.psel         = (cpu_a_m_intf.paddr >= 'h10000000) && (cpu_a_m_intf.paddr <= 'h10002000);
    assign cpu_a_m_intf.prdata  = apb_mem_a_intf.prdata;
    assign cpu_a_m_intf.pready  = apb_mem_a_intf.pready;
    assign cpu_a_m_intf.pslverr = apb_mem_a_intf.pslverr;


    // APB memory slave
    apb_ral_apb_mem u_apb_mem_a (.intf(apb_mem_a_intf));
    




endmodule
