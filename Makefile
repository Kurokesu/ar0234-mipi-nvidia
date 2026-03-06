# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026, UAB Kurokesu. All rights reserved.
#
# Makefile for building AR0234 camera driver on Jetson (device tree overlay + kernel module)

# --- Paths ---
SRC_DIR   := $(shell pwd)
BUILD_DIR := $(SRC_DIR)/build

# --- Device tree overlay ---
DTS       := tegra234-p3767-camera-p3768-ar0234-A.dts
DTBO      := $(DTS:.dts=.dtbo)

# Kernel headers include path (for dt-bindings/gpio/*.h)
KERNEL_INCLUDE := /usr/src/linux-headers-$(shell uname -r | sed 's/-tegra.*/-tegra-ubuntu22.04_aarch64/')/3rdparty/canonical/linux-jammy/kernel-source/include

# Auto-fetched/generated include path (inside build/)
LOCAL_INCLUDE := $(BUILD_DIR)/include

CPP       := cpp
DTC       := dtc
CPP_FLAGS := -nostdinc -undef -D__DTS__ -x assembler-with-cpp \
             -I$(LOCAL_INCLUDE) -I$(KERNEL_INCLUDE)
DTC_FLAGS := -@ -I dts -O dtb -Wno-unit_address_vs_reg

# --- L4T version (parsed once, used for header fetch and DTS patching) ---
L4T_MAJOR := $(shell grep -oP 'R\K[0-9]+' /etc/nv_tegra_release | head -1)
L4T_MINOR := $(shell grep -oP 'REVISION:\s*\K[0-9]+' /etc/nv_tegra_release | head -1)
L4T_PATCH := $(shell grep -oP 'REVISION:\s*[0-9]+\.\K[0-9]+' /etc/nv_tegra_release | head -1)
L4T_TAG   := jetson_$(L4T_MAJOR).$(L4T_MINOR)$(if $(L4T_PATCH),.$(L4T_PATCH))

# --- Kernel module ---
KDIR      := /lib/modules/$(shell uname -r)/build
NV_OOT   := /usr/src/nvidia/nvidia-oot

# Source files needed by kbuild (symlinked into build/)
KBUILD_SRCS := nv_ar0234.c ar0234_mode_tbls.h

# --- Auto-generated include markers ---
DT_HEADER  := $(LOCAL_INCLUDE)/dt-bindings/tegra234-p3767-0000-common.h
CONFTEST_H := $(LOCAL_INCLUDE)/nvidia/conftest.h

# --- Targets ---
.PHONY: all dtbo module clean install

all: $(BUILD_DIR)/$(DTBO) $(BUILD_DIR)/nv_ar0234.ko

dtbo: $(BUILD_DIR)/$(DTBO)
module: $(BUILD_DIR)/nv_ar0234.ko

$(DT_HEADER): | $(BUILD_DIR)
	@echo "  FETCH   NVIDIA device tree headers"
	@./scripts/fetch-nvidia-headers.sh $(LOCAL_INCLUDE) $(L4T_TAG)

$(CONFTEST_H): | $(BUILD_DIR)
	@echo "  GEN     conftest.h"
	@./scripts/conftest.sh $(LOCAL_INCLUDE) $(KDIR)

# Build device tree overlay
$(BUILD_DIR)/$(DTBO): $(DTS) $(DT_HEADER) | $(BUILD_DIR)
	@echo "  CPP     $<"
	@$(CPP) $(CPP_FLAGS) -o $(BUILD_DIR)/$(DTS:.dts=.dts.preprocessed) $<
	@# DTS defaults to 22pin (JetPack 6.2.2+). Patch to 24pin for L4T < 36.5.
	@if [ "$(L4T_MAJOR)" -lt 36 ] 2>/dev/null || { [ "$(L4T_MAJOR)" -eq 36 ] && [ "$(L4T_MINOR)" -lt 5 ]; }; then \
		echo "  PATCH   jetson-header-name -> 24pin (L4T $(L4T_MAJOR).$(L4T_MINOR))"; \
		sed -i 's|Jetson 22pin CSI Connector|Jetson 24pin CSI Connector|' \
			$(BUILD_DIR)/$(DTS:.dts=.dts.preprocessed); \
	fi
	@echo "  DTC     $@"
	@$(DTC) $(DTC_FLAGS) -o $@ $(BUILD_DIR)/$(DTS:.dts=.dts.preprocessed)
	@rm -f $(BUILD_DIR)/$(DTS:.dts=.dts.preprocessed)
	@echo "  Built:  $@"

# Build kernel module -- all kbuild artifacts go into build/
$(BUILD_DIR)/nv_ar0234.ko: $(KBUILD_SRCS) $(CONFTEST_H) | $(BUILD_DIR)
	@# Generate Kbuild and symlink source files into build/
	@echo "obj-m += nv_ar0234.o" > $(BUILD_DIR)/Kbuild
	@for f in $(KBUILD_SRCS); do \
		ln -sf $(SRC_DIR)/$$f $(BUILD_DIR)/$$f; \
	done
	@echo "  KBUILD  nv_ar0234.ko"
	$(MAKE) -C $(KDIR) M=$(BUILD_DIR) \
		KBUILD_EXTRA_SYMBOLS=$(NV_OOT)/Module.symvers \
		CFLAGS_MODULE="-I$(LOCAL_INCLUDE) -I$(NV_OOT)/include" \
		modules
	@echo "  Built:  $(BUILD_DIR)/nv_ar0234.ko"

$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

install: $(BUILD_DIR)/$(DTBO) $(BUILD_DIR)/nv_ar0234.ko
	@echo "  INSTALL $(DTBO) -> /boot/$(DTBO)"
	sudo cp $(BUILD_DIR)/$(DTBO) /boot/$(DTBO)
	@echo "  RELOAD  nv_ar0234.ko"
	@sudo rmmod nv_ar0234 2>/dev/null || true
	sudo insmod $(BUILD_DIR)/nv_ar0234.ko
	@echo "  Done. Module loaded (non-persistent, use setup.sh for permanent install)."

clean:
	rm -rf $(BUILD_DIR)
