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

module cmd_processor 
	(
    input   wire                                     clk,
    input   wire                                     rst_n,
    //-------------------------------------------------//
	input   wire 					                 first_page_addr_valid,
	input   wire [`PTE_WIDTH-1:0]                    first_page_addr,
	input   wire                                     ctx_valid,
    // TX RD
    output  wire [31:0]                              cp_tx_rd_addr,
    output  wire [`JOB_QUEUE_TAG-1:0]                cp_tx_rd_tag,
    output  wire 						             cp_tx_rd_valid,
    input   wire                                     cp_tx_rd_ready,
    // TX WR
    output  wire [31:0]                              cp_tx_wr_addr,
    output  wire [`JOB_QUEUE_TAG-1:0]                cp_tx_wr_tag,
    output  wire						             cp_tx_wr_valid,
    output  wire [511:0]			                 cp_tx_data,
    input   wire                                     cp_tx_wr_ready,
    // RX RD
    input   wire [`JOB_QUEUE_TAG-1:0]                cp_rx_rd_tag,
    input   wire [511:0]                             cp_rx_data,
    input   wire                                     cp_rx_rd_valid,
    // RX WR 
    input   wire                                     cp_rx_wr_valid,
    input   wire [`JOB_QUEUE_TAG-1:0]                cp_rx_wr_tag,
    //---- Terminate Command
	output  wire                                     dsm_reset,

    //---- Start Command
    output  wire [31:0]                              job_queue_base_addr[`NUM_JOB_TYPES-1:0], 
    output  wire                                     job_reader_enable, 
    output  wire [15:0]                              queue_poll_rate,
    output  wire [31:0]                              job_queue_size,
    output  wire [15:0]                              job_config[`NUM_JOB_TYPES-1:0], 
    output  wire                                     job_config_valid 
    
);



wire [31:0]                              cmd_queue_size; // in CLs
wire [511:0]                             cmd_queue_out;
wire 						             cmd_queue_valid;
wire                                     cmd_queue_ready;

////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////
assign cmd_queue_size    = {`CMD_QUEUE_BUFFER_SIZE, `CMD_QUEUE_STRUCT_SIZE};
job_queue cmd_queue(
    .clk                              (clk),
    .rst_n                            (rst_n & ~dsm_reset),
    //-------------------------------------------------//
    .start_queue                      (first_page_addr_valid & ctx_valid),
    .queue_base_addr                  ({first_page_addr, {32-`PTE_WIDTH{1'b0}}}),
    .queue_size                       (cmd_queue_size),
    .queue_poll_rate                  (16'h07FF),
    .queue_reset                      (1'b0),
    // TX RD
    .jq_tx_rd_addr                    (cp_tx_rd_addr),
    .jq_tx_rd_tag                     (cp_tx_rd_tag),
    .jq_tx_rd_valid                   (cp_tx_rd_valid),
    .jq_tx_rd_ready                   (cp_tx_rd_ready),
    // TX WR
    .jq_tx_wr_addr                    (cp_tx_wr_addr),
    .jq_tx_wr_tag                     (cp_tx_wr_tag),
    .jq_tx_wr_valid                   (cp_tx_wr_valid),
    .jq_tx_data                       (cp_tx_data),
    .jq_tx_wr_ready                   (cp_tx_wr_ready),
    // RX RD
    .jq_rx_rd_tag                     (cp_rx_rd_tag),
    .jq_rx_data                       (cp_rx_data),
    .jq_rx_rd_valid                   (cp_rx_rd_valid),
    // RX WR 
    .jq_rx_wr_valid                   (cp_rx_wr_valid),
    .jq_rx_wr_tag                     (cp_rx_wr_tag),
    //
    .job_queue_out                    (cmd_queue_out),
    .job_queue_valid                  (cmd_queue_valid),
    .job_queue_ready                  (cmd_queue_ready)
);

////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////
cmd_interpreter cmd_interpreter(
	.clk                              (clk),
    .rst_n                           (rst_n),
    //////////////////////////////// Commands /////////////////////////////////////
    //---- Terminate Command
	.dsm_reset                        (dsm_reset),
    .first_page_address                   (first_page_addr),

    //---- Start Command
    .job_queue_base_addr 			  (job_queue_base_addr), 
    .job_reader_enable                (job_reader_enable), 
    .job_queue_size                   (job_queue_size),
    .queue_poll_rate                  (queue_poll_rate),
    .job_config                       (job_config), 
    .job_config_valid                 (job_config_valid), 
 
    //////////////// From Command Queue /////////////////////////
    .cmd_queue_out                    (cmd_queue_out),
    .cmd_queue_valid                  (cmd_queue_valid),
    .cmd_queue_ready                  (cmd_queue_ready)
);


endmodule 
