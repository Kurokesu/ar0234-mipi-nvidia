#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026, UAB Kurokesu. All rights reserved.
#
# Fetch NVIDIA public device tree headers from GitLab.
#
# Usage:
#	./scripts/fetch-nvidia-headers.sh <output_dir> [l4t_tag]
#
# If l4t_tag is not provided, it is auto-detected from /etc/nv_tegra_release.

set -e

# Status line formatter (matches Makefile's PRINT)
print() { printf '  %-7s %s\n' "$1" "$2"; }

OUT_DIR="${1:?Usage: $0 <output_dir> [l4t_tag]}"
TAG="${2:-}"

GITLAB_BASE="https://gitlab.com/nvidia/nv-tegra/device/hardware/nvidia/t23x-public-dts/-/raw"
NV_TEGRA_RELEASE="/etc/nv_tegra_release"
DT_HEADER="$OUT_DIR/dt-bindings/tegra234-p3767-0000-common.h"

# Auto-detect tag from nv_tegra_release if not provided
if [ -z "$TAG" ]; then
	read -r NV_RELEASE_STR < "$NV_TEGRA_RELEASE"

	if [[ "$NV_RELEASE_STR" =~ R([0-9]+).*REVISION:\ *([0-9]+)\.([0-9]+) ]]; then
		L4T_MAJOR="${BASH_REMATCH[1]}"
		L4T_MINOR="${BASH_REMATCH[2]}"
		L4T_PATCH="${BASH_REMATCH[3]}"
	else
		echo "ERROR: cannot parse $NV_TEGRA_RELEASE" >&2; exit 1
	fi

	# NVIDIA omits .0 patch in GitLab tags (e.g. jetson_36.5, not jetson_36.5.0)
	if [ "$L4T_PATCH" = "0" ]; then L4T_PATCH=""; fi
	TAG="jetson_${L4T_MAJOR}.${L4T_MINOR}${L4T_PATCH:+.${L4T_PATCH}}"
fi

GITLAB_URL="${GITLAB_BASE}/${TAG}/include/platforms/dt-bindings/${DT_HEADER##*/}"

mkdir -p "${DT_HEADER%/*}"

print FETCH "${DT_HEADER##*/} (tag: $TAG)"
if ! wget -q -O "$DT_HEADER" "$GITLAB_URL" 2>/dev/null; then
	echo "ERROR: failed to download $GITLAB_URL" >&2
	echo "       Verify that tag '$TAG' exists and the file is available." >&2
	exit 1
fi

print WROTE "$OUT_DIR"
