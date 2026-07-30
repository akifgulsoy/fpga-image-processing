import unittest

from model import (
    ConvolutionWindow3x3,
    PixelStreamRegisterSlice,
    ThreeLineBuffer,
    brightness_contrast,
    rgb_to_grayscale,
    threshold_to_mask,
)


class RgbToGrayscaleTests(unittest.TestCase):
    def test_primary_and_extreme_colors(self) -> None:
        vectors = {
            (0, 0, 0): 0,
            (255, 255, 255): 255,
            (255, 0, 0): 77,
            (0, 255, 0): 149,
            (0, 0, 255): 29,
        }
        for pixel, expected in vectors.items():
            with self.subTest(pixel=pixel):
                self.assertEqual(rgb_to_grayscale(*pixel), expected)

    def test_gray_axis_is_preserved(self) -> None:
        for value in range(256):
            with self.subTest(value=value):
                self.assertEqual(rgb_to_grayscale(value, value, value), value)

    def test_monotonic_per_channel(self) -> None:
        baseline = rgb_to_grayscale(20, 40, 60)
        self.assertGreaterEqual(rgb_to_grayscale(21, 40, 60), baseline)
        self.assertGreaterEqual(rgb_to_grayscale(20, 41, 60), baseline)
        self.assertGreaterEqual(rgb_to_grayscale(20, 40, 61), baseline)

    def test_rejects_out_of_range_or_non_integer_channels(self) -> None:
        for pixel in ((-1, 0, 0), (0, 256, 0), (0, 0, 3.5), (True, 0, 0)):
            with self.subTest(pixel=pixel):
                with self.assertRaises((TypeError, ValueError)):
                    rgb_to_grayscale(*pixel)


class ThresholdToMaskTests(unittest.TestCase):
    def test_default_threshold_boundary(self) -> None:
        self.assertEqual(threshold_to_mask(127), 0)
        self.assertEqual(threshold_to_mask(128), 1)
        self.assertEqual(threshold_to_mask(255), 1)

    def test_configurable_threshold_boundary(self) -> None:
        self.assertEqual(threshold_to_mask(31, 32), 0)
        self.assertEqual(threshold_to_mask(32, 32), 1)
        self.assertEqual(threshold_to_mask(0, 0), 1)
        self.assertEqual(threshold_to_mask(255, 255), 1)

    def test_rejects_invalid_values(self) -> None:
        for gray, threshold in ((-1, 128), (256, 128), (128, -1), (128, True)):
            with self.subTest(gray=gray, threshold=threshold):
                with self.assertRaises((TypeError, ValueError)):
                    threshold_to_mask(gray, threshold)


class BrightnessContrastTests(unittest.TestCase):
    def test_identity_defaults(self) -> None:
        for gray in range(256):
            with self.subTest(gray=gray):
                self.assertEqual(brightness_contrast(gray), gray)

    def test_brightness_contrast_and_saturation(self) -> None:
        self.assertEqual(brightness_contrast(128, brightness=16, contrast_q8=512), 144)
        self.assertEqual(brightness_contrast(120, brightness=16, contrast_q8=512), 128)
        self.assertEqual(brightness_contrast(0, brightness=16, contrast_q8=512), 0)
        self.assertEqual(brightness_contrast(255, brightness=16, contrast_q8=512), 255)

    def test_rejects_invalid_parameters(self) -> None:
        for args in ((0, 512, 256), (0, 0, 32768), (0, True, 256), (0, 0, False)):
            with self.subTest(args=args):
                with self.assertRaises((TypeError, ValueError)):
                    brightness_contrast(*args)


