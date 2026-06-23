import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

def create_phone_mockup(screenshot_path, height):
    if not os.path.exists(screenshot_path):
        # Create a fallback placeholder
        screen = Image.new("RGBA", (300, 650), (30, 30, 40, 255))
    else:
        screen = Image.open(screenshot_path).convert("RGBA")
        
    aspect = screen.width / screen.height
    screen_h = height - 20
    screen_w = int(screen_h * aspect)
    
    screen_resized = screen.resize((screen_w, screen_h), Image.Resampling.LANCZOS)
    
    border = 8
    phone_w = screen_w + border * 2
    phone_h = screen_h + border * 2
    
    phone = Image.new("RGBA", (phone_w, phone_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(phone)
    
    # Phone body outline
    draw.rounded_rectangle(
        [0, 0, phone_w, phone_h],
        radius=20,
        fill=(25, 25, 30, 255),
        outline=(100, 100, 110, 255),
        width=2
    )
    
    # Paste screenshot
    phone.paste(screen_resized, (border, border), screen_resized)
    
    # Inner border
    draw.rounded_rectangle(
        [border, border, border + screen_w, border + screen_h],
        radius=14,
        outline=(40, 40, 45, 255),
        width=1
    )
    
    # Notch/Speaker
    notch_w = int(phone_w * 0.3)
    notch_h = 6
    notch_x = (phone_w - notch_w) // 2
    draw.rounded_rectangle(
        [notch_x, border + 4, notch_x + notch_w, border + 4 + notch_h],
        radius=3,
        fill=(10, 10, 12, 255)
    )
    
    # Camera punch hole
    camera_r = 3
    camera_x = phone_w // 2
    camera_y = border + notch_h + 10
    draw.ellipse(
        [camera_x - camera_r, camera_y - camera_r, camera_x + camera_r, camera_y + camera_r],
        fill=(5, 5, 20, 255),
        outline=(30, 30, 50, 255),
        width=1
    )
    
    return phone

def add_shadow(img, offset=(10, 10)):
    alpha = img.getchannel('A')
    shadow_img = Image.new("RGBA", img.size, (0, 0, 0, 120))
    shadow_img.putalpha(alpha)
    shadow_blur = shadow_img.filter(ImageFilter.GaussianBlur(15))
    
    canvas = Image.new("RGBA", (img.width + abs(offset[0]) * 2, img.height + abs(offset[1]) * 2), (0, 0, 0, 0))
    canvas.paste(shadow_blur, (offset[0] + abs(offset[0]), offset[1] + abs(offset[1])), shadow_blur)
    canvas.paste(img, (abs(offset[0]), abs(offset[1])), img)
    return canvas

def get_font(font_name, size):
    paths = [
        os.path.join("C:\\Windows\\Fonts", font_name + ".ttf"),
        os.path.join("C:\\Windows\\Fonts", font_name.lower() + ".ttf"),
        font_name + ".ttf",
    ]
    for path in paths:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except:
                pass
    return ImageFont.load_default()

def generate_tablet_images():
    brain_dir = r"C:\Users\דביר\.gemini\antigravity-ide\brain\423b22ed-f546-4eca-9ecb-8eae1da52a67"
    bg_path = os.path.join(brain_dir, "premium_landscape_bg_1782192571420.png")
    assets_dir = "store_assets"
    
    if not os.path.exists(bg_path):
        print(f"Error: Background image {bg_path} not found")
        return
        
    bg_orig = Image.open(bg_path).convert("RGBA")
    
    # Define features for the 4 screenshots
    features = [
        {
            "filename": "phone_screenshot_1_dashboard.png",
            "title": "FreeSign PDF Hub",
            "sub": "Access all your documents and signatures from a single, clean workspace.",
            "desc": "Manage, organize, and view signed contracts effortlessly."
        },
        {
            "filename": "phone_screenshot_2_editor.png",
            "title": "E-Sign Contracts",
            "sub": "Easily apply handwritten signatures or stamps to any PDF document.",
            "desc": "Position, scale, and rotate your digital signature in real time."
        },
        {
            "filename": "phone_screenshot_3_drawer.png",
            "title": "Page Editor Suite",
            "sub": "Organize multi-page document scans, rotate pages, or delete mistakes.",
            "desc": "Seamless continuous scanning flow with real-time page management."
        },
        {
            "filename": "phone_screenshot_4_paywall.png",
            "title": "Smart Camera Scanner",
            "sub": "Auto-capture paper documents and convert them into crisp PDFs.",
            "desc": "Advanced edge-detection scanner using Google ML Kit."
        }
    ]
    
    # ----------------------------------------------------
    # Generate 7-inch Tablet Screenshots (1280x800)
    # ----------------------------------------------------
    print("Generating 7-inch tablet screenshots (1280x800)...")
    for idx, feat in enumerate(features, 1):
        bg = bg_orig.resize((1280, 800), Image.Resampling.LANCZOS)
        draw = ImageDraw.Draw(bg)
        
        # Mockup phone
        shot_path = os.path.join(assets_dir, feat["filename"])
        phone = create_phone_mockup(shot_path, height=660)
        phone_shadow = add_shadow(phone, offset=(10, 10))
        
        # Paste phone on the right side
        bg.paste(phone_shadow, (760, 50), phone_shadow)
        
        # Draw texts on the left
        font_t = get_font("segoeuib", 56)
        font_s = get_font("segoeui", 26)
        font_d = get_font("segoeui", 20)
        
        draw.text((80, 200), feat["title"], fill="white", font=font_t)
        draw.text((80, 280), feat["sub"], fill=(210, 210, 255, 255), font=font_s)
        draw.line([(80, 330), (700, 330)], fill=(120, 120, 255, 100), width=3)
        draw.text((80, 370), feat["desc"], fill=(180, 180, 210, 255), font=font_d)
        
        # Save file
        out_name = f"tablet_7_inch_{idx}_{feat['filename'].split('_')[-1]}"
        bg.convert("RGB").save(os.path.join(assets_dir, out_name), "PNG", quality=95)
        print(f"Saved 7-inch: {out_name}")

    # ----------------------------------------------------
    # Generate 10-inch Tablet Screenshots (1920x1200)
    # ----------------------------------------------------
    print("Generating 10-inch tablet screenshots (1920x1200)...")
    for idx, feat in enumerate(features, 1):
        bg = bg_orig.resize((1920, 1200), Image.Resampling.LANCZOS)
        draw = ImageDraw.Draw(bg)
        
        # Mockup phone (larger for 10-inch screen)
        shot_path = os.path.join(assets_dir, feat["filename"])
        phone = create_phone_mockup(shot_path, height=980)
        phone_shadow = add_shadow(phone, offset=(15, 15))
        
        # Paste phone on the right side
        bg.paste(phone_shadow, (1150, 80), phone_shadow)
        
        # Draw texts on the left
        font_t = get_font("segoeuib", 82)
        font_s = get_font("segoeui", 38)
        font_d = get_font("segoeui", 28)
        
        draw.text((120, 300), feat["title"], fill="white", font=font_t)
        draw.text((120, 420), feat["sub"], fill=(210, 210, 255, 255), font=font_s)
        draw.line([(120, 490), (1050, 490)], fill=(120, 120, 255, 100), width=4)
        draw.text((120, 550), feat["desc"], fill=(180, 180, 210, 255), font=font_d)
        
        # Save file
        out_name = f"tablet_10_inch_{idx}_{feat['filename'].split('_')[-1]}"
        bg.convert("RGB").save(os.path.join(assets_dir, out_name), "PNG", quality=95)
        print(f"Saved 10-inch: {out_name}")

if __name__ == "__main__":
    generate_tablet_images()
