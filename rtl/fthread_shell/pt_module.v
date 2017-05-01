`include "../framework_defines.vh"

module pt_module (
	input                                   clk,
	input                                   rst_n,
    
    ///////////////////// pagetable <--> io_requester
	// afu_virt_waddr --> afu_phy_waddr
	input  wire  [57:0]                     afu_virt_wr_addr,
	input  wire                             pt_re_wr,
	output wire  [31:0]                     afu_phy_wr_addr,
    output wire                             afu_phy_wr_addr_valid,
	// afu_virt_raddr --> afu_phy_raddr
	input  wire  [57:0]                     afu_virt_rd_addr,
	input  wire                             pt_re_rd,
	output wire  [31:0]                     afu_phy_rd_addr,
    output wire                             afu_phy_rd_addr_valid,
    
    ////////////////////// pagetable <--> server_io
	// pt tx_rd, rx_rd
	output wire  [31:0]                     pt_tx_rd_addr,
	output wire  [`PAGETABLE_TAG-1:0]       pt_tx_rd_tag,
	output wire                             pt_tx_rd_valid,
	input  wire                             pt_tx_rd_ready,

	input  wire  [255:0]                    pt_rx_data,
	input  wire  [`PAGETABLE_TAG-1:0]       pt_rx_rd_tag,
	input  wire                             pt_rx_rd_valid,

	/////////////////////// pagetable <--> cmd_server        
    output wire  [1:0]                      pt_status,
    input  wire                             pt_update,
	input  wire  [31:0]                     pt_base_addr,

	output reg   [`PTE_WIDTH-1:0]           first_page_base_addr,
	output reg                              first_page_base_addr_valid,
	output reg   [57:0]                     ws_virt_base_addr,
    output reg                              ws_virt_base_addr_valid
);

wire  [`PT_ADDRESS_BITS-1:0]   afu_virt_raddr;
reg   [31:0]                   afu_tx_rel_raddr_d1;
reg   [32-`PTE_WIDTH-1:0]      afu_tx_rel_raddr_d2;
reg 						   pt_re_rd_d1;
reg 						   pt_re_rd_d2;

reg   [31:0]                   afu_tx_rel_waddr_d1;
reg   [32-`PTE_WIDTH-1:0]      afu_tx_rel_waddr_d2;
reg 						   pt_re_wr_d1;
reg 						   pt_re_wr_d2;

wire						   tr_pt_re;
reg 						   pt_we;
wire  [`PT_ADDRESS_BITS-1:0]   pt_addr0;
reg   [`PT_ADDRESS_BITS-1:0]   pt_waddr0;
reg   [`PT_ADDRESS_BITS-1:0]   pt_waddr1;
reg   [`PTE_WIDTH-1:0]		   pt_din;
wire  [`PTE_WIDTH-1:0]		   tr_pt_dout;
wire						   tw_pt_re;
wire  [`PT_ADDRESS_BITS-1:0]   tw_pt_raddr;
wire  [`PTE_WIDTH-1:0]		   tw_pt_dout; 

reg   [2:0]					   pt_state;
reg   [31:0]				   pt_base;
reg   [41:0]				   afu_vir_base;

reg   [`PT_ADDRESS_BITS-1:0]   pt_raddr;
reg   [`PT_ADDRESS_BITS:0]     pt_rd_cnt;
reg   [`PT_ADDRESS_BITS:0]     pt_wr_cnt;
reg   [31:0]				   pt_base_inc;

reg  [255:0]                   pt_rx_data_reg;
reg  [`PAGETABLE_TAG-1:0]      pt_rx_rd_tag_reg;
reg                            pt_rx_rd_valid_reg;
  

localparam [2:0]
		PT_FREE_STATE            = 3'b000,
		PT_CONFIG_REQ_STATE      = 3'b001,
		PT_CONFIG_READ_STATE     = 3'b010,
		PT_LOADING_STATE         = 3'b011,
		PT_VALID_STATE           = 3'b100; 


////////////////////////////////////////

