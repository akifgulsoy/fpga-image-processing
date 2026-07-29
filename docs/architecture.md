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
