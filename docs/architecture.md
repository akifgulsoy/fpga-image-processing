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
