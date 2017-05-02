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

`default_nettype none

module order_module_backpressure_wr
#(
                      parameter TAG_WIDTH      = 6,
                      parameter OUT_TAG_WIDTH  = 6,
                      parameter USER_TAG_WIDTH = 8,
                      parameter DATA_WIDTH     = 512,
                      parameter ADDR_WIDTH     = 58)
	(
    input   wire                        clk,
    input   wire                        rst_n,
    //-------------------------------------------------//
    // input requests
    input  wire  [ADDR_WIDTH-1:0]       usr_tx_wr_addr,
    input  wire  [USER_TAG_WIDTH-1:0]   usr_tx_wr_tag,
    input  wire   						usr_tx_wr_valid,
    input  wire  [DATA_WIDTH-1:0]       usr_tx_data,
    output wire                         usr_tx_wr_ready,
    // User Module TX RD
    output  wire [ADDR_WIDTH-1:0]       ord_tx_wr_addr,
    output  wire [OUT_TAG_WIDTH-1:0]    ord_tx_wr_tag,
    output  wire  						ord_tx_wr_valid,
    output  wire [DATA_WIDTH-1:0]       ord_tx_data,
    input   wire                        ord_tx_wr_ready,
    // User Module RX RD
    input   wire [TAG_WIDTH-1:0]        ord_rx_wr_tag,
    input   wire                        ord_rx_wr_valid,
    //
    output  reg  [USER_TAG_WIDTH-1:0]   usr_rx_wr_tag,
    output  reg                         usr_rx_wr_valid,
    input   wire                        usr_rx_wr_ready
);



reg  [2**TAG_WIDTH-1:0]        rob_valid; 
reg                            rob_re;
reg                            rob_re_d1;
reg  [USER_TAG_WIDTH-1:0]      rob_rtag;

wire 						   pend_tag_fifo_full;
wire 						   pend_tag_fifo_valid;
wire 						   absorb_pend_tag;

wire  [USER_TAG_WIDTH+TAG_WIDTH-1:0]     curr_pend_tag;


reg   [TAG_WIDTH-1:0]          ord_tag;

reg  [USER_TAG_WIDTH-1:0]   usr_rx_wr_tag_reg;
reg                         usr_rx_wr_valid_reg;



assign ord_tx_wr_valid = usr_tx_wr_valid & ~pend_tag_fifo_full;
assign ord_tx_wr_tag   = {{{OUT_TAG_WIDTH - TAG_WIDTH}{1'b0}}, ord_tag};
assign ord_tx_wr_addr  = usr_tx_wr_addr;
assign ord_tx_data     = usr_tx_data;

assign usr_tx_wr_ready  = ord_tx_wr_ready & ~pend_tag_fifo_full;


// FIFO of tags for sent TX RD requests
quick_fifo  #(.FIFO_WIDTH(USER_TAG_WIDTH + TAG_WIDTH),        
            .FIFO_DEPTH_BITS(TAG_WIDTH),
            .FIFO_ALMOSTFULL_THRESHOLD(32)
            ) pend_tag_fifo(
        .clk                (clk),
        .reset_n            (rst_n),
        .din                ({usr_tx_wr_tag, ord_tag}),
        .we                 (usr_tx_wr_valid & ord_tx_wr_ready),

        .re                 ( absorb_pend_tag),
        .dout               (curr_pend_tag),
        .empty              (),
        .valid              (pend_tag_fifo_valid),
        .full               (pend_tag_fifo_full),
        .count              (),
        .almostfull         ()
    );

assign absorb_pend_tag    = rob_re;

always@(posedge clk) begin
	if(~rst_n) begin
		rob_valid       <= 0;
        usr_rx_wr_valid <= 1'b0;
        usr_rx_wr_tag   <= 0;

        ord_tag         <= 0;
        rob_re          <= 0;
        rob_re_d1       <= 0;
        rob_rtag        <= 0;
	end
	else begin
        if( usr_tx_wr_valid & ord_tx_wr_ready & ~pend_tag_fifo_full ) ord_tag <= ord_tag + 1'b1;
        // write response in the responses memory if cannot bypass rob buffer

        if(ord_rx_wr_valid) begin
            rob_valid[ord_rx_wr_tag[TAG_WIDTH-1:0]] <= 1'b1;
        end 
        rob_re <= 1'b0;
        // if current pending tag has valid response then read it from the responses memory
        if( ~usr_rx_wr_valid_reg | ~usr_rx_wr_valid | usr_rx_wr_ready) begin
            if( rob_valid[curr_pend_tag[TAG_WIDTH-1:0]] && pend_tag_fifo_valid) begin
                rob_rtag                                <= curr_pend_tag[USER_TAG_WIDTH + TAG_WIDTH - 1: TAG_WIDTH];
                rob_valid[curr_pend_tag[TAG_WIDTH-1:0]] <= 1'b0;
                rob_re                                  <= 1'b1;
                rob_re_d1                               <= 1'b1;
            end
            else begin
                rob_re_d1                               <= 1'b0;
            end 
            rob_re_d1               <= rob_re;
            usr_rx_wr_valid_reg     <= rob_re_d1;
            usr_rx_wr_tag_reg       <= rob_rtag; 

            usr_rx_wr_valid         <= usr_rx_wr_valid_reg;
            usr_rx_wr_tag           <= usr_rx_wr_tag_reg; 
        end 
	end
end


endmodule

`default_nettype wire