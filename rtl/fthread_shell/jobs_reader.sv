`include "../framework_defines.vh"
`include "../afu_defines.vh"

module jobs_reader(

	input   wire                                     clk,
    input   wire                                     rst_n,
    
    input   wire [31:0]                              job_queue_base_addr[`NUM_JOB_TYPES-1:0], 
    input   wire                                     job_reader_enable, 
    input   wire [31:0]                              job_queue_size,
    input   wire [15:0] 			     queue_poll_rate,
    //---------------------- TX, RX Interfaces ----------------------//
    // TX RD
    output  reg  [31:0]                              jrd_tx_rd_addr,
    output  reg  [`JOB_READER_TAG-1:0]               jrd_tx_rd_tag,
    output  reg  						                         jrd_tx_rd_valid,
    input   wire                                     jrd_tx_rd_ready,
    // TX WR
    output  reg  [31:0]                              jrd_tx_wr_addr,
    output  reg  [`JOB_READER_TAG-1:0]               jrd_tx_wr_tag,
    output  reg 						                         jrd_tx_wr_valid,
    output  reg  [511:0]			                       jrd_tx_data,
    input   wire                                     jrd_tx_wr_ready,
    // RX RD
    input   wire [`JOB_READER_TAG-1:0]               jrd_rx_rd_tag,
    input   wire [511:0]                             jrd_rx_data,
    input   wire                                     jrd_rx_rd_valid,
    // RX WR 
    input   wire                                     jrd_rx_wr_valid,
    input   wire [`JOB_READER_TAG-1:0]               jrd_rx_wr_tag,
    //--------------------------------------------------------------//
    output  wire [511:0] 							 job_queue_out[`NUM_JOB_TYPES-1:0],
    output  wire                                     job_queue_valid[`NUM_JOB_TYPES-1:0], 
    input   wire  									 job_queue_ready[`NUM_JOB_TYPES-1:0]
);

wire   [31:0] 					 jq_tx_rd_addr[`NUM_JOB_TYPES-1:0];
wire   [`JOB_QUEUE_TAG-1:0]      jq_tx_rd_tag[`NUM_JOB_TYPES-1:0];
wire   							 jq_tx_rd_valid[`NUM_JOB_TYPES-1:0];
wire   							 jq_tx_rd_ready[`NUM_JOB_TYPES-1:0];

wire   [31:0] 					 jq_tx_wr_addr[`NUM_JOB_TYPES-1:0];
wire   [`JOB_QUEUE_TAG-1:0]      jq_tx_wr_tag[`NUM_JOB_TYPES-1:0];
wire   							 jq_tx_wr_valid[`NUM_JOB_TYPES-1:0]; 
wire   							 jq_tx_wr_ready[`NUM_JOB_TYPES-1:0]; 
wire   [511:0]                   jq_tx_data[`NUM_JOB_TYPES-1:0];

wire   							 jq_rx_rd_valid[`NUM_JOB_TYPES-1:0];
wire   [511:0]                   jq_rx_data[`NUM_JOB_TYPES-1:0];
wire   [`JOB_QUEUE_TAG-1:0]      jq_rx_rd_tag[`NUM_JOB_TYPES-1:0];

wire   							 jq_rx_wr_valid[`NUM_JOB_TYPES-1:0];
wire   [`JOB_QUEUE_TAG-1:0]      jq_rx_wr_tag[`NUM_JOB_TYPES-1:0];

reg    [1:0]      rd_rr_state;
reg   [1:0]      wr_rr_state;
///////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////                           ///////////////////////////
//////////////////////////////////////////         IO Channels             ////////////////////////
/////////////////////////////////////////////                           ///////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

genvar i;

