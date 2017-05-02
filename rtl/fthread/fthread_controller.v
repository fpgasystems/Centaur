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
 
/*
    Command Opcode encoding:
    
 */
///////////////////////////////////////////////////////////////////////////////////////////////////
`include "../spl_defines.vh"
`include "../framework_defines.vh"

module FThread_controller #(parameter MAX_NUM_CONFIG_CL = 2, 
                            parameter USER_RD_TAG       = 2,
                            parameter USER_WR_TAG       = 9) (
	input   wire                                   clk,
    input   wire                                   rst_n,
    
    //--------------- channel <--> scheduler
    input   wire 						           cmd_valid,
    input   wire [`CMD_LINE_WIDTH-1:0] 	           cmd_line,
    output  reg 						           fthread_job_done, 
    
    output  wire                                   reset_user_logic,
    //--------------- channel <--> arbiter
    //- TX RD, RX RD
    output  wire   						           tx_rd_valid,
    output  wire [67:0] 				           tx_rd_hdr, 
    input  	wire 						           tx_rd_ready,

    input  	wire 						           rx_rd_valid,
    input   wire [`FTHREAD_TAG-1:0]                rx_rd_tag,
    input 	wire [511:0] 				           rx_data,
    //- TX WR, RX WR
    output  wire [71:0]				               tx_wr_hdr,  
    output  wire [511:0] 				           tx_data,
    output  wire  						           tx_wr_valid,
    input  	wire						           tx_wr_ready,

    input   wire [`FTHREAD_TAG-1:0]                rx_wr_tag,
    input 	wire 						           rx_wr_valid,
    //------------------------ Pipeline Interfaces ---------------------//
    // Left Pipe
    output  wire                                   left_pipe_tx_rd_valid,
    output  wire [`IF_TAG-1:0]                     left_pipe_tx_rd_tag, 
    input   wire                                   left_pipe_tx_rd_ready,

    input   wire                                   left_pipe_rx_rd_valid,
    input   wire [`IF_TAG-1:0]                     left_pipe_rx_rd_tag,
    input   wire [511:0]                           left_pipe_rx_data,
    output  wire                                   left_pipe_rx_rd_ready,
    // Right Pipe
    input   wire                                   right_pipe_tx_rd_valid,
    input   wire [`IF_TAG-1:0]                     right_pipe_tx_rd_tag, 
    output  wire                                   right_pipe_tx_rd_ready,

    output  wire                                   right_pipe_rx_rd_valid,
    output  wire [`IF_TAG-1:0]                     right_pipe_rx_rd_tag,
    output  wire [511:0]                           right_pipe_rx_data,
    input   wire                                   right_pipe_rx_rd_ready,
    //------------------------ User Module interface -------------------//
    output  reg  					               start_um,
    output  reg  [(MAX_NUM_CONFIG_CL*512)-1:0]     um_params,
    input   wire                                   um_done,

    input   wire [`NUM_USER_STATE_COUNTERS*32-1:0] um_state_counters,
    input   wire                                   um_state_counters_valid,
    // User Module TX RD
    input   wire [57:0]                            um_tx_rd_addr,
    input   wire [USER_RD_TAG-1:0]                 um_tx_rd_tag,
    input   wire 						           um_tx_rd_valid,
    output  wire                                   um_tx_rd_ready,
    // User Module TX WR
    input   wire [57:0]                            um_tx_wr_addr,
    input   wire [USER_WR_TAG-1:0]                 um_tx_wr_tag,
    input   wire 						           um_tx_wr_valid,
    input   wire [511:0]			               um_tx_data,
    output  wire                                   um_tx_wr_ready,
    // User Module RX RD
    output  wire [USER_RD_TAG-1:0]                 um_rx_rd_tag,
    output  wire [511:0]                           um_rx_data,
    output  wire                                   um_rx_rd_valid,
    input   wire                                   um_rx_rd_ready,
    // User Module RX WR 
    output  wire                                   um_rx_wr_valid,
    output  wire [USER_WR_TAG-1:0]                 um_rx_wr_tag
);

localparam [2:0]
		CHANNEL_IDLE_STATE          = 3'b000,
		CHANNEL_STARTING_STATE      = 3'b001,
		CHANNEL_CONFIG_STATE        = 3'b010,
		CHANNEL_RUN_STATE           = 3'b011,
		CHANNEL_DONE_STATE          = 3'b100,
        CHANNEL_DRAIN_WR_FIFO_STATE = 3'b101,
		CHANNEL_WRFENCE_STATE       = 3'b110,
        CHANNEL_DONE_RESP_STATE     = 3'b111;



