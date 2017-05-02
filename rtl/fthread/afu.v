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
 
`include "../afu_defines.vh"

module AFU #(parameter AFU_OPERATOR         = `UNDEF_AFU,          // AFU Common parameters
	         parameter MAX_AFU_CONFIG_WIDTH = 1536,
             parameter USER_RD_TAG          = `AFU_TAG,
             parameter USER_WR_TAG          = `AFU_TAG,
             //------ AFU Specific Paramters ----//
	         parameter DATA_WIDTH_IN    = 4,
	         parameter DATA_WIDTH_OUT   = 4,
             parameter USER_AFU_PARAMETER1 = 1,
             parameter USER_AFU_PARAMETER2 = 1
) (
    input   wire                                   clk,
    input   wire                                   Clk_400,
    input   wire                                   rst_n,
    //-------------------------------------------------//
	input   wire 					               start_um,
    input   wire [MAX_AFU_CONFIG_WIDTH-1:0]        um_params,
    output  wire                                   um_done,
    output  wire [`NUM_USER_STATE_COUNTERS*32-1:0] um_state_counters,
    output  wire                                   um_state_counters_valid,
    // TX RD
    output  wire [57:0]                            um_tx_rd_addr,
    output  wire [USER_RD_TAG-1:0]                 um_tx_rd_tag,
    output  wire 						           um_tx_rd_valid,
    input   wire                                   um_tx_rd_ready,
    // TX WR
    output  wire [57:0]                            um_tx_wr_addr,
    output  wire [USER_WR_TAG-1:0]                 um_tx_wr_tag,
    output  wire						           um_tx_wr_valid,
    output  wire [511:0]			               um_tx_data,
    input   wire                                   um_tx_wr_ready,
    // RX RD
    input   wire [USER_RD_TAG-1:0]                 um_rx_rd_tag,
    input   wire [511:0]                           um_rx_data,
    input   wire                                   um_rx_rd_valid,
    output  wire                                   um_rx_rd_ready,
    // RX WR 
    input   wire                                   um_rx_wr_valid,
    input   wire [USER_WR_TAG-1:0]                 um_rx_wr_tag
);


generate
    if (AFU_OPERATOR == `REGEX_AFU) begin
     regex_mdb regex_mdb(
    .clk                                (clk),
    .Clk_400                            (Clk_400),
    .rst_n                              (rst_n),
    //-------------------------------------------------//
    .start_um                           (start_um),
    .um_params                          (um_params[1023:0]),
    .um_done                            (um_done),
    .um_state_counters                  (um_state_counters),
    .um_state_counters_valid            (um_state_counters_valid),
    // User Module TX RD
    .um_tx_rd_addr                      (um_tx_rd_addr),
    .um_tx_rd_tag                       (um_tx_rd_tag),
    .um_tx_rd_valid                     (um_tx_rd_valid),
    .um_tx_rd_ready                     (um_tx_rd_ready),
    // User Module TX WR
    .um_tx_wr_addr                      (um_tx_wr_addr),
    .um_tx_wr_tag                       (um_tx_wr_tag),
    .um_tx_wr_valid                     (um_tx_wr_valid),
    .um_tx_data                         (um_tx_data),
    .um_tx_wr_ready                     (um_tx_wr_ready),
    // User Module RX RD
    .um_rx_rd_tag                       (um_rx_rd_tag),
    .um_rx_data                         (um_rx_data),
    .um_rx_rd_valid                     (um_rx_rd_valid),
    .um_rx_rd_ready                     (um_rx_rd_ready),
    // User Module RX WR 
    .um_rx_wr_valid                     (um_rx_wr_valid),
    .um_rx_wr_tag                       (um_rx_wr_tag)
    );
    end
    else if ((AFU_OPERATOR == `SKYLINE256_AFU) | (AFU_OPERATOR == `SKYLINE128_AFU) | (AFU_OPERATOR == `SKYLINE64_AFU) ) begin
     skyline #(.NUM_CORES(USER_AFU_PARAMETER1), 
               .NUM_DIMENSIONS(USER_AFU_PARAMETER2))
     skyline_0(
    .clk                                (clk),
    .rst_n                              (rst_n),
    //-------------------------------------------------//
    .start_um                           (start_um),
    .um_params                          (um_params[1535:0]),
    .um_done                            (um_done),
    .um_state_counters                  (um_state_counters),
    .um_state_counters_valid            (um_state_counters_valid),
    // User Module TX RD
    .um_tx_rd_addr                      (um_tx_rd_addr),
    .um_tx_rd_tag                       (um_tx_rd_tag),
    .um_tx_rd_valid                     (um_tx_rd_valid),
    .um_tx_rd_ready                     (um_tx_rd_ready),
    // User Module TX WR
    .um_tx_wr_addr                      (um_tx_wr_addr),
    .um_tx_wr_tag                       (um_tx_wr_tag),
    .um_tx_wr_valid                     (um_tx_wr_valid),
    .um_tx_data                         (um_tx_data),
    .um_tx_wr_ready                     (um_tx_wr_ready),
    // User Module RX RD
    .um_rx_rd_tag                       (um_rx_rd_tag),
    .um_rx_data                         (um_rx_data),
    .um_rx_rd_valid                     (um_rx_rd_valid),
    .um_rx_rd_ready                     (um_rx_rd_ready),
    // User Module RX WR 
    .um_rx_wr_valid                     (um_rx_wr_valid),
    .um_rx_wr_tag                       (um_rx_wr_tag)
    );
    end
    else if (AFU_OPERATOR == `COPY32_AFU) begin
      copy  copy (
    .clk                                (clk),
    .rst_n                              (rst_n),
    //-------------------------------------------------//
    .start_um                           (start_um),
    .um_params                          (um_params[511:0]),
    .um_done                            (um_done),
    // User Module TX RD
    .um_tx_rd_addr                      (um_tx_rd_addr),
    .um_tx_rd_tag                       (um_tx_rd_tag),
    .um_tx_rd_valid                     (um_tx_rd_valid),
    .um_tx_rd_ready                     (um_tx_rd_ready),
    // User Module TX WR
    .um_tx_wr_addr                      (um_tx_wr_addr),
    .um_tx_wr_tag                       (um_tx_wr_tag),
    .um_tx_wr_valid                     (um_tx_wr_valid),
    .um_tx_data                         (um_tx_data),
    .um_tx_wr_ready                     (um_tx_wr_ready),
    // User Module RX RD
    .um_rx_rd_tag                       (um_rx_rd_tag),
    .um_rx_data                         (um_rx_data),
    .um_rx_rd_valid                     (um_rx_rd_valid),
    .um_rx_rd_ready                     (um_rx_rd_ready),
    // User Module RX WR 
    .um_rx_wr_valid                     (um_rx_wr_valid),
    .um_rx_wr_tag                       (um_rx_wr_tag)
);

      assign um_state_counters_valid = 1'b0;

    end
    else if (AFU_OPERATOR == `TEST_AND_COUNT_AFU) begin
        test_count test_count (
            .clk                                (clk),
            .rst_n                              (rst_n),
            //-------------------------------------------------//
            .start_um                           (start_um),
            .um_params                          (um_params[511:0]),
            .um_done                            (um_done),
            // User Module TX RD
            .um_tx_rd_addr                      (um_tx_rd_addr),
            .um_tx_rd_tag                       (um_tx_rd_tag),
            .um_tx_rd_valid                     (um_tx_rd_valid),
            .um_tx_rd_ready                     (um_tx_rd_ready),
            // User Module TX WR
            .um_tx_wr_addr                      (um_tx_wr_addr),
            .um_tx_wr_tag                       (um_tx_wr_tag),
            .um_tx_wr_valid                     (um_tx_wr_valid),
            .um_tx_data                         (um_tx_data),
            .um_tx_wr_ready                     (um_tx_wr_ready),
            // User Module RX RD
            .um_rx_rd_tag                       (um_rx_rd_tag),
            .um_rx_data                         (um_rx_data),
            .um_rx_rd_valid                     (um_rx_rd_valid),
            .um_rx_rd_ready                     (um_rx_rd_ready),
            // User Module RX WR 
            .um_rx_wr_valid                     (um_rx_wr_valid),
            .um_rx_wr_tag                       (um_rx_wr_tag)
        );
        assign um_state_counters_valid = 1'b0;
    end
    else if (AFU_OPERATOR == `SELECTION) begin
        selection selection (
            .clk                                (clk),
            .rst_n                              (rst_n),
            //-------------------------------------------------//
            .start_um                           (start_um),
            .um_params                          (um_params[511:0]),
            .um_done                            (um_done),
            // User Module TX RD
            .um_tx_rd_addr                      (um_tx_rd_addr),
            .um_tx_rd_tag                       (um_tx_rd_tag),
            .um_tx_rd_valid                     (um_tx_rd_valid),
            .um_tx_rd_ready                     (um_tx_rd_ready),
            // User Module TX WR
            .um_tx_wr_addr                      (um_tx_wr_addr),
            .um_tx_wr_tag                       (um_tx_wr_tag),
            .um_tx_wr_valid                     (um_tx_wr_valid),
            .um_tx_data                         (um_tx_data),
            .um_tx_wr_ready                     (um_tx_wr_ready),
            // User Module RX RD
            .um_rx_rd_tag                       (um_rx_rd_tag),
            .um_rx_data                         (um_rx_data),
            .um_rx_rd_valid                     (um_rx_rd_valid),
            .um_rx_rd_ready                     (um_rx_rd_ready),
            // User Module RX WR 
            .um_rx_wr_valid                     (um_rx_wr_valid),
            .um_rx_wr_tag                       (um_rx_wr_tag)
        );
        assign um_state_counters_valid = 1'b0;
    end
    else if (AFU_OPERATOR == `SGD_AFU) begin
        sgd sgd (
            .clk                                (clk),
            .rst_n                              (rst_n),
            //-------------------------------------------------//
            .start_um                           (start_um),
            .um_params                          (um_params[1535:0]),
            .um_done                            (um_done),
            // User Module TX RD
            .um_tx_rd_addr                      (um_tx_rd_addr),
            .um_tx_rd_tag                       (um_tx_rd_tag),
            .um_tx_rd_valid                     (um_tx_rd_valid),
            .um_tx_rd_ready                     (um_tx_rd_ready),
            // User Module TX WR
            .um_tx_wr_addr                      (um_tx_wr_addr),
            .um_tx_wr_tag                       (um_tx_wr_tag),
            .um_tx_wr_valid                     (um_tx_wr_valid),
            .um_tx_data                         (um_tx_data),
            .um_tx_wr_ready                     (um_tx_wr_ready),
            // User Module RX RD
            .um_rx_rd_tag                       (um_rx_rd_tag),
            .um_rx_data                         (um_rx_data),
            .um_rx_rd_valid                     (um_rx_rd_valid),
            .um_rx_rd_ready                     (um_rx_rd_ready),
            // User Module RX WR 
            .um_rx_wr_valid                     (um_rx_wr_valid),
            .um_rx_wr_tag                       (um_rx_wr_tag)
        );
        assign um_state_counters_valid = 1'b0;
    end
    else if (AFU_OPERATOR == `MAX_MIN_SUM_AFU) begin
        minmaxsum minmaxsum (
            .clk                                (clk),
            .rst_n                              (rst_n),
            //-------------------------------------------------//
            .start_um                           (start_um),
            .um_params                          (um_params[511:0]),
            .um_done                            (um_done),
            // User Module TX RD
            .um_tx_rd_addr                      (um_tx_rd_addr),
            .um_tx_rd_tag                       (um_tx_rd_tag),
            .um_tx_rd_valid                     (um_tx_rd_valid),
            .um_tx_rd_ready                     (um_tx_rd_ready),
            // User Module TX WR
            .um_tx_wr_addr                      (um_tx_wr_addr),
            .um_tx_wr_tag                       (um_tx_wr_tag),
            .um_tx_wr_valid                     (um_tx_wr_valid),
            .um_tx_data                         (um_tx_data),
            .um_tx_wr_ready                     (um_tx_wr_ready),
            // User Module RX RD
            .um_rx_rd_tag                       (um_rx_rd_tag),
            .um_rx_data                         (um_rx_data),
            .um_rx_rd_valid                     (um_rx_rd_valid),
            .um_rx_rd_ready                     (um_rx_rd_ready),
            // User Module RX WR 
            .um_rx_wr_valid                     (um_rx_wr_valid),
            .um_rx_wr_tag                       (um_rx_wr_tag)
        );
        assign um_state_counters_valid = 1'b0;
    end
    else if (AFU_OPERATOR == `PERCENTAGE_AFU) begin
      precentage_um precentage_um (
    .clk                                (clk),
    .rst_n                              (rst_n),
    //-------------------------------------------------//
    .start_um                           (start_um),
    .um_params                          (um_params[511:0]),
    .um_done                            (um_done),
    // User Module TX RD
    .um_tx_rd_addr                      (um_tx_rd_addr),
    .um_tx_rd_tag                       (um_tx_rd_tag),
    .um_tx_rd_valid                     (um_tx_rd_valid),
    .um_tx_rd_ready                     (um_tx_rd_ready),
    // User Module TX WR
    .um_tx_wr_addr                      (um_tx_wr_addr),
    .um_tx_wr_tag                       (um_tx_wr_tag),
    .um_tx_wr_valid                     (um_tx_wr_valid),
    .um_tx_data                         (um_tx_data),
    .um_tx_wr_ready                     (um_tx_wr_ready),
    // User Module RX RD
    .um_rx_rd_tag                       (um_rx_rd_tag),
    .um_rx_data                         (um_rx_data),
    .um_rx_rd_valid                     (um_rx_rd_valid),
    .um_rx_rd_ready                     (um_rx_rd_ready),
    // User Module RX WR 
    .um_rx_wr_valid                     (um_rx_wr_valid),
    .um_rx_wr_tag                       (um_rx_wr_tag)
);
      assign um_state_counters_valid = 1'b0;
    end

    else if (AFU_OPERATOR == `MAC_AFU) begin
      addmul addmul (
    .clk                                (clk),
    .rst_n                              (rst_n),
    //-------------------------------------------------//
    .start_um                           (start_um),
    .um_params                          (um_params[511:0]),
    .um_done                            (um_done),
    // User Module TX RD
    .um_tx_rd_addr                      (um_tx_rd_addr),
    .um_tx_rd_tag                       (um_tx_rd_tag),
    .um_tx_rd_valid                     (um_tx_rd_valid),
    .um_tx_rd_ready                     (um_tx_rd_ready),
    // User Module TX WR
    .um_tx_wr_addr                      (um_tx_wr_addr),
    .um_tx_wr_tag                       (um_tx_wr_tag),
    .um_tx_wr_valid                     (um_tx_wr_valid),
    .um_tx_data                         (um_tx_data),
    .um_tx_wr_ready                     (um_tx_wr_ready),
    // User Module RX RD
    .um_rx_rd_tag                       (um_rx_rd_tag),
    .um_rx_data                         (um_rx_data),
    .um_rx_rd_valid                     (um_rx_rd_valid),
    .um_rx_rd_ready                     (um_rx_rd_ready),
    // User Module RX WR 
    .um_rx_wr_valid                     (um_rx_wr_valid),
    .um_rx_wr_tag                       (um_rx_wr_tag)
);
      assign um_state_counters_valid = 1'b0;
    end
    else begin
        assign um_tx_rd_valid          = 1'b0;
        assign um_tx_wr_valid          = 1'b0;
        assign um_rd_done              = 1'b0;
        assign um_wr_done              = 1'b0;
        assign um_state_counters_valid = 1'b0;
    end
endgenerate





endmodule // AFU
