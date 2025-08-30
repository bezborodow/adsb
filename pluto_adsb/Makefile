####################################################################################
## Copyright (c) 2018 - 2023 Analog Devices, Inc.
### SPDX short identifier: BSD-1-Clause
## Auto-generated, do not modify!
####################################################################################

.PHONY: all build

PROJECT_NAME := pluto
M_DIR := $(shell pwd)
export ADI_HDL_DIR := $(realpath $(M_DIR)/../../hdl)
export ADI_IGNORE_VERSION_CHECK := 1
VIVADO := vivado -mode batch -source

all: build

build: ../pluto/pluto.xpr pluto_adsb.tcl
	$(VIVADO) pluto_adsb.tcl
