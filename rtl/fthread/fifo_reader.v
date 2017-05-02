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
 
`include "../framework_defines.vh"

module sw_fifo_reader #(parameter POLL_CYCLES = 32, 
						parameter USER_TAG    = `AFU_TAG) 
	(
    input   wire                                     clk,
    input   wire                                     rst_n,
    //-------------------------------------------------//
	input   wire [57:0]                              fifo_base_addr,
	input   wire [3:0]  						     fifo_addr_code,
	input   wire 								     setup_fifo,
	input   wire                                     reads_finished,
	//--------------------- FIFO to QPI ----------------//
    // TX RD
    output  reg  [57:0]                              fifo_tx_rd_addr,
    output  reg  [2+USER_TAG-1:0]                    fifo_tx_rd_tag,
    output  reg  						             fifo_tx_rd_valid,
    input   wire                                     fifo_tx_rd_ready,
    // TX WR
    output  reg  [57:0]                              fifo_tx_wr_addr,
    output  reg  [`IF_TAG-1:0]                       fifo_tx_wr_tag,
    output  reg 						             fifo_tx_wr_valid,
    output  reg  [511:0]			                 fifo_tx_data,
    input   wire                                     fifo_tx_wr_ready,
    // RX RD
    input   wire [2+USER_TAG-1:0]                    fifo_rx_rd_tag,
    input   wire [511:0]                             fifo_rx_data,
    input   wire                                     fifo_rx_rd_valid,
    output  wire 									 fifo_rx_rd_ready,
    // RX WR 
    input   wire                                     fifo_rx_wr_valid,
    input   wire [`IF_TAG-1:0]                       fifo_rx_wr_tag,
    ///////////////////////// User Logic Interface ////////////////////
    input   wire [USER_TAG-1:0]                      usr_tx_rd_tag,
    input   wire 						             usr_tx_rd_valid,
    input   wire [57:0]                              usr_tx_rd_addr,
    output  wire                                     usr_tx_rd_ready,

    output  reg  [USER_TAG-1:0]                      usr_rx_rd_tag,
    output  reg  [511:0]                             usr_rx_data,
    output  reg                                      usr_rx_rd_valid,
    input   wire 									 usr_rx_rd_ready
);


///////////////////////////////// Wires Declarations ////////////////////////////
wire                   update_status;
wire                   poll_again;
wire                   data_available;
/////////////////////////////////////// Reg Declarations /////////////////////////
reg   [31:0]           numPulledCLs;
reg   [31:0]           otherSideUpdatedBytes;
reg   [31:0]           sizeInNumCL;
reg   [31:0]           usr_rd_count;
reg   [31:0]           poll_count;

reg   [57:0]           fifo_buff_addr;
reg   [57:0]           fifo_struct_base;

reg   [1:0]            fifo_fsm_state;
reg   [1:0]            poll_fsm_state;


reg                    update_set;

reg   [57:0]           poll_rd_addr;
reg 				   poll_rd_valid;
wire                   poll_rd_ready; 

wire  [511:0]          poll_rx_data;
wire  				   poll_rx_valid;           

reg   [31:0]           readBytes;
reg   [31:0]           update_status_threashold;
reg                    write_response_pending;
reg   [31:0]           lastUpdatedBytes;

reg  				   mem_pipeline;
reg   [3:0]            fifo_addr_code_reg;
wire                   mem_fifo_valid;
reg                    mem_fifo_re;
wire                   mem_fifo_full;
wire  [57+USER_TAG:0]  mem_fifo_dout;

wire                   pipe_fifo_valid;
wire                   pipe_fifo_re;
wire                   pipe_fifo_full;
wire                   pipe_fifo_empty;
wire  [USER_TAG-1:0]   pipe_fifo_dout;  			

/////////////////////////////////// Local Parameters /////////////////////////////////////////

localparam [1:0]
		FIFO_IDLE_STATE              = 2'b00,
		FIFO_REQUEST_CONFIG_STATE    = 2'b01,
		FIFO_READ_CONFIG_STATE       = 2'b10,
		FIFO_RUN_STATE               = 2'b11;


