#!/usr/bin/env python3
"""
Generate QR codes for conference materials.

Usage:
    python scripts/generate-qr-codes.py

Generates:
    - slides/assets/qr-repo.png (main GitHub repo)
    - slides/assets/qr-quickstart.png (QUICKSTART.md)
    - slides/assets/qr-bob-download.png (IBM Bob download)
"""

import os
import sys

try:
    import qrcode
except ImportError:
    print("Error: qrcode library not installed")
    print("Install with: pip install qrcode[pil]")
    sys.exit(1)

# Ensure output directory exists
os.makedirs("slides/assets", exist_ok=True)

# QR code configuration
QR_CONFIG = {
    "version": 1,
    "box_size": 10,
    "border": 5,
    "fill_color": "black",
    "back_color": "white"
}

# URLs to encode
URLS = {
    "qr-repo.png": {
        "url": "https://github.com/manavgup/ai-agent-controlplane-demo",
        "description": "Main GitHub repository"
    },
    "qr-quickstart.png": {
        "url": "https://github.com/manavgup/ai-agent-controlplane-demo/blob/main/QUICKSTART.md",
        "description": "Quick start guide"
    },
    "qr-bob-download.png": {
        "url": "https://bob.ibm.com/download",
        "description": "IBM Bob Shell download"
    }
}

def generate_qr_code(url: str, output_path: str) -> None:
    """Generate a QR code for the given URL."""
    qr = qrcode.QRCode(**QR_CONFIG)
    qr.add_data(url)
    qr.make(fit=True)
    
    img = qr.make_image(fill_color=QR_CONFIG["fill_color"], 
                        back_color=QR_CONFIG["back_color"])
    img.save(output_path)

def main():
    print("Generating QR codes for conference materials...\n")
    
    for filename, config in URLS.items():
        output_path = os.path.join("slides", "assets", filename)
        print(f"Generating {filename}...")
        print(f"  URL: {config['url']}")
        print(f"  Description: {config['description']}")
        
        try:
            generate_qr_code(config["url"], output_path)
            print(f"  ✓ Saved to {output_path}\n")
        except Exception as e:
            print(f"  ✗ Error: {e}\n")
            sys.exit(1)
    
    print("All QR codes generated successfully!")
    print("\nNext steps:")
    print("1. Open slides/assets/ to view the QR codes")
    print("2. Add them to your PowerPoint slides:")
    print("   - qr-repo.png → Title slide (bottom right)")
    print("   - qr-quickstart.png → Prerequisites slide (top right)")
    print("   - qr-repo.png → Closing slide (center, larger)")
    print("3. Test scanning from 10+ feet away")

if __name__ == "__main__":
    main()
