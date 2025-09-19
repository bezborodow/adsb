set ad_hdl_dir $::env(ADI_HDL_DIR)
set ad_phdl_dir $::env(ADI_HDL_DIR)
set base_project_xpr $::env(BASE_PROJECT_XPR)
set project_name $::env(PROJECT_NAME)

# Copy project from HDL reference design.
open_project $base_project_xpr
save_project_as $project_name -force

# Add in the custom IP cores.
add_files -fileset sources_1 -norecurse ../ip/adsb/adsb.vhd
add_files -fileset sources_1 -norecurse ../ip/adsb/adsb_fifo.vhd
add_files -fileset sources_1 -norecurse ../ip/adsb/adsb_pkg.vhd
add_files -fileset sources_1 -norecurse ../ip/adsb/adsb_serialiser.vhd
add_files -fileset sources_1 -norecurse ../ip/adsb/adsb_uart.vhd
add_files -fileset sources_1 -norecurse ../ip/adsb/ppm_demod.vhd
add_files -fileset sources_1 -norecurse ../ip/adsb/preamble_detector.vhd
add_files -fileset sources_1 -norecurse ../ip/freq_est/freq_est.vhd
add_files -fileset sources_1 -norecurse ../ip/schmitt_trigger/schmitt_trigger.vhd
add_files -fileset sources_1 -norecurse ../ip/uart/uart_pkg.vhd
add_files -fileset sources_1 -norecurse ../ip/uart/uart_tx.vhd
add_files -fileset sources_1 -norecurse ../ip/uart/uart_tx_enc.vhd

import_files -force -norecurse
update_compile_order -fileset sources_1
report_compile_order -fileset sources_1
set_property top system_top [current_fileset]
get_files

# Open board design.
open_bd_design "${project_name}.srcs/sources_1/bd/system/system.bd"

# Enable UART0.
startgroup
set_property -dict [list \
  CONFIG.PCW_QSPI_GRP_SINGLE_SS_ENABLE {1} \
  CONFIG.PCW_UART0_PERIPHERAL_ENABLE {1} \
] [get_bd_cells sys_ps7]
endgroup

# Now try bringing in the ADS-B component.
create_bd_cell -type module -reference adsb_uart i_adsb_uart

# TODO There is no FIR filter in the reference design.
connect_bd_net [get_bd_pins i_adsb_uart/i_i] [get_bd_pins util_ad9361_adc_fifo/dout_data_0]
connect_bd_net [get_bd_pins i_adsb_uart/q_i] [get_bd_pins util_ad9361_adc_fifo/dout_data_1]
connect_bd_net [get_bd_pins i_adsb_uart/d_vld_i] [get_bd_pins util_ad9361_adc_fifo/dout_valid_0]
connect_bd_net [get_bd_pins util_ad9361_adc_fifo/dout_clk] [get_bd_pins i_adsb_uart/clk]
connect_bd_net [get_bd_pins i_adsb_uart/uart_tx_o] [get_bd_pins sys_ps7/UART0_RX]

# Direct digital synthesiser (DDS.)
# fs = 61.44e6
# fo = 5e6
# B = 24
# dec2bin(uint32(fo * 2^B / fs)) = 101001101010101010101
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:dds_compiler:6.0 dds_compiler_0
endgroup
set_property -dict [list \
  CONFIG.DATA_Has_TLAST {Not_Required} \
  CONFIG.DDS_Clock_Rate {61.44} \
  CONFIG.Has_Phase_Out {true} \
  CONFIG.Has_TREADY {false} \
  CONFIG.Latency {8} \
  CONFIG.Latency_Configuration {Auto} \
  CONFIG.M_DATA_Has_TUSER {Not_Required} \
  CONFIG.Mode_of_Operation {Standard} \
  CONFIG.Noise_Shaping {Taylor_Series_Corrected} \
  CONFIG.Output_Width {16} \
  CONFIG.PINC1 {101001101010101010101} \
  CONFIG.Parameter_Entry {Hardware_Parameters} \
  CONFIG.PartsPresent {Phase_Generator_and_SIN_COS_LUT} \
  CONFIG.Phase_Width {24} \
  CONFIG.S_PHASE_Has_TUSER {Not_Required} \
] [get_bd_cells dds_compiler_0]
connect_bd_net [get_bd_pins dds_compiler_0/aclk] [get_bd_pins util_ad9361_divclk/clk_out]


# Complex multiply.
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:cmpy:6.0 cmpy_0
endgroup
set_property CONFIG.OutputWidth {16} [get_bd_cells cmpy_0]
connect_bd_net [get_bd_pins dds_compiler_0/m_axis_data_tdata] [get_bd_pins cmpy_0/s_axis_a_tdata]
connect_bd_net [get_bd_pins dds_compiler_0/m_axis_data_tvalid] [get_bd_pins cmpy_0/s_axis_a_tvalid]
connect_bd_net [get_bd_pins cmpy_0/aclk] [get_bd_pins util_ad9361_divclk/clk_out]


update_compile_order -fileset sources_1
validate_bd_design
save_bd_design
