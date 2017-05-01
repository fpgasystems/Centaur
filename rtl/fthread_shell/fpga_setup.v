
`include "../framework_defines.vh"
`include "../afu_defines.vh"

module fpga_setup (
	input  wire                         clk,
	input  wire                         rst_n,

  output reg                          ctx_status_valid,
  
  // server_io <--> cmd server: RX_RD
  input  wire                         io_rx_csr_valid,
  input  wire [13:0]                  io_rx_csr_addr,
  input  wire [31:0]                  io_rx_csr_data,

  // TX WR
  input  wire                         setup_tx_wr_ready,
  output reg                          setup_tx_wr_valid,
  output reg   [`FPGA_SETUP_TAG-1:0]  setup_tx_wr_tag,
  output reg   [31:0]                 setup_tx_wr_addr,
  output reg   [511:0]                setup_tx_data,
  
  // setup pagetable
  input  wire  [1:0]                  pt_status,
  output wire                         pt_update,
	output wire  [31:0]                 pt_base_addr, 

  output wire                         spl_reset_t
);

reg   [31:0]                            pt_update_cycles = 0;

reg                                     afu_dsm_updated = 0;
wire                                    csr_afu_dsm_base_valid;
wire  [31:0]                            csr_afu_dsm_base;

reg                                     spl_dsm_updated = 0;
wire                                    csr_spl_dsm_base_valid;
wire  [31:0]                            csr_spl_dsm_base;

reg                                     vir_ctx_updated = 0;
wire  [31:0]                            csr_vir_ctx_base;
wire                                    csr_vir_ctx_valid;

reg                                     pt_status_updated = 0;
reg                                     afu_config_updated = 0;

wire                                    spl_dsm_update;
wire                                    afu_dsm_update;
wire                                    vir_ctx_update;
wire                                    pt_status_update;
wire                                    afu_config_update;
///////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////                           ///////////////////////////
//////////////////////////////////////////            CSR File             ////////////////////////
/////////////////////////////////////////////                           ///////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

csr_file csr_file(
        .clk                        (clk),
        .reset_n                    (rst_n),
        .spl_reset                  (spl_reset_t),
        // server_io --> csr_file
        .io_rx_csr_valid            (io_rx_csr_valid),
        .io_rx_csr_addr             (io_rx_csr_addr),
        .io_rx_csr_data             (io_rx_csr_data),    
        
        // csr_file --> dsm_module, spl_id, afu_id 
        .csr_spl_dsm_base           (csr_spl_dsm_base),
        .csr_spl_dsm_base_valid     (csr_spl_dsm_base_valid),
        .csr_spl_dsm_base_done      (spl_dsm_updated),

        .csr_afu_dsm_base           (csr_afu_dsm_base),
        .csr_afu_dsm_base_valid     (csr_afu_dsm_base_valid),
        .csr_afu_dsm_base_done      (afu_dsm_updated),
        
        // csr_file --> ctx_tracker, FPGA virtual memory space 
        .csr_ctx_base_valid         (csr_vir_ctx_valid),
        .csr_ctx_base               (csr_vir_ctx_base),
        .csr_ctx_base_done          (vir_ctx_updated)
    );

///////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////                           ///////////////////////////
//////////////////////////////////////////          Setup FSM              ////////////////////////
/////////////////////////////////////////////                           ///////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

assign spl_dsm_update    = csr_spl_dsm_base_valid & ~spl_dsm_updated;
assign afu_dsm_update    = csr_afu_dsm_base_valid & ~afu_dsm_updated;
assign vir_ctx_update    = csr_vir_ctx_valid      & (|pt_status) & ~vir_ctx_updated;
assign pt_status_update  = csr_vir_ctx_valid      & pt_status[0] & ~pt_status_updated;

assign afu_config_update = afu_dsm_updated & ~afu_config_updated;

always @(posedge clk) begin
  if (~rst_n | spl_reset_t) begin
    setup_tx_wr_addr   <= 0;
    setup_tx_wr_valid  <= 1'b0;
    setup_tx_wr_tag    <= 'h0;
    setup_tx_data      <= 0;

    spl_dsm_updated    <= 1'b0;
    afu_dsm_updated    <= 1'b0;
    vir_ctx_updated    <= 1'b0;
    pt_status_updated  <= 1'b0;
    afu_config_updated <= 1'b0;

    ctx_status_valid   <= 0;
  end
  else if( setup_tx_wr_ready ) begin
    casex ({spl_dsm_update, afu_dsm_update, afu_config_update, vir_ctx_update, pt_status_update})
      5'b1????: begin  // 
        setup_tx_wr_addr   <= csr_spl_dsm_base;
        setup_tx_wr_valid  <= 1'b1;
        setup_tx_wr_tag    <= 'h1;
        setup_tx_data      <= {480'b0, `SPL_ID};
        spl_dsm_updated    <= 1'b1;
      end
      5'b01???: begin // 
        setup_tx_wr_addr   <= csr_afu_dsm_base;
        setup_tx_wr_valid  <= 1'b1;
        setup_tx_wr_tag    <= 'h2;
        setup_tx_data      <= {448'b0, `AFU_ID};
        afu_dsm_updated    <= 1'b1;
      end
      5'b001??: begin
        setup_tx_wr_addr   <= (csr_afu_dsm_base + `ALLOC_OPERATORS_DSM_OFFSET);
        setup_tx_wr_valid  <= 1'b1;
        setup_tx_wr_tag    <= 'h3;
        setup_tx_data      <= {256'b0,  
                              {16'b0,`FTHREAD_8_PLACED_AFU}, 
                              {16'b0,`FTHREAD_7_PLACED_AFU}, 
                              {16'b0,`FTHREAD_6_PLACED_AFU}, 
                              {16'b0,`FTHREAD_5_PLACED_AFU},
                              {16'b0,`FTHREAD_4_PLACED_AFU}, 
                              {16'b0,`FTHREAD_3_PLACED_AFU}, 
                              {16'b0,`FTHREAD_2_PLACED_AFU}, 
                              {16'b0,`FTHREAD_1_PLACED_AFU} };
        afu_config_updated <= 1'b1;
      end
      5'b0001?: begin
        setup_tx_wr_addr   <= (csr_spl_dsm_base + `CTX_STATUS_DSM_OFFSET);
        setup_tx_wr_valid  <= 1'b1;
        setup_tx_wr_tag    <= 'h4;
        setup_tx_data      <= {384'b0, 127'b0, pt_status[1]};
        vir_ctx_updated    <= 1'b1;

      end
      5'b00001: begin
        setup_tx_wr_addr   <= (csr_afu_dsm_base + `PT_STATUS_DSM_OFFSET);
        setup_tx_wr_valid  <= 1'b1;
        setup_tx_wr_tag    <= 'h5;
        setup_tx_data      <= {480'b0, pt_update_cycles};
        pt_status_updated  <= 1'b1;

        ctx_status_valid   <= pt_status[0];
      end
      5'b00000: begin
        setup_tx_wr_addr   <= 0;
        setup_tx_wr_valid  <= 1'b0;
        setup_tx_wr_tag    <= 'h0;
        setup_tx_data      <= 0;
      end
    endcase
  end
end

///////////////////////////////////////////////////////////////////////////////////////////////////

assign pt_update    = csr_vir_ctx_valid;
assign pt_base_addr = csr_vir_ctx_base;
//
always @(posedge clk) begin
  if (~rst_n | spl_reset_t) begin
    pt_update_cycles    <= 0;
  end
  else begin
    if(pt_update & ~(|pt_status) ) begin 
      pt_update_cycles  <= pt_update_cycles + 1'b1;
    end 
  end
end

endmodule 