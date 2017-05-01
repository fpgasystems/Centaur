## Copyright (C) 1991-2012 Altera Corporation
## Your use of Altera Corporation's design tools, logic functions 
## and other software and tools, and its AMPP partner logic 
## functions, and any output files from any of the foregoing 
## (including device programming or simulation files), and any 
## associated documentation or information are expressly subject 
## to the terms and conditions of the Altera Program License 
## Subscription Agreement, Altera MegaCore Function License 
## Agreement, or other applicable license agreement, including, 
## without limitation, that your use is for the sole purpose of 
## programming logic devices manufactured by Altera and sold by 
## Altera or its authorized distributors.  Please refer to the 
## applicable agreement for further details.


## VENDOR  "Altera"
## PROGRAM "Quartus II"
## VERSION "Version 12.0 Build 232 07/05/2012 Service Pack 1 SJ Full Version"

## DATE    "Wed Aug  8 00:18:41 2012"

##
## DEVICE  "5SGXEA7N1F45C2"
##


#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3

#**************************************************************
# Create Clock
#**************************************************************

create_clock -name {altera_reserved_tck}         -period 100.000 -waveform {0.000 50.000}  [get_ports {altera_reserved_tck}]
create_clock -name {sv_reconfig_pma_testbus_clk} -period  10.000 -waveform {0.000  5.000}  [get_registers {*sv_xcvr_reconfig_basic:s5|*alt_xcvr_arbiter:pif*|*grant*}]
create_clock -name {sysclk}                      -period  10.000 -waveform {0.000  5.000}  [get_ports {pin_lvds_inp_vl_QPI_SYSCLK_DP}]
create_clock -name {hseclk}                      -period   8.888 -waveform {0.000  4.444}  [get_ports {pin_cmos25_inp_vl_HSECLK_112}]
create_clock -name {fabclk}                      -period   5.000 -waveform {0.000  2.500}  [get_ports {pin_lvds_inp_vl_FABCLK_200_DP}]
create_clock -name {rsvclk}                      -period   5.000 -waveform {0.000  2.500}  [get_ports {pin_lvds_inp_vl_RSVCLK_200_DP}]
create_clock -name {atxck0}                      -period   5.000 -waveform {0.000  2.500}  [get_ports {pin_lvds_inp_vl_ATXCK0_x00_DP}]

derive_pll_clocks

#**************************************************************
# Create Generated Clock
#**************************************************************



#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************

derive_clock_uncertainty
set_clock_uncertainty -add -from [get_clocks *qph_reset_pll_fab_s45*divclk*] -to [get_clocks *xcvr_s45_xcvr_qph*aes_qph_hssi_pma_direct_inst*pclk*] .25

#**************************************************************
# Set Input Delay
#**************************************************************



#**************************************************************
# Set Output Delay
#**************************************************************



#**************************************************************
# Set Clock Groups
#**************************************************************

set_clock_groups -asynchronous -group [get_clocks {altera_reserved_tck}] 
set_clock_groups -exclusive -group [get_clocks {sv_reconfig_pma_testbus_clk}] 
set_clock_groups -asynchronous -group [get_clocks {altera_reserved_tck}] 
set_clock_groups -exclusive -group [get_clocks {sv_reconfig_pma_testbus_clk}] 
set_clock_groups -asynchronous -group [get_clocks {altera_reserved_tck}] 
set_clock_groups -exclusive -group [get_clocks {sv_reconfig_pma_testbus_clk}] 
set_clock_groups -exclusive -group [get_clocks {sv_reconfig_pma_testbus_clk}] 
set_clock_groups -asynchronous -group [get_clocks {hseclk}] 
set_clock_groups -asynchronous -group [get_clocks {sysclk}] 

#**************************************************************
# Set False Path
#**************************************************************

