

`include "../afu_defines.vh"

module fpga_core 
	(
    input   wire                                     clk,
    input   wire                                     rst_n,
    //-------------------------------------------------//
	  input   wire 					                           first_page_addr_valid,
	  input   wire [`PTE_WIDTH-1:0]                    first_page_addr,
    input   wire [57:0]                              ws_virt_base_addr,
    input   wire                                     ws_virt_base_addr_valid,
	//---------- server_io <--> cmd server: RX_RD 
  	input   wire                                     io_rx_csr_valid,
  	input   wire [13:0]                              io_rx_csr_addr,
  	input   wire [31:0]                              io_rx_csr_data,
    // TX RD
    output  reg  [31:0]                              fc_tx_rd_addr,
    output  reg  [`FPGA_CORE_TAG-1:0]                fc_tx_rd_tag,
    output  reg  						             fc_tx_rd_valid,
    input   wire                                     fc_tx_rd_ready,
    // TX WR
    output  reg  [31:0]                              fc_tx_wr_addr,
    output  reg  [`FPGA_CORE_TAG-1:0]                fc_tx_wr_tag,
    output  reg 						             fc_tx_wr_valid,
    output  reg  [511:0]			                 fc_tx_data,
    input   wire                                     fc_tx_wr_ready,
    // RX RD
    input   wire [`FPGA_CORE_TAG-1:0]                fc_rx_rd_tag,
    input   wire [511:0]                             fc_rx_data,
    input   wire                                     fc_rx_rd_valid,
    // RX WR 
    input   wire                                     fc_rx_wr_valid,
    input   wire [`FPGA_CORE_TAG-1:0]                fc_rx_wr_tag,
    // setup pagetable
  	input   wire [1:0]                               pt_status,
  	output  wire                                     pt_update,
	output  wire [31:0]                              pt_base_addr,
    // pt tx_rd, rx_rd
    input   wire [31:0]                              pt_tx_rd_addr,
    input   wire                                     pt_tx_rd_valid,
    input   wire [`PAGETABLE_TAG-1:0]                pt_tx_rd_tag,
    output  wire                                     pt_tx_rd_ready,

    output  reg  [255:0]                             pt_rx_data,
    output  reg  [`PAGETABLE_TAG-1:0]                pt_rx_rd_tag,
    output  reg                                      pt_rx_rd_valid,

    output  reg                                      spl_reset,
    //--------------------------  Jobs to FThreads  ----------------------------------//
    output  wire  [`CMD_LINE_WIDTH-1:0]              fthread_job[`NUMBER_OF_FTHREADS-1:0], 
    output  wire                                     fthread_job_valid[`NUMBER_OF_FTHREADS-1:0], 
    input   wire                                     fthread_done[`NUMBER_OF_FTHREADS-1:0] 
    
);


//---- Terminate Command
wire                                     dsm_reset;

//---- Start Command
wire [31:0]                              job_queue_base_addr[`NUM_JOB_TYPES-1:0]; 
wire                                     job_reader_enable; 
wire [31:0]                              job_queue_size;
wire [15:0]                              queue_poll_rate;

wire [15:0]                              job_config[`NUM_JOB_TYPES-1:0]; 
wire                                     job_config_valid;

wire                                     ctx_status_valid;

// TX RD
wire [31:0]                              jrd_tx_rd_addr;
wire [`JOB_READER_TAG-1:0]               jrd_tx_rd_tag;
wire 						             jrd_tx_rd_valid;
wire                                     jrd_tx_rd_ready;
// TX WR
wire [31:0]                              jrd_tx_wr_addr;
wire [`JOB_READER_TAG-1:0]               jrd_tx_wr_tag;
wire						             jrd_tx_wr_valid;
wire [511:0]			                 jrd_tx_data;
wire                                     jrd_tx_wr_ready;
// RX RD
wire [`JOB_READER_TAG-1:0]               jrd_rx_rd_tag;
wire [511:0]                             jrd_rx_data;
wire                                     jrd_rx_rd_valid;
// RX WR 
wire                                     jrd_rx_wr_valid;
wire [`JOB_READER_TAG-1:0]               jrd_rx_wr_tag;

