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
    RELEASE_FILE="/etc/nv_tegra_release"
    if [ ! -f "$RELEASE_FILE" ]; then
        echo "ERROR: $RELEASE_FILE not found -- is this a Jetson?" >&2
        exit 1
    fi
    L4T_MAJOR=$(grep -oP 'R\K[0-9]+' "$RELEASE_FILE" | head -1)
    L4T_MINOR=$(grep -oP 'REVISION:\s*\K[0-9]+' "$RELEASE_FILE" | head -1)
    if [ -z "$L4T_MAJOR" ] || [ -z "$L4T_MINOR" ]; then
        echo "ERROR: could not parse L4T version from $RELEASE_FILE" >&2
        exit 1
    fi
    TAG="jetson_${L4T_MAJOR}.${L4T_MINOR}"
fi

echo "  L4T tag: $TAG"

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
