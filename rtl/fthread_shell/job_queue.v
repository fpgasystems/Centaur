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


module job_queue #(parameter POLL_CYCLES = 32) 
	(
    input   wire                                     clk,
    input   wire                                     rst_n,
    //-------------------------------------------------//
	input   wire 					                 start_queue,
	input   wire [31:0]                              queue_base_addr,
	input   wire [31:0]                              queue_size, // in CLs
        input   wire [15:0]                              queue_poll_rate,
	input   wire                                     queue_reset,
    // TX RD
    output  reg  [31:0]                              jq_tx_rd_addr,
    output  reg  [`JOB_QUEUE_TAG-1:0]                jq_tx_rd_tag,
    output  reg  						             jq_tx_rd_valid,
    input   wire                                     jq_tx_rd_ready,
    // TX WR
    output  reg  [31:0]                              jq_tx_wr_addr,
    output  reg  [`JOB_QUEUE_TAG-1:0]                jq_tx_wr_tag,
    output  reg 						             jq_tx_wr_valid,
    output  reg  [511:0]			                 jq_tx_data,
    input   wire                                     jq_tx_wr_ready,
    // RX RD
    input   wire [`JOB_QUEUE_TAG-1:0]                jq_rx_rd_tag,
    input   wire [511:0]                             jq_rx_data,
    input   wire                                     jq_rx_rd_valid,
    // RX WR 
    input   wire                                     jq_rx_wr_valid,
    input   wire [`JOB_QUEUE_TAG-1:0]                jq_rx_wr_tag,
    ///////////////////////// User Logic Interface ////////////////////
    output  reg  [511:0]                             job_queue_out,
    output  reg  						             job_queue_valid,
    input   wire                                     job_queue_ready
);

///////////////////////////////// Wires Declarations ////////////////////////////

wire                   update_status;
wire  [15:0]           rd_cnt_inc;
/////////////////////////////////////// Reg Declarations /////////////////////////
reg   [31:0]           numPulledJobs;
reg   [31:0]           numAvailableJobs;
reg   [15:0]           queue_buffer_size;
reg   [15:0]           rd_cnt;

reg   [15:0]           prog_poll_cycles;
reg   [15:0]           poll_count;

reg   [31:0]           queue_struct_base;
reg   [31:0]           queue_buffer_base;

reg   [2:0]            jq_fsm_state;

reg  				   last_req_d1;

reg   [5:0]            rx_rd_tag;
reg   [511:0]          rx_rd_data;
reg                    rx_rd_valid;
reg                    rx_wr_valid;
reg   [7:0]            rx_wr_tag;

reg                    write_response_pending;
reg   [31:0]           lastUpdatedJobs;

reg                    jq_producer_valid;

/////////////////////////////////// Local Parameters /////////////////////////////////////////
localparam [2:0]
		CMQ_IDLE_STATE           = 3'b000,

		CMQ_READ_CMD_STATE       = 3'b001,
		CMQ_RECEIVE_STATE        = 3'b010,
		CMQ_PROCESS_STATE        = 3'b011,

		CMQ_CHECK_STATE          = 3'b100,
		CMQ_POLL_STATE           = 3'b101,
		CMQ_POLL_RESP_STATE      = 3'b110;

/////////// buffer response
always@(posedge clk) begin
	if(~rst_n | queue_reset) begin
		rx_rd_tag     <= 0;
    	//rx_rd_data 	  <= 0;
    	rx_rd_valid   <= 0;
        // RX WR 
   	    rx_wr_valid   <= 0;
    	rx_wr_tag     <= 0;
	end
	else begin
		rx_rd_tag     <= jq_rx_rd_tag;
    	rx_rd_data 	  <= jq_rx_data;
    	rx_rd_valid   <= jq_rx_rd_valid;
        // RX WR 
   	    rx_wr_valid   <= jq_rx_wr_valid;
    	rx_wr_tag     <= jq_rx_wr_tag;
	end 
end 

