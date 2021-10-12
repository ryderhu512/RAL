// ===============================================================================
// Date: 2021-10-10
// Creator: Hu,Shiqing
// E-mail: schinghu@gmail.com
// Description: autogen by gentb.py
// ===============================================================================

module ahb_ral_ahb_mem(vc_ahb_if intf);

assign intf.hready = 1;
assign intf.hresp = 0;

reg         AHB_HSEL_s    ;
reg [31:0]  AHB_HADDR_s   ;
reg         AHB_HWRITE_s  ;
reg [1:0]   AHB_HTRANS_s  ;

int ram['h1000/4]; // 4KB ram

/*
- 0x0000 - 0x0fff  --> ram
- 0x1000 - 0x1100  --> register

- 0x1000 -> 
  - 0:0 enable
  - 2:1 cfg

- 0x1004 -> 
  - 7:0 status
*/
// ------------------------------------------------------------------------
// Main code
// ------------------------------------------------------------------------
logic           reg0_ena; // RW
logic [30:0]    reg0_cfg; // RW
logic [31:0]    reg1_sta; // RO

always@(posedge intf.hclk or negedge intf.hresetn) begin
    if(intf.hresetn == 0) begin
        intf.hrdata <= 0;
        AHB_HSEL_s <= 0;
        AHB_HADDR_s <= 0;
        AHB_HWRITE_s <= 0;

        reg0_ena <= '0;
        reg0_cfg <= '0;
        reg1_sta <= '0;
    end else begin
        if((intf.hsel == 1)) begin
            AHB_HADDR_s <= intf.haddr;
            AHB_HWRITE_s <= intf.hwrite;
            AHB_HTRANS_s <= intf.htrans;
        end

        if( intf.hsel == 1)
            AHB_HSEL_s <= 1;
        else if (intf.hready == 1)
            AHB_HSEL_s <= 0;

        // WRITE
        if ((intf.hready == 1)&&(AHB_HWRITE_s == 1)&&(AHB_HSEL_s == 1)&&(AHB_HTRANS_s[1] == 1)) begin
            if(AHB_HADDR_s[15:0] < 'h1000) begin
                ram[AHB_HADDR_s[15:2]] = intf.hwdata;
                $display("[%m][%0t] Write ram[%x] = %x", $time, AHB_HADDR_s, intf.hwdata);
            end else begin
                $display("[%m][%0t] Write register[%0d] = %x", $time, AHB_HADDR_s[11:0], intf.hwdata);
                if(AHB_HADDR_s[15:0] == 'h1000) begin
                    reg0_ena <= intf.hwdata[0];
                    reg0_cfg <= intf.hwdata[31:1];
                end
            ////if(AHB_HADDR_s[15:0] == 'h1004) begin
            ////    reg1_sta <= intf.hwdata[7:0];
            ////end
            end
        end

        // READ - read transfer with wait state is not considered yet
        if ((intf.hready == 1)&&(intf.hwrite == 0)&&(intf.hsel == 1)&&(intf.htrans[1] == 1)) begin
            if(intf.haddr[15:0] < 'h1000) begin
                intf.hrdata <= ram[intf.haddr[15:2]];
                $display("[%m][%0t] Read ram[%x] = %x", $time, intf.haddr, ram[intf.haddr[15:2]]);
            end else begin
                if(intf.haddr[15:0] == 'h1000) begin
                    intf.hrdata <= {reg0_cfg,reg0_ena};
                    $display("[%m][%0t] Read register[%0d] = %x", $time, intf.haddr[11:0], {reg0_cfg,reg0_ena});
                end
                if(intf.haddr[15:0] == 'h1004) begin
                    intf.hrdata <= {reg1_sta};
                    $display("[%m][%0t] Read register[%0d] = %x", $time, intf.haddr[11:0], {reg1_sta});
                end
            end
          end else if (intf.hsel == 0) begin // needed in order to check noc invalid address
            intf.hrdata <= 'hbadcafe;
        end
    end
end

endmodule // ahb_ral_ahb_mem

