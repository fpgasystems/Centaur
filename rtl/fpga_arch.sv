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
 
`include "spl_defines.vh"

`include "afu_defines.vh"


module fpga_arch(
	input                                   clk,
    input                                   Clk_400,
    input                                   rst_n,
    input                                   linkup,
    // CCI TX read request
    input  wire                             cci_tx_rd_almostfull,    
    output wire                             spl_tx_rd_valid,
    output wire [60:0]                      spl_tx_rd_hdr,
    
    // CCI TX write request
    input  wire                             cci_tx_wr_almostfull,
    output wire                             spl_tx_wr_valid,
    output wire                             spl_tx_intr_valid,
    output wire [60:0]                      spl_tx_wr_hdr,    
    output wire [511:0]                     spl_tx_data,
    
    // CCI RX read response
    input  wire                             cci_rx_rd_valid,
    input  wire                             cci_rx_wr_valid0,
    input  wire                             cci_rx_cfg_valid,
    input  wire                             cci_rx_intr_valid0,
    input  wire                             cci_rx_umsg_valid,
    input  wire [`CCI_RX_HDR_WIDTH-1:0]     cci_rx_hdr0,
    input  wire [511:0]                     cci_rx_data,
    
    // CCI RX write response
    input  wire                             cci_rx_wr_valid1,
    input  wire                             cci_rx_intr_valid1,
    input  wire [`CCI_RX_HDR_WIDTH-1:0]     cci_rx_hdr1
);


////////////////////////////////////////////////////////////////////////////////////////////

//-------------- read interface
wire                                  ft_tx_rd_valid[`NUMBER_OF_FTHREADS-1:0];
wire [67:0]                           ft_tx_rd_hdr[`NUMBER_OF_FTHREADS-1:0];
wire                                  ft_tx_rd_ready[`NUMBER_OF_FTHREADS-1:0];

wire                                  ft_rx_rd_valid[`NUMBER_OF_FTHREADS-1:0];
wire [511:0]                          ft_rx_data[`NUMBER_OF_FTHREADS-1:0];
wire [`FTHREAD_TAG-1:0]               ft_rx_rd_tag[`NUMBER_OF_FTHREADS-1:0];
//-------------- write interface
wire [71:0]                           ft_tx_wr_hdr[`NUMBER_OF_FTHREADS-1:0]; 
wire [511:0]                          ft_tx_data[`NUMBER_OF_FTHREADS-1:0];
wire                                  ft_tx_wr_valid[`NUMBER_OF_FTHREADS-1:0];
wire                                  ft_tx_wr_ready[`NUMBER_OF_FTHREADS-1:0];

wire                                  ft_rx_wr_valid[`NUMBER_OF_FTHREADS-1:0]; 
wire [`FTHREAD_TAG-1:0]               ft_rx_wr_tag[`NUMBER_OF_FTHREADS-1:0];
//----------- Scheduler <--> Channels 
wire [`CMD_LINE_WIDTH-1 :0]           fthread_job[`NUMBER_OF_FTHREADS-1:0];
wire                                  fthread_job_valid[`NUMBER_OF_FTHREADS-1:0]; 

wire                                  fthread_done[`NUMBER_OF_FTHREADS-1:0]; 

//----------- CMD Server <--> Channels
wire                                  ft_reset[`NUMBER_OF_FTHREADS-1:0];

reg                                   reset_buff_t;
reg                                   reset_buff[`NUMBER_OF_FTHREADS-1:0];


wire                                  pipe_tx_rd_valid[`NUMBER_OF_FTHREADS:0];
wire [`IF_TAG-1:0]                    pipe_tx_rd_tag[`NUMBER_OF_FTHREADS:0];
wire                                  pipe_tx_rd_ready[`NUMBER_OF_FTHREADS:0];

