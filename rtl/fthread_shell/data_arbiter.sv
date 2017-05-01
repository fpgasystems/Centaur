
`include "../framework_defines.vh"

module DataArbiter (
	input  wire                             clk, 
	input  wire                             rst_n, 
    
    ////////////////// io_requester <--> arbiter
	// TX_RD request, 
    input  wire                             cor_tx_rd_ready,
    output wire                             cor_tx_rd_valid,
    output wire [70:0]                      cor_tx_rd_hdr,
    // TX_WR request, 
    input  wire                             cor_tx_wr_ready,    
    output wire                             cor_tx_wr_valid,
    output wire [74:0]                      cor_tx_wr_hdr, 
    output wire [511:0]                     cor_tx_data,
    
    ////////////////// server_io <--> arbiter           
    // RX_RD response, 
    input  wire                             io_rx_rd_valid,
    input  wire [511:0]                     io_rx_data,
    input  wire [12:0]                      io_rx_rd_tag,

    // RX_WR response,
    input  wire                             io_rx_wr_valid, 
    input  wire [12:0]                      io_rx_wr_tag,

    //////////////////////// Toward Channels ////////////////////////////
    //-------------- read interface
    input  wire                              ft_tx_rd_valid[`NUMBER_OF_FTHREADS-1:0],
    input  wire [67:0]                       ft_tx_rd_hdr[`NUMBER_OF_FTHREADS-1:0],
    output wire                    	         ft_tx_rd_ready[`NUMBER_OF_FTHREADS-1:0],

    output wire                              ft_rx_rd_valid[`NUMBER_OF_FTHREADS-1:0],
    output wire [511:0]                      ft_rx_data[`NUMBER_OF_FTHREADS-1:0],
    output wire [`FTHREAD_TAG-1:0]           ft_rx_rd_tag[`NUMBER_OF_FTHREADS-1:0],
    //-------------- write interface
    input  wire [71:0]                       ft_tx_wr_hdr[`NUMBER_OF_FTHREADS-1:0], 
    input  wire [511:0]                      ft_tx_data[`NUMBER_OF_FTHREADS-1:0],
    input  wire                              ft_tx_wr_valid[`NUMBER_OF_FTHREADS-1:0],
    output wire                              ft_tx_wr_ready[`NUMBER_OF_FTHREADS-1:0],

    output wire                              ft_rx_wr_valid[`NUMBER_OF_FTHREADS-1:0], 
    output wire [`FTHREAD_TAG-1:0]           ft_rx_wr_tag[`NUMBER_OF_FTHREADS-1:0]
    );

wire  [(512+72)-1 : 0]                           usr_wr_tx_lines[`NUMBER_OF_FTHREADS-1:0];
wire  [512+72-1 : 0]                             wr_tx_line;
wire  [`FTHREADS_BITS-1:0]                       wr_tx_tag;
wire                                             wr_tx_valid;

wire  [(512+`FTHREAD_TAG)-1 :0]                  usr_rd_rx_lines[`NUMBER_OF_FTHREADS-1:0];
wire  [67:0]                                     rd_tx_line;
wire  [`FTHREADS_BITS-1:0]                       rd_tx_tag;
wire                                             rd_tx_valid;


reg                                              io_rx_rd_valid_d1;
reg [511:0]                                      io_rx_data_d1;
reg [12:0]                                       io_rx_rd_tag_d1;

reg                                              io_rx_wr_valid_d1; 
reg [12:0]                                       io_rx_wr_tag_d1;
//// Register RX
always @(posedge clk) begin
    if(~rst_n) begin
        io_rx_rd_valid_d1  <= 0;
        //io_rx_data_d1      <= 0;
        io_rx_rd_tag_d1    <= 0;

        io_rx_wr_valid_d1  <= 0; 
        io_rx_wr_tag_d1    <= 0;
    end 
    else begin
        io_rx_rd_valid_d1  <= io_rx_rd_valid;
        io_rx_data_d1      <= io_rx_data;
        io_rx_rd_tag_d1    <= io_rx_rd_tag;

        io_rx_wr_valid_d1  <= io_rx_wr_valid; 
        io_rx_wr_tag_d1    <= io_rx_wr_tag;
    end
end
////