set_false_path -to   [get_keepers {*sv_xcvr_avmm_dcd*|req_ff[0]}]
set_false_path -to   [get_pins -nocase -compatibility_mode {*|alt_rst_sync_uq1|altera_reset_synchronizer_int_chain*|clrn}]
set_false_path -to   [get_registers {*alt_xcvr_resync*sync_r[0]}]
set_false_path -from [get_registers {*sv_xcvr_avmm_dcd*|acc*}] 
set_false_path -from [get_registers {*sv_xcvr_avmm_dcd*|ack}] 
set_false_path -from [get_ports {pin_cmos25_inp_vl_QPI_PWRGOOD}] 
set_false_path -from [get_ports {pin_cmos25_inp_vl_QPI_RESET_N}] 
set_false_path -from [get_ports {pin_cmos25_inp_vl_LMK_Status_LD_N}]
set_false_path -to   [get_ports {pin_cmos25od_out_vl8_LED_G_N[*]}]
set_false_path -to   [get_ports {pin_cmos25od_out_vl8_LED_R_N[*]}]
set_false_path -from [get_ports {pin_cmosVtt_inp_vl_QPI_PWRGOOD}] 
set_false_path -from [get_ports {pin_cmosVtt_inp_vl_QPI_RESET_N}] 
set_false_path -from [get_ports {pin_cmos15_inp_vl_DRAM_PWR_OK_C01}] 
set_false_path -from [get_ports {pin_cmos15_inp_vl_DRAM_PWR_OK_C23}] 
set_false_path -from [get_ports {pin_cmosVtt_inp_vl_EAR_N}] 
set_false_path -from [get_ports {pin_cmosVtt_inp_vl_CPU_ONLY_RESET_N}] 
set_false_path -from [get_ports {pin_cmosVtt_inp_vl2_SOCKET_ID[*]}] 
set_false_path -from [get_ports {pin_cmos25_inp_vl_FPGA_RST_N}] 
set_false_path -from [get_ports {pin_cmos25_inp_vl4_FPGA_STRAP[*]}] 
set_false_path -to   [get_ports {pin_cmos25_out_vl_STUB}]
set_false_path -from [get_keepers {ome_bot:bot_ome|qph_top:top_qph|qph_mach_master:master_mach_qph|ffs_SSM_vl_tx_dat_z_low}] -to [get_keepers {ome_bot:bot_ome|qph_top:top_qph|qph_xcvr_s45:s45_xcvr_qph|qph_xcvr_s45_ctl:ctl_s45_xcvr_qph|ffs_112_vl_tx_dat_z_low_meta}]
set_false_path -from [get_keepers {ome_bot:bot_ome|qph_top:top_qph|qph_mach_master:master_mach_qph|ffs_SSM_vl_XcvrRx_go}] -to [get_keepers {ome_bot:bot_ome|qph_top:top_qph|qph_xcvr_s45:s45_xcvr_qph|qph_xcvr_s45_ctl:ctl_s45_xcvr_qph|ffs_112_vl_XcvrRx_go_pre1}]
set_false_path -from [get_keepers {ome_bot:bot_ome|qph_top:top_qph|qph_mach_master:master_mach_qph|ffs_SSM_vl_rx_dat_z_low}] -to [get_keepers {ome_bot:bot_ome|qph_top:top_qph|qph_xcvr_s45:s45_xcvr_qph|qph_xcvr_s45_ctl:ctl_s45_xcvr_qph|ffs_112_vl_rx_dat_z_low_meta}]
set_false_path -from [get_keepers {ome_bot:bot_ome|qph_top:top_qph|qph_xcvr_s45:s45_xcvr_qph|qph_xcvr_s45_ctl:ctl_s45_xcvr_qph|ffs_SSM_vl_XcvrRx_LTD_mode_trnplat}] -to [get_keepers {ome_bot:bot_ome|qph_top:top_qph|qph_xcvr_s45:s45_xcvr_qph|qph_xcvr_s45_ctl:ctl_s45_xcvr_qph|ffs_112_vl_LTD_mode_trnplat_pre1}]
set_false_path -from [get_keepers {ome_bot:bot_ome|qph_top:top_qph|qph_mach_master:master_mach_qph|ffs_SSM_vl_tx_clk_z_low}] -to [get_keepers {ome_bot:bot_ome|qph_top:top_qph|qph_xcvr_s45:s45_xcvr_qph|qph_xcvr_s45_ctl:ctl_s45_xcvr_qph|ffs_112_vl_tx_clk_z_low_meta}]
set_false_path -from [get_keepers {ome_bot:bot_ome|qph_top:top_qph|qph_mach_master:master_mach_qph|ffs_SSM_vl_rx_clk_z_low}] -to [get_keepers {ome_bot:bot_ome|qph_top:top_qph|qph_xcvr_s45:s45_xcvr_qph|qph_xcvr_s45_ctl:ctl_s45_xcvr_qph|ffs_112_vl_rx_clk_z_low_meta}]
set_false_path -from [get_keepers {ome_bot:bot_ome|qph_top:top_qph|qph_xcvr_s45:s45_xcvr_qph|qph_xcvr_s45_ctl:ctl_s45_xcvr_qph|ffs_112_vl_XcvrRx_rdy_LTD}] -to [get_keepers {ome_bot:bot_ome|qph_top:top_qph|qph_xcvr_s45:s45_xcvr_qph|qph_xcvr_s45_ctl:ctl_s45_xcvr_qph|ffs_SSM_vl_XcvrRx_rdy_LTD_pre}]
set_false_path -from [get_keepers {ome_bot:bot_ome|qph_top:top_qph|qph_xcvr_s45:s45_xcvr_qph|qph_xcvr_s45_ctl:ctl_s45_xcvr_qph|ffs_112_vl_XcvrRx_rdy_LTR}] -to [get_keepers {ome_bot:bot_ome|qph_top:top_qph|qph_xcvr_s45:s45_xcvr_qph|qph_xcvr_s45_ctl:ctl_s45_xcvr_qph|ffs_SSM_vl_XcvrRx_rdy_LTR_pre}]
set_false_path -from [get_keepers {ome_bot:bot_ome|qph_top:top_qph|qph_xcvr_s45:s45_xcvr_qph|qph_xcvr_s45_ctl:ctl_s45_xcvr_qph|ffs_112_vl_XcvrUp_rdy}] -to [get_keepers {ome_bot:bot_ome|qph_top:top_qph|qph_reset_s45:s45_reset_qph|ffs_SSM_vl_sync_run_pre1}]
set_false_path -from [get_keepers {ome_bot:bot_ome|qph_top:top_qph|qph_reset_s45:s45_reset_qph|ffs_112_vl_XcvrUp_go}] -to [get_keepers {ome_bot:bot_ome|qph_top:top_qph|qph_reset_s45:s45_reset_qph|ffs_SSM_vl_sync_run_pre1}]
set_false_path -from [get_keepers {ome_bot:bot_ome|qph_top:top_qph|qph_reset_s45:s45_reset_qph|ffs_112_vl_MachPll_Rdy}] -to [get_keepers {ome_bot:bot_ome|qph_top:top_qph|qph_reset_s45:s45_reset_qph|ffs_SSM_vl_sync_run_pre1}]


