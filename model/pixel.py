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


class ThreeLineBuffer:
    """Cycle-accurate model of a current-plus-two-prior-line buffer."""

    def __init__(self, pixel_width: int = 8, line_pixels: int = 640) -> None:
        if not isinstance(pixel_width, int) or isinstance(pixel_width, bool):
            raise TypeError("pixel_width must be an integer")
        if not isinstance(line_pixels, int) or isinstance(line_pixels, bool):
            raise TypeError("line_pixels must be an integer")
        if pixel_width <= 0:
            raise ValueError("pixel_width must be positive")
        if line_pixels <= 0:
            raise ValueError("line_pixels must be positive")
        self.pixel_width = pixel_width
        self.line_pixels = line_pixels
        self.reset()

    def reset(self) -> None:
        """Apply the RTL reset state, clearing the two prior line histories."""

        self.column = 0
        self.line1 = [0] * self.line_pixels
        self.line2 = [0] * self.line_pixels
        self.m_valid = False
        self.m_pixel = 0
        self.m_line1_pixel = 0
        self.m_line2_pixel = 0

    def step(
        self, s_valid: bool, s_pixel: int, m_ready: bool
    ) -> tuple[bool, bool, int, int, int]:
        """Return combinational signals, then advance one rising clock edge."""

        if not isinstance(s_valid, bool) or not isinstance(m_ready, bool):
            raise TypeError("valid and ready signals must be booleans")
        if not isinstance(s_pixel, int) or isinstance(s_pixel, bool):
            raise TypeError("s_pixel must be an integer")
        if not 0 <= s_pixel < (1 << self.pixel_width):
            raise ValueError("s_pixel does not fit pixel_width")

        s_ready = not self.m_valid or m_ready
        outputs = (
            s_ready,
            self.m_valid,
            self.m_pixel,
            self.m_line1_pixel,
            self.m_line2_pixel,
        )
        if s_ready:
            self.m_valid = s_valid
            if s_valid:
                self.m_pixel = s_pixel
                self.m_line1_pixel = self.line1[self.column]
                self.m_line2_pixel = self.line2[self.column]
                self.line2[self.column] = self.line1[self.column]
                self.line1[self.column] = s_pixel
                self.column = (self.column + 1) % self.line_pixels
        return outputs
