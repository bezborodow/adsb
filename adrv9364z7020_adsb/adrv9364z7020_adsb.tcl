set ad_hdl_dir $::env(ADI_HDL_DIR)
set ad_phdl_dir $::env(ADI_HDL_DIR)
set base_project_xpr $::env(BASE_PROJECT_XPR)
set project_name $::env(PROJECT_NAME)

# Copy project from HDL reference design.
open_project $base_project_xpr
save_project_as $project_name -force

# Add in the custom IP cores.
add_files -fileset sources_1 -norecurse ../ip/adsb/adsb.vhd
add_files -fileset sources_1 -norecurse ../ip/adsb/adsb_envelope.vhd
add_files -fileset sources_1 -norecurse ../ip/adsb/adsb_fifo.vhd
add_files -fileset sources_1 -norecurse ../ip/adsb/adsb_guard.vhd
add_files -fileset sources_1 -norecurse ../ip/adsb/adsb_pkg.vhd
add_files -fileset sources_1 -norecurse ../ip/adsb/adsb_preamble_peak.vhd
add_files -fileset sources_1 -norecurse ../ip/adsb/adsb_preamble_window.vhd
add_files -fileset sources_1 -norecurse ../ip/adsb/adsb_rolling_sum.vhd
add_files -fileset sources_1 -norecurse ../ip/adsb/adsb_serialiser.vhd
add_files -fileset sources_1 -norecurse ../ip/adsb/adsb_tapped_buffer.vhd
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
#report_compile_order -fileset sources_1
set_property top system_top [current_fileset]
get_files

# Open board design.
open_bd_design "${project_name}.srcs/sources_1/bd/system/system.bd"

# Concatenate 16 bit ADC IQ paths as 32 bit.
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0
set_property -dict [list CONFIG.IN1_WIDTH.VALUE_SRC USER CONFIG.IN0_WIDTH.VALUE_SRC USER] [get_bd_cells xlconcat_0]
set_property -dict [list \
  CONFIG.IN0_WIDTH {16} \
  CONFIG.IN1_WIDTH {16} \
] [get_bd_cells xlconcat_0]
connect_bd_net [get_bd_pins xlconcat_0/in0] [get_bd_pins util_ad9361_adc_fifo/dout_data_0]
connect_bd_net [get_bd_pins xlconcat_0/in1] [get_bd_pins util_ad9361_adc_fifo/dout_data_1]

# Direct digital synthesiser (DDS.)
# fs = 61.44e6
# fo = 5e6
# B = 24
# dec2bin(uint32(fo * 2^B / fs)) = 101001101010101010101
create_bd_cell -type ip -vlnv xilinx.com:ip:dds_compiler:6.0 dds_compiler_0
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
create_bd_cell -type ip -vlnv xilinx.com:ip:cmpy:6.0 cmpy_0
set_property CONFIG.OutputWidth {16} [get_bd_cells cmpy_0]
connect_bd_net [get_bd_pins cmpy_0/aclk] [get_bd_pins util_ad9361_divclk/clk_out]
connect_bd_intf_net [get_bd_intf_pins dds_compiler_0/M_AXIS_DATA] [get_bd_intf_pins cmpy_0/S_AXIS_A]
connect_bd_net [get_bd_pins xlconcat_0/dout] [get_bd_pins cmpy_0/s_axis_b_tdata]
connect_bd_net [get_bd_pins cmpy_0/s_axis_b_tvalid] [get_bd_pins util_ad9361_adc_fifo/dout_valid_0]

