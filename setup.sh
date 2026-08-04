#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026, UAB Kurokesu. All rights reserved.
#
# Install camera driver (device tree overlay + kernel module via DKMS)

# Exit on errors
set -e

# Status line formatter (matches Makefile's PRINT)
print() { printf '  %-7s %s\n' "$1" "$2"; }

# Package identity and install paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DKMS_CONF="$SCRIPT_DIR/dkms.conf"
VERSION=$(grep '^PACKAGE_VERSION=' "$DKMS_CONF" | cut -d'"' -f2)
PACKAGE_NAME=$(grep '^PACKAGE_NAME=' "$DKMS_CONF" | cut -d'"' -f2)
SENSOR=$(grep '^BUILT_MODULE_NAME=' "$DKMS_CONF" | cut -d'"' -f2 | sed 's/^nv_//')
DKMS_SRC="/usr/src/${PACKAGE_NAME}-${VERSION}"
TUNING_DIR="$SCRIPT_DIR/tuning"
NVCAM_SETTINGS="/var/nvidia/nvcam/settings"
GLOBAL_ISP="$NVCAM_SETTINGS/camera_overrides.isp"

# Check required variables
if [ -z "$VERSION" ] || [ -z "$PACKAGE_NAME" ] || [ -z "$SENSOR" ]; then
	echo "Error: failed to parse $DKMS_CONF"
	exit 1
fi

# Check prerequisites
if ! command -v dkms >/dev/null 2>&1; then
	echo "Error: dkms not installed. Run:"
	echo "sudo apt install --no-install-recommends dkms"
	exit 1
fi

# Check for headers, dkms's own error would suggest non-existent linux-headers-*
if [ ! -e "/lib/modules/$(uname -r)/build/Makefile" ]; then
	echo "Error: kernel headers not found. Run:"
	echo "sudo apt install --reinstall nvidia-l4t-kernel-headers"
	exit 1
fi

# Remove DKMS registrations matching sensor name, sweep their source trees
dkms status 2>/dev/null | sed 's/[,:].*//' | sort -u | while read -r ENTRY; do
	case "${ENTRY%%/*}" in
	*"$SENSOR"*)
		print DKMS "remove $ENTRY"
		if OUT=$(dkms remove "$ENTRY" --all 2>&1); then
			# dkms remove only deregisters, source tree is installer's to clean
			OLD_SRC="/usr/src/${ENTRY%%/*}-${ENTRY#*/}"
			if [ -f "$OLD_SRC/dkms.conf" ]; then
				print CLEAN "$OLD_SRC"
				rm -rf "$OLD_SRC" || print WARN "could not remove $OLD_SRC" >&2
			fi
		else
			print WARN "could not fully remove $ENTRY" >&2
			printf '%s\n' "$OUT" >&2
		fi
		;;
	esac
done

# Copy source to DKMS tree
print COPY "driver source -> $DKMS_SRC"
rm -rf "$DKMS_SRC"
mkdir -p "$DKMS_SRC"
cp "$DKMS_CONF" "$DKMS_SRC/"
cp "$SCRIPT_DIR/dkms.postinst" "$DKMS_SRC/"
cp "$SCRIPT_DIR/Makefile" "$DKMS_SRC/"
cp "$SCRIPT_DIR"/*.c "$DKMS_SRC/"
cp "$SCRIPT_DIR"/*.h "$DKMS_SRC/"
cp "$SCRIPT_DIR"/*.dts "$DKMS_SRC/"
cp -r "$SCRIPT_DIR/scripts" "$DKMS_SRC/"

# Fetch NVIDIA device tree headers (requires internet)
"$DKMS_SRC/scripts/fetch-nvidia-headers.sh" "$DKMS_SRC/include"

# DKMS add + build + install
print DKMS "add ${PACKAGE_NAME}/${VERSION}"
dkms add -m "$PACKAGE_NAME" -v "$VERSION"

print DKMS "build ${PACKAGE_NAME}/${VERSION}"
dkms build -m "$PACKAGE_NAME" -v "$VERSION"

print DKMS "install ${PACKAGE_NAME}/${VERSION}"
dkms install -m "$PACKAGE_NAME" -v "$VERSION"

# Install ISP tuning
if [ -d "$TUNING_DIR" ]; then
	print COPY "ISP tuning -> $NVCAM_SETTINGS"
	cp "$TUNING_DIR"/*.isp "$NVCAM_SETTINGS/"

	if [ -e "$GLOBAL_ISP" ]; then
		print RETIRE "camera_overrides.isp -> camera_overrides.isp.bak"
		mv "$GLOBAL_ISP" "$GLOBAL_ISP.bak"
	fi
fi

echo ""
echo "Done. To configure CSI connector, run:"
echo "sudo /opt/nvidia/jetson-io/jetson-io.py"
