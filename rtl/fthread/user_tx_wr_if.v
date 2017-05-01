`include "../framework_defines.vh"

module user_tx_wr_if #(parameter USER_TAG = `AFU_TAG)
(
	input   wire                                   clk,
    input   wire                                   rst_n,
    input   wire                                   reset_interface,

    input   wire                                   set_if_pipelined,
    output  wire 								   user_tx_wr_if_empty,
    input   wire                                   set_if_mem_pipelined,
    input   wire [57:0]                            mem_pipeline_addr,

    input   wire                                   writes_finished,
    //--------------------- User RD Request -----------------------------//
    // User Module TX RD
    input   wire [57:0]                            um_tx_wr_addr,
    input   wire [USER_TAG-1:0]                    um_tx_wr_tag,
    input   wire [511:0]                           um_tx_data,
    input   wire 						           um_tx_wr_valid,
    output  wire                                   um_tx_wr_ready,
    // User Module RX RD
    output  reg  [USER_TAG-1:0]                    um_rx_wr_tag,
    output  reg                                    um_rx_wr_valid, 
    //-------------------- to Fthread Controller ------------------------//
    output  wire   						           usr_arb_tx_wr_valid,
    output  wire [57:0] 				           usr_arb_tx_wr_addr, 
    output  wire [`IF_TAG-1:0] 				       usr_arb_tx_wr_tag,
    output  wire [511:0]                           usr_arb_tx_data,
    input  	wire 						           usr_arb_tx_wr_ready,

    input  	wire 						           usr_arb_rx_wr_valid,
    input   wire [`IF_TAG-1:0]                     usr_arb_rx_wr_tag,

    output  wire [57:0]                            wif_tx_rd_addr,
    output  wire [`IF_TAG-1:0]                     wif_tx_rd_tag,
    output  wire                                   wif_tx_rd_valid,
    input   wire                                   wif_tx_rd_ready,

    input   wire [`IF_TAG-1:0]                     wif_rx_rd_tag,
    input   wire [511:0]                           wif_rx_data,
    input   wire                                   wif_rx_rd_valid,
    //-------------------- To pipeline reader ---------------------------//
    input   wire                                   usr_pipe_tx_rd_valid,
    input   wire [`IF_TAG-1:0]                     usr_pipe_tx_rd_tag, 
    output  wire                                   usr_pipe_tx_rd_ready,

    output  reg                                    usr_pipe_rx_rd_valid,
    output  reg  [`IF_TAG-1:0]                     usr_pipe_rx_rd_tag,
    output  reg  [511:0]                           usr_pipe_rx_data,
    input   wire                                   usr_pipe_rx_rd_ready
);


wire  [512+57+USER_TAG:0]    tx_wr_fifo_dout;
wire                         tx_wr_fifo_valid;
wire                         tx_wr_fifo_full;
wire                         tx_wr_fifo_re;
wire                         tx_wr_fifo_empty;

