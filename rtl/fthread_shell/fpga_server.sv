/*
 * Copyright (C) 2017 Systems Group, ETHZ

 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at

 * http://www.apache.org/licenses/LICENSE-2.0

 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
 
// What is the protocol?
/*
    Every AAL Service is one software thread that can issue one or more HW threads at the same time 
    The request for HW threads occur sequentially, 
    When a command to be requested the following steps should occur on the software sid:
      - Workspace allocated for the command (either physical or virtual).
      - If virtual workspace, a setContextWorkspace is executed first
      - Then the command opcode is written to csr
      - The command cntext base (or configuration space) is written to csr
      - Then we expect the command to be scheduled, and we can move to request another command if the maximum number of 
        commands is not exceeded.
*/
`include "../spl_defines.vh"
`include "../framework_defines.vh"

module fpga_server (
    input                                      clk,
    input                                      rst_n,
    // CCI TX read request
    input  wire                                cci_tx_rd_almostfull,    
    output wire                                spl_tx_rd_valid,
    output wire [60:0]                         spl_tx_rd_hdr,
    
    // CCI TX write request
    input  wire                                cci_tx_wr_almostfull,
    output wire                                spl_tx_wr_valid,
    output wire                                spl_tx_intr_valid,
    output wire [60:0]                         spl_tx_wr_hdr,    
    output wire [511:0]                        spl_tx_data,
    
    // CCI RX read response
    input  wire                                cci_rx_rd_valid,
    input  wire                                cci_rx_wr_valid0,
    input  wire                                cci_rx_cfg_valid,
    input  wire                                cci_rx_intr_valid0,
    input  wire                                cci_rx_umsg_valid,
    input  wire [`CCI_RX_HDR_WIDTH-1:0]        cci_rx_hdr0,
    input  wire [511:0]                        cci_rx_data,
    
    // CCI RX write response
    input  wire                                cci_rx_wr_valid1,
    input  wire                                cci_rx_intr_valid1,
    input  wire [`CCI_RX_HDR_WIDTH-1:0]        cci_rx_hdr1,
    //////////////////////// Toward FThreads ////////////////////////////
    //-------------- read interface
    input  wire                                ft_tx_rd_valid[`NUMBER_OF_FTHREADS-1:0],
    input  wire [67:0]                         ft_tx_rd_hdr[`NUMBER_OF_FTHREADS-1:0],
    output wire                                ft_tx_rd_ready[`NUMBER_OF_FTHREADS-1:0],

    output wire                                ft_rx_rd_valid[`NUMBER_OF_FTHREADS-1:0],
    output wire [511:0]                        ft_rx_data[`NUMBER_OF_FTHREADS-1:0],
    output wire [`FTHREAD_TAG-1:0]             ft_rx_rd_tag[`NUMBER_OF_FTHREADS-1:0],
    //-------------- write interface
    input  wire [71:0]                         ft_tx_wr_hdr[`NUMBER_OF_FTHREADS-1:0], 
    input  wire [511:0]                        ft_tx_data[`NUMBER_OF_FTHREADS-1:0],
    input  wire                                ft_tx_wr_valid[`NUMBER_OF_FTHREADS-1:0],
    output wire                                ft_tx_wr_ready[`NUMBER_OF_FTHREADS-1:0],

    output wire                                ft_rx_wr_valid[`NUMBER_OF_FTHREADS-1:0], 
    output wire [`FTHREAD_TAG-1:0]             ft_rx_wr_tag[`NUMBER_OF_FTHREADS-1:0],
    //--------------------------  Jobs to FThreads  ----------------------------------//
    output wire [`CMD_LINE_WIDTH-1:0]          fthread_job[`NUMBER_OF_FTHREADS-1:0], 
    output wire                                fthread_job_valid[`NUMBER_OF_FTHREADS-1:0], 
    input  wire                                fthread_done[`NUMBER_OF_FTHREADS-1:0], 
    //----------- CMD Server <--> FThreads
    output reg                                 ft_reset[`NUMBER_OF_FTHREADS-1:0]

);


////////////////////////////////// Pagetable 
wire  [57:0]                     afu_virt_wr_addr;
wire                             pt_re_wr;
wire  [31:0]                     afu_phy_wr_addr;
wire                             afu_phy_wr_addr_valid;
// afu_virt_raddr --> afu_phy_raddr
wire  [57:0]                     afu_virt_rd_addr;
wire                             pt_re_rd;
wire  [31:0]                     afu_phy_rd_addr;
wire                             afu_phy_rd_addr_valid;
// pagetable <--> server_io
wire  [31:0]                     pt_tx_rd_addr;
wire  [`PAGETABLE_TAG-1:0]       pt_tx_rd_tag;
wire                             pt_tx_rd_valid;
wire                             pt_tx_rd_ready;

wire  [255:0]                    pt_rx_data;
wire  [`PAGETABLE_TAG-1:0]       pt_rx_rd_tag;
wire                             pt_rx_rd_valid;
// pagetable <--> fc        
wire  [1:0]                      pt_status;
wire                             pt_update;
wire  [31:0]                     pt_base_addr;

wire  [`PTE_WIDTH-1:0]           first_page_base_addr;
wire                             first_page_base_addr_valid;

wire [57:0]                      ws_virt_base_addr;
wire                             ws_virt_base_addr_valid;
//////////////////////////////////////////// fpga core
// server_io <--> fpga core: RX_RD CFG
wire                             io_rx_csr_valid;
wire  [13:0]                     io_rx_csr_addr;
wire  [31:0]                     io_rx_csr_data;
// server_io <--> fpga core: TX_WR
wire                             fc_tx_wr_ready;
wire                             fc_tx_wr_valid;
wire  [31:0]                     fc_tx_wr_addr;
wire  [`FPGA_CORE_TAG-1:0]       fc_tx_wr_tag;
wire  [511:0]                    fc_tx_data;
// server_io <--> fpga core: TX_RD
wire                             fc_tx_rd_ready;
wire                             fc_tx_rd_valid;
wire  [31:0]                     fc_tx_rd_addr;
wire  [`FPGA_CORE_TAG-1:0]       fc_tx_rd_tag;
// server_io <--> fpga core: RX_WR
wire                             fc_rx_wr_valid;
wire  [`FPGA_CORE_TAG-1:0]       fc_rx_wr_tag;
// server_io <--> fpga core: RX_RD
wire                             fc_rx_rd_valid;
wire  [`FPGA_CORE_TAG-1:0]       fc_rx_rd_tag;
wire  [511:0]                    fc_rx_data;

wire  [`CMD_LINE_WIDTH-1:0]      cmd_line;
wire                             cmd_valid;

wire                             spl_reset;
/////////////////////////////////////////// Arbiter
// io_requester <--> arbiter
// TX_RD request, 
wire                             cor_tx_rd_ready;
wire                             cor_tx_rd_valid;
wire  [70:0]                     cor_tx_rd_hdr;
// TX_WR request, 
wire                             cor_tx_wr_ready;    
wire                             cor_tx_wr_valid;
wire  [74:0]                     cor_tx_wr_hdr; 
wire  [511:0]                    cor_tx_data;  
////////////////// server_io <--> arbiter           
// RX_RD response, 
wire                             io_rx_rd_valid;
wire  [511:0]                    io_rx_data;
wire  [12:0]                     io_rx_rd_tag;
// RX_WR response,
wire                             io_rx_wr_valid; 
wire  [12:0]                     io_rx_wr_tag;
//////////////////// io_requester <--> server_io
// TX_RD request, 
wire                             rq_tx_rd_ready;
wire                             rq_tx_rd_valid;
wire  [44:0]                     rq_tx_rd_hdr; 
// TX_WR request
wire                             rq_tx_wr_ready;    
wire                             rq_tx_wr_valid;
wire  [48:0]                     rq_tx_wr_hdr; 
wire  [511:0]                    rq_tx_data;

////////////////////////////////////////////////////////////////////////////////
reg                               cci_rx_rd_valid_reg;
reg                               cci_rx_wr_valid0_reg;
reg                               cci_rx_cfg_valid_reg;
reg                               cci_rx_intr_valid0_reg;
reg                               cci_rx_umsg_valid_reg;
reg [`CCI_RX_HDR_WIDTH-1:0]       cci_rx_hdr0_reg;
reg [511:0]                       cci_rx_data_reg;
    
// CCI RX write response
reg                               cci_rx_wr_valid1_reg;
reg                               cci_rx_intr_valid1_reg;
reg [`CCI_RX_HDR_WIDTH-1:0]       cci_rx_hdr1_reg;

reg                               cci_rx_rd_valid_reg2;
reg                               cci_rx_wr_valid0_reg2;
reg                               cci_rx_cfg_valid_reg2;
reg                               cci_rx_intr_valid0_reg2;
reg                               cci_rx_umsg_valid_reg2;
reg [`CCI_RX_HDR_WIDTH-1:0]       cci_rx_hdr0_reg2;
reg [511:0]                       cci_rx_data_reg2;
    
// CCI RX write response
reg                               cci_rx_wr_valid1_reg2;
reg                               cci_rx_intr_valid1_reg2;
reg [`CCI_RX_HDR_WIDTH-1:0]       cci_rx_hdr1_reg2;

integer i;

always@(posedge clk) begin
    for(i = 0; i < `NUMBER_OF_FTHREADS; i = i + 1) begin 
        ft_reset[i] <= spl_reset;
    end 
end


always@(posedge clk) begin 
    if(~rst_n | spl_reset) begin 
        cci_rx_rd_valid_reg      <= 0;
        cci_rx_wr_valid0_reg     <= 0;
        cci_rx_cfg_valid_reg     <= 0;
        cci_rx_intr_valid0_reg   <= 0;
        cci_rx_umsg_valid_reg    <= 0;
        cci_rx_hdr0_reg          <= 0;
        //cci_rx_data_reg          <= 0;
    
        cci_rx_wr_valid1_reg     <= 0;
        cci_rx_intr_valid1_reg   <= 0; 
        cci_rx_hdr1_reg          <= 0;

        cci_rx_rd_valid_reg2     <= 0;
        cci_rx_wr_valid0_reg2    <= 0;
        cci_rx_cfg_valid_reg2    <= 0;
        cci_rx_intr_valid0_reg2  <= 0;
        cci_rx_umsg_valid_reg2   <= 0;
        cci_rx_hdr0_reg2         <= 0;
        //cci_rx_data_reg2         <= 0;
    
        cci_rx_wr_valid1_reg2    <= 0;
        cci_rx_intr_valid1_reg2  <= 0; 
        cci_rx_hdr1_reg2         <= 0;
    end 
    else begin 
        cci_rx_rd_valid_reg      <= cci_rx_rd_valid;
        cci_rx_wr_valid0_reg     <= cci_rx_wr_valid0;
        cci_rx_cfg_valid_reg     <= cci_rx_cfg_valid;
        cci_rx_intr_valid0_reg   <= cci_rx_intr_valid0;
        cci_rx_umsg_valid_reg    <= cci_rx_umsg_valid;
        cci_rx_hdr0_reg          <= cci_rx_hdr0;
        cci_rx_data_reg          <= cci_rx_data;
    
        cci_rx_wr_valid1_reg     <= cci_rx_wr_valid1;
        cci_rx_intr_valid1_reg   <= cci_rx_intr_valid1; 
        cci_rx_hdr1_reg          <= cci_rx_hdr1;

        cci_rx_rd_valid_reg2     <= cci_rx_rd_valid_reg;
        cci_rx_wr_valid0_reg2    <= cci_rx_wr_valid0_reg;
        cci_rx_cfg_valid_reg2    <= cci_rx_cfg_valid_reg;
        cci_rx_intr_valid0_reg2  <= cci_rx_intr_valid0_reg;
        cci_rx_umsg_valid_reg2   <= cci_rx_umsg_valid_reg;
        cci_rx_hdr0_reg2         <= cci_rx_hdr0_reg;
        cci_rx_data_reg2         <= cci_rx_data_reg;
    
        cci_rx_wr_valid1_reg2    <= cci_rx_wr_valid1_reg;
        cci_rx_intr_valid1_reg2  <= cci_rx_intr_valid1_reg; 
        cci_rx_hdr1_reg2         <= cci_rx_hdr1_reg;
    end 
end 

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////                           /////////////////////////////////////////////////
//////////////////////////////////////////            Server IO            //////////////////////////////////////////////
/////////////////////////////////////////////                           /////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

server_io server_io(
    .clk                      (clk),
    .rst_n                    (rst_n & ~spl_reset),
    
    /////////////////////////////////////  CCI Interface  /////////////////////////////////////    
    // CCI TX read request
    .cci_tx_rd_almostfull     (cci_tx_rd_almostfull),    
    .spl_tx_rd_valid          (spl_tx_rd_valid),
    .spl_tx_rd_hdr            (spl_tx_rd_hdr),
    
    // CCI TX write request
    .cci_tx_wr_almostfull     (cci_tx_wr_almostfull),
    .spl_tx_wr_valid          (spl_tx_wr_valid),
    .spl_tx_intr_valid        (spl_tx_intr_valid),
    .spl_tx_wr_hdr            (spl_tx_wr_hdr),    
    .spl_tx_data              (spl_tx_data),
    
    // CCI RX read response
    .cci_rx_rd_valid          (cci_rx_rd_valid_reg2),
    .cci_rx_wr_valid0         (cci_rx_wr_valid0_reg2),
    .cci_rx_cfg_valid         (cci_rx_cfg_valid_reg2),
    .cci_rx_intr_valid0       (cci_rx_intr_valid0_reg2),
    .cci_rx_umsg_valid        (cci_rx_umsg_valid_reg2),
    .cci_rx_hdr0              (cci_rx_hdr0_reg2),
    .cci_rx_data              (cci_rx_data_reg2),
    
    // CCI RX write response
    .cci_rx_wr_valid1         (cci_rx_wr_valid1_reg2),
    .cci_rx_intr_valid1       (cci_rx_intr_valid1_reg2),
    .cci_rx_hdr1              (cci_rx_hdr1_reg2),        
    
    //////////////////////////////// Server components Interfaces /////////////////////////////
    // server_io <--> fc: RX_RD
    .io_rx_csr_valid          (io_rx_csr_valid),
    .io_rx_csr_addr           (io_rx_csr_addr),
    .io_rx_csr_data           (io_rx_csr_data),
    
    // server_io <--> fpga core: TX_WR
    .fc_tx_wr_ready           (fc_tx_wr_ready),
    .fc_tx_wr_valid           (fc_tx_wr_valid),
    .fc_tx_wr_addr            (fc_tx_wr_addr),
    .fc_tx_wr_tag             (fc_tx_wr_tag),
    .fc_tx_data               (fc_tx_data),
	 
	 // server_io <--> fpga core: TX_RD
    .fc_tx_rd_ready           (fc_tx_rd_ready),
    .fc_tx_rd_valid           (fc_tx_rd_valid),
    .fc_tx_rd_addr            (fc_tx_rd_addr),
    .fc_tx_rd_tag             (fc_tx_rd_tag),
	 
	 // server_io <--> fpga core: RX_WR
    .fc_rx_wr_valid           (fc_rx_wr_valid),
    .fc_rx_wr_tag             (fc_rx_wr_tag),
	 
	 // server_io <--> fpga core: RX_RD
    .fc_rx_rd_valid           (fc_rx_rd_valid),
    .fc_rx_rd_tag             (fc_rx_rd_tag),
    .fc_rx_data               (fc_rx_data),

    // server_io <--> io_requester:
    .rq_tx_rd_ready           (rq_tx_rd_ready),
    .rq_tx_rd_valid           (rq_tx_rd_valid),
    .rq_tx_rd_hdr             (rq_tx_rd_hdr),
    
    .rq_tx_wr_ready           (rq_tx_wr_ready),    
    .rq_tx_wr_valid           (rq_tx_wr_valid),
    .rq_tx_wr_hdr             (rq_tx_wr_hdr), 
    .rq_tx_data               (rq_tx_data),

    // server_io <--> arbiter: RX_RD
    .io_rx_rd_valid           (io_rx_rd_valid),
    .io_rx_data               (io_rx_data),
    .io_rx_rd_tag             (io_rx_rd_tag),
    // server_io <--> arbiter: RX_WR
    .io_rx_wr_valid           (io_rx_wr_valid), 
    .io_rx_wr_tag             (io_rx_wr_tag)
);


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////                           /////////////////////////////////////////////////
//////////////////////////////////////////         Pagetable Module        //////////////////////////////////////////////
/////////////////////////////////////////////                           /////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pt_module pt_module(
    .clk                        (clk),
    .rst_n                      (rst_n & ~spl_reset),
    
    ///////////////////// pagetable <--> io_requester
    // afu_virt_waddr --> afu_phy_waddr
    .afu_virt_wr_addr           (afu_virt_wr_addr),
    .pt_re_wr                   (pt_re_wr),
    .afu_phy_wr_addr            (afu_phy_wr_addr),
    .afu_phy_wr_addr_valid      (afu_phy_wr_addr_valid),
    // afu_virt_raddr --> afu_phy_raddr
    .afu_virt_rd_addr           (afu_virt_rd_addr),
    .pt_re_rd                   (pt_re_rd),
    .afu_phy_rd_addr            (afu_phy_rd_addr),
    .afu_phy_rd_addr_valid      (afu_phy_rd_addr_valid),
    
    // fpga core <--> pt_module: TX_RD
    .pt_tx_rd_addr              (pt_tx_rd_addr),
    .pt_tx_rd_tag               (pt_tx_rd_tag),
    .pt_tx_rd_valid             (pt_tx_rd_valid),
    .pt_tx_rd_ready             (pt_tx_rd_ready),
    // fpga core <--> pt_module: RX_RD
    .pt_rx_data                 (pt_rx_data),
    .pt_rx_rd_tag               (pt_rx_rd_tag),
    .pt_rx_rd_valid             (pt_rx_rd_valid),

    /////////////////////// pagetable <--> fc        
    .pt_status                  (pt_status),
    .pt_update                  (pt_update),
    .pt_base_addr               (pt_base_addr),

    .first_page_base_addr       (first_page_base_addr),
    .first_page_base_addr_valid (first_page_base_addr_valid),
    .ws_virt_base_addr          (ws_virt_base_addr),
    .ws_virt_base_addr_valid    (ws_virt_base_addr_valid)
);

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////                           /////////////////////////////////////////////////
//////////////////////////////////////////           FPGA Core             //////////////////////////////////////////////
/////////////////////////////////////////////                           /////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

