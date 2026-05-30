#!/usr/bin/env python3
"""
Generate white-themed app icon for AL-Madhina
"""
from PIL import Image, ImageDraw, ImageFont
import os

# Icon dimensions
ICON_SIZE = 1024
FOREGROUND_SIZE = 1024

# Colors (White theme with green accents)
WHITE = "#FFFFFF"
GREEN = "#004D40"
LIGHT_GREEN = "#00695C"

def create_main_icon():
    """Create the main app icon with white background"""
    img = Image.new('RGB', (ICON_SIZE, ICON_SIZE), WHITE)
    draw = ImageDraw.Draw(img)
    
    # Draw a rounded rectangle border (green)
    border_width = 40
    padding = 80
    draw.rounded_rectangle(
        [padding, padding, ICON_SIZE - padding, ICON_SIZE - padding],
        radius=120,
        outline=GREEN,
        width=border_width
    )
    
    # Try to load a font, fallback to default if not available
    try:
        # Try different font paths
        font_paths = [
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
            "C:\\Windows\\Fonts\\arialbd.ttf",
            "/System/Library/Fonts/Helvetica.ttc"
        ]
        font = None
        for path in font_paths:
            if os.path.exists(path):
                font = ImageFont.truetype(path, 180)
                break
        if font is None:
            font = ImageFont.load_default()
    except:
        font = ImageFont.load_default()
    
    # Draw "AM" text (AL-Madhina)
    text = "AM"
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    
    x = (ICON_SIZE - text_width) // 2
    y = (ICON_SIZE - text_height) // 2 - 50
    
    # Draw text with shadow effect
    shadow_offset = 8
    draw.text((x + shadow_offset, y + shadow_offset), text, fill="#E0E0E0", font=font)
    draw.text((x, y), text, fill=GREEN, font=font)
    
    # Draw subtitle
    try:
        subtitle_font = ImageFont.truetype(font_paths[1] if os.path.exists(font_paths[1]) else font_paths[0], 60)
    except:
        subtitle_font = font
    
    subtitle = "AL-MADHINA"
    bbox = draw.textbbox((0, 0), subtitle, font=subtitle_font)
    subtitle_width = bbox[2] - bbox[0]
    
    subtitle_x = (ICON_SIZE - subtitle_width) // 2
    subtitle_y = y + text_height + 60
    
    draw.text((subtitle_x, subtitle_y), subtitle, fill=LIGHT_GREEN, font=subtitle_font)
    
    return img

def create_foreground_icon():
    """Create foreground for adaptive icon (transparent background)"""
    img = Image.new('RGBA', (FOREGROUND_SIZE, FOREGROUND_SIZE), (255, 255, 255, 0))
    draw = ImageDraw.Draw(img)
    
    # Try to load font
    try:
        font_paths = [
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
            "C:\\Windows\\Fonts\\arialbd.ttf",
            "/System/Library/Fonts/Helvetica.ttc"
        ]
        font = None
        for path in font_paths:
            if os.path.exists(path):
                font = ImageFont.truetype(path, 220)
                break
        if font is None:
            font = ImageFont.load_default()
    except:
        font = ImageFont.load_default()
    
    # Draw "AM" text
    text = "AM"
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    
    x = (FOREGROUND_SIZE - text_width) // 2
    y = (FOREGROUND_SIZE - text_height) // 2
    
    # Draw text with shadow
    shadow_offset = 6
    draw.text((x + shadow_offset, y + shadow_offset), text, fill=(224, 224, 224, 180), font=font)
    draw.text((x, y), text, fill=(0, 77, 64, 255), font=font)
    
    return img

def main():
    print("🎨 Generating white-themed AL-Madhina icons...")
    
    # Create icons directory if it doesn't exist
    icon_dir = os.path.join(os.path.dirname(__file__), 'assets', 'icon')
    os.makedirs(icon_dir, exist_ok=True)
    
    # Generate main icon
    print("📱 Creating main app icon (1024x1024)...")
    main_icon = create_main_icon()
    main_icon_path = os.path.join(icon_dir, 'app_icon.png')
    main_icon.save(main_icon_path, 'PNG')
    print(f"✅ Saved: {main_icon_path}")
    
    # Generate foreground for adaptive icon
    print("🎯 Creating adaptive icon foreground (1024x1024)...")
    foreground_icon = create_foreground_icon()
    foreground_path = os.path.join(icon_dir, 'app_icon_foreground.png')
    foreground_icon.save(foreground_path, 'PNG')
    print(f"✅ Saved: {foreground_path}")
    
    print("\n✨ Icons generated successfully!")
    print("\nNext steps:")
    print("1. Run: cd flutter_preview")
    print("2. Run: flutter pub get")
    print("3. Run: flutter pub run flutter_launcher_icons")
    print("4. Rebuild your app to see the new icon!")

if __name__ == '__main__':
    main()
