"""Bit-accurate reference models for the FPGA image pipeline."""

from .pixel import rgb_to_grayscale, threshold_to_mask

__all__ = ["rgb_to_grayscale", "threshold_to_mask"]
