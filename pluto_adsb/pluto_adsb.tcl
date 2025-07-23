set ad_hdl_dir $::env(ADI_HDL_DIR)

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
add_files -fileset sources_1 -norecurse strobe_gpio.v
add_files -fileset sources_1 -norecurse system_top.v
import_files -force -norecurse
update_compile_order -fileset sources_1
set_property top system_top [current_fileset]
get_files

open_bd_design {pluto_adsb.srcs/sources_1/bd/system/system.bd}
validate_bd_design
save_bd_design

#adi_project_run pluto
#source $ad_hdl_dir/library/axi_ad9361/axi_ad9361_delay.tcl
