// Copyright (c) 2013-2015, Intel Corporation
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice,
// this list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation
// and/or other materials provided with the distribution.
// * Neither the name of Intel Corporation nor the names of its contributors
// may be used to endorse or promote products derived from this software
// without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.


module cci_std_afu(
  // Link/Protocol (LP) clocks and reset
  input  /*var*/  logic             vl_clk_LPdomain_32ui,                      // CCI Inteface Clock. 32ui link/protocol clock domain.
  input  /*var*/  logic             vl_clk_LPdomain_16ui,                      // 2x CCI interface clock. Synchronous.16ui link/protocol clock domain.
  input  /*var*/  logic             ffs_vl_LP32ui_lp2sy_SystemReset_n,         // System Reset
  input  /*var*/  logic             ffs_vl_LP32ui_lp2sy_SoftReset_n,           // CCI-S soft reset

  // Native CCI Interface (cache line interface for back end)
  /* Channel 0 can receive READ, WRITE, WRITE CSR responses.*/
  input  /*var*/  logic      [17:0] ffs_vl18_LP32ui_lp2sy_C0RxHdr,             // System to LP header
  input  /*var*/  logic     [511:0] ffs_vl512_LP32ui_lp2sy_C0RxData,           // System to LP data 
  input  /*var*/  logic             ffs_vl_LP32ui_lp2sy_C0RxWrValid,           // RxWrHdr valid signal 
  input  /*var*/  logic             ffs_vl_LP32ui_lp2sy_C0RxRdValid,           // RxRdHdr valid signal
  input  /*var*/  logic             ffs_vl_LP32ui_lp2sy_C0RxCgValid,           // RxCgHdr valid signal
  input  /*var*/  logic             ffs_vl_LP32ui_lp2sy_C0RxUgValid,           // Rx Umsg Valid signal
  input  /*var*/  logic             ffs_vl_LP32ui_lp2sy_C0RxIrValid,           // Rx Interrupt valid signal
  /* Channel 1 reserved for WRITE RESPONSE ONLY */
  input  /*var*/  logic      [17:0] ffs_vl18_LP32ui_lp2sy_C1RxHdr,             // System to LP header (Channel 1)
  input  /*var*/  logic             ffs_vl_LP32ui_lp2sy_C1RxWrValid,           // RxData valid signal (Channel 1)
  input  /*var*/  logic             ffs_vl_LP32ui_lp2sy_C1RxIrValid,           // Rx Interrupt valid signal (Channel 1)

  /*Channel 0 reserved for READ REQUESTS ONLY */        
  output /*var*/  logic      [60:0] ffs_vl61_LP32ui_sy2lp_C0TxHdr,             // System to LP header 
  output /*var*/  logic             ffs_vl_LP32ui_sy2lp_C0TxRdValid,           // TxRdHdr valid signals 
  /*Channel 1 reserved for WRITE REQUESTS ONLY */       
  output /*var*/  logic      [60:0] ffs_vl61_LP32ui_sy2lp_C1TxHdr,             // System to LP header
  output /*var*/  logic     [511:0] ffs_vl512_LP32ui_sy2lp_C1TxData,           // System to LP data 
  output /*var*/  logic             ffs_vl_LP32ui_sy2lp_C1TxWrValid,           // TxWrHdr valid signal
  output /*var*/  logic             ffs_vl_LP32ui_sy2lp_C1TxIrValid,           // Tx Interrupt valid signal
  /* Tx push flow control */
  input  /*var*/  logic             ffs_vl_LP32ui_lp2sy_C0TxAlmFull,           // Channel 0 almost full
  input  /*var*/  logic             ffs_vl_LP32ui_lp2sy_C1TxAlmFull,           // Channel 1 almost full

  input  /*var*/  logic             ffs_vl_LP32ui_lp2sy_InitDnForSys           // System layer is aok to run
);

/* User AFU goes here
*/
    
    
    fpga_arch fpga_arch(
        .clk                        (vl_clk_LPdomain_32ui),
        .Clk_400                    (vl_clk_LPdomain_16ui),
        .rst_n                      (ffs_vl_LP32ui_lp2sy_SystemReset_n),
        .linkup                     (ffs_vl_LP32ui_lp2sy_InitDnForSys),
    
        // CCI TX read request
        .cci_tx_rd_almostfull       (ffs_vl_LP32ui_lp2sy_C0TxAlmFull),
        .spl_tx_rd_valid            (ffs_vl_LP32ui_sy2lp_C0TxRdValid),
        .spl_tx_rd_hdr              (ffs_vl61_LP32ui_sy2lp_C0TxHdr),
    
        // CCI TX write request
        .cci_tx_wr_almostfull       (ffs_vl_LP32ui_lp2sy_C1TxAlmFull),
        .spl_tx_wr_valid            (ffs_vl_LP32ui_sy2lp_C1TxWrValid),
        .spl_tx_intr_valid          (ffs_vl_LP32ui_sy2lp_C1TxIrValid),
        .spl_tx_wr_hdr              (ffs_vl61_LP32ui_sy2lp_C1TxHdr),    
        .spl_tx_data                (ffs_vl512_LP32ui_sy2lp_C1TxData),
    
        // CCI RX read response
        .cci_rx_rd_valid            (ffs_vl_LP32ui_lp2sy_C0RxRdValid),
        .cci_rx_wr_valid0           (ffs_vl_LP32ui_lp2sy_C0RxWrValid),
        .cci_rx_cfg_valid           (ffs_vl_LP32ui_lp2sy_C0RxCgValid),
        .cci_rx_intr_valid0         (ffs_vl_LP32ui_lp2sy_C0RxIrValid),
        .cci_rx_umsg_valid          (ffs_vl_LP32ui_lp2sy_C0RxUgValid),
        .cci_rx_hdr0                (ffs_vl18_LP32ui_lp2sy_C0RxHdr),
        .cci_rx_data                (ffs_vl512_LP32ui_lp2sy_C0RxData),
    
        // CCI RX write response
        .cci_rx_wr_valid1           (ffs_vl_LP32ui_lp2sy_C1RxWrValid),
        .cci_rx_intr_valid1         (ffs_vl_LP32ui_lp2sy_C1RxIrValid),
        .cci_rx_hdr1                (ffs_vl18_LP32ui_lp2sy_C1RxHdr)
    );

endmodule
