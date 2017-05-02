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
 
`include "../afu_defines.vh"

module fthread #(parameter AFU_OPERATOR           = `UNDEF_AFU,
                 parameter MAX_FTHREAD_CONFIG_CLS = 2,
                 parameter USER_RD_TAG = `AFU_TAG,
                 parameter USER_WR_TAG = `AFU_TAG,
                 parameter USER_AFU_PARAMETER1 = 1,
                 parameter USER_AFU_PARAMETER2 = 1) (
	input   wire                        clk,
    input   wire                        Clk_400,
    input   wire                        rst_n,
    
    /// fthread <--> scheduler
    input   wire 						cmd_valid,
    input   wire [`CMD_LINE_WIDTH-1:0]  cmd_line,
    output  wire 						fthread_job_done, 
    
    /// fthread <--> arbiter
    //-------------- read interface
    output  wire 						tx_rd_valid,
    output  wire [67:0] 				tx_rd_hdr, 
    input  	wire 						tx_rd_ready,

    input  	wire 						rx_rd_valid,
    input   wire [`FTHREAD_TAG-1:0]     rx_rd_tag,
    input 	wire [511:0] 				rx_data,
    //-------------- write interface
    output  wire [71:0]					tx_wr_hdr,  
    output  wire [511:0] 				tx_data,
    output  wire 						tx_wr_valid,
    input  	wire						tx_wr_ready,

    input   wire [`FTHREAD_TAG-1:0]     rx_wr_tag,
    input 	wire 						rx_wr_valid,
    //------------------------ Pipeline Interfaces ---------------------//
    // Left Pipe
    output  wire                        left_pipe_tx_rd_valid,
    output  wire [`IF_TAG-1:0]          left_pipe_tx_rd_tag, 
    input   wire                        left_pipe_tx_rd_ready,

    input   wire                        left_pipe_rx_rd_valid,
    input   wire [`IF_TAG-1:0]         left_pipe_rx_rd_tag,
    input   wire [511:0]                left_pipe_rx_data,
    output  wire                        left_pipe_rx_rd_ready,
    // Right Pipe
    input   wire                        right_pipe_tx_rd_valid,
    input   wire [`IF_TAG-1:0]         right_pipe_tx_rd_tag, 
    output  wire                        right_pipe_tx_rd_ready,

    output  wire                        right_pipe_rx_rd_valid,
    output  wire [`IF_TAG-1:0]         right_pipe_rx_rd_tag,
    output  wire [511:0]                right_pipe_rx_data,
    input   wire                        right_pipe_rx_rd_ready
);



wire                                       start_um;
wire [(MAX_FTHREAD_CONFIG_CLS*512)-1:0]    um_params;

wire                                       um_done;
wire [`NUM_USER_STATE_COUNTERS*32-1:0]     um_state_counters;
wire                                       um_state_counters_valid;
// User Module TX RD
wire [57:0]                 um_tx_rd_addr;
wire [USER_RD_TAG-1:0]      um_tx_rd_tag;
wire                        um_tx_rd_valid;
wire                        um_tx_rd_ready;
// User Module TX WR
wire [57:0]                 um_tx_wr_addr;
wire [USER_WR_TAG-1:0]      um_tx_wr_tag;
wire                        um_tx_wr_valid;
wire [511:0]                um_tx_data;
wire                        um_tx_wr_ready;
// User Module RX RD
wire [USER_RD_TAG-1:0]      um_rx_rd_tag;
wire [511:0]                um_rx_data;
wire                        um_rx_rd_valid;
wire                        um_rx_rd_ready;
// User Module RX WR 
wire                        um_rx_wr_valid;
wire [USER_WR_TAG-1:0]      um_rx_wr_tag;

wire                        reset_user_logic;

reg                         afu_rst_n = 0;

///////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////                           //////////////////////////////////////
//////////////////////////////        FThread Controller        ///////////////////////////////////
//////////////////////////////////                           //////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////


FThread_controller #(.MAX_NUM_CONFIG_CL(MAX_FTHREAD_CONFIG_CLS),
                     .USER_RD_TAG(USER_RD_TAG),
                     .USER_WR_TAG(USER_WR_TAG)
                      ) 
