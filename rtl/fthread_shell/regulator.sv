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
 

module regulator #(
    parameter NUMBER_OF_USERS              = 4,
    parameter USERS_BITS                   = 2,
    parameter USER_LINE_IN_WIDTH           = 512,
    parameter USER_LINE_OUT_WIDTH          = 512,
    parameter PRIORITY_ROUND_ROBIN         = 0,  
    parameter PRIORITY_BATCHED_ROUND_ROBIN = 0, 
    parameter ROUND_ROBIN_BATCH_SIZE       = 16,   
    parameter PRIORITY_EQUAL               = 0,
    parameter PRIORITY_ASCENDING           = 0,
    parameter PRIORITY_DESCENDING          = 0,
    parameter PRIORITY_CUSTOM              = 0,
    parameter ENABLE_OUT_FIFO              = 1,
    parameter ENABLE_IN_BUFFER             = 1
)(

    input  wire                                                     clk,
    input  wire                                                     rst_n,
    
    // Users TX Channel
    input  wire   [USER_LINE_IN_WIDTH - 1 : 0]                      usr_tx_lines[NUMBER_OF_USERS-1:0],
    input  wire                                                     usr_tx_valid[NUMBER_OF_USERS-1:0],
    output wire                                                     usr_tx_ready[NUMBER_OF_USERS-1:0],

    // Users RX Channel
    output reg    [USER_LINE_OUT_WIDTH - 1 : 0]                     usr_rx_lines[NUMBER_OF_USERS-1:0],
    output reg                                                      usr_rx_valid[NUMBER_OF_USERS-1:0],

    // TX Channel
    output wire   [USER_LINE_IN_WIDTH-1:0]                          tx_line,
    output wire   [USERS_BITS-1:0]                                  tx_tag,
    output wire                                                     tx_valid,
    input  wire                                                     tx_ready,

    // RX Channel
    input  wire   [USER_LINE_OUT_WIDTH-1:0]                         rx_line,
    input  wire   [USERS_BITS-1:0]                                  rx_tag,
    input  wire                                                     rx_valid
);

wire    [NUMBER_OF_USERS-1 : 0]           usr_tx_full;
wire    [NUMBER_OF_USERS-1 : 0]           sel_usr_line;
wire    [NUMBER_OF_USERS-1 : 0]           usr_valid;
wire    [USER_LINE_IN_WIDTH-1 : 0]        usr_in_lines[NUMBER_OF_USERS-1:0]; 

wire    [USER_LINE_IN_WIDTH-1 : 0]        rr_tx_line; 
wire    [USERS_BITS-1:0]                  rr_tx_tag;
wire                                      rr_tx_valid;

wire                                      tx_queue_full;


reg   [USER_LINE_OUT_WIDTH-1:0]                        rx_line_reg;
reg   [USERS_BITS-1:0]                                 rx_tag_reg;
reg                                                    rx_valid_reg;

wire    [USER_LINE_OUT_WIDTH - 1 : 0]                  usr_rx_lines_tmp[NUMBER_OF_USERS-1:0];
wire    [NUMBER_OF_USERS-1 : 0]                        usr_rx_valid_tmp; 

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

genvar i;
///////////////////////////////////////////////// user input FIFOs  //////////////////////////////////
generate for( i = 0; i < NUMBER_OF_USERS; i = i + 1) begin: in_fifo
    quick_fifo  #(.FIFO_WIDTH(USER_LINE_IN_WIDTH),        
            .FIFO_DEPTH_BITS(4),
            .FIFO_ALMOSTFULL_THRESHOLD(8)
            ) usr_tx_fifo_X(
        .clk                (clk),
        .reset_n            (rst_n),
        .din                (usr_tx_lines[i]),
        .we                 (usr_tx_valid[i]),
        .re                 (sel_usr_line[i]),
        .dout               (usr_in_lines[i]),
        .empty              (),
        .valid              (usr_valid[i]),
        .full               (usr_tx_full[i]),
        .count              (),
        .almostfull         ()
    );
        end
endgenerate