always@(posedge clk) begin
	if(~rst_n) begin
		pt_rx_data_reg      <= 0;
		pt_rx_rd_tag_reg    <= 0;
		pt_rx_rd_valid_reg  <= 0;
	end
	else begin
		pt_rx_data_reg      <= pt_rx_data;
		pt_rx_rd_tag_reg    <= pt_rx_rd_tag;
		pt_rx_rd_valid_reg  <= pt_rx_rd_valid;
	end 
end 
//////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////                       //////////////////////////////////
//////////////////////////////     Pagetable TX RD         ///////////////////////////////
/////////////////////////////////                       //////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////// 

/////////////////////////////////////////////////////
assign pt_tx_rd_valid = (pt_state == PT_CONFIG_REQ_STATE) | 
                        ((pt_state == PT_LOADING_STATE) & (|pt_rd_cnt));
assign pt_tx_rd_addr  = (pt_state == PT_CONFIG_REQ_STATE)? pt_base : pt_base_inc;
assign pt_tx_rd_tag   = (pt_state == PT_CONFIG_REQ_STATE)? 'b0 : 'b1;

//////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////                       //////////////////////////////////
//////////////////////////////     Pagetable Status        ///////////////////////////////
/////////////////////////////////                       //////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////// 

// page table
    spl_pt_mem #(.ADDR_WIDTH           (`PT_ADDRESS_BITS),
                 .DATA_WIDTH           (`PTE_WIDTH)
    ) pagetable (
        .clk        (clk),             
        
        .we0		(pt_we),
        .addr0      (pt_addr0),
        .din0       (pt_din),
		.re0	  	(tr_pt_re),  		
        .dout0      (tr_pt_dout),
        
		.re1	    (tw_pt_re), 
        .addr1      (tw_pt_raddr),  
        .dout1      (tw_pt_dout)                           
    );


always@(posedge clk) begin
	if( ~rst_n) begin 
		pt_we     <= 0;
      	pt_din    <= 0;
      	pt_waddr0 <= 0;
      	pt_waddr1 <= 0;
	end 
	else begin
		pt_we    <= 1'b0;
		if(pt_rx_rd_valid_reg & (pt_state == PT_LOADING_STATE)) begin
	   		pt_we     <= 1'b1;
	   		pt_waddr0 <= pt_waddr0 + 1'b1;
	   		pt_waddr1 <= pt_waddr0;
	   	end 
      	pt_din   <= pt_rx_data_reg[37:38-`PTE_WIDTH];
	end 
end 

assign pt_addr0 = (pt_state == PT_LOADING_STATE)? pt_waddr1 : afu_virt_raddr;

