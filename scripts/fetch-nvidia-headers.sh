#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026, UAB Kurokesu. All rights reserved.
#
# Fetch NVIDIA public device tree headers from GitLab.
#
# Usage:
#   ./scripts/fetch-nvidia-headers.sh <output_dir> <l4t_tag>

set -e

OUT_DIR="${1:?Usage: $0 <output_dir> <l4t_tag>}"
TAG="${2:?Usage: $0 <output_dir> <l4t_tag>}"

GITLAB_BASE="https://gitlab.com/nvidia/nv-tegra/device/hardware/nvidia/t23x-public-dts/-/raw"

REPO_PATH="include/platforms/dt-bindings/tegra234-p3767-0000-common.h"
LOCAL_FILE="$OUT_DIR/dt-bindings/tegra234-p3767-0000-common.h"
URL="${GITLAB_BASE}/${TAG}/${REPO_PATH}"

mkdir -p "$(dirname "$LOCAL_FILE")"

echo "  FETCH   dt-bindings/tegra234-p3767-0000-common.h (tag: $TAG)"
if ! wget -q -O "$LOCAL_FILE" "$URL" 2>/dev/null; then
    echo "ERROR: failed to download $URL" >&2
    echo "  Verify that tag '$TAG' exists and the file is available." >&2
    exit 1
fi

echo "  Headers fetched to $OUT_DIR"