wire  [`IF_TAG-1:0]          pipe_rd_pending_fifo_tag;
wire                         pipe_rd_pending_fifo_valid;
wire                         pipe_rd_pending_fifo_full;

wire                         fifo_tx_wr_valid;
wire  [57:0]                 fifo_tx_wr_addr;
wire  [USER_TAG+1:0]         fifo_tx_wr_tag;
wire  [511:0]                fifo_tx_data;
wire                         fifo_tx_wr_ready;

wire  [USER_TAG+1:0]         fifo_rx_wr_tag;
wire                         fifo_rx_wr_valid;

wire                         usr_tx_wr_ready;

wire  [USER_TAG-1:0]         usr_rx_wr_tag;
wire                         usr_rx_wr_valid;

wire                         fifo_done;

reg                          wr_if_pipelined = 0;
reg                          in_memory_pipeline = 0;
reg   [57:0]                 fifo_base_addr;
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////                           ////////////////////////////////////////////
/////////////////////////////////////////      Pipelining Control Flags     ////////////////////////////////////////
/////////////////////////////////////////////                           ////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
always @(posedge clk) begin
	if (~rst_n | reset_interface) begin
		wr_if_pipelined    <= 0;
        in_memory_pipeline <= 0;
        fifo_base_addr     <= 0;
	end
	else begin  
        if(set_if_pipelined) begin
		    wr_if_pipelined <= 1'b1;
	    end
        
        fifo_base_addr     <= mem_pipeline_addr;
        if(fifo_done) begin
            in_memory_pipeline <= 1'b0;
        end
        else if(set_if_mem_pipelined) begin
            in_memory_pipeline <= 1'b1;
        end
    end 
end

assign user_tx_wr_if_empty = (in_memory_pipeline)? fifo_done : tx_wr_fifo_empty & ~fifo_tx_wr_valid;  
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////                           ////////////////////////////////////////////
/////////////////////////////////////////        Writer Requests FIFO      /////////////////////////////////////////
/////////////////////////////////////////////                           ////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
quick_fifo  #(.FIFO_WIDTH(512 + 58 + USER_TAG),        
            .FIFO_DEPTH_BITS(9),
            .FIFO_ALMOSTFULL_THRESHOLD((2**9) - 8)
            ) tx_wr_fifo(
        .clk                (clk),
        .reset_n            (rst_n & ~reset_interface),
        .din                ({um_tx_wr_tag, um_tx_wr_addr, um_tx_data}),
        .we                 (um_tx_wr_valid),
        .re                 (tx_wr_fifo_re),
        .dout               (tx_wr_fifo_dout),
        .empty              (tx_wr_fifo_empty),
        .valid              (tx_wr_fifo_valid),
        .full               (tx_wr_fifo_full),
        .count              (),
        .almostfull         ()
    ); 

assign um_tx_wr_ready = ~tx_wr_fifo_full;


assign tx_wr_fifo_re  = (wr_if_pipelined)? usr_pipe_rx_rd_ready &  pipe_rd_pending_fifo_valid : usr_tx_wr_ready;
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////                           ////////////////////////////////////////////
/////////////////////////////////////////      Accesses To Main Memory     /////////////////////////////////////////
/////////////////////////////////////////////                           ////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Pass through in-memory FIFO
sw_fifo_writer #(.USER_TAG(USER_TAG) ) 
sw_fifo_writer(
    .clk                        (clk),
    .rst_n                      (rst_n & ~reset_interface),
    //-------------------------------------------------//
    .fifo_base_addr             (fifo_base_addr),
    .setup_fifo                 (in_memory_pipeline & ~fifo_done),
    .writes_finished            (writes_finished & tx_wr_fifo_empty),
    .fifo_done                  (fifo_done),
    //--------------------- FIFO to QPI ----------------//
    // TX RD
    .fifo_tx_rd_addr            (wif_tx_rd_addr),
    .fifo_tx_rd_tag             (wif_tx_rd_tag),
    .fifo_tx_rd_valid           (wif_tx_rd_valid),
    .fifo_tx_rd_ready           (wif_tx_rd_ready),
    // TX WR
    .fifo_tx_wr_addr            (fifo_tx_wr_addr),
    .fifo_tx_wr_tag             (fifo_tx_wr_tag),
    .fifo_tx_wr_valid           (fifo_tx_wr_valid),
    .fifo_tx_data               (fifo_tx_data),
    .fifo_tx_wr_ready           (fifo_tx_wr_ready),
    // RX RD
    .fifo_rx_rd_tag             (wif_rx_rd_tag),
    .fifo_rx_data               (wif_rx_data),
    .fifo_rx_rd_valid           (wif_rx_rd_valid),
    // RX WR 
    .fifo_rx_wr_valid           (fifo_rx_wr_valid),
    .fifo_rx_wr_tag             (fifo_rx_wr_tag),
    ///////////////////////// User Logic Interface ////////////////////
    .usr_tx_wr_tag              (tx_wr_fifo_dout[512+57+USER_TAG:570]),
    .usr_tx_wr_valid            (tx_wr_fifo_valid & ~wr_if_pipelined),
    .usr_tx_wr_addr             (tx_wr_fifo_dout[569:512]),
    .usr_tx_data                (tx_wr_fifo_dout[511:0]),
    .usr_tx_wr_ready            (usr_tx_wr_ready),

    .usr_rx_wr_tag              (usr_rx_wr_tag),
    .usr_rx_wr_valid            (usr_rx_wr_valid)
);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////                           ////////////////////////////////////////////
/////////////////////////////////////////     Requests Ordering Module      ////////////////////////////////////////
/////////////////////////////////////////////                           ////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
order_module_backpressure_wr #(
               .TAG_WIDTH(7),
               .OUT_TAG_WIDTH(`IF_TAG),
               .USER_TAG_WIDTH(USER_TAG+2)) 