localparam [1:0]
		POLL_IDLE_STATE       = 2'b00,
		POLL_REQUEST_STATE    = 2'b01,
		POLL_RESP_STATE       = 2'b10,
		POLL_VALID_STATE      = 2'b11;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////                           ////////////////////////////////////////////
/////////////////////////////////////////        Reader Requests FIFO      /////////////////////////////////////////
/////////////////////////////////////////////                           ////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
quick_fifo  #(.FIFO_WIDTH(USER_TAG),        
            .FIFO_DEPTH_BITS(9),
            .FIFO_ALMOSTFULL_THRESHOLD((2**9) - 8)
            ) pipe_fifo(
        .clk                (clk),
        .reset_n            (rst_n),
        .din                (mem_fifo_dout[57+USER_TAG:58]),
        .we                 (mem_fifo_valid & mem_pipeline & (mem_fifo_dout[57:54] == fifo_addr_code_reg)),
        .re                 (pipe_fifo_re),
        .dout               (pipe_fifo_dout),
        .empty              (pipe_fifo_empty),
        .valid              (pipe_fifo_valid),
        .full               (pipe_fifo_full),
        .count              (),
        .almostfull         ()
    ); 

quick_fifo  #(.FIFO_WIDTH(58+USER_TAG),        
            .FIFO_DEPTH_BITS(9),
            .FIFO_ALMOSTFULL_THRESHOLD((2**9) - 8)
            ) mem_fifo(
        .clk                (clk),
        .reset_n            (rst_n),
        .din                ({usr_tx_rd_tag, usr_tx_rd_addr}),
        .we                 (usr_tx_rd_valid),
        .re                 (mem_fifo_re),
        .dout               (mem_fifo_dout),
        .empty              (),
        .valid              (mem_fifo_valid),
        .full               (mem_fifo_full),
        .count              (),
        .almostfull         ()
    ); 

assign usr_tx_rd_ready = ~mem_fifo_full;

assign pipe_fifo_re    = fifo_tx_rd_ready & data_available & ~poll_rd_valid;

always @(posedge clk) begin
	if(~rst_n) begin
		mem_pipeline       <= 0;
		fifo_addr_code_reg <= 0;
	end 
	else if(setup_fifo) begin
		mem_pipeline       <= 1'b1;
		fifo_addr_code_reg <= fifo_addr_code;
	end
end

always @(*) begin
	if( mem_pipeline ) begin 
		if( fifo_fsm_state == FIFO_RUN_STATE ) begin
			if(mem_fifo_dout[57:54] == fifo_addr_code_reg) begin
				mem_fifo_re <= ~pipe_fifo_full;
			end 
			else if(fifo_tx_rd_ready & (~pipe_fifo_empty | poll_rd_valid)) begin
				mem_fifo_re <= 0;
			end 
			else begin
				mem_fifo_re <= fifo_tx_rd_ready;
			end 
		end
		else begin
			mem_fifo_re <= 0;
		end 
	end
	else begin
		mem_fifo_re <= fifo_tx_rd_ready;
	end  
