#!/usr/bin/env python3
"""
Simple script to generate launcher icons for Android
"""

from PIL import Image, ImageDraw
import os

# Icon sizes for different densities
SIZES = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}

def create_icon(size, output_path):
    """Create a simple blue icon with a white play symbol"""
    # Create a new image with blue background
    img = Image.new('RGB', (size, size), color='#2196F3')
    draw = ImageDraw.Draw(img)

    # Draw a white circle
    margin = size // 8
    draw.ellipse([margin, margin, size - margin, size - margin], fill='white')

    # Draw a play triangle
    play_margin = size // 4
    play_points = [
        (size // 2 - play_margin // 2, size // 2 - play_margin),
        (size // 2 - play_margin // 2, size // 2 + play_margin),
        (size // 2 + play_margin, size // 2)
    ]
    draw.polygon(play_points, fill='#2196F3')

    # Save the image
    img.save(output_path, 'PNG')
    print(f"Created icon: {output_path}")

def main():
    base_path = 'android/app/src/main/res'

    for density, size in SIZES.items():
        dir_path = os.path.join(base_path, density)
        os.makedirs(dir_path, exist_ok=True)

        icon_path = os.path.join(dir_path, 'ic_launcher.png')
        create_icon(size, icon_path)

    print("All icons generated successfully!")

if __name__ == '__main__':
    main()
