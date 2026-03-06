#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026, UAB Kurokesu. All rights reserved.
#
# Fetch NVIDIA public device tree headers from GitLab.
#
# Usage:
#   ./scripts/fetch-nvidia-headers.sh <output_dir> [l4t_tag]
#
# If l4t_tag is not provided, it is auto-detected from /etc/nv_tegra_release.

set -e

OUT_DIR="${1:?Usage: $0 <output_dir> [l4t_tag]}"
TAG="${2:-}"

GITLAB_BASE="https://gitlab.com/nvidia/nv-tegra/device/hardware/nvidia/t23x-public-dts/-/raw"

# Auto-detect tag from /etc/nv_tegra_release if not provided
if [ -z "$TAG" ]; then
    L4T_MAJOR=$(grep -oP 'R\K[0-9]+' /etc/nv_tegra_release | head -1)
    L4T_MINOR=$(grep -oP 'REVISION:\s*\K[0-9]+' /etc/nv_tegra_release | head -1)
    L4T_PATCH=$(grep -oP 'REVISION:\s*[0-9]+\.\K[0-9]+' /etc/nv_tegra_release | head -1)
    # NVIDIA omits .0 patch in GitLab tags (e.g. jetson_36.5, not jetson_36.5.0)
    if [ "$L4T_PATCH" = "0" ]; then L4T_PATCH=""; fi
    TAG="jetson_${L4T_MAJOR}.${L4T_MINOR}${L4T_PATCH:+.${L4T_PATCH}}"
fi

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