// TX WR
wire                         			 setup_tx_wr_ready;
wire                         			 setup_tx_wr_valid;
wire [`FPGA_SETUP_TAG-1:0]               setup_tx_wr_tag;
wire [31:0]                 			 setup_tx_wr_addr;
wire [511:0]                			 setup_tx_data;

wire [31:0]                              cp_tx_rd_addr;
wire [`JOB_QUEUE_TAG-1:0]                cp_tx_rd_tag;
wire  						             cp_tx_rd_valid;
wire                                     cp_tx_rd_ready;
    // TX WR
wire [31:0]                              cp_tx_wr_addr;
wire [`JOB_QUEUE_TAG-1:0]                cp_tx_wr_tag;
wire 						             cp_tx_wr_valid;
wire [511:0]			                 cp_tx_data;
wire                                     cp_tx_wr_ready;
// RX RD
wire [`JOB_QUEUE_TAG-1:0]                cp_rx_rd_tag;
wire [511:0]                             cp_rx_data;
wire                                     cp_rx_rd_valid;
// RX WR 
wire                                     cp_rx_wr_valid;
wire [`JOB_QUEUE_TAG-1:0]                cp_rx_wr_tag;

wire                                     spl_reset_t;

wire [15:0]                              fthread_config[`NUMBER_OF_FTHREADS-1:0]; 
wire                                     fthread_config_valid;

reg  [`FPGA_CORE_TAG-1:0]                fc_rx_rd_tag_reg = 0;
reg  [511:0]                             fc_rx_data_reg = 0;
reg                                      fc_rx_rd_valid_reg = 0;
// RX WR 
reg                                      fc_rx_wr_valid_reg = 0;
reg  [`FPGA_CORE_TAG-1:0]                fc_rx_wr_tag_reg = 0;



reg  [31:0]                              tx_rd_addr;
reg  [`FPGA_CORE_USR_TAG-1:0]            tx_rd_tag;
reg                                      tx_rd_valid;
reg                                      tx_rd_ready;

wire [`FPGA_CORE_USR_TAG-1:0]            rx_rd_tag;
wire [511:0]                             rx_data;
wire                                     rx_rd_valid;

reg  [1:0]                               core_fsm_state;
///////////////////////////////////////////////////////////////////////////////////////////////////
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

localparam [1:0]
        CORE_SETUP_STATE   = 2'b00,
        CORE_START_STATE   = 2'b01,
        CORE_RUN_STATE     = 2'b10;
///////////////////////////////////////////////////////////////////////////////////////////////////

always@(posedge clk) begin
  if(~rst_n) begin
    spl_reset <= 0;
  end
  else begin
  	spl_reset <= spl_reset_t;
  end 
end

assign fthread_config_valid = 1'b1;

genvar i;

generate for( i = 0; i < `NUMBER_OF_FTHREADS; i = i + 1) begin: ft_configs
	assign fthread_config[i] = PLACED_AFUS[i];
end 
endgenerate

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////                                             ///////////////////////////
//////////////////////               FPGA Core Ordering Module               //////////////////////
///////////////////////////                                             ///////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
order_module_backpressure #(
               .TAG_WIDTH(`FPGA_CORE_TAG),
               .OUT_TAG_WIDTH(`FPGA_CORE_TAG),
               .ADDR_WIDTH(32),
               .DATA_WIDTH(512),
               .USER_TAG_WIDTH(`FPGA_CORE_USR_TAG)) 
