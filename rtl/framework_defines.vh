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
 
`ifndef FRAMEWORK_DEFINES_VH
`define FRAMEWORK_DEFINES_VH

/// Configuration Parameters
`define NUMBER_OF_FTHREADS                 4
`define FTHREADS_BITS                      2

`define PT_ADDRESS_BITS                    11  // 4 GB workspace
`define PTE_WIDTH                          17  // 2 MB pages

`define CMD_QUEUE_STRUCT_SIZE              16'd3
`define CMD_QUEUE_BUFFER_SIZE              16'd32
`define JOB_QUEUE_BUFFER_SIZE              16'd128

`define INT_MAX                            32'hFFFFFFFF



`define CRB_STRUCT_PRODUCER_LINE_OFFSET    32'h1
`define CRB_STRUCT_CONSUMER_LINE_OFFSET    32'h2

`define AFU_ID                             64'h111_00181
`define SPL_ID                             32'h11100101

`define AFU_ID_DSM_OFFSET                  0
`define PT_STATUS_DSM_OFFSET               1
`define CTX_STATUS_DSM_OFFSET              2
`define ALLOC_OPERATORS_DSM_OFFSET         3


`define CMD_LINE_WIDTH                     248

`define NUM_USER_STATE_COUNTERS            10

`define FPGA_TERMINATE_CMD            	   16'h0001
`define START_JOB_MANAGER_CMD              16'h0002

`define SET_CMD_POLL_RATE_INSTR            16'h0010
`define STOP_CMD_POLL_TIMEOUT_INSTR        16'h0020

`define GET_CHANNEL_STATUS_INSTR           16'h0100
`define GET_OPERATOR_STATUS_INSTR          16'h0200
`define GET_PAGETABLE_STATUS_INSTR         16'h0300
`define GET_APPLICATIONS_STATUS_INSTR      16'h0400

`define TERMINATE_OPERATOR_INSTR           16'h1000

`define CTRL_CMD_VALID_FLAG_LOC            25

`define CMQ_VALID_MAGIC_NUMBER             32'h13579bdf
`define CMQ_PROD_VALID_MAGIC_NUMBER        32'h02468ace

`define WR_IF_DIRECT_PIPELINE_CODE 		   2'h1
`define WR_IF_MEM_PIPELINE_CODE 		   2'h3

`define RD_IF_DIRECT_PIPELINE_CODE 		   2'h1
`define RD_IF_MEM_PIPELINE_CODE 		   2'h2

`define PIPEILINE_RD_ADDR_CODE             32'h00000000
////////////////////////////////////////////////////////////////////////////////////////
/// ERROR EVENTS CODES

`define MEMORY_ACCESS_OF_NON_ALLCATED_REGION   8'h0   
`define FIFO_OVERFLOW                          8'h1 
`define WRITE_RESPONSES_OVERFLOW               8'h2 

////////////////////////////////////////////////////////////////////////////////////////
/// Different Modules TAG width (if not specified RD, WR, then it applies for both)
`define QPI_TAG                14

`define JOB_QUEUE_TAG          2
`define JOB_QUEUE_TAG_USED_WR  1'b0
`define JOB_QUEUE_TAG_USED_RD  1'b0

`define JOB_READER_TAG         `JOB_QUEUE_TAG + 2//`FTHREADS_BITS

`define FPGA_SETUP_TAG         4

`define PAGETABLE_TAG          4

`define FPGA_CORE_USR_TAG      3 + ((`JOB_READER_TAG > `FPGA_SETUP_TAG)? `JOB_READER_TAG : `FPGA_SETUP_TAG)
`define FPGA_CORE_TAG          8

`define IF_TAG                 9
`define AFU_TAG                8
`define FTHREAD_TAG            10


`endif