# FIR filter.
create_bd_cell -type ip -vlnv xilinx.com:ip:fir_compiler:7.2 fir_compiler_0
set_property -dict [list \
  CONFIG.Channel_Sequence {Basic} \
  CONFIG.Clock_Frequency {61.44} \
  CONFIG.DATA_Has_TLAST {Not_Required} \
  CONFIG.Filter_Architecture {Systolic_Multiply_Accumulate} \
  CONFIG.M_DATA_Has_TUSER {Not_Required} \
  CONFIG.Number_Channels {1} \
  CONFIG.Number_Paths {2} \
  CONFIG.Output_Rounding_Mode {Symmetric_Rounding_to_Zero} \
  CONFIG.Output_Width {16} \
  CONFIG.RateSpecification {Frequency_Specification} \
  CONFIG.S_DATA_Has_TUSER {Not_Required} \
  CONFIG.SamplePeriod {1} \
  CONFIG.Sample_Frequency {61.44} \
  CONFIG.Select_Pattern {All} \
  CONFIG.CoefficientVector {0,0,0,0,1,1,2,2,3,3,3,3,3,2,0,-2,-6,-10,-14,-18,-23,-26,-28,-28,-25,-19,-9,4,20,39,59,80,98,113,122,122,112,91,57,12,-45,-110,-180,-250,-314,-367,-402,-412,-392,-336,-241,-105,71,284,531,802,1090,1383,1670,1939,2178,2376,2525,2617,2648,2617,2525,2376,2178,1939,1670,1383,1090,802,531,284,71,-105,-241,-336,-392,-412,-402,-367,-314,-250,-180,-110,-45,12,57,91,112,122,122,113,98,80,59,39,20,4,-9,-19,-25,-28,-28,-26,-23,-18,-14,-10,-6,-2,0,2,3,3,3,3,3,2,2,1,1,0,0,0,0} \
  CONFIG.Coefficient_Fractional_Bits {0} \
  CONFIG.Coefficient_Sets {1} \
  CONFIG.Coefficient_Sign {Signed} \
  CONFIG.Coefficient_Structure {Inferred} \
  CONFIG.Coefficient_Width {16} \
  CONFIG.ColumnConfig {60,5} \
  CONFIG.Quantization {Integer_Coefficients} \
] [get_bd_cells fir_compiler_0]
connect_bd_net [get_bd_pins fir_compiler_0/aclk] [get_bd_pins util_ad9361_divclk/clk_out]
connect_bd_intf_net [get_bd_intf_pins cmpy_0/M_AXIS_DOUT] [get_bd_intf_pins fir_compiler_0/S_AXIS_DATA]

# Slice 32 bit data into IQ 16 bit.
create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_0
create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_1
set_property -dict [list \
  CONFIG.DIN_WIDTH {32} \
  CONFIG.DIN_FROM {15} \
  CONFIG.DIN_TO {0} \
] [get_bd_cells xlslice_0]
set_property -dict [list \
  CONFIG.DIN_WIDTH {32} \
  CONFIG.DIN_FROM {31} \
  CONFIG.DIN_TO {16} \
] [get_bd_cells xlslice_1]
connect_bd_net [get_bd_pins xlslice_0/Din] [get_bd_pins fir_compiler_0/m_axis_data_tdata]
connect_bd_net [get_bd_pins xlslice_1/Din] [get_bd_pins fir_compiler_0/m_axis_data_tdata]

# RTL: ADS-B processing component.
create_bd_cell -type module -reference adsb_uart u_adsb_uart
connect_bd_net [get_bd_pins util_ad9361_adc_fifo/dout_clk] [get_bd_pins u_adsb_uart/clk]
#connect_bd_net [get_bd_pins fir_compiler_0/m_axis_data_tvalid] [get_bd_pins u_adsb_uart/d_vld_i]
#connect_bd_net [get_bd_pins xlslice_0/Dout] [get_bd_pins u_adsb_uart/i_i]
#connect_bd_net [get_bd_pins xlslice_1/Dout] [get_bd_pins u_adsb_uart/q_i]
connect_bd_net [get_bd_pins util_ad9361_adc_fifo/dout_valid_0] [get_bd_pins u_adsb_uart/d_vld_i]
connect_bd_net [get_bd_pins util_ad9361_adc_fifo/dout_data_0] [get_bd_pins u_adsb_uart/i_i]
connect_bd_net [get_bd_pins util_ad9361_adc_fifo/dout_data_1] [get_bd_pins u_adsb_uart/q_i]

# Enable UART0.
set_property -dict [list \
  CONFIG.PCW_QSPI_GRP_SINGLE_SS_ENABLE {1} \
  CONFIG.PCW_UART0_PERIPHERAL_ENABLE {1} \
] [get_bd_cells sys_ps7]
connect_bd_net [get_bd_pins u_adsb_uart/uart_tx_o] [get_bd_pins sys_ps7/UART0_RX]

# Check if simulation data file exists.
set data_file "../tb/data/gen/adsb_61_440_000_hertz.dat"
if {![file exists $data_file]} {
    puts "Data file not found. Running generator..."
    exec ../generate_vunit_data
} else {
    puts "Data file exists: $data_file"
}

# Add simulation sources.
add_files -fileset sim_1 -norecurse ../sim/adsb_uart/adsb_uart_tb.vhd
set_property top adsb_uart_tb [get_filesets sim_1]
add_files -fileset sim_1 -norecurse $data_file
set_property used_in_simulation true [get_files $data_file]
set_property used_in_synthesis false [get_files $data_file]
import_files -force -norecurse

# Save board design.
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
validate_bd_design
save_bd_design
set project_name $::env(PROJECT_NAME)
