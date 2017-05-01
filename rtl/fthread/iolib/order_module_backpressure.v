`default_nettype none

module order_module_backpressure
#(
                      parameter TAG_WIDTH      = 6,
                      parameter OUT_TAG_WIDTH  = 6,
                      parameter USER_TAG_WIDTH = 8,
                      parameter DATA_WIDTH     = 512,
                      parameter ADDR_WIDTH     = 58)
	(
    input   wire                        clk,
    input   wire                        rst_n,
    //-------------------------------------------------//
    // input requests
    input  wire  [ADDR_WIDTH-1:0]       usr_tx_rd_addr,
    input  wire  [USER_TAG_WIDTH-1:0]   usr_tx_rd_tag,
    input  wire   						usr_tx_rd_valid,
    output wire                         usr_tx_rd_free,
    // User Module TX RD
    output  wire [ADDR_WIDTH-1:0]       ord_tx_rd_addr,
    output  wire [OUT_TAG_WIDTH-1:0]    ord_tx_rd_tag,
    output  wire  						ord_tx_rd_valid,
    input   wire                        ord_tx_rd_free,
    // User Module RX RD
    input   wire [TAG_WIDTH-1:0]        ord_rx_rd_tag,
    input   wire [DATA_WIDTH-1:0]       ord_rx_rd_data,
    input   wire                        ord_rx_rd_valid,
    //
    output  reg  [USER_TAG_WIDTH-1:0]   usr_rx_rd_tag,
    output  reg  [DATA_WIDTH-1:0]       usr_rx_rd_data,
    output  reg                         usr_rx_rd_valid,
    input   wire                        usr_rx_rd_ready
);



reg  [2**TAG_WIDTH-1:0]        rob_valid; 
reg                            rob_re;
reg                            rob_re_d1;
reg  [USER_TAG_WIDTH-1:0]      rob_rtag;
reg  [USER_TAG_WIDTH+TAG_WIDTH-1:0]      rob_raddr;

wire 						   pend_tag_fifo_full;
wire 						   pend_tag_fifo_valid;
wire 						   absorb_pend_tag;

wire  [USER_TAG_WIDTH+TAG_WIDTH-1:0]     curr_pend_tag;
wire  [DATA_WIDTH-1:0]                   rob_rdata;

reg   [1:0]                    pending_valid;
reg   [DATA_WIDTH-1:0]         pending_data [1:0];
reg   [USER_TAG_WIDTH-1:0]     pending_tag  [1:0];

reg   [TAG_WIDTH-1:0]          ord_tag;





assign ord_tx_rd_valid = usr_tx_rd_valid & ~pend_tag_fifo_full;
assign ord_tx_rd_tag   = {{{OUT_TAG_WIDTH - TAG_WIDTH}{1'b0}}, ord_tag};
assign ord_tx_rd_addr  = usr_tx_rd_addr;

assign usr_tx_rd_free  = ord_tx_rd_free & ~pend_tag_fifo_full;

// RX_RD reorder buffer for rd data         
    spl_sdp_mem #(.DATA_WIDTH   (DATA_WIDTH), 
                  .ADDR_WIDTH   (TAG_WIDTH)       // transfer size 1, tag width 6 -> 64 entries
    ) reorder_buf (
        .clk        (clk), 
        .we         ( ord_rx_rd_valid ),
        .waddr      ( ord_rx_rd_tag[TAG_WIDTH-1:0] ),
        .din        ( ord_rx_rd_data ),

        .re         ( rob_re ),
        .raddr      ( rob_raddr[TAG_WIDTH-1:0] ),
        .dout       ( rob_rdata ) 
    );


// FIFO of tags for sent TX RD requests
quick_fifo  #(.FIFO_WIDTH(USER_TAG_WIDTH + TAG_WIDTH),        
            .FIFO_DEPTH_BITS(TAG_WIDTH),
            .FIFO_ALMOSTFULL_THRESHOLD(32)
            ) pend_tag_fifo(
        .clk                (clk),
        .reset_n            (rst_n),
        .din                ({usr_tx_rd_tag, ord_tag}),
        .we                 (usr_tx_rd_valid & ord_tx_rd_free),

        .re                 ( absorb_pend_tag),
        .dout               (curr_pend_tag),
        .empty              (),
        .valid              (pend_tag_fifo_valid),
        .full               (pend_tag_fifo_full),
        .count              (),
        .almostfull         ()
    );

assign absorb_pend_tag    = rob_re;

always@(posedge clk) begin
	if(~rst_n) begin
		rob_valid       <= 0;
        rob_re          <= 0;
        rob_re_d1       <= 0;
        rob_rtag        <= 0;
        rob_raddr       <= 0;
        usr_rx_rd_valid <= 1'b0;
        //usr_rx_rd_data  <= 0;
        usr_rx_rd_tag   <= 0;
        pending_valid   <= 0;

        ord_tag         <= 0;
	end
	else begin
        if( usr_tx_rd_valid & ord_tx_rd_free & ~pend_tag_fifo_full ) ord_tag <= ord_tag + 1'b1;
        // write response in the responses memory if cannot bypass rob buffer
        if(ord_rx_rd_valid) begin
            rob_valid[ord_rx_rd_tag[TAG_WIDTH-1:0]] <= 1'b1;
        end 

        // read rob buffer
        rob_re     <= 1'b0;
        rob_re_d1  <= rob_re;
        rob_rtag   <= rob_raddr[USER_TAG_WIDTH+TAG_WIDTH-1 : TAG_WIDTH];
        
        // if current pending tag has valid response then read it from the responses memory
        if( rob_valid[curr_pend_tag[TAG_WIDTH-1:0]] && pend_tag_fifo_valid && (~pending_valid[0] | (~pending_valid[1] & ~rob_re_d1) )) begin
            rob_re                   <= 1'b1;
            rob_raddr                <= curr_pend_tag;
            rob_valid[curr_pend_tag[TAG_WIDTH-1:0]] <= 1'b0;
        end

        // usr rx rd:
        // Advance if either new data comes from the order memory or new data is requested by the AFU
        if(~pending_valid[0]) begin
            pending_valid[0] <= rob_re_d1;
            pending_data[0]  <= rob_rdata;
            pending_tag[0]   <= rob_rtag;
        end 
        else if( ~usr_rx_rd_valid | usr_rx_rd_ready) begin
            if(pending_valid[1]) begin 
                pending_valid[0] <= 1'b1;
                pending_data[0]  <= pending_data[1];
                pending_tag[0]   <= pending_tag[1];
            end 
            else begin
                pending_valid[0] <= rob_re_d1;
                pending_data[0]  <= rob_rdata;
                pending_tag[0]   <= rob_rtag;
            end 
        end 

        if( usr_rx_rd_ready) begin
            if(pending_valid[1]) begin 
                pending_valid[1] <= rob_re_d1;
                pending_data[1]  <= rob_rdata;
                pending_tag[1]   <= rob_rtag;
            end 
            else begin
                pending_valid[1] <= 0;
            end
        end 
        else if( pending_valid[0] & ~pending_valid[1] ) begin
            pending_valid[1] <= rob_re_d1;
            pending_data[1]  <= rob_rdata;
            pending_tag[1]   <= rob_rtag;
        end

        if(usr_rx_rd_ready | ~usr_rx_rd_valid) begin
            
            usr_rx_rd_valid <= pending_valid[0];
            usr_rx_rd_data <= pending_data[0];
            usr_rx_rd_tag <= pending_tag[0];
        end
        // Chekc if data got consumed, in case we are not advancing anyway
        //else if (usr_rx_rd_valid && usr_rx_rd_ready) begin
        //    usr_rx_rd_valid <= 1'b0;
		//end
	end
end


endmodule

`default_nettype wire
