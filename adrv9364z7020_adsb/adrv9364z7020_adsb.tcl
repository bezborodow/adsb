set ad_hdl_dir $::env(ADI_HDL_DIR)
set ad_phdl_dir $::env(ADI_HDL_DIR)
set base_project_xpr $::env(BASE_PROJECT_XPR)
set project_name $::env(PROJECT_NAME)

# Copy project from HDL reference design.
open_project $base_project_xpr
save_project_as $project_name -force

# Add in the custom IP cores.
add_files -fileset sources_1 -norecurse ../ip/adsb/adsb_pkg.vhd
add_files -fileset sources_1 -norecurse ../ip/adsb/preamble_detector.vhd
add_files -fileset sources_1 -norecurse ../ip/schmitt_trigger/schmitt_trigger.vhd
add_files -fileset sources_1 -norecurse ../ip/adsb/ppm_demod.vhd
add_files -fileset sources_1 -norecurse ../ip/freq_est/freq_est.vhd
add_files -fileset sources_1 -norecurse ../ip/adsb/adsb.vhd
add_files -fileset sources_1 -norecurse ../ip/adsb/adsb_uart.vhd
add_files -fileset sources_1 -norecurse ../ip/uart/uart_tx.vhd

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

update_compile_order -fileset sources_1
validate_bd_design
save_bd_design
