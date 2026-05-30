#!/usr/bin/env python3
"""
Generate app icons for Flutter app in different sizes
"""
import os
from PIL import Image, ImageDraw

# Create icon image with Kaaba design
def create_kaaba_icon(size):
    """Create a Kaaba-themed icon with green circles"""
    # Create image with white background
    img = Image.new('RGBA', (size, size), (255, 255, 255, 0))
    draw = ImageDraw.Draw(img)
    
    # Scale factor
    margin = size * 0.05
    outer_radius = size / 2 - margin
    inner_radius = outer_radius - (size * 0.08)
    
    # Draw outer circle (dark green)
    circle_width = size * 0.04
    draw.ellipse(
        [(margin, margin), (size - margin, size - margin)],
        outline='#2d6a4f',
        width=int(circle_width)
    )
    
    # Draw inner circle (light green)
    inner_margin = margin + circle_width
    draw.ellipse(
        [(inner_margin, inner_margin), (size - inner_margin, size - inner_margin)],
        outline='#52b788',
        width=int(circle_width * 0.5)
    )
    
    # Draw Kaaba structure
    center_x, center_y = size / 2, size / 2
    kaaba_size = size * 0.3
    
    # Kaaba body - cubic shape
    # Left face (dark green)
    left_x = center_x - kaaba_size / 2
    left_y = center_y - kaaba_size / 4
    draw.polygon(
        [
            (left_x, left_y),
            (left_x, left_y + kaaba_size / 2),
            (center_x, center_y),
            (center_x, center_y - kaaba_size / 4)
        ],
        fill='#2d6a4f'
    )
    
    # Right face (medium green)
    right_x = center_x + kaaba_size / 2
    draw.polygon(
        [
            (right_x, left_y),
            (right_x, left_y + kaaba_size / 2),
            (center_x, center_y),
            (center_x, center_y - kaaba_size / 4)
        ],
        fill='#40916c'
    )
    
    # Top face (light green)
    draw.polygon(
        [
            (left_x, left_y),
            (right_x, left_y),
            (center_x, center_y - kaaba_size / 2)
        ],
        fill='#52b788'
    )
    
    # Door rectangle
    door_width = kaaba_size * 0.3
    door_height = kaaba_size * 0.4
    door_x = center_x - door_width / 2
    door_y = center_y - door_height / 2
    
    draw.rectangle(
        [(door_x, door_y), (door_x + door_width, door_y + door_height)],
        outline='#2d6a4f',
        width=2
    )
    
    # Door handle
    draw.ellipse(
        [(center_x - 2, center_y - 2), (center_x + 2, center_y + 2)],
        fill='#2d6a4f'
    )
    
    return img

# Create icons for different densities
sizes = {
    'mipmap-ldpi': 36,
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}

base_path = r'C:\Users\faisa\AndroidStudioProjects\AlMathina\flutter_preview\android\app\src\main\res'

for density, size in sizes.items():
    img = create_kaaba_icon(size)
    density_path = os.path.join(base_path, density)
    os.makedirs(density_path, exist_ok=True)
    output_path = os.path.join(density_path, 'ic_launcher.png')
    img.save(output_path, 'PNG')
    print(f"✓ Created {density}/ic_launcher.png ({size}x{size})")

# Also save in assets folder for reference
assets_path = r'C:\Users\faisa\AndroidStudioProjects\AlMathina\flutter_preview\assets\images'
img_512 = create_kaaba_icon(512)
img_512.save(os.path.join(assets_path, 'app_icon.png'), 'PNG')
print(f"✓ Created assets/images/app_icon.png (512x512)")

print("\n✅ All icons created successfully!")