genvar i;
///////////////////////////////////////////////////////////////////////////////////////////////
generate for( i = 0; i < `NUMBER_OF_FTHREADS; i = i + 1) begin: usrWrLines 
    assign usr_wr_tx_lines[i] = {ft_tx_wr_hdr[i], ft_tx_data[i]};
end
endgenerate


assign cor_tx_wr_valid = wr_tx_valid;
assign cor_tx_wr_hdr   = {wr_tx_line[512+71: 512+`FTHREAD_TAG], {{3-`FTHREADS_BITS}{1'b0}}, wr_tx_tag, wr_tx_line[512+`FTHREAD_TAG-1:512+0]};
assign cor_tx_data     = wr_tx_line[511:0];

regulator  #(.NUMBER_OF_USERS(`NUMBER_OF_FTHREADS),
    		 .USERS_BITS(`FTHREADS_BITS),
    		 .USER_LINE_IN_WIDTH(512+72),
             .USER_LINE_OUT_WIDTH(`FTHREAD_TAG),
             .PRIORITY_BATCHED_ROUND_ROBIN(1),
             .ROUND_ROBIN_BATCH_SIZE(16))
 WR_Channel_Regulator(

    .clk                 (clk),
    .rst_n               (rst_n),
    
    // Users TX Channel
    .usr_tx_lines        (usr_wr_tx_lines),
    .usr_tx_valid        (ft_tx_wr_valid),
    .usr_tx_ready        (ft_tx_wr_ready),

    // Users RX Channel
    .usr_rx_lines        (ft_rx_wr_tag),
    .usr_rx_valid        (ft_rx_wr_valid),

    // TX Channel
    .tx_line             (wr_tx_line),
    .tx_tag              (wr_tx_tag),
    .tx_valid            (wr_tx_valid),
    .tx_ready            (cor_tx_wr_ready),

    // RX Channel
    .rx_line             (io_rx_wr_tag_d1[`FTHREAD_TAG-1:0]),
    .rx_tag              (io_rx_wr_tag_d1[`FTHREAD_TAG+`FTHREADS_BITS - 1:`FTHREAD_TAG]),
    .rx_valid            (io_rx_wr_valid_d1)
);

////////////////////////////////////////////////////////////////////////////////////////////////////
genvar j;
generate for( j = 0; j < `NUMBER_OF_FTHREADS; j = j + 1) begin: usrRdLines 
    assign ft_rx_data[j]   = usr_rd_rx_lines[j][511 : 0];
    assign ft_rx_rd_tag[j] = usr_rd_rx_lines[j][512 + `FTHREAD_TAG-1 : 512];
end
endgenerate

assign cor_tx_rd_valid = rd_tx_valid;
assign cor_tx_rd_hdr   = {rd_tx_line[67:`FTHREAD_TAG], {{3-`FTHREADS_BITS}{1'b0}}, rd_tx_tag, rd_tx_line[`FTHREAD_TAG-1:0]};

regulator  #(.NUMBER_OF_USERS(`NUMBER_OF_FTHREADS),
    		 .USERS_BITS(`FTHREADS_BITS),
    		 .USER_LINE_IN_WIDTH(68),
             .USER_LINE_OUT_WIDTH(512+`FTHREAD_TAG),
             .PRIORITY_BATCHED_ROUND_ROBIN(1),
             .ROUND_ROBIN_BATCH_SIZE(16))
 RD_Channel_Regulator(

    .clk                 (clk),
    .rst_n               (rst_n),
    
    // Users TX Channel
    .usr_tx_lines        (ft_tx_rd_hdr),
    .usr_tx_valid        (ft_tx_rd_valid),
    .usr_tx_ready        (ft_tx_rd_ready),

    // Users RX Channel
    .usr_rx_lines        (usr_rd_rx_lines),
    .usr_rx_valid        (ft_rx_rd_valid),

    // TX Channel
    .tx_line             (rd_tx_line),
    .tx_tag              (rd_tx_tag),
    .tx_valid            (rd_tx_valid),
    .tx_ready            (cor_tx_rd_ready),

    // RX Channel
    .rx_line             ({io_rx_rd_tag_d1[`FTHREAD_TAG-1:0], io_rx_data_d1}),
    .rx_tag              (io_rx_rd_tag_d1[`FTHREAD_TAG+`FTHREADS_BITS - 1:`FTHREAD_TAG]),
    .rx_valid            (io_rx_rd_valid_d1)
);

endmodule 