fpga_core  fpga_core(
    //
    .clk                        (clk),
    .rst_n                      (rst_n),

    // server_io <--> fpga core: RX_RD
    .io_rx_csr_valid            (io_rx_csr_valid),
    .io_rx_csr_addr             (io_rx_csr_addr),
    .io_rx_csr_data             (io_rx_csr_data),

    .spl_reset                  (spl_reset),
    
    // server_io <--> fpga core: TX_WR
    .fc_tx_wr_ready             (fc_tx_wr_ready),
    .fc_tx_wr_valid             (fc_tx_wr_valid),
    .fc_tx_wr_addr              (fc_tx_wr_addr),
    .fc_tx_wr_tag               (fc_tx_wr_tag),
    .fc_tx_data                 (fc_tx_data),
	 
	 // server_io <--> fpga core: TX_RD
    .fc_tx_rd_ready             (fc_tx_rd_ready),
    .fc_tx_rd_valid             (fc_tx_rd_valid),
    .fc_tx_rd_addr              (fc_tx_rd_addr),
    .fc_tx_rd_tag               (fc_tx_rd_tag),
	 
	 // server_io <--> fpga core: RX_WR
    .fc_rx_wr_valid             (fc_rx_wr_valid),
    .fc_rx_wr_tag               (fc_rx_wr_tag),
	 
	 // server_io <--> fpga core: RX_RD
    .fc_rx_rd_valid             (fc_rx_rd_valid),
    .fc_rx_rd_tag               (fc_rx_rd_tag),
    .fc_rx_data                 (fc_rx_data),

    // fpga core <--> pt_module: TX_RD
    .pt_tx_rd_addr              (pt_tx_rd_addr),
    .pt_tx_rd_tag               (pt_tx_rd_tag),
    .pt_tx_rd_valid             (pt_tx_rd_valid),
    .pt_tx_rd_ready             (pt_tx_rd_ready),
    // fpga core <--> pt_module: RX_RD
    .pt_rx_data                 (pt_rx_data),
    .pt_rx_rd_tag               (pt_rx_rd_tag),
    .pt_rx_rd_valid             (pt_rx_rd_valid),

    // pagetable <--> fpga core
    .pt_status                  (pt_status),
    .pt_update                  (pt_update),
    .pt_base_addr               (pt_base_addr),

    // fpga core -> fthreads
    .fthread_job                (fthread_job), 
    .fthread_job_valid          (fthread_job_valid), 
    .fthread_done               (fthread_done),

    .first_page_addr            (first_page_base_addr),
    .first_page_addr_valid      (first_page_base_addr_valid),
    .ws_virt_base_addr          (ws_virt_base_addr),
    .ws_virt_base_addr_valid    (ws_virt_base_addr_valid)
);


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////                           /////////////////////////////////////////////////
//////////////////////////////////////////         FThreads Arbiter        //////////////////////////////////////////////
/////////////////////////////////////////////                           /////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

