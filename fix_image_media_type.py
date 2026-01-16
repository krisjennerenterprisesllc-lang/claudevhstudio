#!/usr/bin/env python3
"""
Image Media Type Detection Utility

Properly detects image media types by reading file magic bytes rather than
relying on file extensions. This fixes the issue where images are incorrectly
tagged with media_type "image/webp" when they are actually PNG, JPEG, or other formats.

Usage:
    python fix_image_media_type.py <image_file>

Returns:
    The correct media type (e.g., "image/png", "image/jpeg", "image/webp", "image/gif")
"""

import sys
from pathlib import Path
from typing import Optional


def detect_image_type(file_path: str) -> Optional[str]:
    """
    Detect the actual image type by reading file magic bytes.

    Args:
        file_path: Path to the image file

    Returns:
        The correct MIME type (e.g., "image/png") or None if unknown
    """
    try:
        with open(file_path, 'rb') as f:
            header = f.read(12)  # Read first 12 bytes

        if not header:
            return None

        # PNG: 89 50 4E 47 0D 0A 1A 0A
        if header[:8] == b'\x89PNG\r\n\x1a\n':
            return "image/png"

        # JPEG: FF D8 FF
        if header[:3] == b'\xff\xd8\xff':
            return "image/jpeg"

        # WebP: RIFF .... WEBP
        if header[:4] == b'RIFF' and header[8:12] == b'WEBP':
            return "image/webp"

        # GIF: GIF87a or GIF89a
        if header[:6] in (b'GIF87a', b'GIF89a'):
            return "image/gif"

        # BMP: BM
        if header[:2] == b'BM':
            return "image/bmp"

        # ICO: 00 00 01 00
        if header[:4] == b'\x00\x00\x01\x00':
            return "image/x-icon"

        # TIFF: II (little-endian) or MM (big-endian)
        if header[:2] in (b'II', b'MM'):
            return "image/tiff"

        return None

    except Exception as e:
        print(f"Error reading file: {e}", file=sys.stderr)
        return None


def get_base64_with_correct_type(file_path: str) -> tuple[str, str]:
    """
    Read an image file and return base64 data with the correct media type.

    Args:
        file_path: Path to the image file

    Returns:
        Tuple of (media_type, base64_data)
    """
    import base64

    media_type = detect_image_type(file_path)
    if not media_type:
        raise ValueError(f"Could not detect image type for {file_path}")

    with open(file_path, 'rb') as f:
        image_data = f.read()

    base64_data = base64.b64encode(image_data).decode('utf-8')

    return media_type, base64_data


def main():
    """CLI entry point."""
    if len(sys.argv) != 2:
        print("Usage: python fix_image_media_type.py <image_file>")
        print("\nDetects the actual image format by reading file headers.")
        sys.exit(1)

    file_path = sys.argv[1]

    if not Path(file_path).exists():
        print(f"Error: File not found: {file_path}", file=sys.stderr)
        sys.exit(1)

    media_type = detect_image_type(file_path)

    if media_type:
        print(media_type)
    else:
        print("Error: Could not detect image type", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
