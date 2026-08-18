import unittest

from model import (
    Axi4sVideoAdapter,
    ConvolutionWindow3x3,
    GradientMagnitude,
    PixelStreamFrameMetadata,
    PixelStreamLineMetadata,
    PixelStreamRegisterSlice,
    SobelXy,
    ThreeLineBuffer,
    brightness_contrast,
    grayscale_to_sobel,
    gradient_magnitude,
    rgb_to_grayscale,
    sobel_xy,
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


class PixelStreamLineMetadataTests(unittest.TestCase):
    def test_transfers_pixel_and_line_markers_together(self) -> None:
        dut = PixelStreamLineMetadata()
        self.assertEqual(dut.step(True, 10, True, False, True), (True, False, 0, False, False))
        self.assertEqual(dut.step(True, 11, False, False, True), (True, True, 10, True, False))
        self.assertEqual(dut.step(True, 12, False, True, True), (True, True, 11, False, False))
        self.assertEqual(dut.step(False, 0, False, False, True), (True, True, 12, False, True))

    def test_holds_pixel_and_markers_during_backpressure(self) -> None:
        dut = PixelStreamLineMetadata()
        dut.step(True, 91, True, True, False)
        self.assertEqual(dut.step(False, 0, False, False, False), (False, True, 91, True, True))
        self.assertEqual(dut.step(True, 12, False, False, False), (False, True, 91, True, True))

    def test_validates_width_and_marker_types(self) -> None:
        with self.assertRaises(ValueError):
            PixelStreamLineMetadata(0)
        dut = PixelStreamLineMetadata(4)
        with self.assertRaises(ValueError):
            dut.step(True, 16, False, False, True)
        with self.assertRaises(TypeError):
            dut.step(True, 0, 1, False, True)


class Axi4sVideoAdapterTests(unittest.TestCase):
    def test_transfers_axi_payload_and_video_markers(self) -> None:
        dut = Axi4sVideoAdapter()
        self.assertEqual(dut.step(True, 10, True, False, True), (True, False, 0, False, False))
        self.assertEqual(dut.step(True, 11, False, True, True), (True, True, 10, True, False))
        self.assertEqual(dut.step(False, 0, False, False, True), (True, True, 11, False, True))

    def test_holds_axi_payload_and_markers_during_backpressure(self) -> None:
        dut = Axi4sVideoAdapter()
        dut.step(True, 91, True, True, False)
        self.assertEqual(dut.step(False, 0, False, False, False), (False, True, 91, True, True))
        self.assertEqual(dut.step(True, 12, False, False, False), (False, True, 91, True, True))

    def test_validates_width_and_inputs(self) -> None:
        with self.assertRaises(ValueError):
            Axi4sVideoAdapter(0)
        dut = Axi4sVideoAdapter(4)
        with self.assertRaises(ValueError):
            dut.step(True, 16, False, False, True)
        with self.assertRaises(TypeError):
            dut.step(True, 0, 1, False, True)


class PixelStreamFrameMetadataTests(unittest.TestCase):
    def test_generates_markers_for_configured_raster(self) -> None:
        dut = PixelStreamFrameMetadata(line_pixels=2, frame_lines=2)
        expected = [
            (True, False, 0, False, False, False, False),
            (True, True, 10, True, False, True, False),
            (True, True, 11, False, True, False, False),
            (True, True, 12, True, False, False, False),
            (True, True, 13, False, True, False, True),
            (True, True, 14, True, False, True, False),
        ]
        inputs = [10, 11, 12, 13, 14]
        for pixel, output in zip(inputs, expected):
            self.assertEqual(dut.step(True, pixel, True), output)
        self.assertEqual(dut.step(False, 0, True), expected[-1])

    def test_holds_frame_metadata_during_backpressure(self) -> None:
        dut = PixelStreamFrameMetadata(line_pixels=1, frame_lines=1)
        dut.step(True, 91, False)
        self.assertEqual(dut.step(False, 0, False), (False, True, 91, True, True, True, True))
        self.assertEqual(dut.step(True, 12, False), (False, True, 91, True, True, True, True))

    def test_validates_parameters_and_input_width(self) -> None:
        with self.assertRaises(ValueError):
            PixelStreamFrameMetadata(frame_lines=0)
        dut = PixelStreamFrameMetadata(pixel_width=4)
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

    def test_replicates_available_pixels_at_left_border_when_enabled(self) -> None:
        dut = ConvolutionWindow3x3(line_pixels=3, replicate_left_border=True)
        samples = [10, 11, 12, 20, 21, 22, 30]
        expected = [
            (0, 0, 0, 0, 0, 0, 10, 10, 10),
            (0, 0, 0, 0, 0, 0, 10, 10, 11),
            (0, 0, 0, 0, 0, 0, 10, 11, 12),
            (0, 0, 0, 10, 10, 10, 20, 20, 20),
            (0, 0, 0, 10, 10, 11, 20, 20, 21),
            (0, 0, 0, 10, 11, 12, 20, 21, 22),
            (10, 10, 10, 20, 20, 20, 30, 30, 30),
        ]
        for pixel, window in zip(samples, expected):
            dut.step(True, pixel, True)
            self.assertEqual(dut.step(False, 0, True), (True, True, window))

    def test_replicates_available_pixels_at_top_border_when_enabled(self) -> None:
        dut = ConvolutionWindow3x3(line_pixels=3, replicate_top_border=True)
        samples = [10, 11, 12, 20, 21, 22, 30]
        expected = [
            (0, 0, 10, 0, 0, 10, 0, 0, 10),
            (0, 10, 11, 0, 10, 11, 0, 10, 11),
            (10, 11, 12, 10, 11, 12, 10, 11, 12),
            (0, 0, 10, 0, 0, 10, 0, 0, 20),
            (0, 10, 11, 0, 10, 11, 0, 20, 21),
            (10, 11, 12, 10, 11, 12, 20, 21, 22),
            (0, 0, 10, 0, 0, 20, 0, 0, 30),
        ]
        for pixel, window in zip(samples, expected):
            dut.step(True, pixel, True)
            self.assertEqual(dut.step(False, 0, True), (True, True, window))

    def test_combines_left_and_top_border_replication(self) -> None:
        dut = ConvolutionWindow3x3(
            line_pixels=3, replicate_left_border=True, replicate_top_border=True
        )
        samples = [10, 11, 12, 20, 21, 22, 30, 31, 32]
        expected = [
            (10, 10, 10, 10, 10, 10, 10, 10, 10),
            (10, 10, 11, 10, 10, 11, 10, 10, 11),
            (10, 11, 12, 10, 11, 12, 10, 11, 12),
            (10, 10, 10, 10, 10, 10, 20, 20, 20),
            (10, 10, 11, 10, 10, 11, 20, 20, 21),
            (10, 11, 12, 10, 11, 12, 20, 21, 22),
            (10, 10, 10, 20, 20, 20, 30, 30, 30),
            (10, 10, 11, 20, 20, 21, 30, 30, 31),
            (10, 11, 12, 20, 21, 22, 30, 31, 32),
        ]
        for pixel, window in zip(samples, expected):
            dut.step(True, pixel, True)
            self.assertEqual(dut.step(False, 0, True), (True, True, window))

    def test_supports_single_pixel_lines(self) -> None:
        samples = [10, 20, 30]
        zero_filled = [
            (0, 0, 0, 0, 0, 0, 0, 0, 10),
            (0, 0, 0, 0, 0, 10, 0, 0, 20),
            (0, 0, 10, 0, 0, 20, 0, 0, 30),
        ]
        replicated = [
            (10, 10, 10, 10, 10, 10, 10, 10, 10),
            (10, 10, 10, 10, 10, 10, 20, 20, 20),
            (10, 10, 10, 20, 20, 20, 30, 30, 30),
        ]

        for dut, expected in (
            (ConvolutionWindow3x3(line_pixels=1), zero_filled),
            (ConvolutionWindow3x3(
                line_pixels=1,
                replicate_left_border=True,
                replicate_top_border=True,
            ), replicated),
        ):
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
        with self.assertRaises(TypeError):
            ConvolutionWindow3x3(replicate_left_border=1)
        with self.assertRaises(TypeError):
            ConvolutionWindow3x3(replicate_top_border=1)


class SobelXyTests(unittest.TestCase):
    def test_detects_horizontal_and_vertical_edges(self) -> None:
        self.assertEqual(sobel_xy((0, 0, 255, 0, 0, 255, 0, 0, 255)), (1020, 0))
        self.assertEqual(sobel_xy((255, 255, 255, 0, 0, 0, 0, 0, 0)), (0, -1020))

    def test_holds_signed_gradients_during_backpressure(self) -> None:
        dut = SobelXy()
        window = (255, 0, 0, 255, 0, 0, 255, 0, 0)
        dut.step(True, window, False)
        self.assertEqual(dut.step(False, (0,) * 9, False), (False, True, -1020, 0))
        self.assertEqual(dut.step(True, (0,) * 9, False), (False, True, -1020, 0))

    def test_rejects_invalid_window(self) -> None:
        with self.assertRaises(ValueError): sobel_xy((0,) * 8)
        with self.assertRaises(ValueError): sobel_xy((0,) * 8 + (256,))


class GrayscaleToSobelPipelineTests(unittest.TestCase):
    def test_composes_raster_windows_and_sobel_gradients(self) -> None:
        pixels = (0, 0, 255, 0, 0, 255, 0, 0, 255)
        gradients = grayscale_to_sobel(pixels, line_pixels=3)

        self.assertEqual(len(gradients), len(pixels))
        self.assertEqual(gradients[-1], (1020, 0))

    def test_applies_configured_border_policy(self) -> None:
        self.assertEqual(
            grayscale_to_sobel(
                (10,), line_pixels=1,
                replicate_left_border=True,
                replicate_top_border=True,
            ),
            ((0, 0),),
        )

    def test_rejects_non_tuple_raster(self) -> None:
        with self.assertRaises(TypeError):
            grayscale_to_sobel([0, 1], line_pixels=2)


class GradientMagnitudeTests(unittest.TestCase):
    def test_calculates_l1_gradient_magnitude(self) -> None:
        self.assertEqual(gradient_magnitude(1020, 0), 1020)
        self.assertEqual(gradient_magnitude(-300, 200), 500)
        self.assertEqual(gradient_magnitude(-1020, 510), 1530)

    def test_saturates_full_width_inputs(self) -> None:
        self.assertEqual(gradient_magnitude(-1024, -1024), 2047)

    def test_holds_magnitude_during_backpressure(self) -> None:
        dut = GradientMagnitude()
        dut.step(True, -1020, 510, False)
        self.assertEqual(dut.step(False, 0, 0, False), (False, True, 1530))
        self.assertEqual(dut.step(True, 0, 0, False), (False, True, 1530))

    def test_rejects_invalid_gradients(self) -> None:
        with self.assertRaises(ValueError):
            gradient_magnitude(-1025, 0)
        with self.assertRaises(TypeError):
            gradient_magnitude(True, 0)


if __name__ == "__main__":
    unittest.main()
