
`include "../afu_defines.vh"

module cmd_interpreter (
	input   wire                                     clk,
	input   wire                                     rst_n,
    //////////////////////////////// Commands /////////////////////////////////////
    //---- Terminate Command
	output  reg                                      dsm_reset,
    input   wire [`PTE_WIDTH-1:0]                 first_page_address,

    //---- Start Command
    output  reg  [31:0]                              job_queue_base_addr[`NUM_JOB_TYPES-1:0], 
    output  reg                                      job_reader_enable, 
    output  reg  [31:0]                              job_queue_size,
    output  reg  [15:0]                              queue_poll_rate,
    output  reg  [15:0]                              job_config[`NUM_JOB_TYPES-1:0], 
    output  reg                                      job_config_valid, 
 
    //////////////// From Command Queue /////////////////////////
    input   wire  [511:0]                            cmd_queue_out,
    input   wire                                     cmd_queue_valid,
    output  wire                                     cmd_queue_ready           
);

///////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////                           ////////////////////////////////////
/////////////////////////////////          CMD Decoder            /////////////////////////////////
////////////////////////////////////                           ////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

assign cmd_queue_ready = 1'b1;

//
always @(posedge clk) begin
    if( ~rst_n | dsm_reset ) begin
        dsm_reset         <= 1'b0;
        job_reader_enable <= 1'b0;
        job_config_valid  <= 1'b0;
        job_queue_size    <= 0;
        queue_poll_rate   <= 0;
    end
    else if(cmd_queue_valid) begin
        case(cmd_queue_out[15:0])
            `FPGA_TERMINATE_CMD:   begin 
                dsm_reset     <= 1'b1;
            end
            `START_JOB_MANAGER_CMD:   begin 
                job_reader_enable <= 1'b1;
                job_config_valid  <= 1'b1;
                job_queue_size    <= cmd_queue_out[127:96];
                queue_poll_rate   <= cmd_queue_out[31:16];
            end
		endcase 
	end 
    else begin 
        dsm_reset         <= 1'b0;
        job_reader_enable <= 1'b0;
        job_config_valid  <= 1'b0;
        job_queue_size    <= 0;
        queue_poll_rate   <= 0;
    end 
end 

genvar j;
generate for( j = 0; j < `NUM_JOB_TYPES; j = j + 1) begin: job_data

always @(posedge clk) begin
    if( ~rst_n | dsm_reset ) begin
        job_queue_base_addr[j] <= 0;
        job_config[j]          <= 0; 
    end
    else if(cmd_queue_valid & (cmd_queue_out[15:0] == `START_JOB_MANAGER_CMD)) begin
	    job_queue_base_addr[j] <= {first_page_address,  cmd_queue_out[(32-`PTE_WIDTH-1) + j*96 + 32 : j*96 + 32]};
        job_config[j]          <= cmd_queue_out[63 + j*96 + 32 : j*96 + 32 + 32]; 
	end 
end 

end
endgenerate

///////

endmodule
