
`include "../afu_defines.vh"

module job_distributor 
    (
	input                                          clk,
	input                                          rst_n,

	//-------- Standing Job Requests ------//
    input   wire                                   job_queue_valid[`NUM_JOB_TYPES-1:0],
    input   wire [511:0]                           job_queue_out[`NUM_JOB_TYPES-1:-0],
    output  wire                                   job_queue_ready[`NUM_JOB_TYPES-1:0],

    input   wire [57:0]                              ws_virt_base_addr,
    input   wire                                     ws_virt_base_addr_valid,
    //--------- Configuration Matrix ------//
    input   wire [15:0]                            fthread_config[`NUMBER_OF_FTHREADS-1:0], 
    input   wire                                   fthread_config_valid, 

    input   wire [15:0]                            job_config[`NUM_JOB_TYPES-1:0], 
    input   wire                                   job_config_valid, 

    //---------  Jobs to FThreads  --------//
    output  reg   [`CMD_LINE_WIDTH-1:0]            fthread_job[`NUMBER_OF_FTHREADS-1:0], 
    output  reg                                    fthread_job_valid[`NUMBER_OF_FTHREADS-1:0], 
    input   wire                                   fthread_done[`NUMBER_OF_FTHREADS-1:0]
	);


parameter JOB_TY_WIDTH = (`NUM_JOB_TYPES == 1)? 1 : `JOB_TYPE_BITS;

///////////////////////////////////////////////////////////////////////////////////////////////////
reg  [0:`NUMBER_OF_FTHREADS-1]             mapping_matrix[`NUM_JOB_TYPES-1:0];

reg  [15:0]                                fthread_opcode[`NUMBER_OF_FTHREADS-1:0];
reg                                        fthread_opcode_valid;

reg  [15:0]                                job_opcode[`NUM_JOB_TYPES-1:0];
reg                                        job_opcode_valid;

reg  [1:0]                                 distributer_fsm;
reg                                        job_request_valid;
reg                                        job_request_valid_d1;
reg  [511:0]                               job_request;
reg  [JOB_TY_WIDTH-1:0]                    current_job_type;
reg  [JOB_TY_WIDTH-1:0]                    job_index;
reg  [`NUM_JOB_TYPES-1:0]                  current_job_type_vec;
wire [511:0]                               current_job;
wire                                       current_job_type_valid;

wire [0:`NUMBER_OF_FTHREADS-1]             valid_fthread_mapping;
wire [0:`NUMBER_OF_FTHREADS-1]             fthread_select;
reg  [0:`NUMBER_OF_FTHREADS-1]             fthread_select_d1;

wire [0:`NUMBER_OF_FTHREADS-1]             src_job_fthread_mapping;
wire [0:`NUMBER_OF_FTHREADS-1]             dst_job_fthread_mapping;
wire                                       find_pipeline_schedule;

wire [0:`NUMBER_OF_FTHREADS-1]             src_fthread_select;
wire [0:`NUMBER_OF_FTHREADS-1]             dst_fthread_select;
wire                                       pipeline_schedule_valid;
wire                                       dst_fthread_reserve;
reg  [0:`NUMBER_OF_FTHREADS-1]             reserve_fthreads;

reg  [0:`NUMBER_OF_FTHREADS-1]             fthread_job_set;
wire [0:`NUMBER_OF_FTHREADS-1]             is_fthread_select_dst;


reg  [0:`NUMBER_OF_FTHREADS-1]             fthreads_state;
reg  [0:`NUMBER_OF_FTHREADS-1]             fthreads_reserved;

wire [`CMD_LINE_WIDTH-1:0]                 job_line;
wire [`CMD_LINE_WIDTH-1:0]                 src_job_line;
wire [`CMD_LINE_WIDTH-1:0]                 dst_job_line;

wire                                       schedule_decision_made;
wire                                       schedule_success;
wire                                       direct_pipeline_schedule;

reg  [57:0]                                ws_base_addr;
reg  [57:0]                                job1_rd_mem_fifo_addr;
reg  [57:0]                                job1_wr_mem_fifo_addr;
reg  [57:0]                                job2_rd_mem_fifo_addr;
reg  [57:0]                                job2_wr_mem_fifo_addr;

localparam [1:0]
    DIST_READY_STATE     = 2'b00,
    DIST_SCHEDULE_STATE  = 2'b01,
    DIST_SUCCESS_STATE   = 2'b10,
    DIST_FAIL_STATE      = 2'b11;

integer j, i;
genvar n, k;

///////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////                          ////////////////////////////////////
///////////////////////////////         Configuration Matrix         //////////////////////////////
/////////////////////////////////////                          ////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
// The Configuration matrix is filled once upon the setup of the FPGA core. However, in case PR is 
// supported the configuration matrix will change on every PR process.
//----------------------------- FThreads Opcodes configuration ----------------------------------//
always@(posedge clk) begin 
    if(~rst_n) begin 
        for(j = 0; j < `NUMBER_OF_FTHREADS; j = j + 1) begin
            fthread_opcode[j] <= 0;
        end 
        fthread_opcode_valid  <= 1'b0;
    end 
    else if(fthread_config_valid) begin 
        for(j = 0; j < `NUMBER_OF_FTHREADS; j = j + 1) begin
            fthread_opcode[j] <= fthread_config[j];
        end
        fthread_opcode_valid  <= 1'b1;
    end 
end 

//------------------------------- Jobs Opcodes configuration ------------------------------------//
always@(posedge clk) begin 
    if(~rst_n) begin 
        for(j = 0; j < `NUM_JOB_TYPES; j = j + 1) begin
            job_opcode[j] <= 0;
        end 
        job_opcode_valid  <= 1'b0;
    end 
    else if(job_config_valid) begin 
        for(j = 0; j < `NUM_JOB_TYPES; j = j + 1) begin
            job_opcode[j] <= job_config[j];
        end 
        job_opcode_valid  <= 1'b1;
    end 
end

//-------------------------------- Job/Fthread Mapping Matrix -----------------------------------//
always@(posedge clk) begin 
    if(~rst_n) begin 
        for(j = 0; j < `NUM_JOB_TYPES; j = j + 1) begin
            mapping_matrix[j] <= 0;
        end 
    end 
    else if(job_opcode_valid & fthread_opcode_valid) begin 
        for(j = 0; j < `NUM_JOB_TYPES; j = j + 1) begin
            for(i = 0; i < `NUMBER_OF_FTHREADS; i = i + 1) begin
                mapping_matrix[j][i] <= fthread_opcode[i] == job_opcode[j];
            end 
        end 
    end 
end

//----------------------------------------------------------------------------------------------//
always@(posedge clk) begin
    if(~rst_n) begin
        ws_base_addr <= 0;
    end
    else if(ws_virt_base_addr_valid) begin
        ws_base_addr <= ws_virt_base_addr;
    end
end
///////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////                          ////////////////////////////////////
///////////////////////////////            Distributor FSM           //////////////////////////////
/////////////////////////////////////                          ////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

//-------------- Select Job queue to process -------------------------//
assign current_job_type_valid = job_queue_valid[current_job_type];
assign current_job            = job_queue_out[current_job_type];


//--------------------- Scheduling State -----------------------------//
always @(posedge clk) begin
    if (~rst_n) begin
        // reset
        current_job_type_vec <= 0;
        current_job_type     <= 0;
        job_index            <= 0;
        distributer_fsm      <= DIST_READY_STATE;
        job_request          <= 0;
        job_request_valid    <= 0;
        job_request_valid_d1 <= 0;
    end
    else begin
        case(distributer_fsm)
            DIST_READY_STATE: begin
                job_index <= current_job_type;

                for(i = 0; i < `NUM_JOB_TYPES; i = i + 1) begin
                    current_job_type_vec[i] <= (i == current_job_type);
                end

                if( current_job_type_valid ) begin
                    distributer_fsm   <= DIST_SCHEDULE_STATE;
                    job_request       <= current_job;
                    job_request_valid <= 1'b1;
                end

                if(current_job_type == `NUM_JOB_TYPES-1)
                    current_job_type <= 0;
                else 
                    current_job_type <= current_job_type + 1'b1;
            end
            DIST_SCHEDULE_STATE: begin
                job_request_valid_d1 <= job_request_valid;
                job_request_valid    <= 1'b0;

                if(schedule_decision_made) begin 
                    if(schedule_success) begin
                        distributer_fsm <= DIST_SUCCESS_STATE;
                    end
                    else begin
                        distributer_fsm <= DIST_FAIL_STATE;
                    end
                end
            end
            DIST_SUCCESS_STATE: begin
                distributer_fsm <= DIST_READY_STATE;
            end
            DIST_FAIL_STATE: begin // do we need to pend the current pipeline job
                distributer_fsm <= DIST_READY_STATE;
            end
        endcase
    end
end

always@(posedge clk) begin
    if(~rst_n) begin
        job1_rd_mem_fifo_addr <= 0;
        job1_wr_mem_fifo_addr <= 0;

        job2_rd_mem_fifo_addr <= 0;
        job2_wr_mem_fifo_addr <= 0;
    end 
    else begin
        job1_rd_mem_fifo_addr <= ws_base_addr + job_request[255:224];
        job1_wr_mem_fifo_addr <= ws_base_addr + job_request[223:192];

        job2_rd_mem_fifo_addr <= ws_base_addr + job_request[479:448];
        job2_wr_mem_fifo_addr <= ws_base_addr + job_request[447:416];
    end
end

assign src_job_line = {job_request[15:8], job1_rd_mem_fifo_addr, job_request[7:6], job1_wr_mem_fifo_addr, 
                       job_request[5:4], job_request[163:160], job_request[159:102], job_request[95:38]};

assign dst_job_line = {job_request[27:20], job2_rd_mem_fifo_addr, job_request[19:18], job2_wr_mem_fifo_addr, 
                       job_request[17:16], job_request[387:384], job_request[383:326], job_request[319:262]};

assign job_line     = {job_request[15:8], job1_rd_mem_fifo_addr, job_request[7:6], job1_wr_mem_fifo_addr, 
                       job_request[5:4], job_request[163:160], job_request[159:102], job_request[95:38]};

//------------------- Respond to the Job queue you processed ----------------//
generate for(n = 0; n < `NUM_JOB_TYPES; n = n + 1) begin: job_ls
    assign job_queue_ready[n] = current_job_type_vec[n] & schedule_decision_made & schedule_success;
end
endgenerate 

///////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////                          ////////////////////////////////////
///////////////////////////////          Scheduling Decision         //////////////////////////////
/////////////////////////////////////                          ////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

//------------------------- Find individual job schedule ---------------------------//
assign valid_fthread_mapping     = mapping_matrix[job_index] & ~fthreads_state;
    
// If more than one valid fthread mapping, select one giving priorty to the fthread with the lower index 
generate for ( k = `NUMBER_OF_FTHREADS-1; k >1 ; k = k-1) begin: ft_selected_0
    assign fthread_select[k] = valid_fthread_mapping[k] & ~(|(valid_fthread_mapping[0:k-1]));
end 
endgenerate

generate if(`NUMBER_OF_FTHREADS > 1) begin: ft_selected_1 
    assign fthread_select[1] = valid_fthread_mapping[1] & ~valid_fthread_mapping[0];
end
endgenerate

assign fthread_select[0] = valid_fthread_mapping[0];

always @(posedge clk) begin
    if (~rst_n) begin
        fthread_select_d1    <= 0;
    end
    else begin
        fthread_select_d1    <= fthread_select;
    end
end

//-------------------------------- Pipeline Agent -----------------------------------//

generate 
if( `NUMBER_OF_FTHREADS > 1 ) begin 
     
assign find_pipeline_schedule   = job_request[0] & job_request_valid;
assign direct_pipeline_schedule = job_request[5:4] == `WR_IF_DIRECT_PIPELINE_CODE;
assign src_job_fthread_mapping  = mapping_matrix[job_index];
assign dst_job_fthread_mapping  = mapping_matrix[ job_request[`JOB_TYPE_BITS:1] ];


pipeline_agent pipeline_agent(
    .clk                            (clk),
    .rst_n                          (rst_n),

    // Pipelining request     
    .find_pipeline_schedule         (find_pipeline_schedule),
    .direct_pipeline_schedule       (direct_pipeline_schedule),
    .fthreads_state                 (fthreads_state),
    .src_job_fthread_mapping        (src_job_fthread_mapping),
    .dst_job_fthread_mapping        (dst_job_fthread_mapping),

    // Pipeline Schedule decision
    .src_fthread_select             (src_fthread_select),
    .dst_fthread_select             (dst_fthread_select),
    .dst_fthread_reserve            (dst_fthread_reserve),
    .pipeline_schedule_valid        (pipeline_schedule_valid)
);
end 
else begin 

 assign find_pipeline_schedule   = 1'b0;
 assign direct_pipeline_schedule = 0;
 assign src_job_fthread_mapping  = 0;
 assign dst_job_fthread_mapping  = 0;

 assign src_fthread_select       = 0;
 assign dst_fthread_select       = 0;
 assign dst_fthread_reserve      = 1'b0;
 assign pipeline_schedule_valid  = 1'b0;

end 
endgenerate
//
always @(*) begin
    if (pipeline_schedule_valid) begin
        if (dst_fthread_reserve) begin
            reserve_fthreads = dst_fthread_select;
        end
        else begin
            reserve_fthreads = 0;
        end
    end
    else begin
        reserve_fthreads = 0;
    end
end
//
assign schedule_decision_made = job_request_valid_d1;
assign schedule_success       = (pipeline_schedule_valid)? |src_fthread_select : |fthread_select_d1;
///////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////                           ///////////////////////////////////
///////////////////////////////      Job Assignment for FThreads      /////////////////////////////
/////////////////////////////////////                           ///////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
//-------------------------------------------------------------//
// fthread job set
always @(*) begin
    if(job_request_valid_d1) begin 
        if(pipeline_schedule_valid) begin
            fthread_job_set = (src_fthread_select | dst_fthread_select);
        end 
        else begin 
            fthread_job_set = fthread_select_d1;
        end 
    end 
    else begin
        fthread_job_set = 0;
    end
end
//-------------------------------------------------------------//
// fthread job select
assign is_fthread_select_dst = (pipeline_schedule_valid)? dst_fthread_select : 0;
//-------------------------------------------------------------//
// Register and set output job requests toward fthreads
generate for(n = 0; n < `NUMBER_OF_FTHREADS; n = n + 1) begin: mappings 
// job line
always@(posedge clk) begin 
    if(is_fthread_select_dst[n]) begin
        fthread_job[n] <= dst_job_line;
    end
    else if(job_request[0]) begin 
        fthread_job[n] <= src_job_line;
    end 
    else begin
        fthread_job[n] <= job_line;
    end
end
// valid 
always@(posedge clk) begin 
    if(~rst_n) begin 
        fthread_job_valid[n] <= 1'b0;
    end 
    else begin 
        fthread_job_valid[n] <= fthread_job_set[n];
    end 
end
end 
endgenerate
///////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////                          ////////////////////////////////////
///////////////////////////////            FTHREADS States           //////////////////////////////
/////////////////////////////////////                          ////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

always@(posedge clk) begin 
    if(~rst_n) begin 
        for(j = 0; j < `NUMBER_OF_FTHREADS; j = j + 1) begin
            fthreads_state[j]    <= 1'b0;
            fthreads_reserved[j] <= 1'b0;
        end 
    end 
    else begin 
        for(j = 0; j < `NUMBER_OF_FTHREADS; j = j + 1) begin

            if (fthread_done[j]) begin
                fthreads_reserved[j] <= 1'b0;
            end
            else if (reserve_fthreads[j]) begin
                fthreads_reserved[j] <= 1'b1;
            end

            if( fthread_job_set[j] ) begin
                fthreads_state[j] <= 1'b1;
            end 
            else if(fthread_done[j] & ~fthreads_reserved[j]) begin
                fthreads_state[j] <= 1'b0;
            end 
        end
    end 
end


endmodule
