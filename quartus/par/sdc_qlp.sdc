
#---------------------------------------------------------------------------------------------------
# set 5ns paths through raddr (32UI) to embedded address registers in 2x clocked ram (16UI clocking)
#---------------------------------------------------------------------------------------------------
  set_max_delay  -through  *tag*raddr*                                          5.0
  set_max_delay  -through  *quad_ram*raddr*                                     5.0
  set_max_delay  -through  *re*_q*raddr*                                        5.0  
  set_max_delay  -through  *mem_req_fifo*raddr*                                 5.0
  set_max_delay  -through  *4Byteram*raddr*                                     5.0
  
  set_max_delay  -to  [get_registers {*qlp_top*tag*wxe*}]                       5.0
  set_max_delay  -to  [get_registers {*qlp_top*quad_ram*wxe*}]                  5.0
  set_max_delay  -to  [get_registers {*qlp_top*re*_q*wxe*}]                     5.0
  set_max_delay  -to  [get_registers {*mem_top*quad_*wxe*}]                     5.0
  set_max_delay  -to  [get_registers {*qlp_top*4Byteram*wxe*}]                  5.0

  set_max_delay  -to  [get_registers {*qlp_top*quad_ram*wxaddr*}]               5.0
  set_max_delay  -to  [get_registers {*qlp_top*re*_q*wxaddr*}]                  5.0
  set_max_delay  -to  [get_registers {*qlp_top*tag*wxaddr*}]                    5.0
  set_max_delay  -to  [get_registers {*mem_top*quad_*wxaddr*}]                  5.0
  set_max_delay  -to  [get_registers {*qlp_top*4Byteram*wxaddr*}]               5.0
  set_max_delay  -from                *clk_align*                               2.5
  set_max_delay  -from                *4Byteram*wxe*                            2.5
  
  set_max_delay  -to  [get_registers {*reset_sync*reset_reg*}]                  5.0
  set_multicycle_path -end -hold  -to [get_registers {*reset_sync*reset_reg*}]  1

#-----------------------------------------------------------------------------------------
# over constrain due to large clk skews for clk domain crossing
#-----------------------------------------------------------------------------------------
#
  if {$::quartus(nameofexecutable) == "quartus_sta"} {
# set_max_delay                             -to  *top_nlb*                      5.0
  set_max_delay  -from *qph_xcvr_*          -to  *qph_mach*                     5.0
  set_max_delay  -from *qph_mach*           -to  *qph_xcvr_*                    5.0
  set_max_delay  -from *qph_mach*           -to  *qph_mach*                     5.0
  }