FThread_controller(
    .clk                                (clk),
    .rst_n                              (rst_n),
    
    //--------------- fthread <--> scheduler
    .cmd_valid                          (cmd_valid),
    .cmd_line                           (cmd_line),
    .fthread_job_done                   (fthread_job_done), 
    .reset_user_logic                   (reset_user_logic),
    
    //--------------- fthread <--> arbiter
    //- TX RD, RX RD
    .tx_rd_valid                        (tx_rd_valid),
    .tx_rd_hdr                          (tx_rd_hdr), 
    .tx_rd_ready                        (tx_rd_ready),

    .rx_rd_valid                        (rx_rd_valid),
    .rx_rd_tag                          (rx_rd_tag),
    .rx_data                            (rx_data),
    //- TX WR, RX WR
    .tx_wr_hdr                          (tx_wr_hdr),  
    .tx_data                            (tx_data),
    .tx_wr_valid                        (tx_wr_valid),
    .tx_wr_ready                        (tx_wr_ready),

    .rx_wr_tag                          (rx_wr_tag),
    .rx_wr_valid                        (rx_wr_valid),
    //------------------------ Pipeline Interfaces ---------------------//
    // Left Pipe
    .left_pipe_tx_rd_valid              (left_pipe_tx_rd_valid),
    .left_pipe_tx_rd_tag                (left_pipe_tx_rd_tag), 
    .left_pipe_tx_rd_ready              (left_pipe_tx_rd_ready),

    .left_pipe_rx_rd_valid              (left_pipe_rx_rd_valid),
    .left_pipe_rx_rd_tag                (left_pipe_rx_rd_tag),
    .left_pipe_rx_data                  (left_pipe_rx_data),
    .left_pipe_rx_rd_ready              (left_pipe_rx_rd_ready),
    // Right Pipe
    .right_pipe_tx_rd_valid             (right_pipe_tx_rd_valid),
    .right_pipe_tx_rd_tag               (right_pipe_tx_rd_tag), 
    .right_pipe_tx_rd_ready             (right_pipe_tx_rd_ready),

    .right_pipe_rx_rd_valid             (right_pipe_rx_rd_valid),
    .right_pipe_rx_rd_tag               (right_pipe_rx_rd_tag),
    .right_pipe_rx_data                 (right_pipe_rx_data),
    .right_pipe_rx_rd_ready             (right_pipe_rx_rd_ready),
    //------------------------ User Module interface
    .start_um                           (start_um),
    .um_params                          (um_params),
    .um_done                            (um_done),
    .um_state_counters                  (um_state_counters),
    .um_state_counters_valid            (um_state_counters_valid),
    // User Module TX RD
    .um_tx_rd_addr                      (um_tx_rd_addr),
    .um_tx_rd_tag                       (um_tx_rd_tag),
    .um_tx_rd_valid                     (um_tx_rd_valid),
    .um_tx_rd_ready                     (um_tx_rd_ready),
    // User Module TX WR
    .um_tx_wr_addr                      (um_tx_wr_addr),
    .um_tx_wr_tag                       (um_tx_wr_tag),
    .um_tx_wr_valid                     (um_tx_wr_valid),
    .um_tx_data                         (um_tx_data),
    .um_tx_wr_ready                     (um_tx_wr_ready),
    // User Module RX RD
    .um_rx_rd_tag                       (um_rx_rd_tag),
    .um_rx_data                         (um_rx_data),
    .um_rx_rd_valid                     (um_rx_rd_valid),
    .um_rx_rd_ready                     (um_rx_rd_ready),
    // User Module RX WR 
    .um_rx_wr_valid                     (um_rx_wr_valid),
    .um_rx_wr_tag                       (um_rx_wr_tag)
);


///////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////                           //////////////////////////////////////
//////////////////////////////             User AFU             ///////////////////////////////////
//////////////////////////////////                           //////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
always @(posedge clk) begin
   afu_rst_n <= rst_n & ~reset_user_logic;
end

AFU #(.AFU_OPERATOR(AFU_OPERATOR),
      .MAX_AFU_CONFIG_WIDTH(MAX_FTHREAD_CONFIG_CLS*512),
      .USER_RD_TAG(USER_RD_TAG),
      .USER_WR_TAG(USER_WR_TAG),
      .USER_AFU_PARAMETER1(USER_AFU_PARAMETER1),
      .USER_AFU_PARAMETER2(USER_AFU_PARAMETER2)
      )
AFU(
    .clk                                (clk),
    .Clk_400                            (Clk_400),
    .rst_n                              (afu_rst_n ),
    //-------------------------------------------------//
    .start_um                           (start_um),
    .um_params                          (um_params),              
    .um_done                            (um_done),
    .um_state_counters                  (um_state_counters),
    .um_state_counters_valid            (um_state_counters_valid),
    // User Module TX RD
    .um_tx_rd_addr                      (um_tx_rd_addr),
    .um_tx_rd_tag                       (um_tx_rd_tag),
    .um_tx_rd_valid                     (um_tx_rd_valid),
    .um_tx_rd_ready                     (um_tx_rd_ready),
    // User Module TX WR
    .um_tx_wr_addr                      (um_tx_wr_addr),
    .um_tx_wr_tag                       (um_tx_wr_tag),
    .um_tx_wr_valid                     (um_tx_wr_valid),
    .um_tx_data                         (um_tx_data),
    .um_tx_wr_ready                     (um_tx_wr_ready),
    // User Module RX RD
    .um_rx_rd_tag                       (um_rx_rd_tag),
    .um_rx_data                         (um_rx_data),
    .um_rx_rd_valid                     (um_rx_rd_valid),
    .um_rx_rd_ready                     (um_rx_rd_ready),
    // User Module RX WR 
    .um_rx_wr_valid                     (um_rx_wr_valid),
    .um_rx_wr_tag                       (um_rx_wr_tag)
);





endmodule
