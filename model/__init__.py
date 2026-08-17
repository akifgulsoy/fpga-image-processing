"""Bit-accurate reference models for the FPGA image pipeline."""

from .pixel import (
    Axi4sVideoAdapter,
    ConvolutionWindow3x3,
    GradientMagnitude,
    PixelStreamFrameMetadata,
    PixelStreamLineMetadata,
    PixelStreamRegisterSlice,
    SobelXy,
    ThreeLineBuffer,
    brightness_contrast,
    gradient_magnitude,
    rgb_to_grayscale,
    sobel_xy,
    threshold_to_mask,
)

__all__ = [
    "Axi4sVideoAdapter",
    "ConvolutionWindow3x3",
    "GradientMagnitude",
    "PixelStreamFrameMetadata",
    "PixelStreamLineMetadata",
    "PixelStreamRegisterSlice",
    "SobelXy",
    "ThreeLineBuffer",
    "brightness_contrast",
    "gradient_magnitude",
    "rgb_to_grayscale",
    "sobel_xy",
    "threshold_to_mask",
]