reg   [2:0]                          ch_status_state;

wire 						         ft_tx_wr_ready;
reg  						         ft_tx_wr_valid;
reg   [57:0]				         ft_tx_wr_addr;
reg   [`FTHREAD_TAG-1:0]             ft_tx_wr_tag;
reg   [511:0]				         ft_tx_data;

reg                                  ft_tx_rd_valid;
reg   [57:0]                         ft_tx_rd_addr;
reg   [`FTHREAD_TAG-1:0]             ft_tx_rd_tag;
wire                                 ft_tx_rd_ready;

reg   [(MAX_NUM_CONFIG_CL*512)-1:0]	 config_param_line;

wire  [57:0]				         cfg_tx_rd_addr;
wire 						         cfg_tx_rd_ready;
wire  [`IF_TAG-1:0]                  cfg_tx_rd_tag;
wire 						         cfg_tx_rd_valid;

reg   [`IF_TAG-1:0]                  cfg_rx_rd_tag;
reg   [511:0] 				         cfg_rx_data;
reg  						         cfg_rx_rd_valid;

reg 					 	         cmd_buff_valid;
reg   [`CMD_LINE_WIDTH-1:0]	         cmd_buff;

reg                                  reserved_cmd_valid;
reg   [`CMD_LINE_WIDTH-1:0]          reserved_cmd;

wire  [3:0]                          wr_cmd;

reg   [31:0]                         writes_sent;
reg   [31:0]                         writes_done;

reg   [31:0]                         finishCycles;
reg   [31:0]                         RdReqCnt;
reg   [31:0]                         GRdReqCnt;
reg   [31:0]                         WrReqCnt;
reg   [31:0]                         exeCycles;
reg   [31:0]                         ConfigCycles;
reg   [31:0]                         ReadCycles;
reg   [31:0]                         ReadyCycles;

reg                                  rx_rd_valid_reg;
reg   [`FTHREAD_TAG-1:0]             rx_rd_tag_reg;
reg   [511:0]                        rx_data_reg;

reg   [`FTHREAD_TAG-1:0]             rx_wr_tag_reg;
reg                                  rx_wr_valid_reg;

wire  [(MAX_NUM_CONFIG_CL*512)-1:0]  afu_config_struct;
wire                                 afu_config_struct_valid;

wire                                 flush_cmd;
wire                                 read_reserved_cmd;


wire                                 tx_rd_fifo_full;
wire                                 tx_wr_fifo_full;
wire                                 tx_wr_fifo_empty;

reg                                  set_wr_if_direct_pipelined;
reg                                  set_wr_if_mem_pipelined;
reg  [57:0]                          wr_mem_pipeline_addr;

reg                                  set_rd_if_direct_pipelined;
reg                                  set_rd_if_mem_pipelined;
reg  [57:0]                          rd_mem_pipeline_addr;
reg  [3:0]                           rd_direct_pipeline_addr_code;
reg  [3:0]                           rd_mem_pipeline_addr_code;


wire                                 user_tx_wr_if_empty;

wire                                 usr_arb_tx_wr_valid;
wire [57:0]                          usr_arb_tx_wr_addr;
wire [`IF_TAG-1:0]                   usr_arb_tx_wr_tag;
wire [511:0]                         usr_arb_tx_data;
wire                                 usr_arb_tx_wr_ready;

reg                                  usr_arb_rx_wr_valid;
reg  [`IF_TAG-1:0]                   usr_arb_rx_wr_tag;

wire                                 rif_tx_wr_valid;
wire [57:0]                          rif_tx_wr_addr;
wire [`IF_TAG-1:0]                   rif_tx_wr_tag;
wire [511:0]                         rif_tx_data;
wire                                 rif_tx_wr_ready;

reg                                  rif_rx_wr_valid;
reg  [`IF_TAG-1:0]                   rif_rx_wr_tag;

wire                                 wif_tx_rd_valid;
wire [57:0]                          wif_tx_rd_addr;
wire [`IF_TAG-1:0]                   wif_tx_rd_tag;
wire                                 wif_tx_rd_ready;

reg                                  wif_rx_rd_valid;
reg  [`IF_TAG-1:0]                   wif_rx_rd_tag;
reg  [511:0]                         wif_rx_data;

