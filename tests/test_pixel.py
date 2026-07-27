import unittest

from model import rgb_to_grayscale


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


if __name__ == "__main__":
    unittest.main()
