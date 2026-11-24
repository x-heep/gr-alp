# Copyright 2026 EPFL, Politecnico di Torino, and Universidad Politecnica de Madrid.
# Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Author: Michele Caon, Luigi Giuffrida, Daniel Vázquez, David Mallasén
# Description: Top-level makefile for GR-ALP

# Global configuration
ROOT_DIR		:= $(realpath .)
X_ALP_DIR 		:= $(ROOT_DIR)/hw/vendor/x-alp
BUILD_DIR 		:= build
SW_BUILD_DIR	:= sw/build
FPGA_BOARDS		:= aup-zu3 zcu104

# FUSESOC and Python values (default)
ifndef CONDA_DEFAULT_ENV
$(info USING VENV)
FUSESOC = ./.venv/bin/fusesoc
PYTHON  = ./.venv/bin/python
else
$(info USING MINICONDA $(CONDA_DEFAULT_ENV))
FUSESOC := $(shell which fusesoc)
PYTHON  := $(shell which python)
endif

# Implementation specific variables
# TARGET options are 'asic' (default) and the FPGA boards (FPGA_BOARDS)
TARGET ?= asic

# X-ALP mcu-gen configuration
X_ALP_CFG  		?= $(ROOT_DIR)/config/mcu-gen-config.py
PADS_CFG_ASIC	?= $(ROOT_DIR)/config/gr-alp_pad_cfg.py
PADS_CFG_FPGA	?= $(ROOT_DIR)/config/gr-alp_pad_cfg.py  # Currently the same as ASIC, but can be different if needed in the future

