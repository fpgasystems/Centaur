`include "../framework_defines.vh"

module user_tx_rd_if #(parameter USER_TAG = `AFU_TAG)
(
	input   wire                                   clk,
    input   wire                                   rst_n,
    input   wire                                   reset_interface,

    input   wire                                   set_if_mem_pipelined,
    input   wire                                   set_if_direct_pipelined,
    input   wire [57:0]                            mem_pipeline_addr,
    input   wire [3:0]                             mem_pipeline_addr_code,
    input   wire [3:0]                             direct_pipeline_addr_code,

    input   wire                                   reads_finished,
    //--------------------- User RD Request -----------------------------//
    // User Module TX RD
    input   wire [57:0]                            um_tx_rd_addr,
    input   wire [USER_TAG-1:0]                    um_tx_rd_tag,
    input   wire 						           um_tx_rd_valid,
    output  wire                                   um_tx_rd_ready,
    // User Module RX RD
    output  wire [USER_TAG-1:0]                    um_rx_rd_tag,
    output  wire [511:0]                           um_rx_data,
    output  wire                                   um_rx_rd_valid, 
    input   wire                                   um_rx_rd_ready,
    //-------------------- to Fthread Controller ------------------------//
    output  wire   						           usr_arb_tx_rd_valid,
    output  wire [57:0] 				           usr_arb_tx_rd_addr, 
    output  wire [`IF_TAG-1:0] 				       usr_arb_tx_rd_tag,
    input  	wire 						           usr_arb_tx_rd_ready,

    input  	wire 						           usr_arb_rx_rd_valid,
    input   wire [`IF_TAG-1:0]                     usr_arb_rx_rd_tag,
    input 	wire [511:0] 				           usr_arb_rx_data,

    output  wire [57:0]                            rif_tx_wr_addr,
    output  wire [`IF_TAG-1:0]                     rif_tx_wr_tag,
    output  wire                                   rif_tx_wr_valid,
    output  wire [511:0]                           rif_tx_data,
    input   wire                                   rif_tx_wr_ready,

    input   wire [`IF_TAG-1:0]                     rif_rx_wr_tag,
    input   wire                                   rif_rx_wr_valid,
    
    //-------------------- To pipeline writer ---------------------------//
    output  wire                                   usr_pipe_tx_rd_valid,
    output  wire [`IF_TAG-1:0]                     usr_pipe_tx_rd_tag, 
    input   wire                                   usr_pipe_tx_rd_ready,

    input   wire                                   usr_pipe_rx_rd_valid,
    input   wire [`IF_TAG-1:0]                     usr_pipe_rx_rd_tag,
    input   wire [511:0]                           usr_pipe_rx_data,
    output  wire                                   usr_pipe_rx_rd_ready
);


wire  [57+USER_TAG:0]        tx_rd_fifo_dout;
wire                         tx_rd_fifo_valid;
wire                         tx_rd_fifo_full;
wire                         tx_rd_fifo_re;
wire                         ord_tx_rd_ready;


// RX RD
reg   [`IF_TAG-1:0]          rx_rd_tag_reg;
reg   [511:0]                rx_data_reg;
reg                          rx_rd_valid_reg;

wire                         tx_rd_ready;
wire                         tx_rd_valid;
wire  [57:0]                 tx_rd_addr;
wire  [`IF_TAG-1:0]          tx_rd_tag;

wire                         usr_tx_rd_ready;
wire                         usr_tx_rd_valid;
wire  [57:0]                 usr_tx_rd_addr;
wire  [USER_TAG+1:0]         usr_tx_rd_tag;

wire  [USER_TAG+1:0]         usr_rx_rd_tag;
wire                         usr_rx_rd_valid;
wire  [511:0]                usr_rx_data;

