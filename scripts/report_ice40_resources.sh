#!/usr/bin/env bash
# Produce a reproducible resource and timing report for the grayscale stage.
set -euo pipefail

build_dir="${1:-build}"
mkdir -p "$build_dir"

{
    yosys -V
    nextpnr-ice40 --version
} > "$build_dir/ice40-rgb-to-grayscale-report.txt" 2>&1

yosys -p "read_verilog -sv rtl/rgb_to_grayscale.sv; \
    synth_ice40 -top rgb_to_grayscale -json $build_dir/rgb_to_grayscale.json; stat" \
    2>&1 | tee -a "$build_dir/ice40-rgb-to-grayscale-report.txt"

nextpnr-ice40 --hx8k --package ct256 --freq 25 \
    --pcf-allow-unconstrained \
    --json "$build_dir/rgb_to_grayscale.json" \
    --asc "$build_dir/rgb_to_grayscale.asc" \
    2>&1 | tee -a "$build_dir/ice40-rgb-to-grayscale-report.txt"
