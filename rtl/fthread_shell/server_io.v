`include "spl_defines.vh"
`include "framework_defines.vh"

module server_io(
    input  wire                             clk,
    input  wire                             rst_n,
    
    /////////////////////////////////////  CCI Interface  /////////////////////////////////////    
    // CCI TX read request
    input  wire                             cci_tx_rd_almostfull,    
    output reg                              spl_tx_rd_valid,
    output reg  [60:0]                      spl_tx_rd_hdr,
    
    // CCI TX write request
    input  wire                             cci_tx_wr_almostfull,
    output reg                              spl_tx_wr_valid,
    output wire                             spl_tx_intr_valid,
    output reg  [60:0]                      spl_tx_wr_hdr,    
    output reg  [511:0]                     spl_tx_data,
    
    // CCI RX read response
    input  wire                             cci_rx_rd_valid,
    input  wire                             cci_rx_wr_valid0,
    input  wire                             cci_rx_cfg_valid,
    input  wire                             cci_rx_intr_valid0,
    input  wire                             cci_rx_umsg_valid,
    input  wire [`CCI_RX_HDR_WIDTH-1:0]     cci_rx_hdr0,
    input  wire [511:0]                     cci_rx_data,
    
    // CCI RX write response
    input  wire                             cci_rx_wr_valid1,
    input  wire                             cci_rx_intr_valid1,
    input  wire [`CCI_RX_HDR_WIDTH-1:0]     cci_rx_hdr1,        
    
    //////////////////////////////// Server components Interfaces /////////////////////////////
    // server_io <--> cmd_server: RX_RD
    output reg                              io_rx_csr_valid,
    output reg  [13:0]                      io_rx_csr_addr,
    output reg  [31:0]                      io_rx_csr_data,  
    // server_io <--> cmd_server: TX_WR
    output wire                             fc_tx_wr_ready,
    input  wire                             fc_tx_wr_valid,
    input  wire [31:0]                      fc_tx_wr_addr,
    input  wire [`FPGA_CORE_TAG-1:0]        fc_tx_wr_tag,
    input  wire [511:0]                     fc_tx_data,
	 // server_io <--> cmd server: TX_RD
    output wire                             fc_tx_rd_ready,
    input  wire                             fc_tx_rd_valid,
    input  wire [31:0]                      fc_tx_rd_addr,
    input  wire [`FPGA_CORE_TAG-1:0]        fc_tx_rd_tag,
	 
	 // server_io <--> cmd server: RX_WR
    output reg                              fc_rx_wr_valid,
    output reg  [`FPGA_CORE_TAG-1:0]        fc_rx_wr_tag,
	 
	 // server_io <--> cmd server: RX_RD
    output reg                              fc_rx_rd_valid,
    output reg  [`FPGA_CORE_TAG-1:0]        fc_rx_rd_tag,
    output reg  [511:0]                     fc_rx_data,
    
    // server_io <--> io_requester: TX_WR
    output wire                             rq_tx_wr_ready,    
    input  wire                             rq_tx_wr_valid,
    input  wire [48:0]                      rq_tx_wr_hdr, 
    input  wire [511:0]                     rq_tx_data,
    // server_io <--> io_requester: TX_RD
    output wire                             rq_tx_rd_ready,
    input  wire                             rq_tx_rd_valid,
    input  wire [44:0]                      rq_tx_rd_hdr,

    // server_io <--> arbiter: RX_RD
    output reg                              io_rx_rd_valid,
    output reg  [511:0]                     io_rx_data,
    output reg  [12:0]                      io_rx_rd_tag,
    // server_io <--> arbiter: RX_WR
    output reg                              io_rx_wr_valid, 
    output reg  [12:0]                      io_rx_wr_tag
);


wire                             wr_rp_buf_empty;
wire                             wr_rp_buf_valid;
wire  [`CCI_RX_HDR_WIDTH-1:0]    wr_rp_buf_hdr;
wire  [`CCI_RX_HDR_WIDTH-1:0]    wr_rp_hdr;
wire                             wr_rp_valid;
wire  [8:0]                      wr_rp_buf_count;

wire  [3:0]                      cci_tx_wr_cmd;
wire  [31:0]					 cci_tx_wr_addr;
wire  [511:0]               cci_tx_data;
wire  [13:0]                     cci_tx_wr_tag;
wire  [31:0]					 cci_tx_rd_addr;
wire  [13:0]                     cci_tx_rd_tag;

wire                             tx_wr_fifo_valid;
wire   [511:0]                   tx_wr_fifo_data;      
wire   [60:0]                    tx_wr_fifo_hdr;
wire                             tx_wr_fifo_full;
wire   [4:0]                     tx_wr_fifo_count;

wire                             tx_rd_fifo_valid;
wire   [60:0]                    tx_rd_fifo_hdr;
wire                             tx_rd_fifo_full;

reg    [31:0]                    idle_read_cycles;
reg    [31:0]                    idle_write_cycles;
reg    [31:0]                    idle_rw_cycles;