generate for(i = 0; i < `NUM_JOB_TYPES; i = i + 1) begin: jq_tx_ready
    
    assign jq_tx_rd_ready[i] = jrd_tx_rd_ready & (rd_rr_state == i);
    assign jq_tx_wr_ready[i] = jrd_tx_wr_ready & (wr_rr_state == i);
end 
endgenerate 
//------------------- TX RD -----------------------//
always @(posedge clk) begin
  	if (~rst_n) begin
    	jrd_tx_rd_addr  <= 0;
  		jrd_tx_rd_tag   <= 0;
  		jrd_tx_rd_valid <= 0;

  		rd_rr_state     <= 0;
  	end
  	else if( jrd_tx_rd_ready ) begin
  		jrd_tx_rd_addr  <= jq_tx_rd_addr[rd_rr_state];

      if( `JOB_QUEUE_TAG_USED_RD )
  		  jrd_tx_rd_tag   <= {rd_rr_state, jq_tx_rd_tag[rd_rr_state]};
      else
        jrd_tx_rd_tag   <= {rd_rr_state, {`JOB_QUEUE_TAG{1'b0}}};

  		jrd_tx_rd_valid <= jq_tx_rd_valid[rd_rr_state];

  		rd_rr_state     <= (rd_rr_state == `NUM_JOB_TYPES-1)? 0 : rd_rr_state + 1'b1;
	end 
end

//------------------- TX WR -----------------------//
always @(posedge clk) begin
  	if (~rst_n) begin
    	jrd_tx_wr_addr  <= 0;
  		jrd_tx_wr_tag   <= 0;
  		jrd_tx_wr_valid <= 0;
  		//jrd_tx_data     <= 0;

  		wr_rr_state     <= 0;
  	end
  	else if( jrd_tx_wr_ready ) begin
  		jrd_tx_wr_addr  <= jq_tx_wr_addr[wr_rr_state];

      if( `JOB_QUEUE_TAG_USED_WR )
  		  jrd_tx_wr_tag   <= {wr_rr_state, jq_tx_wr_tag[wr_rr_state]};
      else
        jrd_tx_wr_tag   <= {wr_rr_state, {`JOB_QUEUE_TAG{1'b0}}};
        
  		jrd_tx_wr_valid <= jq_tx_wr_valid[wr_rr_state];
  		jrd_tx_data     <= jq_tx_data[wr_rr_state];

  		wr_rr_state     <= (wr_rr_state == `NUM_JOB_TYPES-1)? 0 : wr_rr_state + 1'b1;
	end 
end


//-------------------- RX RD, WR ----------------------//
generate for(i = 0; i < `NUM_JOB_TYPES; i = i + 1) begin: jq_rx

	// rx rd
	assign jq_rx_rd_tag[i]   = jrd_rx_rd_tag[`JOB_QUEUE_TAG-1:0];
	assign jq_rx_data[i]     = jrd_rx_data;
	assign jq_rx_rd_valid[i] = jrd_rx_rd_valid & (jrd_rx_rd_tag[`JOB_READER_TAG-1:`JOB_READER_TAG-2] == i);

	// rx wr
	assign jq_rx_wr_tag[i]   = jrd_rx_wr_tag[`JOB_QUEUE_TAG-1:0];
	assign jq_rx_wr_valid[i] = jrd_rx_wr_valid & (jrd_rx_wr_tag[`JOB_READER_TAG-1:`JOB_READER_TAG-2] == i);
end 
endgenerate 
///////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////                           ///////////////////////////
//////////////////////////////////////////           Job Queues            ////////////////////////
/////////////////////////////////////////////                           ///////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

generate for(i = 0; i < `NUM_JOB_TYPES; i = i + 1) begin: job_q

	job_queue job_queue_x (
    .clk                              (clk),
    .rst_n                            (rst_n),
    //-------------------------------------------------//
    .queue_poll_rate                  (queue_poll_rate),
    .start_queue                      (job_reader_enable),
    .queue_base_addr                  (job_queue_base_addr[i]),
    .queue_size                       (job_queue_size),
    .queue_reset                      (1'b0),
    // TX RD
    .jq_tx_rd_addr                    (jq_tx_rd_addr[i]),
    .jq_tx_rd_tag                     (jq_tx_rd_tag[i]),
    .jq_tx_rd_valid                   (jq_tx_rd_valid[i]),
    .jq_tx_rd_ready                   (jq_tx_rd_ready[i]),
    // TX WR
    .jq_tx_wr_addr                    (jq_tx_wr_addr[i]),
    .jq_tx_wr_tag                     (jq_tx_wr_tag[i]),
    .jq_tx_wr_valid                   (jq_tx_wr_valid[i]),
    .jq_tx_data                       (jq_tx_data[i]),
    .jq_tx_wr_ready                   (jq_tx_wr_ready[i]),
    // RX RD
    .jq_rx_rd_tag                     (jq_rx_rd_tag[i]),
    .jq_rx_data                       (jq_rx_data[i]),
    .jq_rx_rd_valid                   (jq_rx_rd_valid[i]),
    // RX WR 
    .jq_rx_wr_valid                   (jq_rx_wr_valid[i]),
    .jq_rx_wr_tag                     (jq_rx_wr_tag[i]),
    //
    .job_queue_out                    (job_queue_out[i]),
    .job_queue_valid                  (job_queue_valid[i]),
    .job_queue_ready                  (job_queue_ready[i])
);


end 
endgenerate 





endmodule 