wire                                 usr_arb_tx_rd_valid;
wire [57:0]                          usr_arb_tx_rd_addr;
wire [`IF_TAG-1:0]                   usr_arb_tx_rd_tag;
wire                                 usr_arb_tx_rd_ready;

reg                                  usr_arb_rx_rd_valid;
reg  [`IF_TAG-1:0]                   usr_arb_rx_rd_tag;
reg  [511:0]                         usr_arb_rx_data;

reg                                  run_rd_tx;
reg                                  run_wr_tx;

reg                                  rif_done;
reg                                  wif_done;
reg                                  start_d0;
///////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////                           //////////////////////////////////////
//////////////////////////////            FThread IO            ///////////////////////////////////
//////////////////////////////////                           //////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
// Register RX RD,WR: Data, tags
always@(posedge clk)begin
    rx_rd_tag_reg     <= rx_rd_tag;
    rx_data_reg       <= rx_data;
    rx_wr_tag_reg     <= rx_wr_tag;
end 

// Register RX RD,WR: Valids
always@(posedge clk)begin
    if(~rst_n) begin
        rx_rd_valid_reg   <= 0;
        rx_wr_valid_reg   <= 0;
    end 
    else begin 
        rx_rd_valid_reg   <= rx_rd_valid;
        rx_wr_valid_reg   <= rx_wr_valid;
    end 
end 

// RX RD: used by the user module and configurator
// data
always@(posedge clk) begin
    usr_arb_rx_rd_tag    <= rx_rd_tag_reg[`IF_TAG-1:0];
    usr_arb_rx_data      <= rx_data_reg; 

    wif_rx_data          <= rx_data_reg;
    wif_rx_rd_tag        <= rx_rd_tag_reg[`IF_TAG-1:0];
	 
	 cfg_rx_data          <= rx_data_reg;
	 cfg_rx_rd_tag        <= rx_rd_tag_reg[`IF_TAG-1:0];
end 
//valids
always@(posedge clk) begin
    if(~ rst_n)begin
        usr_arb_rx_rd_valid  <= 0;
        wif_rx_rd_valid      <= 0;
		  cfg_rx_rd_valid      <= 0;
    end 
    else begin
        usr_arb_rx_rd_valid  <= rx_rd_valid_reg & rx_rd_tag_reg[`FTHREAD_TAG-1] & run_rd_tx;
        wif_rx_rd_valid      <= rx_rd_valid_reg & ~rx_rd_tag_reg[`FTHREAD_TAG-1] & run_rd_tx;
		  
		  cfg_rx_rd_valid      <= rx_rd_valid_reg & ~run_rd_tx;
    end 
end  

//assign cfg_rx_data     = rx_data_reg;
//assign cfg_rx_rd_valid = rx_rd_valid_reg & ~run_rd_tx;
//assign cfg_rx_rd_tag   = rx_rd_tag_reg[`IF_TAG-1:0];
//////////////////////////////////////////////////////////// TX RD FIFO
quick_fifo  #(.FIFO_WIDTH(68),        
            .FIFO_DEPTH_BITS(9),
            .FIFO_ALMOSTFULL_THRESHOLD(32)
            ) tx_rd_fifo(
        .clk                (clk),
        .reset_n            (rst_n),
        .din                ({ft_tx_rd_addr, ft_tx_rd_tag}),
        .we                 (ft_tx_rd_valid),
        .re                 (tx_rd_ready),
        .dout               (tx_rd_hdr),
        .empty              (),
        .valid              (tx_rd_valid),
        .full               (tx_rd_fifo_full),
        .count              (),
        .almostfull         ()
    );

///////////////////////////////////////////////////////////////////////////////////////////////////
// RX WR: used by the user module
// tag
always@(posedge clk) begin
    usr_arb_rx_wr_tag   <= rx_wr_tag_reg[`IF_TAG-1:0];
    rif_rx_wr_tag       <= rx_wr_tag_reg[`IF_TAG-1:0];
end 
// valid
always@(posedge clk) begin
    if(~ rst_n)begin
        usr_arb_rx_wr_valid <= 0;
        rif_rx_wr_valid     <= 0;
    end 
    else begin
        usr_arb_rx_wr_valid <= rx_wr_valid_reg & rx_wr_tag_reg[`FTHREAD_TAG-1] & run_wr_tx;
        rif_rx_wr_valid     <= rx_wr_valid_reg & ~rx_wr_tag_reg[`FTHREAD_TAG-1] & run_wr_tx;
    end 
end 

//////////////////////////////////////////////////////////// TX WR FIFO
assign wr_cmd      = (run_wr_tx)? `CCI_REQ_WR_LINE : `CCI_REQ_WR_THRU;

