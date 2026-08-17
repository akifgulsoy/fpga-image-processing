# Roadmap

The project grows from pixel-level primitives into a reusable streaming image
pipeline. Each milestone must include synthesizable RTL, a bit-accurate
reference model, self-checking tests, and concise documentation.

## Milestone 1 — Pixel primitives

- [x] RGB888 to grayscale conversion
- [x] Threshold and binary-mask stage
- [x] Brightness and contrast adjustment
- [x] Pixel stream register slice

## Milestone 2 — Neighborhood operations

- [x] Parameterized three-line buffer
- [x] 3x3 convolution window generator
- [x] Sobel X/Y kernels
- [x] Gradient magnitude approximation

## Milestone 3 — Frame-aware streaming

- [x] Start/end-of-line metadata
- [x] Configurable frame dimensions
- [x] Configurable left-edge zero/replicate border policy
- [x] Configurable top-edge zero/replicate border policy
- [ ] Remaining border policies
- [x] AXI4-Stream video adapter

## Milestone 4 — Integration

- [ ] Grayscale-to-Sobel reference pipeline
- [ ] Verilator or cocotb regression option
- [ ] Synthesis smoke test with Yosys
- [ ] Resource and timing reports for a documented FPGA target

Benchmarks and hardware results will only be added when they can be reproduced
from checked-in scripts and named tool versions.
