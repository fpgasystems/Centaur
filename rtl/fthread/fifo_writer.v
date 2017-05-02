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

module sw_fifo_writer #(parameter POLL_CYCLES = 32, 
						parameter USER_TAG    = `AFU_TAG) 
	(
    input   wire                                     clk,
    input   wire                                     rst_n,
    //-------------------------------------------------//
	input   wire [57:0]                              fifo_base_addr,
	input   wire 								     setup_fifo,
	input   wire                                     writes_finished,
	output  reg                                      fifo_done,
	//--------------------- FIFO to QPI ----------------//
    // TX RD
    output  reg  [57:0]                              fifo_tx_rd_addr,
    output  reg  [`IF_TAG-1:0]                       fifo_tx_rd_tag,
    output  reg  						             fifo_tx_rd_valid,
    input   wire                                     fifo_tx_rd_ready,
    // TX WR
    output  reg  [57:0]                              fifo_tx_wr_addr,
    output  reg  [USER_TAG+1:0]                      fifo_tx_wr_tag,
    output  reg 						             fifo_tx_wr_valid,
    output  reg  [511:0]			                 fifo_tx_data,
    input   wire                                     fifo_tx_wr_ready,
    // RX RD
    input   wire [`IF_TAG-1:0]                       fifo_rx_rd_tag,
    input   wire [511:0]                             fifo_rx_data,
    input   wire                                     fifo_rx_rd_valid,
    //output  wire 									 fifo_rx_rd_ready,
    // RX WR 
    input   wire                                     fifo_rx_wr_valid,
    input   wire [USER_TAG+1:0]                      fifo_rx_wr_tag,
    ///////////////////////// User Logic Interface ////////////////////
    input   wire [USER_TAG-1:0]                      usr_tx_wr_tag,
    input   wire [57:0] 							 usr_tx_wr_addr,
    input   wire 						             usr_tx_wr_valid,
    input   wire [511:0]                             usr_tx_data,
    output  wire                                     usr_tx_wr_ready,

    output  wire [USER_TAG-1:0]                      usr_rx_wr_tag,
    output  wire                                     usr_rx_wr_valid
);


///////////////////////////////// Wires Declarations ////////////////////////////
//wire                   update_status;
reg                    poll_again;
reg                    space_available;
reg                    delay_poll_1;
//reg                    update_set;
reg                    update_check;
reg                    update_check_set;
/////////////////////////////////////// Reg Declarations /////////////////////////
reg   [31:0]           numPushedBytes;
reg   [31:0]           otherSideUpdatedBytes;
reg   [31:0]           sizeInNumCL;
reg   [31:0]           sizeInBytes;
reg   [31:0]           usr_wr_count;
reg   [31:0]           poll_count;

reg                    last_state_set;
wire                   issue_last_state;

reg   [57:0]           fifo_buff_addr;
reg   [57:0]           fifo_struct_base;

reg   [2:0]            fifo_fsm_state;
reg   [1:0]            poll_fsm_state;


wire                   all_writes_done;
reg   [31:0]           writes_sent; 
reg   [31:0]           writes_done;          

reg   [31:0]           writtenBytes;
reg   [31:0]           update_status_threashold;
reg                    write_response_pending;
reg   [31:0]           lastUpdatedBytes;
wire  [31:0]           updateBytes;

reg                    updateStatus_fifo_valid;
wire                   updateStatus_fifo_full;
wire                   updateStatus_fifo_re;
reg   [32:0]           updateStatus_fifo_dout;

/////////////////////////////////// Local Parameters /////////////////////////////////////////

localparam [2:0]
		FIFO_IDLE_STATE              = 3'b000,
		FIFO_REQUEST_CONFIG_STATE    = 3'b001,
		FIFO_READ_CONFIG_STATE       = 3'b010,
		FIFO_RUN_STATE               = 3'b011,
		FIFO_PURGE_STATE             = 3'b100,
		FIFO_DONE_STATE              = 3'b101;


localparam [1:0]
		POLL_IDLE_STATE       = 2'b00,
		POLL_REQUEST_STATE    = 2'b01,
		POLL_RESP_STATE       = 2'b10,
		POLL_VALID_STATE      = 2'b11;

/////////////////////////////// FIFO Polling Logic /////////////////////////////////

/////////////////////////////// FIFO Status Logic /////////////////////////////////


always @(posedge clk) begin
	if(~rst_n) begin
		sizeInNumCL       <= 0;
		sizeInBytes       <= 0;
		fifo_buff_addr    <= 0;
		fifo_struct_base  <= 0;
		fifo_fsm_state    <= 0;

		fifo_tx_rd_valid  <= 0;
		fifo_tx_rd_addr   <= 0;
		fifo_tx_rd_tag    <= 0;

		otherSideUpdatedBytes <= 0;
		poll_fsm_state        <= 0;
		poll_count            <= 0;
		fifo_done             <= 1'b0;
		update_status_threashold <= 1024;

		poll_again            <= 1'b0;
		delay_poll_1          <= 1'b0;
	end 
	else begin
		poll_again      <=  (sizeInBytes == (numPushedBytes - otherSideUpdatedBytes)) & ~writes_finished;
		delay_poll_1    <= 1'b0;
		//
		case (fifo_fsm_state)
		    FIFO_IDLE_STATE: begin
		    	if (setup_fifo) begin
		    		fifo_fsm_state     <= FIFO_REQUEST_CONFIG_STATE;
		    		fifo_struct_base   <= fifo_base_addr;
		    	end
		    	fifo_done      <= 1'b0;
		    end
		    FIFO_REQUEST_CONFIG_STATE: begin  // This state enable reading the CRB configuration line
		    	fifo_tx_rd_valid  <= 1'b1;
		    	fifo_tx_rd_addr   <= fifo_struct_base;
		    	fifo_tx_rd_tag    <= {1'b0, 8'b0};

		    	fifo_fsm_state    <= FIFO_READ_CONFIG_STATE;
		    	
		    end
		    FIFO_READ_CONFIG_STATE: begin  // This state enable reading the CRB configuration line
		    	if(fifo_tx_rd_ready) fifo_tx_rd_valid <= 1'b0;

		    	if(fifo_rx_rd_valid) fifo_fsm_state   <= FIFO_RUN_STATE;

		    	fifo_buff_addr           <= fifo_rx_data[63:6];
		    	sizeInNumCL              <= (fifo_rx_data[127:96]  >> 6) - 1;
		    	sizeInBytes              <= fifo_rx_data[127:96];
		    	update_status_threashold <= fifo_rx_data[159:128];
		    end
		    FIFO_RUN_STATE: begin  // This state enable writing user generated to the Buffer

		    	if(writes_finished) begin
		    		fifo_fsm_state     <= FIFO_PURGE_STATE;
		    	end

		    	fifo_tx_rd_tag     <= {1'b0, 8'b0};
		    	fifo_tx_rd_addr    <= fifo_struct_base  + `CRB_STRUCT_CONSUMER_LINE_OFFSET;

		    	case (poll_fsm_state)
		    		POLL_IDLE_STATE: begin
		    			poll_fsm_state     <= POLL_RESP_STATE;
		    			fifo_tx_rd_valid   <= 1'b1;
		    		end
		    		POLL_REQUEST_STATE: begin  // This state enable reading the producer status line
		    			if( poll_count == POLL_CYCLES)  begin
							fifo_tx_rd_valid  <= 1'b1;
							poll_fsm_state    <= POLL_RESP_STATE;
						end 
						poll_count         <= poll_count + 1'b1;
		    		end
		    		POLL_RESP_STATE: begin  
		    			if(fifo_tx_rd_ready) fifo_tx_rd_valid <= 1'b0;

		    			if(fifo_rx_rd_valid) begin
		    				poll_fsm_state        <= POLL_VALID_STATE;
		    				otherSideUpdatedBytes <= fifo_rx_data[63:32];
		    				delay_poll_1          <= 1'b1;
		    			end

		    			poll_count        <= 0;
		    		end
		    		POLL_VALID_STATE: begin
		    			if(poll_again & ~delay_poll_1) begin
		    				poll_fsm_state <= POLL_REQUEST_STATE;
		    			end
		    		end
		    	endcase
		    end
		    FIFO_PURGE_STATE: begin
		    	if( (fifo_tx_wr_ready & fifo_tx_wr_valid) | ~fifo_tx_wr_valid) begin
		    		fifo_fsm_state <= FIFO_DONE_STATE;
		    	end
		    end
		    FIFO_DONE_STATE: begin
		    	if(fifo_tx_wr_ready & last_state_set) begin
		    		fifo_fsm_state <= FIFO_IDLE_STATE;
		    		fifo_done      <= 1'b1;
		    	end
		    end
		endcase
	end
end

assign all_writes_done = writes_sent == writes_done;
/////////////////////////////////////////////////////////////
always@(posedge clk) begin
	if(~rst_n)begin
		writes_sent <= 0;
		writes_done <= 0;
	end
	else begin
		if( fifo_tx_wr_valid & fifo_tx_wr_ready) begin
			writes_sent <= writes_sent + 1'b1;
		end 

		if( fifo_rx_wr_valid ) begin
			writes_done <= writes_done + 1'b1;
		end 
	end 
end 


always@(posedge clk) begin
	if(~rst_n)begin
		writtenBytes <= 0;
	end
	else if(fifo_rx_wr_valid & fifo_rx_wr_tag[USER_TAG+1]) begin
		writtenBytes <= writtenBytes + 64;
	end 
end 

//////////////////////////////////////////////////////////////////////////////////////
///////////////////////////// FIFO Consumer Status Update ////////////////////////////
////////////////////////////// TX WR  Requests Generation ////////////////////////////

//assign update_check = (writtenBytes - lastUpdatedBytes) >= update_status_threashold;
assign updateBytes  = (issue_last_state)? numPushedBytes : lastUpdatedBytes + update_status_threashold;

assign updateStatus_fifo_re = ((fifo_fsm_state == FIFO_RUN_STATE) | (fifo_fsm_state == FIFO_DONE_STATE)) & ~write_response_pending;

always @(posedge clk) begin
	if(~rst_n) begin
		lastUpdatedBytes <= 0;

		update_check     <= 0;
		update_check_set <= 1'b0;
	end 
	else begin 
		update_check     <= (writtenBytes - lastUpdatedBytes) >= update_status_threashold;
		update_check_set <= 1'b0;

		if(((update_check & ~update_check_set) | issue_last_state) & ~updateStatus_fifo_full) begin 
			lastUpdatedBytes <= updateBytes;
			update_check_set <= 1'b1;
		end
	end 
end

/*


*/
always @(posedge clk) begin
	if(~rst_n) begin
		updateStatus_fifo_dout  <= 0;
		updateStatus_fifo_valid <= 1'b0;
	end 
	else begin
		if(updateStatus_fifo_re) begin 
			updateStatus_fifo_valid <= 1'b0;
		end

		if(~updateStatus_fifo_full & ((update_check & ~update_check_set) | issue_last_state)) begin
			updateStatus_fifo_dout  <= {issue_last_state, updateBytes};
			updateStatus_fifo_valid <= 1'b1;
		end 
	end
end

assign updateStatus_fifo_full = updateStatus_fifo_valid;

/*
quick_fifo  #(.FIFO_WIDTH(33),        
            .FIFO_DEPTH_BITS(9),
            .FIFO_ALMOSTFULL_THRESHOLD((2**9) - 8)
            ) updateStatus_fifo(
        .clk                (clk),
        .reset_n            (rst_n),
        .din                ({issue_last_state, updateBytes}),
        .we                 ((update_check & ~update_check_set) | issue_last_state),
        .re                 (updateStatus_fifo_re),
        .dout               (updateStatus_fifo_dout),
        .empty              (),
        .valid              (updateStatus_fifo_valid),
        .full               (updateStatus_fifo_full),
        .count              (),
        .almostfull         ()
    ); 
*/
always @(posedge clk) begin 
	if(~rst_n) begin
		fifo_tx_wr_addr  <= 0;
		fifo_tx_wr_valid <= 0;
		fifo_tx_wr_tag   <= 0;
		fifo_tx_data     <= 0;
		
		write_response_pending <= 0;

		last_state_set   <= 0;
		numPushedBytes   <= 0;
		usr_wr_count     <= 0;

		space_available  <= 0;

	end 
	else begin

		space_available  <= (numPushedBytes - otherSideUpdatedBytes) < sizeInBytes; 

		if(fifo_rx_wr_valid & ~fifo_rx_wr_tag[USER_TAG+1])
			write_response_pending <= 1'b0;
		else if(fifo_tx_wr_ready & fifo_tx_wr_valid & ~fifo_tx_wr_tag[USER_TAG+1])
			write_response_pending <= 1'b1;

		if(fifo_tx_wr_ready) begin 
			if((fifo_fsm_state == FIFO_RUN_STATE) | (fifo_fsm_state == FIFO_DONE_STATE)) begin
				if(updateStatus_fifo_valid & ~write_response_pending) begin
					last_state_set   <= updateStatus_fifo_dout[32];

					fifo_tx_data     <= {415'b0, updateStatus_fifo_dout[32], 32'b0, updateStatus_fifo_dout[31:0], usr_wr_count};
					fifo_tx_wr_addr  <= fifo_struct_base + `CRB_STRUCT_PRODUCER_LINE_OFFSET;
					fifo_tx_wr_tag   <= {2'b00, usr_tx_wr_tag};
					fifo_tx_wr_valid <= 1'b1;
				end
				else begin
					fifo_tx_wr_addr  <= fifo_buff_addr + usr_wr_count;
					fifo_tx_wr_valid <= usr_tx_wr_valid & space_available;
					fifo_tx_wr_tag   <= {2'b10, usr_tx_wr_tag};
					fifo_tx_data     <= usr_tx_data;

					if(usr_tx_wr_valid & space_available) begin
		    			if(usr_wr_count == sizeInNumCL) begin
		    				usr_wr_count <= 0;
		    			end
		    			else begin
		    				usr_wr_count <= usr_wr_count + 1'b1;
		    			end
		    			numPushedBytes   <= numPushedBytes + 64;
		    			space_available  <= (numPushedBytes - otherSideUpdatedBytes) < (sizeInBytes-64); 
		    		end
				end
			end
			else if(fifo_fsm_state == FIFO_IDLE_STATE) begin
				fifo_tx_wr_addr  <= usr_tx_wr_addr;
				fifo_tx_wr_valid <= usr_tx_wr_valid;
				fifo_tx_wr_tag   <= {2'b10, usr_tx_wr_tag};
				fifo_tx_data     <= usr_tx_data;
			end
		end 
	end
end

assign issue_last_state = (fifo_fsm_state == FIFO_DONE_STATE) & ~updateStatus_fifo_full & all_writes_done;


assign usr_tx_wr_ready = (fifo_fsm_state == FIFO_IDLE_STATE)? 
                         fifo_tx_wr_ready: 
                         fifo_tx_wr_ready & space_available & ~(updateStatus_fifo_valid & ~write_response_pending) & (fifo_fsm_state == FIFO_RUN_STATE);

assign usr_rx_wr_valid = fifo_rx_wr_valid & fifo_rx_wr_tag[USER_TAG+1];
assign usr_rx_wr_tag   = fifo_rx_wr_tag[USER_TAG-1:0];


endmodule
