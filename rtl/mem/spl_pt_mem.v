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


module spl_pt_mem #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 8
) (
    input  wire                     clk,
    
    // port 0, read/write
    input  wire                     we0,
	input  wire                     re0, 
    input  wire [ADDR_WIDTH-1:0]    addr0,  
    input  wire [DATA_WIDTH-1:0]    din0,	
    output reg  [DATA_WIDTH-1:0]    dout0,
    
    // port 1, read only
	input  wire                     re1,
    input  wire [ADDR_WIDTH-1:0]    addr1,
    output reg  [DATA_WIDTH-1:0]    dout1    
);


`ifdef VENDOR_XILINX
    (* ram_extract = "yes", ram_style = "block" *)
    reg  [DATA_WIDTH-1:0]         mem[0:2**ADDR_WIDTH-1];
`else
    (* ramstyle = "AUTO, no_rw_check" *) 
    reg  [DATA_WIDTH-1:0]         mem[0:2**ADDR_WIDTH-1];
`endif

    always @(posedge clk) begin
        if (we0)
            mem[addr0] <= din0;  
        
		if (re0)
        	dout0 <= mem[addr0];
			
		if (re1)			
        	dout1 <= mem[addr1];             			
    end    
	
endmodule


						
