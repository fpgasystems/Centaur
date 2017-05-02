/*
 * Copyright (C) 2017 Systems Group, ETHZ

 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at

 * http://www.apache.org/licenses/LICENSE-2.0

 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
 
module io_requester(
	input                                   clk,
	input                                   rst_n,

	////////////////// io_requester <--> arbiter
	// RD TX
	output wire                             cor_tx_rd_ready,
    input  wire                             cor_tx_rd_valid,
    input  wire  [70:0]                     cor_tx_rd_hdr,
    // WR TX
    output wire                             cor_tx_wr_ready,    
    input  wire                             cor_tx_wr_valid,
    input  wire  [74:0]                     cor_tx_wr_hdr, 
    input  wire  [511:0]                    cor_tx_data,

    //////////////////// io_requester <--> server_io
    // TX_RD request, 
    input  wire                             rq_tx_rd_ready,
    output reg                              rq_tx_rd_valid,
    output reg   [44:0]                     rq_tx_rd_hdr,
    
    // TX_WR request
    input  wire                             rq_tx_wr_ready,    
    output reg                              rq_tx_wr_valid,
    output reg   [48:0]                     rq_tx_wr_hdr, 
    output reg   [511:0]                    rq_tx_data,

    ///////////////////// io_requester <--> pagetable
    // afu_virt_waddr --> afu_phy_waddr
	output reg   [57:0]                     afu_virt_wr_addr,
	output reg                              pt_re_wr,
	input  wire  [31:0]                     afu_phy_wr_addr,
    input  wire                             afu_phy_wr_addr_valid,
	// afu_virt_raddr --> afu_phy_raddr
	output reg   [57:0]                     afu_virt_rd_addr,
	output reg                              pt_re_rd,
	input  wire  [31:0]                     afu_phy_rd_addr,
    input  wire                             afu_phy_rd_addr_valid

);

wire                               trq_empty;
wire  [4:0]                        trq_count;
wire                               trq_full;
wire                               trq_valid;
wire  [44:0]                       trq_dout;

wire                               twq_empty;
wire  [4:0]                        twq_count;
wire                               twq_full;
wire                               twq_valid;
wire  [560:0]                      twq_dout;

reg  [31:0]                        rd_cnt;

reg  [511:0]                       afu_virt_wr_data_d0;
reg  [74:0]                        afu_virt_wr_hdr_d0;
reg                                afu_virt_wr_valid_d0;

reg  [511:0]                       afu_virt_wr_data_d1;
reg  [74:0]                        afu_virt_wr_hdr_d1;
reg                                afu_virt_wr_valid_d1;

reg  [511:0]                       afu_virt_wr_data_d2;
reg  [74:0]                        afu_virt_wr_hdr_d2;
reg                                afu_virt_wr_valid_d2;

reg  [511:0]                       afu_virt_wr_data_d3;
reg  [74:0]                        afu_virt_wr_hdr_d3;
reg                                afu_virt_wr_valid_d3;

reg  [70:0]                        afu_virt_rd_hdr_d0;
reg                                afu_virt_rd_valid_d0;

reg  [70:0]                        afu_virt_rd_hdr_d1;
reg                                afu_virt_rd_valid_d1;

reg  [70:0]                        afu_virt_rd_hdr_d2;
reg                                afu_virt_rd_valid_d2;

reg  [70:0]                        afu_virt_rd_hdr_d3;
reg                                afu_virt_rd_valid_d3;
//-------------------------------------------------
always @(posedge clk) begin
    if( ~rst_n ) begin
        rd_cnt     <= 32'b0;
    end
    else if (rq_tx_rd_valid) begin
       rd_cnt <= rd_cnt +1'b1;
   end 
end

//////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////                       //////////////////////////////////
//////////////////////////////        TX RD Channel        ///////////////////////////////
/////////////////////////////////                       //////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////

assign cor_tx_rd_ready = ~trq_full;

always@(posedge clk) begin
	if(~rst_n) begin 
		rq_tx_rd_valid <= 0;
		rq_tx_rd_hdr   <= 0;
	end 
	else if(rq_tx_rd_ready) begin
		rq_tx_rd_valid <= trq_valid;
		rq_tx_rd_hdr   <= trq_dout;
	end 
end 
// TX_RD transmit queue    
quick_fifo  #(.FIFO_WIDTH(45),        // 
            .FIFO_DEPTH_BITS(5),
            .FIFO_ALMOSTFULL_THRESHOLD(2**5 - 8)
            ) txrd_queue(
        .clk                (clk),
        .reset_n            (rst_n),
        .din                (afu_virt_rd_hdr_d3[44:0]),
        .we                 (afu_virt_rd_valid_d3),
        .re                 (rq_tx_rd_ready),
        .dout               (trq_dout),
        .empty              (trq_empty),
        .valid              (trq_valid),
        .full               (),
        .count              (trq_count),
        .almostfull         (trq_full)
    ); 


always@(posedge clk) begin
   if( ~rst_n ) begin
        pt_re_rd             <= 0;
		afu_virt_rd_addr     <= 0;

		afu_virt_rd_valid_d0 <= 0;
		//afu_virt_rd_hdr_d0   <= 0;
		// S1
		afu_virt_rd_valid_d1 <= 0;
		//afu_virt_rd_hdr_d1   <= 0;
		// S2
		afu_virt_rd_valid_d2 <= 0;
		//afu_virt_rd_hdr_d2   <= 0;

		// S3: PT response available at this cycle, compose it to store in the FIFO.
		afu_virt_rd_valid_d3 <= 0;
		//afu_virt_rd_hdr_d3   <= 0;
    end
    else begin
       	pt_re_rd             <= cor_tx_rd_valid & cor_tx_rd_ready;
       	afu_virt_rd_addr     <= cor_tx_rd_hdr[70:13];
		 
		// PT pipeline stages delay
		// S0
		afu_virt_rd_valid_d0 <= cor_tx_rd_valid & cor_tx_rd_ready;
		afu_virt_rd_hdr_d0   <= cor_tx_rd_hdr;
		// S1
		afu_virt_rd_valid_d1 <= afu_virt_rd_valid_d0;
		afu_virt_rd_hdr_d1   <= afu_virt_rd_hdr_d0;
		// S2
		afu_virt_rd_valid_d2 <= afu_virt_rd_valid_d1;
		afu_virt_rd_hdr_d2   <= afu_virt_rd_hdr_d1;
		 
		// S3: PT response available at this cycle, compose it to store in the FIFO.
		afu_virt_rd_valid_d3 <= afu_virt_rd_valid_d2;
		afu_virt_rd_hdr_d3   <= {afu_phy_rd_addr, afu_virt_rd_hdr_d2[12:0]};
   end 
end 

//////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////                       //////////////////////////////////
//////////////////////////////        TX WR Channel        ///////////////////////////////
/////////////////////////////////                       //////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
assign cor_tx_wr_ready = ~twq_full;

always@(posedge clk) begin
	if(~rst_n) begin 
		rq_tx_wr_valid <= 0;
		rq_tx_data     <= 0;
		rq_tx_wr_hdr   <= 0;
	end 
	else if(rq_tx_wr_ready) begin
		rq_tx_wr_valid <= twq_valid;
		rq_tx_data     <= twq_dout[511:0];
		rq_tx_wr_hdr   <= twq_dout[560:512];
	end 
end 
// TX_WR transmit queue    
quick_fifo  #(.FIFO_WIDTH(561),        //
            .FIFO_DEPTH_BITS(5),
            .FIFO_ALMOSTFULL_THRESHOLD(2**5 -8)
            ) txwr_queue(
        .clk                (clk),
        .reset_n            (rst_n),
        .din                ({afu_virt_wr_hdr_d3[48:0], afu_virt_wr_data_d3}),
        .we                 (afu_virt_wr_valid_d3),
        .re                 (rq_tx_wr_ready),
        .dout               (twq_dout),
        .empty              (twq_empty),
        .valid              (twq_valid),
        .full               (),
        .count              (twq_count),
        .almostfull         (twq_full)
    ); 


always@(posedge clk) begin
   if( ~rst_n ) begin
       	pt_re_wr             <= 0;
		afu_virt_wr_addr     <= 0;
		// PT pipeline stages delay
		// S0
		afu_virt_wr_valid_d0 <= 0;
		afu_virt_wr_hdr_d0   <= 0;
		afu_virt_wr_data_d0  <= 0;
		// S1
		afu_virt_wr_valid_d1 <= 0;
		afu_virt_wr_hdr_d1   <= 0;
		afu_virt_wr_data_d1  <= 0;
		// S2
		afu_virt_wr_valid_d2 <= 0;
		afu_virt_wr_hdr_d2   <= 0;
		afu_virt_wr_data_d2  <= 0;
		 
		// S3: PT response available at this cycle, compose it to store in the FIFO.
		afu_virt_wr_valid_d3 <= 0;
		afu_virt_wr_hdr_d3   <= 0;
		afu_virt_wr_data_d3  <= 0;
    end
    else begin
       	pt_re_wr             <= cor_tx_wr_valid & cor_tx_wr_ready;
       	afu_virt_wr_addr     <= cor_tx_wr_hdr[70:13];
		 
		// PT pipeline stages delay
		// S0
		afu_virt_wr_valid_d0 <= cor_tx_wr_valid & cor_tx_wr_ready;
		afu_virt_wr_hdr_d0   <= cor_tx_wr_hdr;
		afu_virt_wr_data_d0  <= cor_tx_data;
		// S1
		afu_virt_wr_valid_d1 <= afu_virt_wr_valid_d0;
		afu_virt_wr_hdr_d1   <= afu_virt_wr_hdr_d0;
		afu_virt_wr_data_d1  <= afu_virt_wr_data_d0;
		// S2
		afu_virt_wr_valid_d2 <= afu_virt_wr_valid_d1;
		afu_virt_wr_hdr_d2   <= afu_virt_wr_hdr_d1;
		afu_virt_wr_data_d2  <= afu_virt_wr_data_d1;
		// S3: PT response available at this cycle, compose it to store in the FIFO.
		afu_virt_wr_valid_d3 <= afu_virt_wr_valid_d2;
		afu_virt_wr_hdr_d3   <= { afu_virt_wr_hdr_d2[74:71], afu_phy_wr_addr, afu_virt_wr_hdr_d2[12:0]};
		afu_virt_wr_data_d3  <= afu_virt_wr_data_d2;
   end 
end 

endmodule
