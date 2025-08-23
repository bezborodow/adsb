set ad_hdl_dir $::env(ADI_HDL_DIR)
set ad_phdl_dir $::env(ADI_HDL_DIR)

#create_project pluto_adsb . -part xc7z010clg400-1 -force

#set_property IP_REPO_PATHS "$ad_hdl_dir/library" [current_project]
#update_ip_catalog

#open_bd_design {../pluto/pluto.srcs/sources_1/bd/system/system.bd}
#set bd_file [read_bd {../pluto/pluto.srcs/sources_1/bd/system/system.bd}]
#open_bd_design $bd_file

#save_bd_design

#update_compile_order -fileset sources_1

# Regenerate outputs
#upgrade_ip [get_ips]
#report_ip_status
#generate_target all [get_files system.bd]
#make_wrapper -files [get_files system.bd] -top
#add_files -norecurse pluto_adsb/pluto_adsb.srcs/sources_1/bd/system/hdl/system_wrapper.v


open_project {../pluto/pluto.xpr}
save_project_as pluto_adsb -force

remove_files [get_files *system_top.v]

# Add in the GPIO strobe customisation.
add_files -fileset sources_1 -norecurse strobe_gpio.v
add_files -fileset sources_1 -norecurse ../ip/adsb/adsb_uart.vhd
add_files -fileset sources_1 -norecurse ../ip/adsb/adsb.vhd
add_files -fileset sources_1 -norecurse ../ip/adsb/ppm_demod.vhd
add_files -fileset sources_1 -norecurse ../ip/adsb/preamble_detector.vhd
add_files -fileset sources_1 -norecurse ../ip/adsb/adsb_pkg.vhd
add_files -fileset sources_1 -norecurse ../ip/freq_est/freq_est.vhd
add_files -fileset sources_1 -norecurse ../ip/schmitt_trigger/schmitt_trigger.vhd
#set_property FILE_TYPE {VHDL} [get_files ../ip/adsb/adsb_uart.vhd]
add_files -fileset sources_1 -norecurse system_top.v

import_files -force -norecurse
update_compile_order -fileset sources_1
report_compile_order -fileset sources_1
set_property top system_top [current_fileset]
get_files

#puts "file exists? [file exists ../ip/adsb/adsb_uart.vhd]"

open_bd_design {pluto_adsb.srcs/sources_1/bd/system/system.bd}

# Now try bringing in the ADS-B component.
#ad_ip_instance adsb_uart adsb_uart_sys
#ad_connect i_adsb_uart/i_i rx_fir_decimator/data_out_0
#ad_connect i_adsb_uart/q_i rx_fir_decimator/data_out_1
create_bd_cell -type module -reference adsb_uart i_adsb_uart
connect_bd_net [get_bd_pins i_adsb_uart/i_i] [get_bd_pins rx_fir_decimator/data_out_0]
connect_bd_net [get_bd_pins i_adsb_uart/q_i] [get_bd_pins rx_fir_decimator/data_out_1]
connect_bd_net [get_bd_pins axi_ad9361/l_clk] [get_bd_pins i_adsb_uart/clk]

validate_bd_design
save_bd_design


#adi_project_run pluto
#source $ad_hdl_dir/library/axi_ad9361/axi_ad9361_delay.tcl