//////
always @(posedge clk) begin       
    if(~rst_n) begin
        idle_read_cycles  <= 0;
        idle_write_cycles <= 0;
        idle_rw_cycles    <= 0;
    end 
    else begin
        if( ~cci_tx_wr_almostfull & ~spl_tx_wr_valid) 
            idle_write_cycles <= idle_write_cycles + 1'b1;
        
        if( ~cci_tx_rd_almostfull & ~spl_tx_rd_valid) 
            idle_read_cycles <= idle_read_cycles + 1'b1;
        
        if( ~cci_tx_wr_almostfull & ~spl_tx_wr_valid & ~cci_tx_rd_almostfull & ~spl_tx_rd_valid)
            idle_rw_cycles    <= idle_rw_cycles + 1'b1; 
    end
end
///////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////                           ///////////////////////////////////////
/////////////////////////////          TX WR Driver            ////////////////////////////////////
/////////////////////////////////                           ///////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

// TW WR is used by cmd server and io_requester

// toward cci
assign cci_tx_wr_cmd  = (fc_tx_wr_valid)?`CCI_REQ_WR_THRU       : rq_tx_wr_hdr[48:45];
assign cci_tx_wr_addr = (fc_tx_wr_valid)?fc_tx_wr_addr          : rq_tx_wr_hdr[44:13];
assign cci_tx_data    = (fc_tx_wr_valid)?fc_tx_data             : rq_tx_data;
assign cci_tx_wr_tag  = (fc_tx_wr_valid)?{1'b0, {{`QPI_TAG-`FPGA_CORE_TAG-1}{1'b0}}, fc_tx_wr_tag} : 
                                         {1'b1, rq_tx_wr_hdr[12:0]};


assign spl_tx_intr_valid = 1'b0;

always @(posedge clk) begin       
    if(~rst_n) begin
        spl_tx_wr_valid <= 0;
        spl_tx_wr_hdr   <= 0;
        //spl_tx_data     <= 0;
    end 
    else if(~cci_tx_wr_almostfull) begin
        spl_tx_wr_valid <= tx_wr_fifo_valid;
        spl_tx_wr_hdr   <= tx_wr_fifo_hdr;
        spl_tx_data     <= tx_wr_fifo_data; 
    end
    else spl_tx_wr_valid <= 1'b0;
end

// toward cci TX WR users: i.e. cmd_server, io_requester

assign rq_tx_wr_ready = (fc_tx_wr_valid)? 1'b0 : ~tx_wr_fifo_full;
assign fc_tx_wr_ready = ~tx_wr_fifo_full;


quick_fifo  #(.FIFO_WIDTH(512 + 61),        
            .FIFO_DEPTH_BITS(5),
            .FIFO_ALMOSTFULL_THRESHOLD(2**5 - 8)
            ) tx_wr_fifo(
        .clk                (clk),
        .reset_n            (rst_n),
        .din                ({5'b0, cci_tx_wr_cmd, 6'b0, cci_tx_wr_addr, cci_tx_wr_tag, cci_tx_data}),
        .we                 ((fc_tx_wr_valid | rq_tx_wr_valid)),
        .re                 (~cci_tx_wr_almostfull),
        .dout               ({tx_wr_fifo_hdr, tx_wr_fifo_data}),
        .empty              (),
        .valid              (tx_wr_fifo_valid),
        .full               (tx_wr_fifo_full),
        .count              (tx_wr_fifo_count),
        .almostfull         ()
    );
///////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////                           ///////////////////////////////////////
/////////////////////////////          TX RD Driver            ////////////////////////////////////
/////////////////////////////////                           ///////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

// TX RD is used by the io_requester and the fpga core
// toward cci
assign cci_tx_rd_addr = (fc_tx_rd_valid)? fc_tx_rd_addr : rq_tx_rd_hdr[44:13];
assign cci_tx_rd_tag  = (fc_tx_rd_valid)? {1'b0, {{`QPI_TAG-`FPGA_CORE_TAG-1}{1'b0}}, fc_tx_rd_tag} : 
                                          {1'b1, rq_tx_rd_hdr[12:0]};

always @(posedge clk) begin
    if(~rst_n) begin
        spl_tx_rd_valid <= 0;
        spl_tx_rd_hdr   <= 0;
    end 
    else if(~cci_tx_rd_almostfull) begin
        spl_tx_rd_valid <= tx_rd_fifo_valid;
        spl_tx_rd_hdr   <= tx_rd_fifo_hdr;
    end
    else spl_tx_rd_valid <= 0;
end
        
// toward cci TX RD users: i.e. cmd_server, io_requester
assign rq_tx_rd_ready  = (fc_tx_rd_valid)? 1'b0 : ~tx_rd_fifo_full;
assign fc_tx_rd_ready  = ~tx_rd_fifo_full;

quick_fifo  #(.FIFO_WIDTH(61),        
            .FIFO_DEPTH_BITS(5),
            .FIFO_ALMOSTFULL_THRESHOLD(2**5 - 8)
            ) tx_rd_fifo(
        .clk                (clk),
        .reset_n            (rst_n),
        .din                ({5'b0, `CCI_REQ_RD, 6'b0, cci_tx_rd_addr, cci_tx_rd_tag}),
        .we                 ((rq_tx_rd_valid | fc_tx_rd_valid)),
        .re                 (~cci_tx_rd_almostfull),
        .dout               (tx_rd_fifo_hdr),
        .empty              (),
        .valid              (tx_rd_fifo_valid),
        .full               (tx_rd_fifo_full),
        .count              (),
        .almostfull         ()
    );

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////                           /////////////////////////////////////////////////
//////////////////////////////////////////        RX RD Distributor        //////////////////////////////////////////////
/////////////////////////////////////////////                           /////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// RX RD is used by cmd_server, arbiter, and page table

