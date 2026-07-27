"""Reference models for pixel-level RTL blocks."""


def _channel(value: int, name: str) -> int:
    if not isinstance(value, int) or isinstance(value, bool):
        raise TypeError(f"{name} must be an integer")
    if not 0 <= value <= 255:
        raise ValueError(f"{name} must be in the range 0..255")
    return value


def rgb_to_grayscale(red: int, green: int, blue: int) -> int:
    """Convert one RGB888 pixel using the RTL's fixed-point coefficients."""

    red = _channel(red, "red")
    green = _channel(green, "green")
    blue = _channel(blue, "blue")
    return (77 * red + 150 * green + 29 * blue + 128) >> 8


def threshold_to_mask(gray: int, threshold: int = 128) -> int:
    """Convert an 8-bit grayscale pixel to a binary mask bit.

    Pixels at or above ``threshold`` map to one, matching the RTL's
    unsigned greater-than-or-equal comparison.
    """

    gray = _channel(gray, "gray")
    threshold = _channel(threshold, "threshold")
    return int(gray >= threshold)