reg   [57:0]                 fifo_base_addr;
reg   [3:0]                  fifo_addr_code;
reg   [3:0]                  direct_pipeline_code;
reg                          direct_pipeline_code_valid;
reg                          in_memory_pipeline;
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////                           ////////////////////////////////////////////
/////////////////////////////////////////      Pipelining Control Flags     ////////////////////////////////////////
/////////////////////////////////////////////                           ////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
always @(posedge clk) begin
    if (~rst_n | reset_interface | reads_finished) begin
        in_memory_pipeline   <= 0;
        fifo_base_addr       <= 0;
        fifo_addr_code       <= 0;
        direct_pipeline_code <= 0;

        direct_pipeline_code_valid <= 1'b0;
    end
    else begin  
        if(set_if_mem_pipelined) begin
            in_memory_pipeline  <= 1'b1;
            fifo_base_addr      <= mem_pipeline_addr;
            fifo_addr_code      <= mem_pipeline_addr_code;
        end

        if(set_if_direct_pipelined) begin
            direct_pipeline_code       <= direct_pipeline_addr_code;
            direct_pipeline_code_valid <= 1'b1;
        end
    end 
end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////                           ////////////////////////////////////////////
/////////////////////////////////////////        Reader Requests FIFO      /////////////////////////////////////////
/////////////////////////////////////////////                           ////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
quick_fifo  #(.FIFO_WIDTH(58 + USER_TAG),        
            .FIFO_DEPTH_BITS(9),
            .FIFO_ALMOSTFULL_THRESHOLD((2**9) - 8)
            ) tx_rd_fifo(
        .clk                (clk),
        .reset_n            (rst_n & ~reset_interface),
        .din                ({um_tx_rd_tag, um_tx_rd_addr}),
        .we                 (um_tx_rd_valid),
        .re                 (tx_rd_fifo_re),
        .dout               (tx_rd_fifo_dout),
        .empty              (),
        .valid              (tx_rd_fifo_valid),
        .full               (tx_rd_fifo_full),
        .count              (),
        .almostfull         ()
    ); 

assign um_tx_rd_ready = ~tx_rd_fifo_full;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////                           ////////////////////////////////////////////
/////////////////////////////////////////      Through SW FIFO Reader      /////////////////////////////////////////
/////////////////////////////////////////////                           ////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Arbiter TX RD

//(direct_pipeline_code_valid)?(tx_rd_addr[57:54] != direct_pipeline_code) & tx_rd_valid : tx_rd_valid;

