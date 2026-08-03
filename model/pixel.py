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


class PixelStreamLineMetadata:
    """Cycle-accurate register slice for pixels and line markers."""
    def __init__(self, pixel_width: int = 8) -> None:
        if not isinstance(pixel_width, int) or isinstance(pixel_width, bool):
            raise TypeError("pixel_width must be an integer")
        if pixel_width <= 0:
            raise ValueError("pixel_width must be positive")
        self.pixel_width = pixel_width
        self.reset()

    def reset(self) -> None:
        self.m_valid = False
        self.m_pixel = 0
        self.m_sol = False
        self.m_eol = False

    def step(self, s_valid: bool, s_pixel: int, s_sol: bool, s_eol: bool, m_ready: bool) -> tuple[bool, bool, int, bool, bool]:
        if not all(isinstance(value, bool) for value in (s_valid, s_sol, s_eol, m_ready)):
            raise TypeError("valid, line markers, and ready signals must be booleans")
        if not isinstance(s_pixel, int) or isinstance(s_pixel, bool):
            raise TypeError("s_pixel must be an integer")
        if not 0 <= s_pixel < (1 << self.pixel_width):
            raise ValueError("s_pixel does not fit pixel_width")
        s_ready = not self.m_valid or m_ready
        outputs = (s_ready, self.m_valid, self.m_pixel, self.m_sol, self.m_eol)
        if s_ready:
            self.m_valid = s_valid
            if s_valid:
                self.m_pixel, self.m_sol, self.m_eol = s_pixel, s_sol, s_eol
        return outputs


class PixelStreamFrameMetadata:
    """Cycle-accurate raster marker generator for configured frame dimensions."""

    def __init__(self, pixel_width: int = 8, line_pixels: int = 640, frame_lines: int = 480) -> None:
        if any(not isinstance(value, int) or isinstance(value, bool)
               for value in (pixel_width, line_pixels, frame_lines)):
            raise TypeError("pixel_width, line_pixels, and frame_lines must be integers")
        if pixel_width <= 0 or line_pixels <= 0 or frame_lines <= 0:
            raise ValueError("pixel_width, line_pixels, and frame_lines must be positive")
        self.pixel_width = pixel_width
        self.line_pixels = line_pixels
        self.frame_lines = frame_lines
        self.reset()

    def reset(self) -> None:
        self.column = self.line = 0
        self.m_valid = False
        self.m_pixel = 0
        self.m_sol = self.m_eol = self.m_sof = self.m_eof = False

    def step(self, s_valid: bool, s_pixel: int, m_ready: bool) -> tuple[bool, bool, int, bool, bool, bool, bool]:
        if not isinstance(s_valid, bool) or not isinstance(m_ready, bool):
            raise TypeError("valid and ready signals must be booleans")
        if not isinstance(s_pixel, int) or isinstance(s_pixel, bool):
            raise TypeError("s_pixel must be an integer")
        if not 0 <= s_pixel < (1 << self.pixel_width):
            raise ValueError("s_pixel does not fit pixel_width")
        s_ready = not self.m_valid or m_ready
        outputs = (s_ready, self.m_valid, self.m_pixel, self.m_sol, self.m_eol,
                   self.m_sof, self.m_eof)
        if s_ready:
            self.m_valid = s_valid
            if s_valid:
                self.m_pixel = s_pixel
                self.m_sol = self.column == 0
                self.m_eol = self.column == self.line_pixels - 1
                self.m_sof = self.m_sol and self.line == 0
                self.m_eof = self.m_eol and self.line == self.frame_lines - 1
                if self.m_eol:
                    self.column = 0
                    self.line = (self.line + 1) % self.frame_lines
                else:
                    self.column += 1
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


