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


def brightness_contrast(
    gray: int, brightness: int = 0, contrast_q8: int = 256
) -> int:
    """Apply signed brightness and 8.8 fixed-point contrast with saturation."""

    gray = _channel(gray, "gray")
    if not isinstance(brightness, int) or isinstance(brightness, bool):
        raise TypeError("brightness must be an integer")
    if not -512 <= brightness <= 511:
        raise ValueError("brightness must be in the range -512..511")
    if not isinstance(contrast_q8, int) or isinstance(contrast_q8, bool):
        raise TypeError("contrast_q8 must be an integer")
    if not -32768 <= contrast_q8 <= 32767:
        raise ValueError("contrast_q8 must be in the range -32768..32767")

    adjusted = ((gray - 128) * contrast_q8 >> 8) + 128 + brightness
    return max(0, min(255, adjusted))


class PixelStreamRegisterSlice:
    """Cycle-accurate model of the one-entry ready/valid register slice."""

    def __init__(self, data_width: int = 8) -> None:
        if not isinstance(data_width, int) or isinstance(data_width, bool):
            raise TypeError("data_width must be an integer")
        if data_width <= 0:
            raise ValueError("data_width must be positive")
        self.data_width = data_width
        self.reset()

    def reset(self) -> None:
        """Apply the RTL reset state."""

        self.m_valid = False
        self.m_data = 0

    def step(self, s_valid: bool, s_data: int, m_ready: bool) -> tuple[bool, bool, int]:
        """Return combinational signals, then advance one rising clock edge."""

        if not isinstance(s_valid, bool) or not isinstance(m_ready, bool):
            raise TypeError("valid and ready signals must be booleans")
        if not isinstance(s_data, int) or isinstance(s_data, bool):
            raise TypeError("s_data must be an integer")
        if not 0 <= s_data < (1 << self.data_width):
            raise ValueError("s_data does not fit data_width")

        s_ready = not self.m_valid or m_ready
        outputs = (s_ready, self.m_valid, self.m_data)
        if s_ready:
            self.m_valid = s_valid
            if s_valid:
                self.m_data = s_data
        return outputs
