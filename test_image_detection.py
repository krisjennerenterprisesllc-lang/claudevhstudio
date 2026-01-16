#!/usr/bin/env python3
"""
Test script for image media type detection.

Creates sample images in different formats and validates that the detection
utility correctly identifies each format.
"""

import os
import sys
from pathlib import Path

# Add current directory to path to import the fix module
sys.path.insert(0, str(Path(__file__).parent))

from fix_image_media_type import detect_image_type


def create_test_images():
    """Create minimal valid images in different formats for testing."""
    test_dir = Path("test_images")
    test_dir.mkdir(exist_ok=True)

    test_files = {}

    # Minimal 1x1 PNG (67 bytes)
    png_data = (
        b'\x89PNG\r\n\x1a\n'  # PNG signature
        b'\x00\x00\x00\rIHDR'  # IHDR chunk
        b'\x00\x00\x00\x01\x00\x00\x00\x01'  # 1x1 dimensions
        b'\x08\x02\x00\x00\x00\x90wS\xde'  # bit depth, color type, CRC
        b'\x00\x00\x00\x0cIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4'  # IDAT chunk
        b'\x00\x00\x00\x00IEND\xaeB`\x82'  # IEND chunk
    )
    png_file = test_dir / "test.png"
    png_file.write_bytes(png_data)
    test_files["PNG"] = str(png_file)

    # Minimal JPEG (134 bytes) - 1x1 white pixel
    jpeg_data = (
        b'\xff\xd8\xff\xe0'  # JPEG SOI + APP0
        b'\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00'
        b'\xff\xdb\x00C'  # DQT
        b'\x00\x08\x06\x06\x07\x06\x05\x08\x07\x07\x07\t\t\x08\n\x0c\x14\r\x0c\x0b\x0b\x0c'
        b'\x19\x12\x13\x0f\x14\x1d\x1a\x1f\x1e\x1d\x1a\x1c\x1c $.\' ",#\x1c\x1c(7),01444'
        b'\x1f\'9=82<.342'
        b'\xff\xc0\x00\x0b\x08\x00\x01\x00\x01\x01\x01\x11\x00'  # SOF0 (1x1)
        b'\xff\xc4\x00\x14\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'  # DHT
        b'\xff\xda\x00\x08\x01\x01\x00\x00?\x00\x7f\x00'  # SOS + minimal scan data
        b'\xff\xd9'  # EOI
    )
    jpeg_file = test_dir / "test.jpg"
    jpeg_file.write_bytes(jpeg_data)
    test_files["JPEG"] = str(jpeg_file)

    # Minimal WebP (44 bytes)
    webp_data = (
        b'RIFF'  # RIFF header
        b'\x24\x00\x00\x00'  # File size - 8
        b'WEBP'  # WebP signature
        b'VP8 '  # VP8 chunk
        b'\x18\x00\x00\x00'  # Chunk size
        b'\x30\x01\x00\x9d\x01\x2a\x01\x00\x01\x00'  # VP8 header for 1x1
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'  # Padding
    )
    webp_file = test_dir / "test.webp"
    webp_file.write_bytes(webp_data)
    test_files["WebP"] = str(webp_file)

    # Minimal GIF (35 bytes) - 1x1 transparent pixel
    gif_data = (
        b'GIF89a'  # GIF signature
        b'\x01\x00\x01\x00'  # 1x1 dimensions
        b'\x80\x00\x00'  # Global color table info
        b'\xff\xff\xff\x00\x00\x00'  # Color table (white, black)
        b'\x21\xf9\x04\x01\x00\x00\x00\x00'  # Graphics control extension
        b'\x2c\x00\x00\x00\x00\x01\x00\x01\x00\x00'  # Image descriptor
        b'\x02\x02\x44\x01\x00'  # Image data
        b'\x3b'  # GIF trailer
    )
    gif_file = test_dir / "test.gif"
    gif_file.write_bytes(gif_data)
    test_files["GIF"] = str(gif_file)

    return test_files


def test_detection():
    """Test the image type detection on various formats."""
    print("Creating test images...")
    test_files = create_test_images()

    print("\nTesting image type detection:\n")

    expected = {
        "PNG": "image/png",
        "JPEG": "image/jpeg",
        "WebP": "image/webp",
        "GIF": "image/gif",
    }

    all_passed = True

    for format_name, file_path in test_files.items():
        detected = detect_image_type(file_path)
        expected_type = expected[format_name]

        status = "✅ PASS" if detected == expected_type else "❌ FAIL"
        print(f"{status} - {format_name:5s}: {file_path}")
        print(f"         Expected: {expected_type}")
        print(f"         Detected: {detected}")
        print()

        if detected != expected_type:
            all_passed = False

    # Test with misnamed files (wrong extension)
    print("Testing with misnamed files (wrong extensions):\n")

    # Rename PNG to .webp
    png_as_webp = Path("test_images") / "fake.webp"
    Path(test_files["PNG"]).rename(png_as_webp)

    detected = detect_image_type(str(png_as_webp))
    status = "✅ PASS" if detected == "image/png" else "❌ FAIL"
    print(f"{status} - PNG file named .webp")
    print(f"         File: {png_as_webp}")
    print(f"         Expected: image/png (actual content)")
    print(f"         Detected: {detected}")
    print()

    if detected != "image/png":
        all_passed = False

    # Cleanup
    print("\nCleaning up test files...")
    import shutil
    shutil.rmtree("test_images")

    if all_passed:
        print("\n✅ All tests passed!")
        return 0
    else:
        print("\n❌ Some tests failed!")
        return 1


if __name__ == "__main__":
    sys.exit(test_detection())