class ConvolutionWindow3x3:
    """Cycle-accurate model of a zero-filled 3x3 raster window generator."""

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
        """Apply the RTL reset state, clearing history and left borders."""

        self.column = 0
        self.line1 = [0] * self.line_pixels
        self.line2 = [0] * self.line_pixels
        self.top_left = self.top_mid = 0
        self.mid_left = self.mid_mid = 0
        self.bot_left = self.bot_mid = 0
        self.m_valid = False
        self.window = (0,) * 9

    def step(
        self, s_valid: bool, s_pixel: int, m_ready: bool
    ) -> tuple[bool, bool, tuple[int, ...]]:
        """Return combinational signals, then advance one rising clock edge."""

        if not isinstance(s_valid, bool) or not isinstance(m_ready, bool):
            raise TypeError("valid and ready signals must be booleans")
        if not isinstance(s_pixel, int) or isinstance(s_pixel, bool):
            raise TypeError("s_pixel must be an integer")
        if not 0 <= s_pixel < (1 << self.pixel_width):
            raise ValueError("s_pixel does not fit pixel_width")

        s_ready = not self.m_valid or m_ready
        outputs = (s_ready, self.m_valid, self.window)
        if s_ready:
            self.m_valid = s_valid
            if s_valid:
                top_right = self.line2[self.column]
                mid_right = self.line1[self.column]
                self.window = (
                    self.top_left, self.top_mid, top_right,
                    self.mid_left, self.mid_mid, mid_right,
                    self.bot_left, self.bot_mid, s_pixel,
                )
                self.line2[self.column] = mid_right
                self.line1[self.column] = s_pixel
                if self.column == self.line_pixels - 1:
                    self.column = 0
                    self.top_left = self.top_mid = 0
                    self.mid_left = self.mid_mid = 0
                    self.bot_left = self.bot_mid = 0
                else:
                    self.column += 1
                    self.top_left, self.top_mid = self.top_mid, top_right
                    self.mid_left, self.mid_mid = self.mid_mid, mid_right
                    self.bot_left, self.bot_mid = self.bot_mid, s_pixel
        return outputs


def sobel_xy(window: tuple[int, ...], pixel_width: int = 8) -> tuple[int, int]:
    """Calculate signed Sobel X/Y gradients for one 3x3 grayscale window."""
    if not isinstance(pixel_width, int) or isinstance(pixel_width, bool):
        raise TypeError("pixel_width must be an integer")
    if pixel_width <= 0:
        raise ValueError("pixel_width must be positive")
    if not isinstance(window, tuple) or len(window) != 9:
        raise ValueError("window must be a nine-element tuple")
    maximum = (1 << pixel_width) - 1
    if any(not isinstance(pixel, int) or isinstance(pixel, bool) or not 0 <= pixel <= maximum for pixel in window):
        raise ValueError("window pixels must fit pixel_width")
    tl, tm, tr, ml, _mm, mr, bl, bm, br = window
    return (tr - tl + 2 * (mr - ml) + br - bl,
            bl - tl + 2 * (bm - tm) + br - tr)


class SobelXy:
    """Cycle-accurate model of the registered Sobel X/Y stage."""
    def __init__(self, pixel_width: int = 8) -> None:
        self.pixel_width = pixel_width
        self.reset()

    def reset(self) -> None:
        self.m_valid = False
        self.m_gx = self.m_gy = 0

    def step(self, s_valid: bool, window: tuple[int, ...], m_ready: bool) -> tuple[bool, bool, int, int]:
        if not isinstance(s_valid, bool) or not isinstance(m_ready, bool):
            raise TypeError("valid and ready signals must be booleans")
        gradients = sobel_xy(window, self.pixel_width)
        s_ready = not self.m_valid or m_ready
        outputs = (s_ready, self.m_valid, self.m_gx, self.m_gy)
        if s_ready:
            self.m_valid = s_valid
            if s_valid:
                self.m_gx, self.m_gy = gradients
        return outputs


def gradient_magnitude(gx: int, gy: int, pixel_width: int = 8) -> int:
    """Approximate gradient magnitude as saturated ``abs(gx) + abs(gy)``."""
    if not isinstance(pixel_width, int) or isinstance(pixel_width, bool):
        raise TypeError("pixel_width must be an integer")
    if pixel_width <= 0:
        raise ValueError("pixel_width must be positive")
    limit = 1 << (pixel_width + 2)
    for value, name in ((gx, "gx"), (gy, "gy")):
        if not isinstance(value, int) or isinstance(value, bool):
            raise TypeError(f"{name} must be an integer")
        if not -limit <= value < limit:
            raise ValueError(f"{name} does not fit the signed gradient width")
    return min((1 << (pixel_width + 3)) - 1, abs(gx) + abs(gy))


class GradientMagnitude:
    """Cycle-accurate model of the registered gradient magnitude stage."""

    def __init__(self, pixel_width: int = 8) -> None:
        self.pixel_width = pixel_width
        self.reset()

    def reset(self) -> None:
        self.m_valid = False
        self.m_magnitude = 0

    def step(self, s_valid: bool, gx: int, gy: int, m_ready: bool) -> tuple[bool, bool, int]:
        if not isinstance(s_valid, bool) or not isinstance(m_ready, bool):
            raise TypeError("valid and ready signals must be booleans")
        magnitude = gradient_magnitude(gx, gy, self.pixel_width)
        s_ready = not self.m_valid or m_ready
        outputs = (s_ready, self.m_valid, self.m_magnitude)
        if s_ready:
            self.m_valid = s_valid
            if s_valid:
                self.m_magnitude = magnitude
        return outputs
