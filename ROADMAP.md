# Roadmap

The project grows from pixel-level primitives into a reusable streaming image
pipeline. Each milestone must include synthesizable RTL, a bit-accurate
reference model, self-checking tests, and concise documentation.

## Milestone 1 — Pixel primitives

- [x] RGB888 to grayscale conversion
- [x] Threshold and binary-mask stage
- [ ] Brightness and contrast adjustment
- [ ] Pixel stream register slice

## Milestone 2 — Neighborhood operations

- [ ] Parameterized three-line buffer
- [ ] 3x3 convolution window generator
- [ ] Sobel X/Y kernels
- [ ] Gradient magnitude approximation

## Milestone 3 — Frame-aware streaming

- [ ] Start/end-of-line metadata
- [ ] Configurable frame dimensions
- [ ] Border policies
- [ ] AXI4-Stream video adapter

## Milestone 4 — Integration

- [ ] Grayscale-to-Sobel reference pipeline
- [ ] Verilator or cocotb regression option
- [ ] Synthesis smoke test with Yosys
- [ ] Resource and timing reports for a documented FPGA target

Benchmarks and hardware results will only be added when they can be reproduced
from checked-in scripts and named tool versions.