generate for( i = 0; i < NUMBER_OF_USERS; i = i + 1) begin: usrTXFull
    assign usr_tx_ready[i] = ~usr_tx_full[i];
end
endgenerate
/////////////////////////////////////////////////////////////////////////////////////////////////////
generate
    if( PRIORITY_BATCHED_ROUND_ROBIN == 1 ) begin 
        BatchRoundRobinArbitrationLogic #(
            .NUMBER_OF_USERS(NUMBER_OF_USERS),
            .USERS_BITS(USERS_BITS),
            .USER_LINE_IN_WIDTH(USER_LINE_IN_WIDTH),
            .USER_LINE_OUT_WIDTH(USER_LINE_OUT_WIDTH),
            .BATCH_SIZE(ROUND_ROBIN_BATCH_SIZE)
        ) BatchRoundRobinArbitrationLogic(
            .clk                        (clk),
            .rst_n                      (rst_n), 

            // Users TX Channel
            .usr_tx_lines               (usr_in_lines),
            .usr_tx_valid               (usr_valid),
            .usr_tx_ready               (sel_usr_line),
            // TX Channel
            .rr_tx_line                  (rr_tx_line),
            .rr_tx_tag                   (rr_tx_tag),
            .rr_tx_valid                 (rr_tx_valid),
            .rr_tx_ready                 (~tx_queue_full)
        );
    end 
    else begin 

        RoundRobinArbitrationLogic #(
            .NUMBER_OF_USERS(NUMBER_OF_USERS),
            .USERS_BITS(USERS_BITS),
            .USER_LINE_IN_WIDTH(USER_LINE_IN_WIDTH),
            .USER_LINE_OUT_WIDTH(USER_LINE_OUT_WIDTH)
        ) RoundRobinArbitrationLogic(
            .clk                        (clk),
            .rst_n                      (rst_n), 

            // Users TX Channel
            .usr_tx_lines               (usr_in_lines),
            .usr_tx_valid               (usr_valid),
            .usr_tx_ready               (sel_usr_line),
            // TX Channel
            .rr_tx_line                  (rr_tx_line),
            .rr_tx_tag                   (rr_tx_tag),
            .rr_tx_valid                 (rr_tx_valid),
            .rr_tx_ready                 (~tx_queue_full)
        );
    end 
     
endgenerate


////////////////////////////////////////////////////// Out TX FIFO  ////////////////////////////////

quick_fifo  #(.FIFO_WIDTH(USER_LINE_IN_WIDTH + USERS_BITS),        
            .FIFO_DEPTH_BITS(4),
            .FIFO_ALMOSTFULL_THRESHOLD(8)
            ) tx_req_queue(
        .clk                (clk),
        .reset_n            (rst_n),
        .din                ({rr_tx_tag, rr_tx_line}),
        .we                 ( rr_tx_valid ),
        .re                 ( tx_ready ),
        .dout               ({tx_tag, tx_line}),
        .empty              (),
        .valid              (tx_valid),
        .full               (tx_queue_full),
        .count              (),
        .almostfull         ()
    );

////////////////////////////////////////////////////// RX to Users Register ///////////////////////////

always@(posedge clk) begin 
    if(~rst_n) begin 
        rx_line_reg   <= 0;
        rx_tag_reg    <= 0;
        rx_valid_reg  <= 0;
    end 
    else begin
        rx_line_reg   <= rx_line;
        rx_tag_reg    <= rx_tag;
        rx_valid_reg  <= rx_valid;
    end 
end 

generate for( i = 0; i < NUMBER_OF_USERS; i = i + 1) begin: rxUsr
    assign usr_rx_valid_tmp[i]  = rx_valid_reg & (rx_tag_reg == i);
    assign usr_rx_lines_tmp[i]  = rx_line_reg;

    always@(posedge clk) begin
        if(~ rst_n) begin 
            usr_rx_valid[i]  <= 1'b0;
            //usr_rx_lines[i]  <= 0;
        end 
        else begin
            usr_rx_valid[i]  <= usr_rx_valid_tmp[i];
            usr_rx_lines[i]  <= usr_rx_lines_tmp[i];
        end 
    end 
end
endgenerate

endmodule