DataArbiter DataArbiter(
    .clk                      (clk),
    .rst_n                    (rst_n & ~spl_reset),

    ////////////////// io_requester <--> arbiter
    // RD TX
    .cor_tx_rd_ready          (cor_tx_rd_ready),
    .cor_tx_rd_valid          (cor_tx_rd_valid),
    .cor_tx_rd_hdr            (cor_tx_rd_hdr),

    // WR TX
    .cor_tx_wr_ready          (cor_tx_wr_ready),    
    .cor_tx_wr_valid          (cor_tx_wr_valid),
    .cor_tx_wr_hdr            (cor_tx_wr_hdr), 
    .cor_tx_data              (cor_tx_data),
    
    ///////////////////// arbiter <--> server_io   
    // RX_RD response,
    .io_rx_rd_valid           (io_rx_rd_valid),
    .io_rx_data               (io_rx_data),
    .io_rx_rd_tag             (io_rx_rd_tag),

    // RX_WR response, 
    .io_rx_wr_valid           (io_rx_wr_valid), 
    .io_rx_wr_tag             (io_rx_wr_tag),

    //////////////////////// Toward FThreads ////////////////////////////
    .ft_tx_rd_valid           (ft_tx_rd_valid),
    .ft_tx_rd_hdr             (ft_tx_rd_hdr),
    .ft_tx_rd_ready           (ft_tx_rd_ready),

    .ft_rx_rd_valid           (ft_rx_rd_valid),
    .ft_rx_data               (ft_rx_data),
    .ft_rx_rd_tag             (ft_rx_rd_tag),
    //-------------- write interface
    .ft_tx_wr_hdr             (ft_tx_wr_hdr), 
    .ft_tx_data               (ft_tx_data),
    .ft_tx_wr_valid           (ft_tx_wr_valid),
    .ft_tx_wr_ready           (ft_tx_wr_ready),

    .ft_rx_wr_valid           (ft_rx_wr_valid), 
    .ft_rx_wr_tag             (ft_rx_wr_tag)
);
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////                           /////////////////////////////////////////////////
//////////////////////////////////////////          IO Requester           //////////////////////////////////////////////
/////////////////////////////////////////////                           /////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

