`include "framework_defines.vh"

`ifndef AFU_DEFINES_VH
`define AFU_DEFINES_VH

`define REGEX_AFU             16'h1
`define MURMUR_AFU            16'h2
`define TEST_AND_COUNT_AFU    16'h3
`define MAX_MIN_SUM_AFU       16'h4
`define COPY32_AFU            16'h5
`define COPY64_AFU            16'h6
`define COPY128_AFU           16'h7
`define COPY256_AFU           16'h8
`define COPY512_AFU           16'h9
`define PERCENTAGE_AFU        16'ha
`define MAC_AFU               16'hb
`define SELECTION             16'hc
`define SKYLINE256_AFU        16'hd
`define SKYLINE128_AFU        16'he
`define SKYLINE64_AFU         16'hf
`define SGD_AFU               16'h10

`define UNDEF_AFU             16'hffff

`define FTHREAD_1_PLACED_AFU        `SGD_AFU
`define FTHREAD_2_PLACED_AFU        `SKYLINE128_AFU
`define FTHREAD_3_PLACED_AFU        `REGEX_AFU
`define FTHREAD_4_PLACED_AFU        `PERCENTAGE_AFU
`define FTHREAD_5_PLACED_AFU        `COPY32_AFU
`define FTHREAD_6_PLACED_AFU        `COPY32_AFU
`define FTHREAD_7_PLACED_AFU        `COPY32_AFU
`define FTHREAD_8_PLACED_AFU        `COPY32_AFU

`define FTHREAD_1_AFU_CONFIG_LINES  3
`define FTHREAD_2_AFU_CONFIG_LINES  3
`define FTHREAD_3_AFU_CONFIG_LINES  2
`define FTHREAD_4_AFU_CONFIG_LINES  1
`define FTHREAD_5_AFU_CONFIG_LINES  1
`define FTHREAD_6_AFU_CONFIG_LINES  1
`define FTHREAD_7_AFU_CONFIG_LINES  1
`define FTHREAD_8_AFU_CONFIG_LINES  1

`define FTHREAD_1_USER_AFU_RD_TAG 	`AFU_TAG
`define FTHREAD_2_USER_AFU_RD_TAG 	`AFU_TAG
`define FTHREAD_3_USER_AFU_RD_TAG 	`AFU_TAG
`define FTHREAD_4_USER_AFU_RD_TAG 	`AFU_TAG
`define FTHREAD_5_USER_AFU_RD_TAG 	`AFU_TAG
`define FTHREAD_6_USER_AFU_RD_TAG 	`AFU_TAG
`define FTHREAD_7_USER_AFU_RD_TAG 	`AFU_TAG
`define FTHREAD_8_USER_AFU_RD_TAG 	`AFU_TAG

`define FTHREAD_1_USER_AFU_WR_TAG 	`AFU_TAG
`define FTHREAD_2_USER_AFU_WR_TAG 	`AFU_TAG
`define FTHREAD_3_USER_AFU_WR_TAG 	`AFU_TAG
`define FTHREAD_4_USER_AFU_WR_TAG 	`AFU_TAG
`define FTHREAD_5_USER_AFU_WR_TAG 	`AFU_TAG
`define FTHREAD_6_USER_AFU_WR_TAG 	`AFU_TAG
`define FTHREAD_7_USER_AFU_WR_TAG 	`AFU_TAG
`define FTHREAD_8_USER_AFU_WR_TAG 	`AFU_TAG


`define NUM_JOB_TYPES               4
`define JOB_TYPE_BITS               2

`endif