#**************************************************************
# Set Multicycle Path
#**************************************************************

#**************************************************************
# Set Maximum Delay
#**************************************************************

for {set i 0} {$i<24} {incr i} {
	#timequest crashes if set_max_skew is set for a single path.  set_max_skew is not set for debug channels
	if { [ lsearch {4 12 19} $i ] < 0 } {
		set_max_skew -from_clock [list *rx_pmas[ $i ]*rx_pma_deser|clk90b] -to_clock {*s45_reset_qph*qph_reset_pll_fab_s45_inst*divclk} -exclude { ccpp odv } 2.25
	}
	set_max_delay -from [get_registers [list *qph_xcvr_s45_xcvr*rx_pmas[ $i ]*BURIED_SYNC_DATA* *qph_xcvr_s45_xcvr*phase_align_gen[ $i ]*tff* ]] -to [get_registers [list *qph_xcvr_s45_xcvr*phase_align_gen*tff_d[0]* *deskew_mach_qph|ffs_vl20x32_xcvr_rx_dat_holding_reg* *deskew_mach_qph|ffs_vl20x319_SSM_rx_sr* *s45_xcvr_qph|ffs_32ui_vl20_rx_lane_invert* *qph_mach_deskew*ffs_vl_Rx_FastInbandReset*] ] 5
	set_min_delay -from [get_registers [list *qph_xcvr_s45_xcvr*rx_pmas[ $i ]*BURIED_SYNC_DATA* *qph_xcvr_s45_xcvr*phase_align_gen[ $i ]*tff* ]] -to [get_registers [list *qph_xcvr_s45_xcvr*phase_align_gen*tff_d[0]* *deskew_mach_qph|ffs_vl20x32_xcvr_rx_dat_holding_reg* *deskew_mach_qph|ffs_vl20x319_SSM_rx_sr* *s45_xcvr_qph|ffs_32ui_vl20_rx_lane_invert* *qph_mach_deskew*ffs_vl_Rx_FastInbandReset*] ] -5
}

#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************