io_requester io_requester(
    .clk                      (clk),
    .rst_n                    (rst_n & ~spl_reset),

    ////////////////// io_requester <--> arbiter
    // RD TX
    .cor_tx_rd_ready          (cor_tx_rd_ready),
    .cor_tx_rd_valid          (cor_tx_rd_valid),
    .cor_tx_rd_hdr            (cor_tx_rd_hdr),
    // WR TX
    .cor_tx_wr_ready          (cor_tx_wr_ready),    
    .cor_tx_wr_valid          (cor_tx_wr_valid),
    .cor_tx_wr_hdr            (cor_tx_wr_hdr), 
    .cor_tx_data              (cor_tx_data),

    //////////////////// io_requester <--> server_io
    // TX_RD request, 
    .rq_tx_rd_ready           (rq_tx_rd_ready),
    .rq_tx_rd_valid           (rq_tx_rd_valid),
    .rq_tx_rd_hdr             (rq_tx_rd_hdr),
    
    // TX_WR request,
    .rq_tx_wr_ready           (rq_tx_wr_ready),    
    .rq_tx_wr_valid           (rq_tx_wr_valid),
    .rq_tx_wr_hdr             (rq_tx_wr_hdr), 
    .rq_tx_data               (rq_tx_data),

    ///////////////////// io_requester <--> pagetable
    // afu_virt_waddr --> afu_phy_waddr
    .afu_virt_wr_addr         (afu_virt_wr_addr),
    .pt_re_wr                 (pt_re_wr),
    .afu_phy_wr_addr          (afu_phy_wr_addr),
    .afu_phy_wr_addr_valid    (afu_phy_wr_addr_valid),
    // afu_virt_raddr --> afu_phy_raddr
    .afu_virt_rd_addr         (afu_virt_rd_addr),
    .pt_re_rd                 (pt_re_rd),
    .afu_phy_rd_addr          (afu_phy_rd_addr),
    .afu_phy_rd_addr_valid    (afu_phy_rd_addr_valid)
);


endmodule

