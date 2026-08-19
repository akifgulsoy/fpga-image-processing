# FPGA Image Processing

A growing collection of synthesizable SystemVerilog building blocks for
streaming image-processing pipelines. The project pairs each RTL block with a
small software reference model and a self-checking testbench.

## Current milestone

The first block converts one RGB888 pixel per clock into an 8-bit grayscale
pixel:

```text
Y = (77R + 150G + 29B + 128) >> 8
```

The coefficients approximate BT.601 luma with integer arithmetic and no
multiplier-sized floating-point logic. The stream uses valid/ready
backpressure and holds its output stable while the downstream block is
stalled.

The next block converts grayscale pixels to a binary mask. Its unsigned,
configurable threshold defaults to 128: pixels below it produce `0`, while
pixels equal to or above it produce `1`.

The brightness/contrast block adjusts a grayscale pixel around midpoint 128.
`BRIGHTNESS` is signed in output-code values and `CONTRAST_Q8` is signed 8.8
fixed point (256 is unity); results saturate to the 0--255 range.

`pixel_stream_register_slice` is a parameterized one-entry ready/valid buffer
for inserting a registered boundary between compatible pixel-stream stages.
It preserves payload and valid while downstream backpressure is asserted.

`pixel_stream_line_metadata` carries a pixel with start-of-line (SOL) and
end-of-line (EOL) flags through a one-entry ready/valid boundary. The metadata
remains aligned with its pixel, including during downstream stalls.

`pixel_stream_frame_metadata` generates SOL/EOL and start/end-of-frame (SOF/EOF)
markers from configurable line and frame dimensions while preserving the
ready/valid stream contract.

`axi4s_video_adapter` accepts an AXI4-Stream video input, mapping `TUSER[0]`
to SOF and `TLAST` to EOL through a registered ready/valid boundary.

`three_line_buffer` accepts a fixed-width raster stream and outputs each
current pixel together with pixels from the same column in the prior two rows.
The first two rows use zero-filled history after reset.

`convolution_window_3x3` turns the current pixel and the two prior raster rows
into a 3x3 window suitable for streaming convolution kernels. Its default
zero-filled borders can optionally replicate the available left-edge pixel
into the window's left column and/or the available top-row pixels. It also
supports one-pixel raster lines, including both border-policy modes.

`sobel_xy` applies signed Sobel X and Y kernels to a 3x3 grayscale window.
For 8-bit input pixels, each result is an 11-bit signed gradient.

`gradient_magnitude` approximates edge strength as `abs(Gx) + abs(Gy)`. Its
11-bit unsigned output saturates at 2047 and preserves ready/valid
backpressure.

The `grayscale_to_sobel` Python reference pipeline composes the raster window
and Sobel models, returning one signed `(Gx, Gy)` pair per grayscale pixel.

`grayscale_to_edge_magnitude` extends that reference pipeline through the
saturated L1 gradient-magnitude model, returning one edge-strength value per
raster pixel with the same border-policy selections.

## Repository layout

```text
rtl/        Synthesizable SystemVerilog
tb/         Self-checking RTL testbenches
model/      Bit-accurate Python reference models
tests/      Python unit tests
docs/       Architecture notes
scripts/    Local verification commands
```

## Run the checks

Python 3 is enough for the reference-model tests:

```powershell
python -m unittest discover -s tests -p "test_*.py" -v
```

When Icarus Verilog is installed, run the complete local suite:

```powershell
.\scripts\run_tests.ps1 -RequireSimulator
```

GitHub Actions runs both the Python and RTL tests on every push and pull
request.

## Design goals

- Synthesizable, vendor-neutral SystemVerilog
- One pixel per clock after pipeline fill
- Explicit valid/ready flow control
- Bit-accurate software models
- Self-checking tests, including backpressure
- Small commits that advance a documented roadmap

See [ROADMAP.md](ROADMAP.md) for the planned pipeline.

## License

MIT