always @(posedge clk) begin
    if(~rst_n) begin
        io_rx_csr_valid <= 0;
        io_rx_csr_addr  <= 0;
        io_rx_csr_data  <= 0;

        // 
        io_rx_rd_valid  <= 0;
        io_rx_rd_tag    <= 0;
        //io_rx_data      <= 0;
		//
		//fc_rx_data      <= 512'b0;
		fc_rx_rd_tag    <= 0;
		fc_rx_rd_valid  <= 1'b0;
    end 
    else begin
        // 
        io_rx_csr_valid <= cci_rx_cfg_valid;
        io_rx_csr_addr  <= cci_rx_hdr0[13:0];
        io_rx_csr_data  <= cci_rx_data[31:0];

        // 
        io_rx_rd_valid  <= cci_rx_rd_valid & cci_rx_hdr0[13];
        io_rx_rd_tag    <= cci_rx_hdr0[12:0];
        io_rx_data      <= cci_rx_data;
		//
		fc_rx_data      <= cci_rx_data;
		fc_rx_rd_tag    <= cci_rx_hdr0[`FPGA_CORE_TAG-1:0];
		fc_rx_rd_valid  <= cci_rx_rd_valid & ~cci_rx_hdr0[13];
    end
end


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////                           /////////////////////////////////////////////////
//////////////////////////////////////////        RX WR Distributor        //////////////////////////////////////////////
/////////////////////////////////////////////                           /////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// regulate RX WR multiple responses

quick_fifo  #(.FIFO_WIDTH(`CCI_RX_HDR_WIDTH),
            .FIFO_DEPTH_BITS(9),
            .FIFO_ALMOSTFULL_THRESHOLD(8)
            ) wr_rp_buf(
        .clk                (clk),
        .reset_n            (rst_n),
        .din                (cci_rx_hdr0),
        .we                 (cci_rx_wr_valid1 & cci_rx_wr_valid0),
        .re                 ( ~(cci_rx_wr_valid1 | cci_rx_wr_valid0) & wr_rp_buf_valid ),
        .dout               (wr_rp_buf_hdr),
        .empty              (wr_rp_buf_empty),
        .valid              (wr_rp_buf_valid),
        .full               (),
        .count              (wr_rp_buf_count),
        .almostfull         ()
    );

//
assign wr_rp_valid = cci_rx_wr_valid1 | cci_rx_wr_valid0 | wr_rp_buf_valid;
assign wr_rp_hdr   = (cci_rx_wr_valid1)? cci_rx_hdr1 : ((cci_rx_wr_valid0)? cci_rx_hdr0 : wr_rp_buf_hdr);

// SOME DEBUG COUNTERS
reg   [39:0]          rx_wr_resp_ch1;
reg   [39:0]          rx_wr_resp_ch0;
reg   [39:0]          rx_wr_resp_tot;
reg   [39:0]          tx_wr_req_tot;

always @(posedge clk) begin
    if(~rst_n) begin
        rx_wr_resp_ch1 <= 0;
        rx_wr_resp_ch0 <= 0;
        rx_wr_resp_tot <= 0;

        tx_wr_req_tot  <= 0;
    end else begin
        rx_wr_resp_ch1 <= (cci_rx_wr_valid1)? rx_wr_resp_ch1 + 1'b1 : rx_wr_resp_ch1;
        rx_wr_resp_ch0 <= (cci_rx_wr_valid0)? rx_wr_resp_ch0 + 1'b1 : rx_wr_resp_ch0;
        rx_wr_resp_tot <= (wr_rp_valid)?      rx_wr_resp_tot + 1'b1 : rx_wr_resp_tot; 

        tx_wr_req_tot  <= (spl_tx_wr_valid)?  tx_wr_req_tot  + 1'b1 : tx_wr_req_tot;
    end
end

// RX WR is used by arbiter and cmd_server 
always @(posedge clk) begin
    if(~rst_n) begin
		//
		fc_rx_wr_tag   <= 0;
		fc_rx_wr_valid <= 1'b0;
		
		io_rx_wr_valid <= 1'b0;
        io_rx_wr_tag   <= 0;
    end 
    else begin
		fc_rx_wr_tag   <= wr_rp_hdr[`FPGA_CORE_TAG-1:0];
		fc_rx_wr_valid <= wr_rp_valid & ~wr_rp_hdr[13];

        io_rx_wr_valid <= wr_rp_valid & wr_rp_hdr[13];
        io_rx_wr_tag   <= wr_rp_hdr[12:0];
    end
end



endmodule        

