# project

set ad_hdl_dir $::env(ADI_HDL_DIR)
set ad_phdl_dir $::env(ADI_HDL_DIR)

source $ad_hdl_dir/projects/scripts/adi_board.tcl
source $ad_hdl_dir/projects/scripts/adi_project.tcl

set sys_zynq 1

create_project zc706 . -part xc7z045ffg900-2 -force

set_property board_part xilinx.com:zc706:part0:1.2 [current_project]
set_property ip_repo_paths [list $ad_hdl_dir/library ../ip]  [current_fileset]

update_ip_catalog

create_bd_design "system"
source $ad_hdl_dir/projects/pluto/system_bd.tcl

regenerate_bd_layout
save_bd_design
validate_bd_design

generate_target {synthesis implementation} [get_files zc706.srcs/sources_1/bd/system/system.bd]
make_wrapper -files [get_files zc706.srcs/sources_1/bd/system/system.bd] -top
import_files -force -norecurse -fileset sources_1 zc706.srcs/sources_1/bd/system/hdl/system_wrapper.v

adi_project_files zc706 [list \
  "$ad_hdl_dir/library/common/ad_iobuf.v" \
  "$ad_hdl_dir/projects/fmcomms2/zc706/system_top.v" \
  "$ad_hdl_dir/projects/fmcomms2/zc706/system_constr.xdc"\
  "$ad_hdl_dir/projects/common/zc706/zc706_system_constr.xdc" ]

adi_project_run zc706