omodule(
    
    .clk                     (clk),
    .rst_n                   (rst_n & ~spl_reset_t),
    //-------------------------------------------------//
    // input requests
    .usr_tx_rd_addr          (tx_rd_addr),
    .usr_tx_rd_tag           (tx_rd_tag),
    .usr_tx_rd_valid         (tx_rd_valid),
    .usr_tx_rd_free          (tx_rd_ready),
    // TX RD
    .ord_tx_rd_addr          (fc_tx_rd_addr),
    .ord_tx_rd_tag           (fc_tx_rd_tag),
    .ord_tx_rd_valid         (fc_tx_rd_valid),
    .ord_tx_rd_free          (fc_tx_rd_ready),
    // RX RD
    .ord_rx_rd_tag           (fc_rx_rd_tag_reg),
    .ord_rx_rd_data          (fc_rx_data_reg),
    .ord_rx_rd_valid         (fc_rx_rd_valid_reg),  
    //
    .usr_rx_rd_tag           (rx_rd_tag),
    .usr_rx_rd_data          (rx_data), 
    .usr_rx_rd_valid         (rx_rd_valid),
    .usr_rx_rd_ready         (1'b1)
);
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////                                             ///////////////////////////
//////////////////////                FPGA Core State Machine                //////////////////////
///////////////////////////                                             ///////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

always@(posedge clk) begin
	if(~rst_n | dsm_reset | spl_reset_t) begin
		core_fsm_state <= 0;

		fc_tx_wr_addr  <= 0;
		fc_tx_wr_tag   <= 0;
		fc_tx_wr_valid <= 0;
		fc_tx_data     <= 0;

		tx_rd_addr     <= 0;
		tx_rd_tag      <= 0;
		tx_rd_valid    <= 0;
	end 
	else begin
		case (core_fsm_state)
			CORE_SETUP_STATE: begin
				if( ctx_status_valid ) begin
					core_fsm_state <= CORE_START_STATE;
				end
				// TX RD
                if( tx_rd_ready ) begin
                    tx_rd_addr  <= pt_tx_rd_addr;
                    tx_rd_tag   <= {3'h4,  {(`FPGA_CORE_USR_TAG-3-`PAGETABLE_TAG){1'b0}}, pt_tx_rd_tag};
                    tx_rd_valid <= pt_tx_rd_valid;
                end
				// TX WR
				if( fc_tx_wr_ready ) begin
					fc_tx_wr_addr  <= setup_tx_wr_addr;
					fc_tx_wr_tag   <= {3'h4, {(`FPGA_CORE_TAG-3-`FPGA_SETUP_TAG){1'b0}}, setup_tx_wr_tag};
					fc_tx_wr_valid <= setup_tx_wr_valid;
					fc_tx_data     <= setup_tx_data;
				end  
			end 
			CORE_START_STATE: begin
				if( job_reader_enable ) begin
					core_fsm_state <= CORE_RUN_STATE;
				end
				// TX RD
				if( tx_rd_ready ) begin
					tx_rd_addr  <= cp_tx_rd_addr;
					tx_rd_tag   <= {3'h1, {(`FPGA_CORE_USR_TAG-3-`JOB_QUEUE_TAG){1'b0}}, cp_tx_rd_tag};
					tx_rd_valid <= cp_tx_rd_valid;
				end
				// TX WR
				if( fc_tx_wr_ready ) begin
					fc_tx_wr_addr  <= cp_tx_wr_addr;
					fc_tx_wr_tag   <= {3'h1, {(`FPGA_CORE_TAG-3-`JOB_QUEUE_TAG){1'b0}}, cp_tx_wr_tag};
					fc_tx_wr_valid <= cp_tx_wr_valid;
					fc_tx_data     <= cp_tx_data;
				end  
			end
			CORE_RUN_STATE: begin
				// TX RD
				if( tx_rd_ready ) begin
					if( cp_tx_rd_valid ) begin
						tx_rd_addr  <= cp_tx_rd_addr;
						tx_rd_tag   <= {3'h1, {(`FPGA_CORE_USR_TAG-3-`JOB_QUEUE_TAG){1'b0}}, cp_tx_rd_tag};
						tx_rd_valid <= 1'b1;
					end 
					else begin 
						tx_rd_addr  <= jrd_tx_rd_addr;
						tx_rd_tag   <= {3'h2, jrd_tx_rd_tag};
						tx_rd_valid <= jrd_tx_rd_valid;
					end 
				end
				// TX WR
				if( fc_tx_wr_ready ) begin
					if( cp_tx_wr_valid ) begin
						fc_tx_wr_addr  <= cp_tx_wr_addr;
						fc_tx_wr_tag   <= {3'h1, {(`FPGA_CORE_TAG-3-`JOB_QUEUE_TAG){1'b0}}, cp_tx_wr_tag};
						fc_tx_wr_valid <= 1'b1;
						fc_tx_data     <= cp_tx_data;
					end 
					else begin 
						fc_tx_wr_addr  <= jrd_tx_wr_addr;
						fc_tx_wr_tag   <= {3'h2, jrd_tx_wr_tag};
						fc_tx_wr_valid <= jrd_tx_wr_valid;
						fc_tx_data     <= jrd_tx_data;
					end
				end
			end   
		endcase 
	end 
end 

assign setup_tx_wr_ready = fc_tx_wr_ready & (core_fsm_state == CORE_SETUP_STATE);

assign cp_tx_wr_ready    = fc_tx_wr_ready & ( (core_fsm_state == CORE_START_STATE) | 
											((core_fsm_state == CORE_RUN_STATE) & cp_tx_wr_valid) );

assign jrd_tx_wr_ready   = fc_tx_wr_ready & ((core_fsm_state == CORE_RUN_STATE) & ~cp_tx_wr_valid);

assign pt_tx_rd_ready    = tx_rd_ready & (core_fsm_state == CORE_SETUP_STATE);

assign cp_tx_rd_ready    = tx_rd_ready & ( (core_fsm_state == CORE_START_STATE) | 
										   ((core_fsm_state == CORE_RUN_STATE) & cp_tx_rd_valid) );

assign jrd_tx_rd_ready   = tx_rd_ready & ((core_fsm_state == CORE_RUN_STATE) & ~cp_tx_rd_valid);

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////                                             ///////////////////////////
//////////////////////                     RX WR, RX RD                      //////////////////////
///////////////////////////                                             ///////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

always@(posedge clk) begin
  if(~rst_n | spl_reset_t) begin
    //fc_rx_data_reg       <= 0;
    fc_rx_rd_tag_reg     <= 0;
    fc_rx_rd_valid_reg   <= 0;
    
    fc_rx_wr_tag_reg     <= 0;
    fc_rx_wr_valid_reg   <= 0;
  end
  else begin
    fc_rx_data_reg       <= fc_rx_data;
    fc_rx_rd_tag_reg     <= fc_rx_rd_tag;
    fc_rx_rd_valid_reg   <= fc_rx_rd_valid;
    
    fc_rx_wr_tag_reg     <= fc_rx_wr_tag;
    fc_rx_wr_valid_reg   <= fc_rx_wr_valid;
    //
    pt_rx_data           <= rx_data[255:0];
    pt_rx_rd_tag         <= rx_rd_tag[`PAGETABLE_TAG-1:0];
    pt_rx_rd_valid       <= rx_rd_valid & rx_rd_tag[`FPGA_CORE_USR_TAG-1];

  end 
end

assign cp_rx_data      = rx_data;
assign cp_rx_rd_tag    = rx_rd_tag[`JOB_QUEUE_TAG-1:0];
assign cp_rx_rd_valid  = rx_rd_valid & rx_rd_tag[`FPGA_CORE_USR_TAG-3];

assign cp_rx_wr_valid  = fc_rx_wr_valid_reg & fc_rx_wr_tag_reg[`FPGA_CORE_USR_TAG-3];
assign cp_rx_wr_tag    = fc_rx_wr_tag_reg[`JOB_QUEUE_TAG-1:0];

assign jrd_rx_data     = rx_data;
assign jrd_rx_rd_tag   = rx_rd_tag[`JOB_READER_TAG-1:0];
assign jrd_rx_rd_valid = rx_rd_valid & rx_rd_tag[`FPGA_CORE_USR_TAG-2];

assign jrd_rx_wr_valid = fc_rx_wr_valid_reg & fc_rx_wr_tag_reg[`FPGA_CORE_USR_TAG-2];
assign jrd_rx_wr_tag   = fc_rx_wr_tag_reg[`JOB_READER_TAG-1:0];

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////                                             ///////////////////////////
//////////////////////         FPGA Setup Module (Platform Dependent)        //////////////////////
///////////////////////////                                             ///////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

fpga_setup fpga_setup(
	.clk                        (clk),
    .rst_n 						(rst_n & ~dsm_reset & ~spl_reset_t),

  	.ctx_status_valid 			(ctx_status_valid),
  
  	// server_io <--> cmd server: RX_RD
  	.io_rx_csr_valid 			(io_rx_csr_valid),
  	.io_rx_csr_addr 			(io_rx_csr_addr),
  	.io_rx_csr_data 			(io_rx_csr_data),

  	// TX WR
  	.setup_tx_wr_ready 			(setup_tx_wr_ready),
  	.setup_tx_wr_valid 			(setup_tx_wr_valid),
  	.setup_tx_wr_tag 			(setup_tx_wr_tag),
  	.setup_tx_wr_addr 			(setup_tx_wr_addr),
  	.setup_tx_data 				(setup_tx_data),
  
  	// setup pagetable
  	.pt_status 					(pt_status),
  	.pt_update 					(pt_update),
  	.pt_base_addr 				(pt_base_addr), 

  	.spl_reset_t 				(spl_reset_t)
);

///////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////                         /////////////////////////////////////
////////////////////////////////       CMD Processor Module        ////////////////////////////////
/////////////////////////////////////                         /////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

cmd_processor cmd_processor
(
    .clk                        (clk),
    .rst_n 						(rst_n & ~spl_reset_t),
    //-------------------------------------------------//
	.first_page_addr_valid 		(first_page_addr_valid),
	.first_page_addr 			(first_page_addr),
	.ctx_valid 					(ctx_status_valid),
    // TX RD
    .cp_tx_rd_addr 				(cp_tx_rd_addr),
    .cp_tx_rd_tag 				(cp_tx_rd_tag),
    .cp_tx_rd_valid 			(cp_tx_rd_valid),
    .cp_tx_rd_ready 			(cp_tx_rd_ready),
    // TX WR
    .cp_tx_wr_addr 				(cp_tx_wr_addr),
    .cp_tx_wr_tag 				(cp_tx_wr_tag),
    .cp_tx_wr_valid 			(cp_tx_wr_valid),
    .cp_tx_data 				(cp_tx_data),
    .cp_tx_wr_ready 			(cp_tx_wr_ready),
    // RX RD
    .cp_rx_rd_tag 				(cp_rx_rd_tag),
    .cp_rx_data 				(cp_rx_data),
    .cp_rx_rd_valid 			(cp_rx_rd_valid),
    // RX WR 
    .cp_rx_wr_valid 			(cp_rx_wr_valid),
    .cp_rx_wr_tag 				(cp_rx_wr_tag),
    //---- Terminate Command
	.dsm_reset 					(dsm_reset),

    //---- Start Command
    .job_queue_base_addr 		(job_queue_base_addr), 
    .job_reader_enable 			(job_reader_enable), 
    .job_queue_size 			(job_queue_size),
    .queue_poll_rate                    (queue_poll_rate),
    .job_config 				(job_config), 
    .job_config_valid 			(job_config_valid) 
    
);

///////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////                         /////////////////////////////////////
////////////////////////////////        Job Manager Module         ////////////////////////////////
/////////////////////////////////////                         /////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

job_manager job_manager
(
	.clk                        (clk),
    .rst_n 						(rst_n & ~dsm_reset & ~spl_reset_t),
    
    .job_queue_base_addr 		(job_queue_base_addr), 
    .job_reader_enable 			(job_reader_enable), 
    .job_queue_size 			  (job_queue_size),
    .queue_poll_rate                    (queue_poll_rate),
    .ws_virt_base_addr      (ws_virt_base_addr),
    .ws_virt_base_addr_valid(ws_virt_base_addr_valid),
    //----------------- TX, RX Interfaces --------------------//
    // TX RD
    .jrd_tx_rd_addr 			(jrd_tx_rd_addr),
    .jrd_tx_rd_tag 				(jrd_tx_rd_tag),
    .jrd_tx_rd_valid 			(jrd_tx_rd_valid),
    .jrd_tx_rd_ready 			(jrd_tx_rd_ready),
    // TX WR
    .jrd_tx_wr_addr 			(jrd_tx_wr_addr),
    .jrd_tx_wr_tag 				(jrd_tx_wr_tag),
    .jrd_tx_wr_valid 			(jrd_tx_wr_valid),
    .jrd_tx_data 				(jrd_tx_data),
    .jrd_tx_wr_ready 			(jrd_tx_wr_ready),
    // RX RD
    .jrd_rx_rd_tag 				(jrd_rx_rd_tag),
    .jrd_rx_data 			    (jrd_rx_data),
    .jrd_rx_rd_valid 			(jrd_rx_rd_valid),
    // RX WR 
    .jrd_rx_wr_valid 			(jrd_rx_wr_valid),
    .jrd_rx_wr_tag 				(jrd_rx_wr_tag),
    //---------------- Configuration Matrix ------------------//
    .fthread_config 			(fthread_config), 
    .fthread_config_valid 		(fthread_config_valid), 

    .job_config 				(job_config), 
    .job_config_valid 			(job_config_valid), 

    //------------------  Jobs to FThreads  ------------------//
    .fthread_job 				(fthread_job), 
    .fthread_job_valid 			(fthread_job_valid), 
    .fthread_done 				(fthread_done)
);











endmodule 
