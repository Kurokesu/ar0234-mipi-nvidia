# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026, UAB Kurokesu. All rights reserved.
#
# Makefile for building Jetson camera driver (device tree overlay + kernel module)

SRC_DIR   := $(shell pwd)
BUILD_DIR := build

DRV_SRC   := $(wildcard *.c *.h)
DRV_NAME  := $(shell grep '^BUILT_MODULE_NAME=' dkms.conf | cut -d'"' -f2)
DTS       := $(wildcard *.dts)
DTBO      := $(DTS:.dts=.dtbo)
DTC       := dtc
DTC_FLAGS := -@ -I dts -O dtb -Wno-unit_address_vs_reg

UNAME_R        := $(shell uname -r)
KERNEL_RELEASE := $(shell echo '$(UNAME_R)' | sed 's/-tegra.*/-tegra-ubuntu22.04_aarch64/')
JETSON_KSRC    := 3rdparty/canonical/linux-jammy/kernel-source
KERNEL_INCLUDE := /usr/src/linux-headers-$(KERNEL_RELEASE)/$(JETSON_KSRC)/include
LOCAL_INCLUDE  := $(BUILD_DIR)/include

CPP       := cpp
CPP_FLAGS := -nostdinc -undef -D__DTS__ -x assembler-with-cpp \
             -I$(LOCAL_INCLUDE) -I$(KERNEL_INCLUDE)

# L4T version (used for DTS patching)
L4T_MAJOR := $(shell grep -oP 'R\K[0-9]+' /etc/nv_tegra_release | head -1)
L4T_MINOR := $(shell grep -oP 'REVISION:\s*\K[0-9]+' /etc/nv_tegra_release | head -1)

# Kernel module
KDIR   ?= /lib/modules/$(UNAME_R)/build
NV_OOT := /usr/src/nvidia/nvidia-oot

# Auto-generated include markers
DT_HEADER  := $(LOCAL_INCLUDE)/dt-bindings/tegra234-p3767-0000-common.h
CONFTEST_H := $(LOCAL_INCLUDE)/nvidia/conftest.h

# Status line formatter (8-char tag column, arg at col 11)
PRINT = printf '  %-7s %s\n'

# Targets
.PHONY: all dtbo module clean install

all: $(addprefix $(BUILD_DIR)/,$(DTBO)) $(BUILD_DIR)/$(DRV_NAME).ko

dtbo: $(addprefix $(BUILD_DIR)/,$(DTBO))
module: $(BUILD_DIR)/$(DRV_NAME).ko

$(DT_HEADER): | $(BUILD_DIR)
	@$(PRINT) FETCH 'NVIDIA device tree headers'
	@./scripts/fetch-nvidia-headers.sh $(LOCAL_INCLUDE)

$(CONFTEST_H): | $(BUILD_DIR)
	@$(PRINT) GEN conftest.h
	@./scripts/conftest.sh $(LOCAL_INCLUDE) $(KDIR)

# Build device tree overlay (pattern rule for all DTS variants)
$(BUILD_DIR)/%.dtbo: %.dts $(DT_HEADER) | $(BUILD_DIR)
	@$(PRINT) CPP $<
	@$(CPP) $(CPP_FLAGS) -o $(BUILD_DIR)/$*.dts.preprocessed $<
	@# DTS defaults to 22pin (JetPack 6.2.2+). Patch to 24pin for L4T < 36.5.
	@if [ $$(($(L4T_MAJOR) * 100 + $(L4T_MINOR))) -lt 3605 ]; then \
		$(PRINT) PATCH 'jetson-header-name -> 24pin (L4T $(L4T_MAJOR).$(L4T_MINOR))'; \
		sed -i 's|Jetson 22pin CSI Connector|Jetson 24pin CSI Connector|' \
			$(BUILD_DIR)/$*.dts.preprocessed; \
	fi
	@$(PRINT) DTC $@
	@$(DTC) $(DTC_FLAGS) -o $@ $(BUILD_DIR)/$*.dts.preprocessed
	@rm -f $(BUILD_DIR)/$*.dts.preprocessed
	@$(PRINT) BUILT $@

# Build kernel module (all kbuild artifacts go into build/)
$(BUILD_DIR)/$(DRV_NAME).ko: $(DRV_SRC) $(CONFTEST_H) | $(BUILD_DIR)
	@# Generate Kbuild and symlink source files into build/
	@echo "obj-m += $(DRV_NAME).o" > $(BUILD_DIR)/Kbuild
	@for f in $(DRV_SRC); do \
		ln -sf $(SRC_DIR)/$$f $(BUILD_DIR)/$$f; \
	done
	@$(PRINT) KBUILD $(DRV_NAME).ko
	@$(MAKE) -C $(KDIR) M=$(SRC_DIR)/$(BUILD_DIR) \
		KBUILD_EXTRA_SYMBOLS=$(NV_OOT)/Module.symvers \
		CFLAGS_MODULE="-I$(SRC_DIR)/$(LOCAL_INCLUDE) -I$(NV_OOT)/include" \
		modules
	@$(PRINT) BUILT $@

$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

install: $(addprefix $(BUILD_DIR)/,$(DTBO)) $(BUILD_DIR)/$(DRV_NAME).ko
	@for dtbo in $(DTBO); do \
		$(PRINT) INSTALL "$$dtbo -> /boot/$$dtbo"; \
		sudo cp $(BUILD_DIR)/$$dtbo /boot/$$dtbo; \
	done
	@$(PRINT) RELOAD $(DRV_NAME).ko
	@sudo rmmod $(DRV_NAME) 2>/dev/null || true
	@sudo insmod $(BUILD_DIR)/$(DRV_NAME).ko
	@$(PRINT) DONE '$(DRV_NAME).ko loaded (non-persistent; setup.sh for permanent)'

clean:
	@$(PRINT) CLEAN '$(BUILD_DIR)'
	@rm -rf $(BUILD_DIR)