# Application spacific makefile
APP_MAKE 	:= $(wildcard sw/applications/$(PROJECT)/*akefile)
APP_PARAMS  ?=

ifeq ($(TARGET),asic)
	PADS_CFG := $(PADS_CFG_ASIC)
else ifeq ($(filter $(TARGET),$(FPGA_BOARDS)),$(TARGET))
	PADS_CFG := $(PADS_CFG_FPGA)
else
	$(error ### ERROR: Unsupported target implementation: $(TARGET))
endif

# Verilog format and linting variables
RTL_FILES := $(wildcard hw/gr-alp/*.sv)
# GR-ALP templated files
# Collects all .tpl files in the project excluding certain directories
GR_ALP_GEN_TPLS := $(shell find . \( -path './hw/vendor' -o -path './sw/device' -o -path './sw/linker' -o -path './build' \) -prune -o -name '*.tpl' -print)
EXTERNAL_MCU_GEN_TEMPLATES = $(addprefix $(X_ALP_REL_PATH)/,$(GR_ALP_GEN_TPLS))

# Testing flags
# Optional TEST_FLAGS options are '--compile-only'
TEST_FLAGS=

# Software
PROJECT := gr_alp_hello_world
LINKER	?= spm

# Simulation
LOG_LEVEL ?= LOG_MEDIUM

# Vendor
MODULE_NAME ?= x-alp

.PHONY: verible
verible:
	@for file in $(RTL_FILES); do \
		verible-verilog-format $$file --inplace \
			--formal_parameters_indentation indent --named_parameter_indentation indent \
			--named_port_indentation indent --port_declarations_indentation indent 2> /dev/null; \
		verible-verilog-lint $$file --lint_fatal=false --parse_fatal=false; \
	done

## Runs black formating for python files
format-python:
	$(PYTHON) -m black config
	$(PYTHON) -m black test

## Build the firmware (sw/applications first, then X-ALP's)
## @param PROJECT=<folder_name_of_the_project_to_be_built>
## @param LINKER=spm(default),dram
.PHONY: app
app: | $(BUILD_DIR)/sw/app/
ifneq ($(APP_MAKE),)
	@echo "### Calling application-specific makefile '$(APP_MAKE)'..."
	$(MAKE) -C $(dir $(APP_MAKE)) APP_PARAMS="$(APP_PARAMS)"
endif
	@echo "### Building application..."
	$(MAKE) -C $(X_ALP_DIR) app LINKER=$(LINKER)

## @section RTL & SW generation

## Generate X-ALP MCU files
.PHONY: mcu-gen
mcu-gen: | $(BUILD_DIR)/
	@echo "### Building X-ALP MCU for '$(TARGET)'..."
	$(MAKE) -C $(X_ALP_DIR) mcu-gen \
		X_ALP_CFG=$(realpath $(X_ALP_CFG)) \
		PADS_CFG=$(realpath $(PADS_CFG)) \
		EXTERNAL_MCU_GEN_TEMPLATES="$(EXTERNAL_MCU_GEN_TEMPLATES)"
	$(MAKE) verible
	@echo "✅ DONE! X-ALP MCU and GR-ALP generated successfully"

## @section Verilator

# Firmware and run options of the Verilator testbench
VERILATOR_RUN_ARGS = --BINARY=$(ROOT_DIR)/$(SW_BUILD_DIR)/main.$(LINKER).elf --BOOTMODE=force \
	--LOG_LEVEL=$(LOG_LEVEL) --trace=false $(SIM_ARGS)

## Verilator simulation with C++
.PHONY: verilator-build
verilator-build:
	$(FUSESOC) --cores-root . run --no-export --target=sim --tool=verilator $(FUSESOC_FLAGS) \
		--build x-heep:systems:gr-alp $(FUSESOC_PARAM) 2>&1 | tee buildsim.log

## First builds the app and then uses Verilator to simulate the HW model and run the FW
.PHONY: verilator-run-app
verilator-run-app:
	$(MAKE) app
	$(MAKE) verilator-run

## Launches the RTL simulation with the compiled firmware (`app` target) using
## the C++ Verilator model previously built (`verilator-build` target).
.PHONY: verilator-run
verilator-run:
	$(FUSESOC) --cores-root . run --no-export --target=sim --tool=verilator $(FUSESOC_FLAGS) \
		--run x-heep:systems:gr-alp $(FUSESOC_PARAM) \
		$(VERILATOR_RUN_ARGS)

## @section Vivado

## Builds (synthesis and implementation) the bitstream for the FPGA version using Vivado
## @param FPGA_BOARD=aup-zu3,zcu104
## @param FUSESOC_FLAGS=--flag=<flagname>
vivado-fpga:
	$(FUSESOC) --cores-root . run --no-export --target=$(FPGA_BOARD) $(FUSESOC_FLAGS) \
		--build x-heep:systems:gr-alp $(FUSESOC_PARAM) 2>&1 | tee buildvivado.log

## Loads the generated bitstream into the FPGA
## @param FPGA_BOARD=aup-zu3,zcu104
vivado-fpga-pgm:
	$(FUSESOC) --cores-root . run --no-export --target=$(FPGA_BOARD) $(FUSESOC_FLAGS) \
		--run x-heep:systems:gr-alp $(FUSESOC_PARAM) 2>&1 | tee programfpga.log

## @section Testing

## Run GR-ALP tests
.PHONY: test
test: mcu-gen
	$(RM) test/*.log
	$(PYTHON) test/gr_alp_test_apps.py $(TEST_FLAGS) 2>&1 | tee test/gr_alp_test_apps.log
	@echo "You can also find the output in test/gr_alp_test_apps.log"

## @section Utilities

## Rename the project (files, SystemVerilog modules, FuseSoC core, CI) to NAME
## @param NAME=<new name: lowercase letters and digits, words separated by - or _>
.PHONY: rename
rename:
	python3 util/rename.py $(NAME)

## Update vendor submodules
## @note These targets are used to update the vendored submodules.
## @param MODULE_NAME=module_name The name of the submodule to update when using vendor-update.
.PHONY: vendor-update
vendor-update:
	@echo "Updating vendored module '$(MODULE_NAME)'..."
	$(PYTHON) util/vendor.py hw/vendor/$(MODULE_NAME).vendor.hjson -Uv

.PHONY: vendor-update-all
vendor-update-all:
	@echo "Updating all vendored modules..."
	find hw/vendor -maxdepth 1 -type f -name "*.vendor.hjson" -exec ./util/vendor.py -vU {} \;

## Create directories
%/:
	mkdir -p $@

# Export variables
export X_ALP_CFG
export PADS_CFG
export PROJECT
# X-ALP builds its (RV64) boot ROM with RISCV_XALP; the CORE-V toolchain covers RV64 too
export RISCV_XALP ?= $(RISCV_XHEEP)

# Relative path from X-ALP to this directory, and from X-ALP's sw/ to GR-ALP's sw/
# (the SW build looks for PROJECT there first)
X_ALP_REL_PATH	= $(shell python3 -c "import os; print(os.path.relpath('.', '$(X_ALP_DIR)'))")
export SOURCE	= ../$(X_ALP_REL_PATH)/sw/

# Any target not defined here is forwarded to X-ALP's Makefile (as X-HEEP's external.mk does)
%:
	$(MAKE) -C $(X_ALP_DIR) $@
