#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT}/build"
mkdir -p "${BUILD_DIR}"

if ! command -v iverilog >/dev/null 2>&1; then
  echo "ERROR: Icarus Verilog (iverilog) is required." >&2
  exit 1
fi
if ! command -v vvp >/dev/null 2>&1; then
  echo "ERROR: vvp is required." >&2
  exit 1
fi

iverilog -g2012 -Wall -s fifo_tb \
  -o "${BUILD_DIR}/fifo_tb.vvp" \
  "${ROOT}/rtl/sync_fifo.sv" \
  "${ROOT}/tb/fifo_tb.sv"

vvp "${BUILD_DIR}/fifo_tb.vvp"