omodule(
    
    .clk                     (clk),
    .rst_n                   (rst_n & ~reset_interface),
    //-------------------------------------------------//
    // input requests
    .usr_tx_wr_addr          (fifo_tx_wr_addr),
    .usr_tx_wr_tag           (fifo_tx_wr_tag),
    .usr_tx_wr_valid         (fifo_tx_wr_valid),
    .usr_tx_data             (fifo_tx_data),
    .usr_tx_wr_ready         (fifo_tx_wr_ready),
    // TX RD
    .ord_tx_wr_addr          (usr_arb_tx_wr_addr),
    .ord_tx_wr_tag           (usr_arb_tx_wr_tag),
    .ord_tx_wr_valid         (usr_arb_tx_wr_valid),
    .ord_tx_data             (usr_arb_tx_data),
    .ord_tx_wr_ready         (usr_arb_tx_wr_ready),
    // RX RD
    .ord_rx_wr_tag           (usr_arb_rx_wr_tag[7:0]),
    .ord_rx_wr_valid         (usr_arb_rx_wr_valid),  
    //
    .usr_rx_wr_tag           (fifo_rx_wr_tag),
    .usr_rx_wr_valid         (fifo_rx_wr_valid),
    .usr_rx_wr_ready         (1'b1)
);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////                           ////////////////////////////////////////////
/////////////////////////////////////////      Direct AFU-AFU Pipeline     /////////////////////////////////////////
/////////////////////////////////////////////                           ////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//-------------------------------------------//
// Pipe RX RD
// data, tag
always @(posedge clk) begin
   if(usr_pipe_rx_rd_ready) begin
	usr_pipe_rx_rd_tag   <= pipe_rd_pending_fifo_tag;
	usr_pipe_rx_data     <= tx_wr_fifo_dout[511:0];
   end 
end
// valid
always @(posedge clk) begin
	if (~rst_n) begin
		usr_pipe_rx_rd_valid <= 0;
	end
	else if(usr_pipe_rx_rd_ready) begin
		usr_pipe_rx_rd_valid <= pipe_rd_pending_fifo_valid & tx_wr_fifo_valid;
	end
end

//--------------------------------------------//
// pipe_rd_pending_fifo

quick_fifo  #(.FIFO_WIDTH(`IF_TAG),        
            .FIFO_DEPTH_BITS(9),
            .FIFO_ALMOSTFULL_THRESHOLD((2**9) - 8)
            ) pipe_rd_pending_fifo(
        .clk                (clk),
        .reset_n            (rst_n),
        .din                (usr_pipe_tx_rd_tag),
        .we                 (usr_pipe_tx_rd_valid & wr_if_pipelined),
        .re                 (tx_wr_fifo_valid & usr_pipe_rx_rd_ready),
        .dout               (pipe_rd_pending_fifo_tag),
        .empty              (),
        .valid              (pipe_rd_pending_fifo_valid),
        .full               (pipe_rd_pending_fifo_full),
        .count              (),
        .almostfull         ()
    ); 

assign usr_pipe_tx_rd_ready = ~pipe_rd_pending_fifo_full;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////                           ////////////////////////////////////////////
/////////////////////////////////////////      Write Request Responses     /////////////////////////////////////////
/////////////////////////////////////////////                           ////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// tag
always @(posedge clk) begin
    if (wr_if_pipelined) begin
        um_rx_wr_tag <= tx_wr_fifo_dout[512+57+USER_TAG:570];
    end
    else begin
        um_rx_wr_tag <= fifo_rx_wr_tag;//[USER_TAG-1:0];
    end
end
// valid
always @(posedge clk) begin
    if (~rst_n) begin
        // reset
        um_rx_wr_valid <= 0;
    end
    else if (wr_if_pipelined) begin
        um_rx_wr_valid <= usr_pipe_rx_rd_ready &  pipe_rd_pending_fifo_valid & tx_wr_fifo_valid;
    end
    else begin
        um_rx_wr_valid <= usr_rx_wr_valid;
    end
end

endmodule