class PixelStreamRegisterSliceTests(unittest.TestCase):
    def test_captures_and_forwards_data(self) -> None:
        dut = PixelStreamRegisterSlice()
        self.assertEqual(dut.step(True, 37, True), (True, False, 0))
        self.assertEqual(dut.step(False, 0, True), (True, True, 37))
        self.assertEqual(dut.step(False, 0, True), (True, False, 37))

    def test_holds_payload_during_backpressure(self) -> None:
        dut = PixelStreamRegisterSlice()
        dut.step(True, 91, False)
        self.assertEqual(dut.step(False, 0, False), (False, True, 91))
        self.assertEqual(dut.step(True, 12, False), (False, True, 91))
        self.assertEqual(dut.step(False, 0, True), (True, True, 91))

    def test_validates_width_and_inputs(self) -> None:
        with self.assertRaises(ValueError):
            PixelStreamRegisterSlice(0)
        dut = PixelStreamRegisterSlice(4)
        with self.assertRaises(ValueError):
            dut.step(True, 16, True)
        with self.assertRaises(TypeError):
            dut.step(1, 0, True)


class ThreeLineBufferTests(unittest.TestCase):
    def test_returns_current_and_prior_rows_at_matching_column(self) -> None:
        dut = ThreeLineBuffer(line_pixels=4)
        samples = [10, 11, 12, 13, 20, 21, 22, 23, 30]
        expected = [
            (0, 0), (0, 0), (0, 0), (0, 0),
            (10, 0), (11, 0), (12, 0), (13, 0), (20, 10),
        ]
        for pixel, (line1, line2) in zip(samples, expected):
            dut.step(True, pixel, True)
            outputs = dut.step(False, 0, True)
            self.assertEqual(outputs, (True, True, pixel, line1, line2))

    def test_holds_all_outputs_during_backpressure(self) -> None:
        dut = ThreeLineBuffer(line_pixels=2)
        dut.step(True, 7, False)
        self.assertEqual(dut.step(False, 0, False), (False, True, 7, 0, 0))
        self.assertEqual(dut.step(True, 9, False), (False, True, 7, 0, 0))
        self.assertEqual(dut.step(False, 0, True), (True, True, 7, 0, 0))

    def test_validates_parameters_and_input_width(self) -> None:
        with self.assertRaises(ValueError):
            ThreeLineBuffer(line_pixels=0)
        dut = ThreeLineBuffer(pixel_width=4, line_pixels=1)
        with self.assertRaises(ValueError):
            dut.step(True, 16, True)
        with self.assertRaises(TypeError):
            dut.step(True, False, True)


class ConvolutionWindow3x3Tests(unittest.TestCase):
    def test_generates_raster_windows_with_zero_filled_borders(self) -> None:
        dut = ConvolutionWindow3x3(line_pixels=3)
        samples = [10, 11, 12, 20, 21, 22, 30, 31, 32]
        expected = [
            (0, 0, 0, 0, 0, 0, 0, 0, 10),
            (0, 0, 0, 0, 0, 0, 0, 10, 11),
            (0, 0, 0, 0, 0, 0, 10, 11, 12),
            (0, 0, 0, 0, 0, 10, 0, 0, 20),
            (0, 0, 0, 0, 10, 11, 0, 20, 21),
            (0, 0, 0, 10, 11, 12, 20, 21, 22),
            (0, 0, 10, 0, 0, 20, 0, 0, 30),
            (0, 10, 11, 0, 20, 21, 0, 30, 31),
            (10, 11, 12, 20, 21, 22, 30, 31, 32),
        ]
        for pixel, window in zip(samples, expected):
            dut.step(True, pixel, True)
            self.assertEqual(dut.step(False, 0, True), (True, True, window))

    def test_holds_window_during_backpressure(self) -> None:
        dut = ConvolutionWindow3x3(line_pixels=2)
        dut.step(True, 7, False)
        self.assertEqual(
            dut.step(False, 0, False), (False, True, (0, 0, 0, 0, 0, 0, 0, 0, 7))
        )
        self.assertEqual(
            dut.step(True, 9, False), (False, True, (0, 0, 0, 0, 0, 0, 0, 0, 7))
        )

    def test_validates_parameters_and_input_width(self) -> None:
        with self.assertRaises(ValueError):
            ConvolutionWindow3x3(line_pixels=0)
        dut = ConvolutionWindow3x3(pixel_width=4, line_pixels=1)
        with self.assertRaises(ValueError):
            dut.step(True, 16, True)
        with self.assertRaises(TypeError):
            dut.step(True, False, True)


if __name__ == "__main__":
    unittest.main()