wire                                  pipe_rx_rd_valid[`NUMBER_OF_FTHREADS:0];
wire [511:0]                          pipe_rx_data[`NUMBER_OF_FTHREADS:0];
wire [`IF_TAG-1:0]                    pipe_rx_rd_tag[`NUMBER_OF_FTHREADS:0];
wire                                  pipe_rx_rd_ready[`NUMBER_OF_FTHREADS:0];

//
always@(posedge clk) begin
    reset_buff_t  <= rst_n;
end

parameter integer PLACED_AFUS[0:7] = 
'{
    {`FTHREAD_1_PLACED_AFU}, 
    {`FTHREAD_2_PLACED_AFU},
    {`FTHREAD_3_PLACED_AFU},
    {`FTHREAD_4_PLACED_AFU},
    {`FTHREAD_5_PLACED_AFU}, 
    {`FTHREAD_6_PLACED_AFU},
    {`FTHREAD_7_PLACED_AFU},
    {`FTHREAD_8_PLACED_AFU}
};

parameter integer PLACED_AFU_CONFIG_WIDTH [0:7] = 
'{
    `FTHREAD_1_AFU_CONFIG_LINES,
    `FTHREAD_2_AFU_CONFIG_LINES,
    `FTHREAD_3_AFU_CONFIG_LINES,
    `FTHREAD_4_AFU_CONFIG_LINES,
    `FTHREAD_5_AFU_CONFIG_LINES,
    `FTHREAD_6_AFU_CONFIG_LINES,
    `FTHREAD_7_AFU_CONFIG_LINES,
    `FTHREAD_8_AFU_CONFIG_LINES
};

parameter integer USER_AFU_RD_TAG [0:7] = 
'{
    `FTHREAD_1_USER_AFU_RD_TAG,
    `FTHREAD_2_USER_AFU_RD_TAG,
    `FTHREAD_3_USER_AFU_RD_TAG,
    `FTHREAD_4_USER_AFU_RD_TAG,
    `FTHREAD_5_USER_AFU_RD_TAG,
    `FTHREAD_6_USER_AFU_RD_TAG,
    `FTHREAD_7_USER_AFU_RD_TAG,
    `FTHREAD_8_USER_AFU_RD_TAG
};

parameter integer USER_AFU_WR_TAG [0:7] = 
'{
    `FTHREAD_1_USER_AFU_WR_TAG,
    `FTHREAD_2_USER_AFU_WR_TAG,
    `FTHREAD_3_USER_AFU_WR_TAG,
    `FTHREAD_4_USER_AFU_WR_TAG,
    `FTHREAD_5_USER_AFU_WR_TAG,
    `FTHREAD_6_USER_AFU_WR_TAG,
    `FTHREAD_7_USER_AFU_WR_TAG,
    `FTHREAD_8_USER_AFU_WR_TAG
};

parameter integer USER_AFU_PARAMETER1 [0:7] = 
'{
    128,
    128,
    64,
    64,
    1,
    1,
    1,
    1
};

parameter integer USER_AFU_PARAMETER2 [0:7] =
'{
    16,
    16,
    8,
    8,
    1,
    1,
    1,
    1
};
////////////////////////////////////////////////////////////////////////////////////////////

fpga_server  fpga_server(
    .clk                            (clk),
    .rst_n                          (reset_buff_t),
    // CCI TX read request
    .cci_tx_rd_almostfull           (cci_tx_rd_almostfull),    
    .spl_tx_rd_valid                (spl_tx_rd_valid),
    .spl_tx_rd_hdr                  (spl_tx_rd_hdr),
    
    // CCI TX write request
    .cci_tx_wr_almostfull           (cci_tx_wr_almostfull),
    .spl_tx_wr_valid                (spl_tx_wr_valid),
    .spl_tx_intr_valid              (spl_tx_intr_valid),
    .spl_tx_wr_hdr                  (spl_tx_wr_hdr),    
    .spl_tx_data                    (spl_tx_data),
    
    // CCI RX read response
    .cci_rx_rd_valid                (cci_rx_rd_valid),
    .cci_rx_wr_valid0               (cci_rx_wr_valid0),
    .cci_rx_cfg_valid               (cci_rx_cfg_valid),
    .cci_rx_intr_valid0             (cci_rx_intr_valid0),
    .cci_rx_umsg_valid              (cci_rx_umsg_valid),
    .cci_rx_hdr0                    (cci_rx_hdr0),
    .cci_rx_data                    (cci_rx_data),
    
    // CCI RX write response
    .cci_rx_wr_valid1               (cci_rx_wr_valid1),
    .cci_rx_intr_valid1             (cci_rx_intr_valid1),
    .cci_rx_hdr1                    (cci_rx_hdr1),
    //////////////////////// Toward Channels ////////////////////////////
    //-------------- read interface
    .ft_tx_rd_valid                (ft_tx_rd_valid),
    .ft_tx_rd_hdr                  (ft_tx_rd_hdr),
    .ft_tx_rd_ready                (ft_tx_rd_ready),

    .ft_rx_rd_valid                (ft_rx_rd_valid),
    .ft_rx_data                    (ft_rx_data),
    .ft_rx_rd_tag                  (ft_rx_rd_tag),
    //-------------- write interface
    .ft_tx_wr_hdr                  (ft_tx_wr_hdr), 
    .ft_tx_data                    (ft_tx_data),
    .ft_tx_wr_valid                (ft_tx_wr_valid),
    .ft_tx_wr_ready                (ft_tx_wr_ready),

    .ft_rx_wr_valid                (ft_rx_wr_valid), 
    .ft_rx_wr_tag                  (ft_rx_wr_tag),
    
    //----------- Scheduler <--> Channels 
    .fthread_job                   (fthread_job), 
    .fthread_job_valid             (fthread_job_valid), 
    .fthread_done                  (fthread_done),
    // To Channels
    .ft_reset                      (ft_reset)
);

genvar i;

generate for( i = 0; i < `NUMBER_OF_FTHREADS; i = i + 1) begin: fthreads 
    always@(posedge clk) begin
        reset_buff[i] <= rst_n;
    end
    //
    fthread #(.AFU_OPERATOR( PLACED_AFUS[i] ),
              .MAX_FTHREAD_CONFIG_CLS( PLACED_AFU_CONFIG_WIDTH[i] ),
              .USER_RD_TAG(USER_AFU_RD_TAG[i]),
              .USER_WR_TAG(USER_AFU_WR_TAG[i]), 
              .USER_AFU_PARAMETER1(USER_AFU_PARAMETER1[i]),
              .USER_AFU_PARAMETER2(USER_AFU_PARAMETER2[i])
        ) 
    fthread_X(
    .clk                            (clk),
    .Clk_400                        (Clk_400),
    .rst_n                          (reset_buff[i] & ~ft_reset[i]),
    
    /// channel <--> scheduler
    .cmd_valid                      (fthread_job_valid[i]),
    .cmd_line                       (fthread_job[i]),
    .fthread_job_done               (fthread_done[i]), 
    
    /// channel <--> arbiter
    //-------------- read interface
    .tx_rd_valid                    (ft_tx_rd_valid[i]),
    .tx_rd_hdr                      (ft_tx_rd_hdr[i]),
    .tx_rd_ready                    (ft_tx_rd_ready[i]),

    .rx_rd_valid                    (ft_rx_rd_valid[i]),
    .rx_data                        (ft_rx_data[i]),
    .rx_rd_tag                      (ft_rx_rd_tag[i]),
    //-------------- write interface
    .tx_wr_hdr                      (ft_tx_wr_hdr[i]), 
    .tx_data                        (ft_tx_data[i]),
    .tx_wr_valid                    (ft_tx_wr_valid[i]),
    .tx_wr_ready                    (ft_tx_wr_ready[i]),

    .rx_wr_valid                    (ft_rx_wr_valid[i]), 
    .rx_wr_tag                      (ft_rx_wr_tag[i]),
    //------------------------ Pipeline Interfaces ---------------------//
    // Left Pipe: TX output, RX input
    .left_pipe_tx_rd_valid          (pipe_tx_rd_valid[i]),
    .left_pipe_tx_rd_tag            (pipe_tx_rd_tag[i]), 
    .left_pipe_tx_rd_ready          (pipe_tx_rd_ready[i]),

    .left_pipe_rx_rd_valid          (pipe_rx_rd_valid[i]),
    .left_pipe_rx_rd_tag            (pipe_rx_rd_tag[i]),
    .left_pipe_rx_data              (pipe_rx_data[i]),
    .left_pipe_rx_rd_ready          (pipe_rx_rd_ready[i]),
    
    // Right Pipe: TX input, RX Output
    .right_pipe_tx_rd_valid         (pipe_tx_rd_valid[i+1]),
    .right_pipe_tx_rd_tag           (pipe_tx_rd_tag[i+1]), 
    .right_pipe_tx_rd_ready         (pipe_tx_rd_ready[i+1]),

    .right_pipe_rx_rd_valid         (pipe_rx_rd_valid[i+1]),
    .right_pipe_rx_rd_tag           (pipe_rx_rd_tag[i+1]),
    .right_pipe_rx_data             (pipe_rx_data[i+1]),
    .right_pipe_rx_rd_ready         (pipe_rx_rd_ready[i+1])
);
    //
end 
endgenerate

//
assign pipe_tx_rd_ready[0] = 1'b1;
assign pipe_rx_rd_valid[0] = 1'b0;
assign pipe_rx_rd_tag[0]   = 0;
assign pipe_rx_data[0]     = 0;
//
assign pipe_tx_rd_valid[`NUMBER_OF_FTHREADS] = 1'b0;
assign pipe_tx_rd_tag[`NUMBER_OF_FTHREADS]   = 0;
assign pipe_rx_rd_ready[`NUMBER_OF_FTHREADS] = 1'b1;


endmodule
