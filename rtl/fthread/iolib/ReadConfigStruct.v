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

module ReadConfigStruct #(parameter MAX_NUM_CONFIG_CL = 2) 
     (
    input   wire                                             clk,
    input   wire                                             rst_n,
    //-------------------------------------------------//
	input   wire 					                         get_config_struct,
	input   wire [57:0]                                      base_addr,
	input   wire [31:0]                                      config_struct_length,
    // User Module TX RD
    output  reg  [57:0]                                      cs_tx_rd_addr,
    output  reg  [8:0]                                       cs_tx_rd_tag,
    output  reg  						                     cs_tx_rd_valid,
    input   wire                                             cs_tx_rd_free,
    // User Module RX RD
    input   wire [8:0]                                       cs_rx_rd_tag,
    input   wire [511:0]                                     cs_rx_rd_data,
    input   wire                                             cs_rx_rd_valid,
    //
    output  wire  [(MAX_NUM_CONFIG_CL<<9)-1:0]               afu_config_struct,
    output  wire						                     afu_config_struct_valid
);



wire                   rd_done;
wire                   all_reads_done;

reg   [31:0]           numReadsSent;
reg   [31:0]           numReadsDone;
reg   [31:0]           rd_cnt;

reg   [511:0]          config_lines[MAX_NUM_CONFIG_CL];
reg                    config_lines_valid[MAX_NUM_CONFIG_CL];

genvar i;

generate for( i = 0; i < MAX_NUM_CONFIG_CL; i = i + 1) begin: configLines  

    always@(posedge clk) begin
        if(~rst_n) begin
            //config_lines[ i ]       <= 0;
            config_lines_valid[ i ] <= 0;
        end 
        else if(cs_rx_rd_valid) begin
            config_lines[ i ]       <= (cs_rx_rd_tag[1:0] == i)? cs_rx_rd_data : config_lines[ i ];
            config_lines_valid[ i ] <= (cs_rx_rd_tag[1:0] == i)? 1'b1          : config_lines_valid[ i ];
        end  
    end 


assign afu_config_struct[512*(i+1) - 1 : 512*i] = config_lines[ i ];
end

endgenerate


/////////////////////////////// Generating Read Requests //////////////////////////////
//
assign all_reads_done          = (numReadsSent == numReadsDone) & (numReadsSent != 0);
assign afu_config_struct_valid = rd_done & all_reads_done;
assign rd_done                 = (rd_cnt == config_struct_length);

always@(posedge clk) begin
    if(~rst_n) begin 
        cs_tx_rd_valid <= 1'b0;
    	rd_cnt         <= 0;
    	cs_tx_rd_addr  <= 0;
        cs_tx_rd_tag   <= 0;
    end 
    else if(cs_tx_rd_free | ~cs_tx_rd_valid) begin
        if( ~rd_done & get_config_struct ) begin
            rd_cnt         <= rd_cnt + 1'b1;
            cs_tx_rd_valid <= 1'b1;
        	cs_tx_rd_addr  <= ({1'b0,  base_addr} + {1'b0, rd_cnt});
            cs_tx_rd_tag   <= rd_cnt[8:0];
        end
        else begin
            cs_tx_rd_valid <= 1'b0;
        end 
    end
end 

////////////////////////////////////////////////////////////////////////////////////////////////////
always @(posedge clk) begin 
    if(~rst_n) begin
        numReadsSent <= 0;
        numReadsDone <= 0;
    end 
    else begin
        numReadsSent <= (cs_tx_rd_valid & cs_tx_rd_free)? numReadsSent + 1'b1 : numReadsSent;
        numReadsDone <= (cs_rx_rd_valid)?                 numReadsDone + 1'b1 : numReadsDone;
    end 
end


endmodule
