# Architecture

## Stream contract

Blocks use a ready/valid pixel stream:

- A transfer occurs on a rising clock edge when both `valid` and `ready` are
  high.
- A producer holds payload and `valid` stable while `ready` is low.
- Reset is asynchronous and active low.

The initial grayscale block contains one output register. It accepts a new
pixel whenever that register is empty or the downstream block consumes its
current value. This permits one pixel per clock without dropping data during
backpressure.

## Grayscale arithmetic

The conversion uses fixed integer coefficients:

```text
gray = (77 * red + 150 * green + 29 * blue + 128) / 256
```

The coefficients sum to 256, so black maps to 0 and white maps to 255. Adding
128 provides round-to-nearest behavior before the right shift.

## Threshold and binary mask

`threshold_to_mask` has one registered output and follows the same ready/valid
contract as the grayscale stage. It compares each unsigned 8-bit grayscale
pixel against the `THRESHOLD` parameter (128 by default). A pixel transfers as
mask bit `1` when `gray >= THRESHOLD`; otherwise it transfers as `0`.

## Brightness and contrast

`brightness_contrast` has one registered output and preserves the stream
contract under backpressure. It calculates
`((gray - 128) * CONTRAST_Q8 >>> 8) + 128 + BRIGHTNESS`, then saturates the
result to unsigned 8-bit range. `CONTRAST_Q8` is signed 8.8 fixed point, so
its default value of 256 is unity gain; `BRIGHTNESS` is a signed output-code
offset.

## Pixel stream register slice

`pixel_stream_register_slice` provides a parameterized-width, one-entry
registered boundary for any compatible ready/valid pixel stream. It accepts
an input when its register is empty or the current output is accepted, and
holds the registered payload stable while downstream `ready` is low.

## Three-line buffer

## Start/end-of-line metadata

`pixel_stream_line_metadata` is a one-entry stream boundary for a pixel and
its line markers. `SOL` marks the first pixel of a line and `EOL` its last;
the module transfers both flags with the pixel and holds all three outputs
stable whenever downstream backpressure is asserted.

## Configurable frame dimensions

`pixel_stream_frame_metadata` derives raster metadata from `LINE_PIXELS` and
`FRAME_LINES` parameters. It emits `SOL` and `EOL` at the configured column
bounds and `SOF` and `EOF` at the first and last pixels of the configured
frame. Column and line counters advance only when an input transfer is
accepted, so all markers and their pixel remain stable during backpressure.

`three_line_buffer` stores two prior raster rows for a fixed `LINE_PIXELS`
width. On each accepted input pixel, it emits that pixel and the two stored
pixels at the current column, then updates both history rows and advances the
column. The column advances only on input transfers, so downstream
backpressure preserves raster alignment. Reset clears the histories, making
the unavailable prior rows zero-filled.

## 3x3 convolution window

`convolution_window_3x3` extends the two-row history with horizontal shift
registers. Each accepted pixel produces a registered window whose bottom-right
entry is the current pixel; its top and middle rows are the corresponding
pixels from the two prior rows. The first two raster rows and the leftmost
column are zero-filled by default. Setting `REPLICATE_LEFT_BORDER` makes the
leftmost output column repeat each available row's first pixel instead; missing
prior rows remain zero-filled. Horizontal state resets at each fixed-width line
boundary, and all state advances only on a ready/valid input transfer.

## Sobel X/Y kernels

`sobel_xy` consumes a 3x3 grayscale window and registers the signed gradients:
`Gx = (tr - tl) + 2(mr - ml) + (br - bl)` and
`Gy = (bl - tl) + 2(bm - tm) + (br - tr)`. For 8-bit pixels each result fits
in signed 11 bits (-1020 through 1020), and the output stays stable while
downstream backpressure is asserted.

## Gradient magnitude

`gradient_magnitude` calculates the hardware-friendly L1 approximation
`abs(Gx) + abs(Gy)` from signed Sobel gradients. It registers the unsigned
result, saturating at the representable 11-bit maximum (2047 for 8-bit
pixels), and holds it stable until the downstream stage accepts it.
