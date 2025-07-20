####################################################################################
## Copyright (c) 2018 - 2023 Analog Devices, Inc.
### SPDX short identifier: BSD-1-Clause
## Auto-generated, do not modify!
####################################################################################

PROJECT_NAME := pluto
M_DIR := $(shell pwd)
export ADI_HDL_DIR := $(M_DIR)/../../hdl
export ADI_IGNORE_VERSION_CHECK := 1

M_DEPS += $(ADI_HDL_DIR)/projects/common/xilinx/adi_fir_filter_constr.xdc
M_DEPS += $(ADI_HDL_DIR)/projects/common/xilinx/adi_fir_filter_bd.tcl
M_DEPS += $(ADI_HDL_DIR)/library/util_cdc/sync_bits.v
M_DEPS += $(ADI_HDL_DIR)/library/common/util_pulse_gen.v
M_DEPS += $(ADI_HDL_DIR)/library/common/ad_iobuf.v
M_DEPS += $(ADI_HDL_DIR)/library/common/ad_bus_mux.v
M_DEPS += $(ADI_HDL_DIR)/library/axi_tdd/scripts/axi_tdd.tcl
M_DEPS += $(ADI_HDL_DIR)/library/axi_ad9361/axi_ad9361_delay.tcl

LIB_DEPS += axi_ad9361
LIB_DEPS += axi_dmac
LIB_DEPS += axi_tdd
LIB_DEPS += util_pack/util_cpack2
LIB_DEPS += util_pack/util_upack2

include $(ADI_HDL_DIR)/projects/scripts/project-xilinx.mk
