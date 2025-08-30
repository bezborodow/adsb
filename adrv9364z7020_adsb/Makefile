####################################################################################
## Copyright (c) 2018 - 2023 Analog Devices, Inc.
### SPDX short identifier: BSD-1-Clause
## Auto-generated, do not modify!
####################################################################################

.PHONY: all build

export PROJECT_NAME := adrv9364z7020_adsb

# Location of the HDL reference repository from Analog Devices.
M_DIR := $(shell pwd)
export ADI_HDL_DIR := $(realpath $(M_DIR)/../../hdl)

# Tested against Vivado 2023.2.
export ADI_IGNORE_VERSION_CHECK := 0
VIVADO := vivado -mode batch -source

# This project is copied from the HDL reference design and then modified.
# It is stored under the HDL repo.
export BASE_PROJECT_XPR := $(ADI_HDL_DIR)/projects/adrv9364z7020/ccbob_lvds/adrv9364z7020_ccbob_lvds.xpr

all: build

build: $(BASE_PROJECT_XPR) adrv9364z7020_adsb.tcl
	$(VIVADO) adrv9364z7020_adsb.tcl