end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////                           ////////////////////////////////////////////
/////////////////////////////////////////        FIFO Polling Logic        /////////////////////////////////////////
/////////////////////////////////////////////                           ////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
always @(posedge clk) begin
	if(~rst_n | reads_finished) begin
		otherSideUpdatedBytes <= 0;
		poll_fsm_state        <= 0;
		poll_count            <= 0;
		poll_rd_addr          <= 0;
		poll_rd_valid         <= 0;
	end 
	else begin
		case (poll_fsm_state)
		    POLL_IDLE_STATE: begin
		    	if (fifo_fsm_state == FIFO_RUN_STATE) begin
		    		poll_fsm_state     <= POLL_RESP_STATE;
		    		poll_rd_addr       <= fifo_struct_base  + `CRB_STRUCT_PRODUCER_LINE_OFFSET;
		    		poll_rd_valid      <= 1'b1;
		    	end
		    end
		    POLL_REQUEST_STATE: begin  // This state enable reading the producer status line
		    	if( poll_count == POLL_CYCLES)  begin
					poll_rd_valid  <= 1'b1;
					poll_fsm_state <= POLL_RESP_STATE;
				end 
				poll_count         <= poll_count + 1'b1;
		    end
		    POLL_RESP_STATE: begin  
		    	if(poll_rd_ready) poll_rd_valid <= 1'b0;

		    	if(poll_rx_valid) begin
		    		poll_fsm_state        <= POLL_VALID_STATE;
		    		otherSideUpdatedBytes <= poll_rx_data[63:32];
		    	end

		    	poll_count        <= 0;
		    end
		    POLL_VALID_STATE: begin
		    	if(poll_again) begin
		    		poll_fsm_state <= POLL_REQUEST_STATE;
		    	end
		    end
		endcase
	end
end 
/////////////////////////////// FIFO Status Logic /////////////////////////////////

assign poll_again       = (otherSideUpdatedBytes >> 6) == numPulledCLs;
assign data_available   = (otherSideUpdatedBytes >> 6) > numPulledCLs; 

assign poll_rd_ready    = (fifo_fsm_state == FIFO_RUN_STATE) & fifo_tx_rd_ready;

always @(posedge clk) begin
	if(~rst_n) begin
		sizeInNumCL       <= 0;
		fifo_buff_addr    <= 0;
		fifo_struct_base  <= 0;
		usr_rd_count      <= 0;
		fifo_fsm_state    <= 0;
		numPulledCLs      <= 0;

		fifo_tx_rd_valid  <= 0;
		fifo_tx_rd_addr   <= 0;
		fifo_tx_rd_tag    <= 0;
	end 
	else begin
		case (fifo_fsm_state)
		    FIFO_IDLE_STATE: begin
		    	if (setup_fifo) begin
		    		fifo_fsm_state     <= FIFO_REQUEST_CONFIG_STATE;
		    		fifo_struct_base   <= fifo_base_addr;
		    	end

		    	if(fifo_tx_rd_ready) begin
		    		fifo_tx_rd_valid <= mem_fifo_valid;
		    		fifo_tx_rd_addr  <= mem_fifo_dout[57:0];
		    		fifo_tx_rd_tag   <= {2'b00, mem_fifo_dout[57+USER_TAG:58]};
		    	end 
		    end
		    FIFO_REQUEST_CONFIG_STATE: begin  // This state enable reading the CRB configuration line
		    	fifo_tx_rd_valid  <= 1'b1;
		    	fifo_tx_rd_addr   <= fifo_struct_base;
		    	fifo_tx_rd_tag    <= {2'b11, {USER_TAG{1'b0}}};

		    	fifo_fsm_state    <= FIFO_READ_CONFIG_STATE;
		    	
		    end
		    FIFO_READ_CONFIG_STATE: begin  // This state enable reading the CRB configuration line
		    	if(fifo_tx_rd_ready) fifo_tx_rd_valid <= 1'b0;

		    	if(fifo_rx_rd_valid) fifo_fsm_state   <= FIFO_RUN_STATE;

		    	fifo_buff_addr           <= fifo_rx_data[63:6];
		    	sizeInNumCL              <= (fifo_rx_data[127:96]  >> 6) - 1;
		    	update_status_threashold <= fifo_rx_data[159:128];
		    end
		    FIFO_RUN_STATE: begin  // This state enable writing user generated to the Buffer
		    	if(reads_finished) begin
		    		fifo_fsm_state     <= FIFO_IDLE_STATE;
		    	end

		    	if(fifo_tx_rd_ready) begin
		    		if(poll_rd_valid) begin
		    			fifo_tx_rd_valid <= 1'b1;
		    			fifo_tx_rd_addr  <= poll_rd_addr;
		    			fifo_tx_rd_tag   <= {2'b11, {USER_TAG{1'b0}}};
		    		end
		    		else if(~pipe_fifo_empty) begin
		    			if(data_available & pipe_fifo_valid) begin
		    				fifo_tx_rd_valid <= 1'b1;
		    				fifo_tx_rd_addr  <= fifo_buff_addr + usr_rd_count;
		    				fifo_tx_rd_tag   <= {2'b01, pipe_fifo_dout};

		    				if(usr_rd_count == sizeInNumCL) begin
		    					usr_rd_count <= 0;
		    				end
		    				else begin
		    					usr_rd_count <= usr_rd_count + 1'b1;
		    				end
		    				numPulledCLs <= numPulledCLs + 1'b1;
		    			end
		    			else begin
		    				fifo_tx_rd_valid <= 1'b0;
		    			end  
		    		end
		    		else if(mem_fifo_dout[57:54] != fifo_addr_code_reg) begin
		    			fifo_tx_rd_valid <= mem_fifo_valid;
		    			fifo_tx_rd_addr  <= mem_fifo_dout[57:0];
		    			fifo_tx_rd_tag   <= {2'b00, mem_fifo_dout[57+USER_TAG:58]};
		    		end
		    		else begin
		    			fifo_tx_rd_valid <= 1'b0;
		    		end
		    	end
		    end
		endcase
	end
end

//////////////////////////////////////////////////////////////////////////////////////
////////// RX RD 
//////////////////////////////////////////////////////////////////////////////////////

always@(posedge clk) begin
	if(~rst_n) begin 
		usr_rx_rd_valid  <= 1'b0;
	end 
	else if( usr_rx_rd_ready ) begin 
		usr_rx_rd_valid  <= fifo_rx_rd_valid & ~fifo_rx_rd_tag[USER_TAG+1];
	end 
end 

always@(posedge clk) begin
	if( usr_rx_rd_ready ) begin 
		usr_rx_data      <= fifo_rx_data;
		usr_rx_rd_tag    <= fifo_rx_rd_tag[USER_TAG-1:0];
	end 
end 

//assign usr_rx_data      = fifo_rx_data;
//assign usr_rx_rd_valid  = fifo_rx_rd_valid & ~fifo_rx_rd_tag[USER_TAG+1];
//assign usr_rx_rd_tag    = fifo_rx_rd_tag[USER_TAG-1:0];
assign fifo_rx_rd_ready = (usr_rx_rd_ready)? 1'b1 :  fifo_rx_rd_valid & fifo_rx_rd_tag[USER_TAG+1];

assign poll_rx_data    = fifo_rx_data;
assign poll_rx_valid   = fifo_rx_rd_valid & fifo_rx_rd_tag[USER_TAG+1];
/////////////////////////////////////////////////////////////


always@(posedge clk) begin
	if(~rst_n)begin
		readBytes <= 0;
	end
	else if(fifo_rx_rd_valid & ~fifo_rx_rd_tag[USER_TAG+1] & fifo_rx_rd_tag[USER_TAG]) begin
		readBytes <= readBytes + 64;
	end 
end 

//////////////////////////////////////////////////////////////////////////////////////
///////////////////////////// FIFO Consumer Status Update ////////////////////////////
////////////////////////////// TX WR  Requests Generation ////////////////////////////

always @(posedge clk) begin 
	if(~rst_n) begin
		fifo_tx_wr_addr  <= 0;
		fifo_tx_wr_valid <= 0;
		fifo_tx_wr_tag   <= 0;
		update_set       <= 1'b0;

		lastUpdatedBytes <= 0;

		write_response_pending <= 0;
	end 
	else begin

		if(fifo_rx_wr_valid)
			write_response_pending <= 1'b0;
		else if(fifo_tx_wr_ready & fifo_tx_wr_valid)
			write_response_pending <= 1'b1;

		if(fifo_tx_wr_ready) begin 
			if(update_status & ~write_response_pending) begin
				lastUpdatedBytes <= readBytes;

				fifo_tx_data     <= {448'b0, readBytes, usr_rd_count};
				fifo_tx_wr_addr  <= fifo_struct_base + `CRB_STRUCT_CONSUMER_LINE_OFFSET;
				fifo_tx_wr_tag   <= 0;
				fifo_tx_wr_valid <= 1'b1;
			end
			else begin
				fifo_tx_wr_valid <= 0;
			end
		end 
	end
end

assign update_status = ((readBytes - lastUpdatedBytes) > update_status_threashold);



endmodule