quick_fifo  #(.FIFO_WIDTH(512+72),        
            .FIFO_DEPTH_BITS(9),
            .FIFO_ALMOSTFULL_THRESHOLD(32)
            ) tx_wr_fifo(
        .clk                (clk),
        .reset_n            (rst_n),
        .din                ({ wr_cmd, ft_tx_wr_addr, ft_tx_wr_tag, ft_tx_data}),
        .we                 (ft_tx_wr_valid),
        .re                 (tx_wr_ready),
        .dout               ({tx_wr_hdr, tx_data}),
        .empty              (tx_wr_fifo_empty),
        .valid              (tx_wr_valid),
        .full               (tx_wr_fifo_full),
        .count              (),
        .almostfull         ()
    );

/////////////////////////////////////////////////////////////////////////////////
// Track All Write requests that are finished
always@(posedge clk) begin
	if( ~rst_n  | (ch_status_state == CHANNEL_IDLE_STATE) )begin
		writes_sent <= 0;
		writes_done <= 0;
	end 
	else begin
       writes_sent <= (tx_wr_valid & tx_wr_ready)? (writes_sent + 1'b1) : writes_sent;
       writes_done <= (rx_wr_valid_reg)? (writes_done + 1'b1) : writes_done;
	end 
end 
 
///////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////                           //////////////////////////////////////
//////////////////////////////           Command Buffer         ///////////////////////////////////
//////////////////////////////////                           //////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

// communicate with the scheduler

assign flush_cmd = (ch_status_state == CHANNEL_DONE_STATE);

// cmd_line
always@(posedge clk) begin
    if(~cmd_buff_valid) begin
        cmd_buff       <= reserved_cmd;
    end
end
// valid
always@(posedge clk) begin
	if(~rst_n) begin
		cmd_buff_valid <= 1'b0;
	end 
	else if(flush_cmd) begin
		cmd_buff_valid <= 1'b0;
    end 
    else if(reserved_cmd_valid & (ch_status_state == CHANNEL_IDLE_STATE)) begin
        cmd_buff_valid <= 1'b1;
    end 
end 

// reserved cmd
// cmd_line
always@(posedge clk) begin
    if(~reserved_cmd_valid) begin
        reserved_cmd       <= cmd_line;
    end
end
// valid
always@(posedge clk) begin
    if(~rst_n) begin
        reserved_cmd_valid <= 1'b0;
    end 
    else if(read_reserved_cmd) begin
        reserved_cmd_valid <= 1'b0;
    end 
    else if(cmd_valid) begin
        reserved_cmd_valid <= 1'b1;
    end 
end 

assign read_reserved_cmd = reserved_cmd_valid & (ch_status_state == CHANNEL_IDLE_STATE);
///////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////                           //////////////////////////////////////
//////////////////////////////       FThread State Machine      ///////////////////////////////////
//////////////////////////////////                           //////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

always@(posedge clk) begin
    if(~rst_n) begin
        ch_status_state              <= 3'b0;
        
        set_wr_if_direct_pipelined   <= 0;
        set_wr_if_mem_pipelined      <= 0;
        wr_mem_pipeline_addr         <= 0;

        set_rd_if_direct_pipelined   <= 0;
        set_rd_if_mem_pipelined      <= 0;
        rd_mem_pipeline_addr         <= 0;
        rd_mem_pipeline_addr_code    <= 0;
        rd_direct_pipeline_addr_code <= 0;

        fthread_job_done             <= 0;

        start_d0                     <= 0;
        rif_done                     <= 0;
        wif_done                     <= 0;

        config_param_line            <= 0;
        run_rd_tx                    <= 0;
        run_wr_tx                    <= 0;

        ft_tx_wr_valid      <= 0;
        ft_tx_data          <= 0;
        ft_tx_wr_addr       <= 0;
        ft_tx_wr_tag        <= 0;

        ft_tx_rd_valid      <= 0;
        ft_tx_rd_addr       <= 0;
        ft_tx_rd_tag        <= 0;
    end 
    else begin
        case (ch_status_state) 
            CHANNEL_IDLE_STATE: begin 
                /* If a valid job request is available in the command buffer, then we issue a status update that the job is starting 
                and compute some necessary flags for the configuration of the FThread Controller */
                ft_tx_wr_valid    <= 1'b0;
                fthread_job_done  <= 0;
                start_d0          <= 0;
                ft_tx_rd_valid    <= 0;
                rif_done          <= 0;
                wif_done          <= 0;

                if(cmd_buff_valid) begin
                    // Go to start state, set some flags
                    ch_status_state              <= CHANNEL_STARTING_STATE;  

                    // WR IF Config                    
                    set_wr_if_direct_pipelined   <= (cmd_buff[121:120] == `WR_IF_DIRECT_PIPELINE_CODE);
                    set_wr_if_mem_pipelined      <= (cmd_buff[121:120] == `WR_IF_MEM_PIPELINE_CODE);
                    wr_mem_pipeline_addr         <= cmd_buff[179:122];

                    // RD IF Config
                    set_rd_if_direct_pipelined   <= cmd_buff[180];
                    set_rd_if_mem_pipelined      <= cmd_buff[181];
                    rd_mem_pipeline_addr         <= cmd_buff[239:182];
                    rd_mem_pipeline_addr_code    <= cmd_buff[243:240];
                    rd_direct_pipeline_addr_code <= cmd_buff[247:244];

                    // write fthread status as starting to the SW to see.
                    ft_tx_wr_valid      <= 1'b1;
                    ft_tx_data          <= {um_state_counters[255:0], ReadyCycles, ReadCycles, finishCycles, ConfigCycles, exeCycles, WrReqCnt, RdReqCnt, 29'b0, CHANNEL_STARTING_STATE};
                    ft_tx_wr_addr       <= cmd_buff[57:0];
                    ft_tx_wr_tag        <= 0;
                end
            end 
            CHANNEL_STARTING_STATE: begin
                /* This state is just a stopby state until the starting status update request is sent to memory*/
                if(ft_tx_wr_ready) begin
                    ch_status_state   <= CHANNEL_CONFIG_STATE;
                    ft_tx_wr_valid    <= 1'b0;
                end
            end
            CHANNEL_CONFIG_STATE: begin
                /* During this state the Config struct reader is started to read the user AFU configuration data structure. 
                When the configuration is obtained we switch to the Run state and trigger the user AFU*/
                if (afu_config_struct_valid) begin
                    ch_status_state     <= CHANNEL_RUN_STATE;
                    start_d0            <= 1'b1;
                    run_rd_tx           <= 1'b1;
                    run_wr_tx           <= 1'b1;
                end 
                config_param_line       <= afu_config_struct;
                //
                if(ft_tx_rd_ready) begin
                    ft_tx_rd_valid <= cfg_tx_rd_valid;
                    ft_tx_rd_addr  <= cfg_tx_rd_addr;
                    ft_tx_rd_tag   <= {1'b0, cfg_tx_rd_tag};
                end
            end 
            CHANNEL_RUN_STATE: begin
                /* In this state the user AFU is active, we stay in this state until the user declares it finished processing and producing 
                all the results. Then we move to the Drain WR FIFO state, to make sure all user generated write requests are submitted to
                memory*/
                start_d0 <= 1'b0;

                if(um_done) begin
                    ch_status_state   <= CHANNEL_DRAIN_WR_FIFO_STATE;
                    config_param_line <= 0;
                    wif_done          <= 1'b1;
                    rif_done          <= 1'b1;

                    set_rd_if_direct_pipelined   <= 0;
                    set_rd_if_mem_pipelined      <= 0;
                    rd_mem_pipeline_addr         <= 0;
                    rd_mem_pipeline_addr_code    <= 0;
                    rd_direct_pipeline_addr_code <= 0;
                end
                //
                // TX RD
                if(ft_tx_rd_ready) begin
                    if(wif_tx_rd_valid) begin
                        ft_tx_rd_valid <= 1'b1;
                        ft_tx_rd_addr  <= wif_tx_rd_addr;
                        ft_tx_rd_tag   <= {1'b0, wif_tx_rd_tag};
                    end 
                    else begin 
                        ft_tx_rd_valid <= usr_arb_tx_rd_valid;
                        ft_tx_rd_addr  <= usr_arb_tx_rd_addr;
                        ft_tx_rd_tag   <= {1'b1, usr_arb_tx_rd_tag};
                    end
                end
                // TX WR
                if(ft_tx_wr_ready) begin
                    if(rif_tx_wr_valid) begin
                        ft_tx_wr_valid <= 1'b1;
                        ft_tx_wr_addr  <= rif_tx_wr_addr;
                        ft_tx_wr_tag   <= {1'b0, rif_tx_wr_tag};
                        ft_tx_data     <= rif_tx_data;
                    end 
                    else begin 
                        ft_tx_wr_valid <= usr_arb_tx_wr_valid;
                        ft_tx_wr_addr  <= usr_arb_tx_wr_addr;
                        ft_tx_wr_tag   <= {1'b1, usr_arb_tx_wr_tag};
                        ft_tx_data     <= usr_arb_tx_data;
                    end
                end
            end
            CHANNEL_DRAIN_WR_FIFO_STATE: begin
                /* In this state we make sure all the write requests in the different FIFOs are submitted to memory*/
                if (user_tx_wr_if_empty & tx_wr_fifo_empty & ~ft_tx_wr_valid) begin
                    ch_status_state     <= CHANNEL_WRFENCE_STATE;
                end

                if(tx_wr_fifo_empty) begin
                    set_wr_if_direct_pipelined   <= 0;
                    set_wr_if_mem_pipelined      <= 0;
                    wr_mem_pipeline_addr         <= 0;
                end
                // TX RD
                if(ft_tx_rd_ready) begin
                    ft_tx_rd_valid <= wif_tx_rd_valid;
                    ft_tx_rd_addr  <= wif_tx_rd_addr;
                    ft_tx_rd_tag   <= {1'b0, wif_tx_rd_tag};
                end
                // TX WR
                if(ft_tx_wr_ready) begin
                    if(rif_tx_wr_valid) begin
                        ft_tx_wr_valid <= 1'b1;
                        ft_tx_wr_addr  <= rif_tx_wr_addr;
                        ft_tx_wr_tag   <= {1'b0, rif_tx_wr_tag};
                        ft_tx_data     <= rif_tx_data;
                    end 
                    else begin 
                        ft_tx_wr_valid <= usr_arb_tx_wr_valid;
                        ft_tx_wr_addr  <= usr_arb_tx_wr_addr;
                        ft_tx_wr_tag   <= {1'b1, usr_arb_tx_wr_tag};
                        ft_tx_data     <= usr_arb_tx_data;
                    end
                end
            end
            CHANNEL_WRFENCE_STATE: begin
                run_rd_tx                    <= 0;
                run_wr_tx                    <= 0;
                
                if (writes_sent == writes_done) begin
                    ch_status_state   <= CHANNEL_DONE_STATE;
                    //
                    ft_tx_wr_valid      <= 1'b1;
                    ft_tx_data          <= {um_state_counters[255:0], ReadyCycles, ReadCycles, finishCycles, ConfigCycles, exeCycles, WrReqCnt, RdReqCnt, 29'b0, CHANNEL_DONE_STATE};
                    ft_tx_wr_addr       <= cmd_buff[57:0];
                    ft_tx_wr_tag        <= 0;
                end
            end
            CHANNEL_DONE_STATE: begin
                if(ft_tx_wr_ready) begin
                    ch_status_state   <= CHANNEL_DONE_RESP_STATE;
                    ft_tx_wr_valid    <= 1'b0;
                end
            end
            CHANNEL_DONE_RESP_STATE: begin
                if(rx_wr_valid_reg) begin
                    ch_status_state   <= CHANNEL_IDLE_STATE;
                    fthread_job_done  <= 1'b1;
                end
            end 
        endcase 
    end 
end

assign ft_tx_rd_ready      = ~tx_rd_fifo_full;
assign wif_tx_rd_ready     = ft_tx_rd_ready & run_rd_tx;
assign usr_arb_tx_rd_ready = ft_tx_rd_ready & run_rd_tx & ~wif_tx_rd_valid;
assign cfg_tx_rd_ready     = ft_tx_rd_ready;

assign ft_tx_wr_ready      = ~tx_wr_fifo_full;
assign rif_tx_wr_ready     = ft_tx_wr_ready & run_wr_tx;
assign usr_arb_tx_wr_ready = ft_tx_wr_ready & run_wr_tx & ~rif_tx_wr_valid;
///////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////                           //////////////////////////////////////
//////////////////////////////            Configurer            ///////////////////////////////////
//////////////////////////////////                           //////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

ReadConfigStruct #(.MAX_NUM_CONFIG_CL(MAX_NUM_CONFIG_CL)) 
     ReadConfigStruct (
    .clk                       (clk),
    .rst_n                     (rst_n & ~(ch_status_state == CHANNEL_DONE_RESP_STATE)),
    //-------------------------------------------------//
    .get_config_struct         ( ch_status_state == CHANNEL_CONFIG_STATE ),
    .base_addr                 (cmd_buff[115:58]),
    .config_struct_length      ( {28'b0, cmd_buff[119:116]}),
    // User Module TX RD
    .cs_tx_rd_addr             (cfg_tx_rd_addr),
    .cs_tx_rd_tag              (cfg_tx_rd_tag),
    .cs_tx_rd_valid            (cfg_tx_rd_valid),
    .cs_tx_rd_free             (cfg_tx_rd_ready),
    // User Module RX RD
    .cs_rx_rd_tag              (cfg_rx_rd_tag),
    .cs_rx_rd_data             (cfg_rx_data),
    .cs_rx_rd_valid            (cfg_rx_rd_valid),
    //
    .afu_config_struct         (afu_config_struct),
    .afu_config_struct_valid   (afu_config_struct_valid)
);


///////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////                              ///////////////////////////////////
//////////////////////////////    User Module Control Interface     ///////////////////////////////
//////////////////////////////////                              ///////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
// 

always@(posedge clk) begin
	um_params        <= config_param_line;
end 

always@(posedge clk) begin
	if( ~rst_n) begin 
		start_um         <= 0;
	end 
	else begin
		start_um         <= start_d0;
	end 
end
//assign um_params        = config_param_line;

assign reset_user_logic = (ch_status_state == CHANNEL_IDLE_STATE);

///////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////                           //////////////////////////////////////
//////////////////////////////    User Module IO Interfaces     ///////////////////////////////////
//////////////////////////////////                           //////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
// RD Interface

user_tx_rd_if #(.USER_TAG(USER_RD_TAG))
user_tx_rd_if(
    .clk                                (clk),
    .rst_n                              (rst_n),
    .reset_interface                    ( (ch_status_state == CHANNEL_IDLE_STATE) ),

    .set_if_mem_pipelined               (set_rd_if_mem_pipelined),
    .set_if_direct_pipelined            (set_rd_if_direct_pipelined),
    .mem_pipeline_addr                  (rd_mem_pipeline_addr),
    .mem_pipeline_addr_code             (rd_mem_pipeline_addr_code),
    .direct_pipeline_addr_code          (rd_direct_pipeline_addr_code),

    .reads_finished                     (rif_done),
    //--------------------- User RD Request -----------------------------//
    // User Module TX RD
    .um_tx_rd_addr                      (um_tx_rd_addr),
    .um_tx_rd_tag                       (um_tx_rd_tag),
    .um_tx_rd_valid                     (um_tx_rd_valid),
    .um_tx_rd_ready                     (um_tx_rd_ready),
    // User Module RX RD
    .um_rx_rd_tag                       (um_rx_rd_tag),
    .um_rx_data                         (um_rx_data),
    .um_rx_rd_valid                     (um_rx_rd_valid),
    .um_rx_rd_ready                     (um_rx_rd_ready),
    //-------------------- to Fthread Controller ------------------------//
    .usr_arb_tx_rd_valid                (usr_arb_tx_rd_valid),
    .usr_arb_tx_rd_addr                 (usr_arb_tx_rd_addr), 
    .usr_arb_tx_rd_tag                  (usr_arb_tx_rd_tag),
    .usr_arb_tx_rd_ready                (usr_arb_tx_rd_ready),

    .usr_arb_rx_rd_valid                (usr_arb_rx_rd_valid),
    .usr_arb_rx_rd_tag                  (usr_arb_rx_rd_tag),
    .usr_arb_rx_data                    (usr_arb_rx_data),
    .rif_tx_wr_addr                     (rif_tx_wr_addr),
    .rif_tx_wr_tag                      (rif_tx_wr_tag),
    .rif_tx_wr_valid                    (rif_tx_wr_valid),
    .rif_tx_data                        (rif_tx_data),
    .rif_tx_wr_ready                    (rif_tx_wr_ready),

    .rif_rx_wr_tag                      (rif_rx_wr_tag),
    .rif_rx_wr_valid                    (rif_rx_wr_valid),
    //-------------------- to pipeline writer ---------------------------//
    .usr_pipe_tx_rd_valid               (left_pipe_tx_rd_valid),
    .usr_pipe_tx_rd_tag                 (left_pipe_tx_rd_tag), 
    .usr_pipe_tx_rd_ready               (left_pipe_tx_rd_ready),

    .usr_pipe_rx_rd_valid               (left_pipe_rx_rd_valid),
    .usr_pipe_rx_rd_tag                 (left_pipe_rx_rd_tag),
    .usr_pipe_rx_data                   (left_pipe_rx_data),
    .usr_pipe_rx_rd_ready               (left_pipe_rx_rd_ready)
);


// WR Interface

user_tx_wr_if #(.USER_TAG(USER_WR_TAG) )
user_tx_wr_if(
    .clk                                (clk),
    .rst_n                              (rst_n),
    .reset_interface                    ( (ch_status_state == CHANNEL_IDLE_STATE) ),

    .set_if_pipelined                   (set_wr_if_direct_pipelined),
    .user_tx_wr_if_empty                (user_tx_wr_if_empty),
    .set_if_mem_pipelined               (set_wr_if_mem_pipelined),
    .mem_pipeline_addr                  (wr_mem_pipeline_addr),

    .writes_finished                    (wif_done),
    //--------------------- User RD Request -----------------------------//
    // User Module TX WR
    .um_tx_wr_addr                      (um_tx_wr_addr),
    .um_tx_wr_tag                       (um_tx_wr_tag),
    .um_tx_wr_valid                     (um_tx_wr_valid),
    .um_tx_data                         (um_tx_data),
    .um_tx_wr_ready                     (um_tx_wr_ready),
    // User Module RX WR
    .um_rx_wr_valid                     (um_rx_wr_valid),
    .um_rx_wr_tag                       (um_rx_wr_tag),
    //-------------------- to Fthread Controller ------------------------//
    .usr_arb_tx_wr_valid                (usr_arb_tx_wr_valid),
    .usr_arb_tx_wr_addr                 (usr_arb_tx_wr_addr), 
    .usr_arb_tx_wr_tag                  (usr_arb_tx_wr_tag),
    .usr_arb_tx_wr_ready                (usr_arb_tx_wr_ready),
    .usr_arb_tx_data                    (usr_arb_tx_data),

    .usr_arb_rx_wr_valid                (usr_arb_rx_wr_valid),
    .usr_arb_rx_wr_tag                  (usr_arb_rx_wr_tag),

    .wif_tx_rd_addr                     (wif_tx_rd_addr),
    .wif_tx_rd_tag                      (wif_tx_rd_tag),
    .wif_tx_rd_valid                    (wif_tx_rd_valid),
    .wif_tx_rd_ready                    (wif_tx_rd_ready),

    .wif_rx_rd_tag                      (wif_rx_rd_tag),
    .wif_rx_data                        (wif_rx_data),
    .wif_rx_rd_valid                    (wif_rx_rd_valid),
    //-------------------- To pipeline reader
    .usr_pipe_tx_rd_valid               (right_pipe_tx_rd_valid),
    .usr_pipe_tx_rd_tag                 (right_pipe_tx_rd_tag), 
    .usr_pipe_tx_rd_ready               (right_pipe_tx_rd_ready),

    .usr_pipe_rx_rd_valid               (right_pipe_rx_rd_valid),
    .usr_pipe_rx_rd_tag                 (right_pipe_rx_rd_tag),
    .usr_pipe_rx_data                   (right_pipe_rx_data),
    .usr_pipe_rx_rd_ready               (right_pipe_rx_rd_ready)
);



///////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////                           //////////////////////////////////////
//////////////////////////////        Profiling Counters        ///////////////////////////////////
//////////////////////////////////                           //////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

always@(posedge clk) begin
    if(~rst_n | (ch_status_state == CHANNEL_IDLE_STATE)) begin
        RdReqCnt     <= 32'b0;
        GRdReqCnt    <= 32'b0;
        WrReqCnt     <= 32'b0;
        exeCycles    <= 32'b0;
        finishCycles <= 32'b0;
        ConfigCycles <= 32'b0;
        ReadCycles   <= 0;
        ReadyCycles  <= 0;
    end 
    else begin
        exeCycles <= exeCycles + 1'b1;

        if(tx_rd_valid & tx_rd_ready) begin
            GRdReqCnt  <= GRdReqCnt + 1'b1;
        end

        if(um_tx_rd_valid & um_tx_rd_ready) begin
            RdReqCnt  <= RdReqCnt + 1'b1;
        end
        //
        if(um_tx_wr_valid & um_tx_wr_ready) begin
            WrReqCnt  <= WrReqCnt + 1'b1;
        end
        //
        if( ch_status_state[2] ) begin
            finishCycles <= finishCycles + 1'b1;
        end
        //
        if(ch_status_state == CHANNEL_CONFIG_STATE) begin
            ConfigCycles <= ConfigCycles + 1'b1;
        end
        // 
        if(um_tx_rd_valid) begin
           ReadCycles <= ReadCycles + 1'b1;
        end 
        //
        if(tx_rd_ready) begin 
       ReadyCycles <= ReadyCycles + 1'b1;
        end 
    end
end 

endmodule