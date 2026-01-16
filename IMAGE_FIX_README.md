# Image Media Type Fix

## Problem

When uploading images to the Anthropic Claude API, you may encounter this error:

```
API Error: 400 {"type":"error","error":{"type":"invalid_request_error",
"message":"messages.14.content.6.image.source.base64.data: Image does not
match the provided media type image/webp"}}
```

This happens when the `media_type` field doesn't match the actual image format in the base64 data.

## Root Cause

The error occurs when code incorrectly determines the image type, often by:
- Hardcoding `media_type` as `"image/webp"`
- Using file extension only (which can be wrong or missing)
- Not validating the actual image data format

## Solution

Use the provided `fix_image_media_type.py` utility to detect the actual image format by reading file magic bytes (file headers).

### Basic Usage

```bash
# Detect image type
python fix_image_media_type.py screenshot.png
# Output: image/png

python fix_image_media_type.py photo.jpg
# Output: image/jpeg
```

### Integration with Anthropic API (Python)

```python
from fix_image_media_type import get_base64_with_correct_type
import anthropic

# Properly detect and encode image
media_type, base64_data = get_base64_with_correct_type("screenshot.png")

client = anthropic.Anthropic(api_key="your-api-key")

message = client.messages.create(
    model="claude-3-5-sonnet-20241022",
    max_tokens=1024,
    messages=[
        {
            "role": "user",
            "content": [
                {
                    "type": "image",
                    "source": {
                        "type": "base64",
                        "media_type": media_type,  # Correctly detected!
                        "data": base64_data,
                    },
                },
                {
                    "type": "text",
                    "text": "What's in this image?"
                }
            ],
        }
    ],
)
```

### Integration Example (TypeScript/JavaScript)

```typescript
import { exec } from 'child_process';
import { promisify } from 'util';
import fs from 'fs';

const execAsync = promisify(exec);

async function getImageMediaType(filePath: string): Promise<string> {
  const { stdout } = await execAsync(`python fix_image_media_type.py "${filePath}"`);
  return stdout.trim();
}

async function sendImageToClaude(imagePath: string, prompt: string) {
  const mediaType = await getImageMediaType(imagePath);
  const imageData = fs.readFileSync(imagePath).toString('base64');

  const response = await anthropic.messages.create({
    model: 'claude-3-5-sonnet-20241022',
    max_tokens: 1024,
    messages: [
      {
        role: 'user',
        content: [
          {
            type: 'image',
            source: {
              type: 'base64',
              media_type: mediaType,  // Correctly detected!
              data: imageData,
            },
          },
          {
            type: 'text',
            text: prompt,
          },
        ],
      },
    ],
  });

  return response;
}
```

## Supported Image Formats

The utility correctly detects:

- **PNG** (`image/png`) - Magic bytes: `89 50 4E 47 0D 0A 1A 0A`
- **JPEG** (`image/jpeg`) - Magic bytes: `FF D8 FF`
- **WebP** (`image/webp`) - Magic bytes: `RIFF ... WEBP`
- **GIF** (`image/gif`) - Magic bytes: `GIF87a` or `GIF89a`
- **BMP** (`image/bmp`) - Magic bytes: `BM`
- **ICO** (`image/x-icon`) - Magic bytes: `00 00 01 00`
- **TIFF** (`image/tiff`) - Magic bytes: `II` or `MM`

## How It Works

Instead of trusting file extensions, the utility reads the first few bytes of the file (magic bytes/file signature) to determine the actual format:

```python
from fix_image_media_type import detect_image_type

# Returns "image/png" even if file is named "photo.webp"
actual_type = detect_image_type("photo.webp")
```

## Testing

Create test images and verify detection:

```bash
# Test with various formats
python fix_image_media_type.py test.png
python fix_image_media_type.py test.jpg
python fix_image_media_type.py test.webp
python fix_image_media_type.py test.gif
```

## Common Mistakes to Avoid

❌ **WRONG** - Using file extension only:
```python
# Don't do this!
ext = file_path.split('.')[-1]
media_type = f"image/{ext}"  # Can be wrong!
```

❌ **WRONG** - Hardcoding media type:
```python
# Don't do this!
media_type = "image/webp"  # Assumes all images are WebP
```

✅ **CORRECT** - Detect from file content:
```python
from fix_image_media_type import detect_image_type
media_type = detect_image_type(file_path)  # Reads actual file data
```

## License

Copyright © 2026 Kris Enterprises LLC. All rights reserved.
