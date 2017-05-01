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


module csr_file(
    input  wire                             clk,
    input  wire                             reset_n,
    output wire                             spl_reset, 
 
    // csr_file --> dsm_module, spl_id, afu_id   
    output reg                              csr_spl_dsm_base_valid,
    output reg  [31:0]                      csr_spl_dsm_base,
    input  wire                             csr_spl_dsm_base_done,

    output reg                              csr_afu_dsm_base_valid,
    output reg  [31:0]                      csr_afu_dsm_base,
    input  wire                             csr_afu_dsm_base_done,
    
    // csr_file --> ctx_tracker, FPGA virtual memory space 
    output reg                              csr_ctx_base_valid,
    output reg  [31:0]                      csr_ctx_base,
    input  wire                             csr_ctx_base_done,
        
    // server_io --> csr_file
    input  wire                             io_rx_csr_valid,
    input  wire [13:0]                      io_rx_csr_addr,
    input  wire [31:0]                      io_rx_csr_data
);


    localparam [5:0]
        SPL_CSR_DSR_BASEL          = 6'b00_0000,   // 1000  //10'h244,      // 910
        SPL_CSR_DSR_BASEH          = 6'b00_0001,   // 1004  //10'h245,      // 914
        SPL_CSR_CTX_BASELL         = 6'b00_0010,   // 1008  //10'h246,      // 918
        SPL_CSR_CTX_BASELH         = 6'b00_0011,   // 100c  //10'h247;      // 91c   
        SPL_CSR_CTRL               = 6'b00_0100,   // 1010  //10'h248,      // 920     
        SPL_CSR_SCRATCH            = 6'b11_1111;   //10'h27f,      // 9fc
        
    localparam [5:0]
        AFU_CSR_DSR_BASEL          = 6'b00_0000,   //10'h280,      // a00
        AFU_CSR_DSR_BASEH          = 6'b00_0001,   //10'h281,      // a04
        AFU_CSR_CTX_BASEL          = 6'b00_0010,   //10'h282,      // a08
        AFU_CSR_CTX_BASEH          = 6'b00_0011,   //10'h283,      // a0c  
        AFU_CSR_SCRATCH            = 6'b11_1111,   //10'h2bf;      // afc 
        AFU_CSR_CMD_OPCODE         = 6'b00_1111; 
                
                      
    
    reg  [5:0]                     spl_dsr_base_hi;
    reg  [5:0]                     afu_dsr_base_hi;
    reg                            csr_reset = 0;
    reg                            csr_enable = 0;
    
    assign spl_reset  = csr_reset;
    //--------------------------------------------------------------------
    // RX - spl_csr<--spl_io                 
    //--------------------------------------------------------------------
    always @(posedge clk) begin
        if (~reset_n) begin
            csr_spl_dsm_base_valid <= 1'b0;
            csr_afu_dsm_base_valid <= 1'b0;
            csr_ctx_base_valid     <= 1'b0;

            spl_dsr_base_hi        <= 0;
            afu_dsr_base_hi        <= 0;

            csr_reset              <= 0;
            csr_enable             <= 0;
        end 
        
        else begin             
            csr_reset     <= 1'b0;   
            csr_enable    <= 0;

            if ( csr_ctx_base_done )      csr_ctx_base_valid     <= 1'b0;
            if ( csr_spl_dsm_base_done )  csr_spl_dsm_base_valid <= 1'b0;  
            if ( csr_afu_dsm_base_done )  csr_afu_dsm_base_valid <= 1'b0; 

            if ( csr_spl_dsm_base_done )  spl_dsr_base_hi        <= 0;  
            if ( csr_afu_dsm_base_done )  afu_dsr_base_hi        <= 0;                
                                               
            if (io_rx_csr_valid) begin
                if (io_rx_csr_addr[13:6] == 8'h10) begin
                    case (io_rx_csr_addr[5:0]) 
                        SPL_CSR_DSR_BASEH : begin                
                            spl_dsr_base_hi <= io_rx_csr_data[5:0];                                                         
                        end

                        SPL_CSR_DSR_BASEL : begin                
                            csr_spl_dsm_base_valid <= 1'b1;
                            csr_spl_dsm_base       <= {spl_dsr_base_hi, io_rx_csr_data[31:6]};                           
                        end

                        SPL_CSR_CTX_BASELH : begin                
                            csr_ctx_base[31:26] <= io_rx_csr_data[5:0];                          
                        end

                        SPL_CSR_CTX_BASELL : begin                
                            csr_ctx_base[25:0] <= io_rx_csr_data[31:6];                            
                            csr_ctx_base_valid <= 1'b1;
                        end
                        
                        SPL_CSR_CTRL : begin                
                            csr_reset  <= io_rx_csr_data[0];
                            csr_enable <= io_rx_csr_data[1];
                        end  								
                    endcase
                end
                
                else if (io_rx_csr_addr[13:6] == 8'h8a) begin
                    case (io_rx_csr_addr[5:0]) 
                        AFU_CSR_DSR_BASEH : begin                
                            afu_dsr_base_hi <= io_rx_csr_data[5:0];                               
                        end

                        AFU_CSR_DSR_BASEL : begin                
                            csr_afu_dsm_base_valid <= 1'b1;                            
                            csr_afu_dsm_base       <= {afu_dsr_base_hi, io_rx_csr_data[31:6]};                                            
                        end 
                    endcase
                end
            end
        end
    end // rx csr                

endmodule        