/////////////////////////////// CRB Status Logic /////////////////////////////////
always @(posedge clk) begin
	if(~rst_n | queue_reset) begin
		numPulledJobs     <= 0;
		numAvailableJobs  <= 0;

		queue_struct_base <= 0;
		queue_buffer_base <= 0;
		queue_buffer_size <= 0;

		jq_fsm_state      <= CMQ_IDLE_STATE;
		poll_count        <= 0;
                prog_poll_cycles  <= 0;

		jq_tx_rd_addr     <= 0;
		jq_tx_rd_valid    <= 0;
		jq_tx_rd_tag      <= 0;
		last_req_d1       <= 0;

		jq_producer_valid <= 0;

		job_queue_valid   <= 0;
		job_queue_out     <= 0;

		rd_cnt            <= 0;
	end 
	else begin
		case (jq_fsm_state)
		    CMQ_IDLE_STATE: begin
		    	jq_fsm_state      <= (start_queue)? CMQ_POLL_STATE : CMQ_IDLE_STATE;
		    	queue_struct_base <= queue_base_addr;
 				queue_buffer_base <= queue_base_addr + queue_size[3:0];
 				queue_buffer_size <= queue_size[31:16];
		    	rd_cnt            <= 0;
                        prog_poll_cycles  <= queue_poll_rate;
		    end
		    /////////////////////// Read Commands from the Queue States ////////////////////////////
		    CMQ_READ_CMD_STATE: begin   
		    	jq_fsm_state      <=  CMQ_RECEIVE_STATE;
		    	rd_cnt            <= (rd_cnt_inc == queue_buffer_size)? 0 : rd_cnt_inc;
            	jq_tx_rd_valid    <= 1'b1;
        		jq_tx_rd_addr     <= {1'b0,  queue_buffer_base} + {1'b0, rd_cnt};
            	jq_tx_rd_tag      <= 'h2;
				numAvailableJobs  <= numAvailableJobs - 1;
				last_req_d1       <= (numAvailableJobs == 1);     
		    end

		    CMQ_RECEIVE_STATE: begin  
		    	if( jq_tx_rd_ready ) jq_tx_rd_valid <= 1'b0;

		    	jq_fsm_state      <= (rx_rd_valid)? CMQ_PROCESS_STATE : CMQ_RECEIVE_STATE;
		    	numPulledJobs     <= (rx_rd_valid)? numPulledJobs + 1'b1 : numPulledJobs;

		    	job_queue_out     <= rx_rd_data;
		        job_queue_valid   <= (rx_rd_valid)? 1'b1 : 1'b0;
		    end
		    CMQ_PROCESS_STATE: begin  
		    	jq_fsm_state      <= (~job_queue_ready)? CMQ_PROCESS_STATE : 
		    	                     (last_req_d1)?  CMQ_POLL_STATE : CMQ_READ_CMD_STATE;
		    	job_queue_valid   <= (~job_queue_ready)? 1'b1 : 1'b0;
		    end
		    /////////////////////////// Poll On CMD Queue Producer and Check Validity //////////////////////
		    CMQ_CHECK_STATE: begin
		    	jq_fsm_state <= ((numAvailableJobs != 0) & jq_producer_valid)? CMQ_READ_CMD_STATE : CMQ_POLL_STATE;
		    end
		    CMQ_POLL_STATE: begin  

		    	if( poll_count == prog_poll_cycles)  begin
					jq_tx_rd_addr  <= queue_struct_base + `CRB_STRUCT_PRODUCER_LINE_OFFSET;
					jq_tx_rd_valid <= 1'b1;
					jq_tx_rd_tag   <= 'h1;

					jq_fsm_state   <= CMQ_POLL_RESP_STATE;
				end 
				poll_count         <= poll_count + 1'b1;
			end
			CMQ_POLL_RESP_STATE: begin
				if( jq_tx_rd_ready ) jq_tx_rd_valid <= 1'b0;

				poll_count         <= 0;

		    	jq_fsm_state       <= (rx_rd_valid)? CMQ_CHECK_STATE : CMQ_POLL_RESP_STATE;
		    	numAvailableJobs   <= (rx_rd_valid)? ((rx_rd_data[63:32] >> 6) - numPulledJobs) : numAvailableJobs;
				jq_producer_valid  <= (rx_rd_valid)? (rx_rd_data[95:64] == `CMQ_PROD_VALID_MAGIC_NUMBER) : 0;
		    end
		endcase
	end
end

assign rd_cnt_inc = rd_cnt + 1'b1;

//////////////////////////////////////////////////////////////////////////////////////
////////////////////////////// CRB Consumer Status Update ////////////////////////////
////////////////////////////// TX WR  Requests Generation ////////////////////////////

always @(posedge clk) begin 
	if(~rst_n | queue_reset) begin
		//jq_tx_data             <= 0;
		jq_tx_wr_addr          <= 0;
		jq_tx_wr_valid         <= 0;
		jq_tx_wr_tag           <= 0;

		lastUpdatedJobs        <= 0;

		write_response_pending <= 0;
	end 
	else begin
		write_response_pending <= (write_response_pending)? ~rx_wr_valid : (jq_tx_wr_ready & jq_tx_wr_valid);

		if(jq_tx_wr_ready | ~jq_tx_wr_valid) begin
			if( update_status ) begin
				lastUpdatedJobs <= numPulledJobs;
				jq_tx_data      <= {448'b0, numPulledJobs << 6, numPulledJobs};
				jq_tx_wr_addr   <= queue_struct_base + `CRB_STRUCT_CONSUMER_LINE_OFFSET;
				jq_tx_wr_tag    <= 0;
				jq_tx_wr_valid  <= 1'b1;
			end
			else begin
				jq_tx_wr_valid <= 0;
			end
		end
	end
end

assign update_status   = ((numPulledJobs - lastUpdatedJobs) > 0) & ~write_response_pending;


endmodule