assign pt_status = {1'b0, (pt_state == PT_VALID_STATE)};
/////////////////////////////////////////////////////
always@(posedge clk) begin
	if( ~rst_n) begin 
		pt_state                   <= 3'b000;
		pt_base                    <= 32'b0;

		first_page_base_addr_valid <= 0;
		first_page_base_addr       <= 0;
		afu_vir_base               <= 0;
		pt_base_inc                <= 0;
		pt_rd_cnt                  <= 0;
		pt_wr_cnt                  <= 0;

		ws_virt_base_addr          <= 0;
		ws_virt_base_addr_valid    <= 1'b0;
	end 
	else begin
		case( pt_state ) 
			PT_FREE_STATE: begin
				pt_state <= (pt_update)? PT_CONFIG_REQ_STATE : PT_FREE_STATE;
				pt_base  <= pt_base_addr;

				ws_virt_base_addr_valid <= 1'b0;
			end 
			PT_CONFIG_REQ_STATE: begin
				pt_state       <= (pt_tx_rd_ready)? PT_CONFIG_READ_STATE : PT_CONFIG_REQ_STATE;
			end 
			PT_CONFIG_READ_STATE: begin
				if(pt_rx_rd_valid_reg) begin 
					pt_state 	 <= PT_LOADING_STATE;
					pt_base  	 <= pt_rx_data_reg[37:6];
					afu_vir_base <= pt_rx_data_reg[111:70];
                    
					pt_base_inc  <= pt_rx_data_reg[37:6];
					pt_rd_cnt    <= pt_rx_data_reg[160+`PT_ADDRESS_BITS:160];
					pt_wr_cnt    <= pt_rx_data_reg[160+`PT_ADDRESS_BITS:160];

					ws_virt_base_addr       <= pt_rx_data_reg[127:70];
					ws_virt_base_addr_valid <= 1'b1;
				end
			end
			PT_LOADING_STATE: begin
				pt_state       <= ((|pt_rd_cnt) | (|pt_wr_cnt))? PT_LOADING_STATE : PT_VALID_STATE;
				if(pt_tx_rd_ready & (|pt_rd_cnt)) begin 
					pt_rd_cnt      <= pt_rd_cnt - 1'b1;
					pt_base_inc    <= pt_base_inc + 1'b1;
				end
				//
			    if(pt_rx_rd_valid_reg) begin
			    	pt_wr_cnt <= pt_wr_cnt - 1'b1;

			    	first_page_base_addr_valid <= 1'b1;

			    	if(~first_page_base_addr_valid) begin
			    		first_page_base_addr       <= pt_rx_data_reg[37:38-`PTE_WIDTH];
			    	end
			    end
			end
			PT_VALID_STATE: begin
				pt_state       <= PT_VALID_STATE;
			end
		endcase 
	end 
end 
//////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////                       //////////////////////////////////
//////////////////////////////     WR Addr Translator      ///////////////////////////////
/////////////////////////////////                       //////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////// 

assign tw_pt_re              = pt_re_wr_d1;
assign tw_pt_raddr           = afu_tx_rel_waddr_d1[32-`PTE_WIDTH+`PT_ADDRESS_BITS-1:32-`PTE_WIDTH];

assign afu_phy_wr_addr       = {tw_pt_dout, afu_tx_rel_waddr_d2};
assign afu_phy_wr_addr_valid = pt_re_wr_d2;

always@(posedge clk) begin
	if( ~rst_n) begin
		afu_tx_rel_waddr_d1 <= 0;
		afu_tx_rel_waddr_d2 <= 0;
		pt_re_wr_d1         <= 1'b0;
		pt_re_wr_d2         <= 1'b0;
	end
	else begin
		// Stage 1 of the pipline
		afu_tx_rel_waddr_d1 <= (afu_virt_wr_addr[31:0] - afu_vir_base[31:0]);
		pt_re_wr_d1         <= pt_re_wr;

		// Stage 2 of the pipline
		afu_tx_rel_waddr_d2 <= afu_tx_rel_waddr_d1[32-`PTE_WIDTH-1:0];
		pt_re_wr_d2         <= pt_re_wr_d1;
	end
end 



//////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////                       //////////////////////////////////
//////////////////////////////     RD Addr Translator      ///////////////////////////////
/////////////////////////////////                       //////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////// 

assign tr_pt_re       = pt_re_rd_d1;
assign afu_virt_raddr = afu_tx_rel_raddr_d1[32-`PTE_WIDTH+`PT_ADDRESS_BITS-1:32-`PTE_WIDTH];

assign afu_phy_rd_addr       =  {tr_pt_dout, afu_tx_rel_raddr_d2};
assign afu_phy_rd_addr_valid = pt_re_rd_d2;

always@(posedge clk) begin
	if( ~rst_n) begin
		afu_tx_rel_raddr_d1 <= 0;
		afu_tx_rel_raddr_d2 <= 0;
		pt_re_rd_d1         <= 1'b0;
		pt_re_rd_d2         <= 1'b0;
	end
	else begin
		// Stage 1 of the pipline
		afu_tx_rel_raddr_d1 <= afu_virt_rd_addr[31:0] - afu_vir_base[31:0];
		pt_re_rd_d1         <= pt_re_rd;

		// Stage 2 of the pipline
		afu_tx_rel_raddr_d2 <= afu_tx_rel_raddr_d1[32-`PTE_WIDTH-1:0];
		pt_re_rd_d2         <= pt_re_rd_d1;
	end
end 

endmodule 
