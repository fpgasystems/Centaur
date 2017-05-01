
`include "../framework_defines.vh"
`include "../afu_defines.vh"

module job_manager(

	input   wire                                     clk,
    input   wire                                     rst_n,
    
    input   wire [31:0]                              job_queue_base_addr[`NUM_JOB_TYPES-1:0], 
    input   wire                                     job_reader_enable, 
    input   wire [31:0]                              job_queue_size,
    input   wire [57:0]                              ws_virt_base_addr,
    input   wire [15:0]                              queue_poll_rate,
    input   wire                                     ws_virt_base_addr_valid,
    //--------------------------------- TX, RX Interfaces ---------------------------------------//
    // TX RD
    output  wire [31:0]                              jrd_tx_rd_addr,
    output  wire [`JOB_READER_TAG-1:0]               jrd_tx_rd_tag,
    output  wire 						             jrd_tx_rd_valid,
    input   wire                                     jrd_tx_rd_ready,
    // TX WR
    output  wire [31:0]                              jrd_tx_wr_addr,
    output  wire [`JOB_READER_TAG-1:0]               jrd_tx_wr_tag,
    output  wire						             jrd_tx_wr_valid,
    output  wire [511:0]			                 jrd_tx_data,
    input   wire                                     jrd_tx_wr_ready,
    // RX RD
    input   wire [`JOB_READER_TAG-1:0]               jrd_rx_rd_tag,
    input   wire [511:0]                             jrd_rx_data,
    input   wire                                     jrd_rx_rd_valid,
    // RX WR 
    input   wire                                     jrd_rx_wr_valid,
    input   wire [`JOB_READER_TAG-1:0]               jrd_rx_wr_tag,
    //-------------------------------- Configuration Matrix -------------------------------------//
    input   wire [15:0]                              fthread_config[`NUMBER_OF_FTHREADS-1:0], 
    input   wire                                     fthread_config_valid, 

    input   wire [15:0]                              job_config[`NUM_JOB_TYPES-1:0], 
    input   wire                                     job_config_valid, 

    //-----------------------------------  Jobs to FThreads  ------------------------------------//
    output  wire  [`CMD_LINE_WIDTH-1:0]              fthread_job[`NUMBER_OF_FTHREADS-1:0], 
    output  wire                                     fthread_job_valid[`NUMBER_OF_FTHREADS-1:0], 
    input   wire                                     fthread_done[`NUMBER_OF_FTHREADS-1:0]
);



wire [511:0] 							 job_queue_out[`NUM_JOB_TYPES-1:0];
wire                                     job_queue_valid[`NUM_JOB_TYPES-1:0]; 
wire  									 job_queue_ready[`NUM_JOB_TYPES-1:0];



jobs_reader jobs_reader(

	.clk                        (clk),
    .rst_n 						(rst_n),
    
    .job_queue_base_addr 		(job_queue_base_addr), 
    .job_reader_enable 			(job_reader_enable), 
    .job_queue_size 			(job_queue_size),
    .queue_poll_rate                    (queue_poll_rate),
    //---------------------- TX, RX Interfaces ----------------------//
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
    //--------------------------------------------------------------//
    .job_queue_out 				(job_queue_out),
    .job_queue_valid 			(job_queue_valid), 
    .job_queue_ready 			(job_queue_ready)
);


job_distributor job_distributor
    (
	.clk                        (clk),
    .rst_n 						(rst_n),
    .ws_virt_base_addr          (ws_virt_base_addr),
    .ws_virt_base_addr_valid    (ws_virt_base_addr_valid),
	//-------- Standing Job Requests ------//
    .job_queue_out 				(job_queue_out),
    .job_queue_valid 			(job_queue_valid), 
    .job_queue_ready 			(job_queue_ready),
    //--------- Configuration Matrix ------//
    .fthread_config             (fthread_config), 
    .fthread_config_valid       (fthread_config_valid), 

    .job_config 				(job_config), 
    .job_config_valid 			(job_config_valid), 

    //---------  Jobs to FThreads  --------//
    .fthread_job 				(fthread_job), 
    .fthread_job_valid 			(fthread_job_valid), 
    .fthread_done 				(fthread_done)
	);


endmodule 
