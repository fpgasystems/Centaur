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


`ifndef SPL_DEFINES_VH
`define SPL_DEFINES_VH

//     `ifdef MAX_TRANSFER_SIZE_4
//         `define MAX_TRANSFER_SIZE       3'h4
//     `elsif MAX_TRANSFER_SIZE_3
//         `define MAX_TRANSFER_SIZE       3'h3  
//     `elsif MAX_TRANSFER_SIZE_2
   // `ifdef MAX_TRANSFER_SIZE_2
   //     `define MAX_TRANSFER_SIZE       3'h2
    //`elsif MAX_TRANSFER_SIZE_1
        `define MAX_TRANSFER_SIZE       3'h1  
    //`else
   //     *** must define MAX_TRANSFER_SIZE_1 or MAX_TRANSFER_SIZE_2 ***
  //  `endif

    `define AFU_IF_TX_HDR_WIDTH    99    
    `define VIR_ADDR_WIDTH         42
    
    `define SPL_WTAG_WIDTH         6
    `define MAX_NUM_WTAGS          2**`SPL_WTAG_WIDTH
    
    `define SPL_TAG_WIDTH          6  
    `define MAX_NUM_TAGS           2**`SPL_TAG_WIDTH
          
    `define SPL_TWQ_WIDTH          566      // data(512) + len(6) + cmd(2) + addr(32) +tag(14) = 566
    `define SPL_TRQ_WIDTH          38+`SPL_TAG_WIDTH        // addr(32) + len(6) + TAG_WIDTH

//    `define CCI_REQ_WR_DSR         4'b0000
    `define CCI_REQ_WR_THRU        4'b0001
    `define CCI_REQ_WR_LINE        4'b0010  
    `define CCI_REQ_WR             `CCI_REQ_WR_LINE
    `define CCI_REQ_RD             4'b0100
    `define CCI_REQ_WR_FENCE       4'b0101
//    `define CCI_REQ_TASKDONE       4'b0111

    `define CCI_RSP_WR_CSR         4'b0000
    `define CCI_RSP_RD_CSR         4'b1100
    `define CCI_RSP_WR             4'b0001
    `define CCI_RSP_RD             4'b0100
    
    `define CCI_DATA_WIDTH              512
    `define CCI_RX_HDR_WIDTH            18
    `define CCI_TX_HDR_WIDTH            61
           
    `define COR_REQ_WR_DSR         2'b00
    `define COR_REQ_WR_THRU        2'b01
    `define COR_REQ_WR_LINE        2'b10  
    `define COR_REQ_WR_FENCE       2'b11
        
    `define PCIE_FMTTYPE_MEM_READ32     7'b000_0000         
    `define PCIE_FMTTYPE_MEM_READ64     7'b010_0000
    `define PCIE_FMTTYPE_MEM_WRITE32    7'b100_0000
    `define PCIE_FMTTYPE_MEM_WRITE64    7'b110_0000
    `define PCIE_FMTTYPE_CFG_WRITE      7'b100_0100
    `define PCIE_FMTTYPE_CPL            7'b000_1010
    `define PCIE_FMTTYPE_CPLD           7'b100_1010               
    
    `define AVL_TXQ_HDR_WIDTH         49        // cfg(1) + addr(32) + rd(1) + wr(1) + tag(14) = 49
    `define AVL_TXQ_CPL_WIDTH         96        // data(64) + requester ID(16) + tag(8) + length(1) + low_addr(7) = 96            
    
`endif