// Pass through in-memory FIFO
sw_fifo_reader #(.USER_TAG(USER_TAG) ) 
sw_fifo_reader(
    .clk                        (clk),
    .rst_n                      (rst_n & ~reset_interface),
    //-------------------------------------------------//
    .fifo_base_addr             (fifo_base_addr),
    .fifo_addr_code             (fifo_addr_code),
    .setup_fifo                 (in_memory_pipeline),
    .reads_finished             (reads_finished),
    //--------------------- FIFO to QPI ----------------//
    // TX RD
    .fifo_tx_wr_addr            (rif_tx_wr_addr),
    .fifo_tx_wr_tag             (rif_tx_wr_tag),
    .fifo_tx_wr_valid           (rif_tx_wr_valid),
    .fifo_tx_data               (rif_tx_data),
    .fifo_tx_wr_ready           (rif_tx_wr_ready),
    // TX RD
    .fifo_tx_rd_addr            (usr_tx_rd_addr),
    .fifo_tx_rd_tag             (usr_tx_rd_tag),
    .fifo_tx_rd_valid           (usr_tx_rd_valid),
    .fifo_tx_rd_ready           (usr_tx_rd_ready),
    // RX RD
    .fifo_rx_wr_tag             (rif_rx_wr_tag),
    .fifo_rx_wr_valid           (rif_rx_wr_valid),
    // RX WR 
    .fifo_rx_rd_valid           (usr_rx_rd_valid),
    .fifo_rx_rd_tag             (usr_rx_rd_tag),
    .fifo_rx_data               (usr_rx_data),
    .fifo_rx_rd_ready           (usr_rx_rd_ready),
    ///////////////////////// User Logic Interface ////////////////////
    .usr_tx_rd_tag              (tx_rd_fifo_dout[57+USER_TAG:58]),
    .usr_tx_rd_valid            (tx_rd_fifo_valid),
    .usr_tx_rd_addr             (tx_rd_fifo_dout[57:0]),
    .usr_tx_rd_ready            (tx_rd_fifo_re),

    .usr_rx_rd_tag              (um_rx_rd_tag),
    .usr_rx_rd_valid            (um_rx_rd_valid),
    .usr_rx_data                (um_rx_data),
    .usr_rx_rd_ready            (um_rx_rd_ready)
);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////                           ////////////////////////////////////////////
/////////////////////////////////////////     Requests Ordering Module      ////////////////////////////////////////
/////////////////////////////////////////////                           ////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
order_module_backpressure #(
               .TAG_WIDTH(7),
               .OUT_TAG_WIDTH(`IF_TAG),
               .USER_TAG_WIDTH(USER_TAG+2)) 
omodule(
    
    .clk                     (clk),
    .rst_n                   (rst_n & ~reset_interface),
    //-------------------------------------------------//
    // input requests
    .usr_tx_rd_addr          (usr_tx_rd_addr),
    .usr_tx_rd_tag           (usr_tx_rd_tag),
    .usr_tx_rd_valid         (usr_tx_rd_valid),
    .usr_tx_rd_free          (usr_tx_rd_ready),
    // TX RD
    .ord_tx_rd_addr          (tx_rd_addr),
    .ord_tx_rd_tag           (tx_rd_tag),
    .ord_tx_rd_valid         (tx_rd_valid),
    .ord_tx_rd_free          (tx_rd_ready),
    // RX RD
    .ord_rx_rd_tag           (rx_rd_tag_reg[6:0]),
    .ord_rx_rd_data          (rx_data_reg),
    .ord_rx_rd_valid         (rx_rd_valid_reg),  
    //
    .usr_rx_rd_tag           (usr_rx_rd_tag),
    .usr_rx_rd_data          (usr_rx_data), 
    .usr_rx_rd_valid         (usr_rx_rd_valid),
	.usr_rx_rd_ready         (usr_rx_rd_ready)
);

//--------------------------------------------//
assign tx_rd_ready = ((tx_rd_addr[57:54] == direct_pipeline_code) & direct_pipeline_code_valid)? usr_pipe_tx_rd_ready  : usr_arb_tx_rd_ready;
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////                           ////////////////////////////////////////////
/////////////////////////////////////////      Accesses To Main Memory     /////////////////////////////////////////
/////////////////////////////////////////////                           ////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Arbiter TX RD

assign usr_arb_tx_rd_addr  = tx_rd_addr;
assign usr_arb_tx_rd_tag   = tx_rd_tag;
assign usr_arb_tx_rd_valid = (direct_pipeline_code_valid)?(tx_rd_addr[57:54] != direct_pipeline_code) & tx_rd_valid : tx_rd_valid;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////                           ////////////////////////////////////////////
/////////////////////////////////////////      Direct AFU-AFU Pipeline     /////////////////////////////////////////
/////////////////////////////////////////////                           ////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//-------------------------------------------//
// Pipe TX RD

assign usr_pipe_tx_rd_tag   = tx_rd_tag;
assign usr_pipe_tx_rd_valid = (tx_rd_addr[57:54] == direct_pipeline_code) & direct_pipeline_code_valid & tx_rd_valid;

assign usr_pipe_rx_rd_ready = ~usr_arb_rx_rd_valid;
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////                           ////////////////////////////////////////////
/////////////////////////////////////////      Read Request Responses      /////////////////////////////////////////
/////////////////////////////////////////////                           ////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//--------------------------------------------//
// order module rd rx
// data
always @(posedge clk) begin
    if(usr_arb_rx_rd_valid) begin
        rx_data_reg     <= usr_arb_rx_data;
    end
    else begin
        rx_data_reg     <= usr_pipe_rx_data;
    end
end
// valid
always @(posedge clk) begin
    if (~rst_n | reset_interface) begin
        rx_rd_tag_reg   <= 0;
        rx_rd_valid_reg <= 0;
    end
    else begin
        if(usr_arb_rx_rd_valid) begin
            rx_rd_tag_reg   <= usr_arb_rx_rd_tag;
            rx_rd_valid_reg <= 1'b1;
        end
        else begin
            rx_rd_tag_reg   <= usr_pipe_rx_rd_tag;
            rx_rd_valid_reg <= usr_pipe_rx_rd_valid;
        end
    end
end


endmodule
