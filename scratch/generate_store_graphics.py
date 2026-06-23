import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

def create_mockup(screenshot_path, height=400):
    if not os.path.exists(screenshot_path):
        print(f"Warning: Screenshot {screenshot_path} not found. Creating a placeholder screen.")
        screen = Image.new("RGBA", (180, 390), (30, 30, 40, 255))
        draw = ImageDraw.Draw(screen)
        draw.text((20, 180), "Screenshot", fill="white")
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
    
    draw.rounded_rectangle(
        [0, 0, phone_w, phone_h],
        radius=20,
        fill=(25, 25, 30, 255),
        outline=(100, 100, 110, 255),
        width=2
    )
    
    phone.paste(screen_resized, (border, border), screen_resized)
    
    draw.rounded_rectangle(
        [border, border, border + screen_w, border + screen_h],
        radius=14,
        outline=(40, 40, 45, 255),
        width=1
    )
    
    notch_w = 60
    notch_h = 6
    notch_x = (phone_w - notch_w) // 2
    draw.rounded_rectangle(
        [notch_x, border + 4, notch_x + notch_w, border + 4 + notch_h],
        radius=3,
        fill=(10, 10, 12, 255)
    )
    
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

def add_shadow(img, offset=(8, 8), background_color=(0, 0, 0, 0)):
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    
    alpha = img.getchannel('A')
    
    shadow_img = Image.new("RGBA", img.size, (0, 0, 0, 120))
    shadow_img.putalpha(alpha)
    
    shadow_blur = shadow_img.filter(ImageFilter.GaussianBlur(15))
    
    canvas = Image.new("RGBA", (img.width + abs(offset[0]) * 2, img.height + abs(offset[1]) * 2), background_color)
    
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
            except Exception as e:
                print(f"Error loading font {path}: {e}")
    return ImageFont.load_default()

def draw_bullet(draw, x, y, text, font, fill_color):
    draw.text((x, y), "✓", fill=(100, 255, 150, 255), font=font)
    draw.text((x + 25, y), text, fill=fill_color, font=font)

def generate_graphics():
    brain_dir = r"C:\Users\דביר\.gemini\antigravity-ide\brain\423b22ed-f546-4eca-9ecb-8eae1da52a67"
    bg_filename = "premium_landscape_bg_1782192571420.png"
    bg_path = os.path.join(brain_dir, bg_filename)
    
    if not os.path.exists(bg_path):
        print(f"Error: Background image not found at {bg_path}")
        return
        
    assets_dir = "store_assets"
    os.makedirs(assets_dir, exist_ok=True)
    
    # Fonts
    font_title = get_font("segoeuib", 52)
    font_subtitle = get_font("segoeui", 26)
    font_bullet = get_font("segoeui", 22)
    
    bg_orig = Image.open(bg_path).convert("RGBA")
    
    # ----------------------------------------------------
    # 1. Feature Graphic (1024x500) - English Only
    # ----------------------------------------------------
    print("Generating Feature Graphic (1024x500)...")
    fg_w, fg_h = 1024, 500
    bg_fg = bg_orig.resize((fg_w, fg_h), Image.Resampling.LANCZOS)
    
    fg = bg_fg.copy()
    draw_fg = ImageDraw.Draw(fg)
    
    # Use our cleaned mockup (which has fictitious signature and English doc)
    phone_screenshot_path = os.path.join(assets_dir, "phone_screenshot_2_editor.png")
    phone_img = create_mockup(phone_screenshot_path, height=410)
    phone_with_shadow = add_shadow(phone_img, offset=(10, 10))
    
    # Paste Phone on the Right
    fg.paste(phone_with_shadow, (700, 20), phone_with_shadow)
    
    # Draw texts on the Left (English)
    draw_fg.text((80, 70), "FreeSign PDF", fill="white", font=font_title)
    draw_fg.text((80, 140), "Secure PDF Editor & Signer", fill=(210, 210, 255, 255), font=font_subtitle)
    draw_fg.line([(80, 190), (620, 190)], fill=(120, 120, 255, 100), width=2)
    
    draw_bullet(draw_fg, 80, 220, "Secure electronic signatures on any contract", font_bullet, (240, 240, 255, 255))
    draw_bullet(draw_fg, 80, 265, "Continuous multi-page document scanner", font_bullet, (240, 240, 255, 255))
    draw_bullet(draw_fg, 80, 310, "Draw, add text, white-out eraser with ease", font_bullet, (240, 240, 255, 255))
    draw_bullet(draw_fg, 80, 355, "Horizontal axis lock for precision lines", font_bullet, (240, 240, 255, 255))
    draw_bullet(draw_fg, 80, 400, "100% private - documents remain on your device", font_bullet, (240, 240, 255, 255))
    
    # Save as main Feature Graphic
    fg.convert("RGB").save(os.path.join(assets_dir, "feature_graphic_1024x500.png"), "PNG", quality=95)
    print("Feature Graphic saved!")
    
    # ----------------------------------------------------
    # 2. Marquee Promo Tile (1400x560) - English Only
    # ----------------------------------------------------
    print("Generating Marquee Promo Tile (1400x560)...")
    mq_w, mq_h = 1400, 560
    bg_mq = bg_orig.resize((mq_w, mq_h), Image.Resampling.LANCZOS)
    
    phone_dashboard_path = os.path.join(assets_dir, "phone_screenshot_1_dashboard.png")
    phone1 = create_mockup(phone_dashboard_path, height=460) # Dashboard
    phone2 = create_mockup(phone_screenshot_path, height=460) # Editor (clean)
    
    phone1_shadow = add_shadow(phone1, offset=(12, 12))
    phone2_shadow = add_shadow(phone2, offset=(12, 12))
    
    mq = bg_mq.copy()
    draw_mq = ImageDraw.Draw(mq)
    
    # Paste two phones on the right side
    mq.paste(phone1_shadow, (900, 40), phone1_shadow)
    mq.paste(phone2_shadow, (1110, 40), phone2_shadow)
    
    # Draw texts on the left (English)
    font_title_large = get_font("segoeuib", 68)
    font_subtitle_large = get_font("segoeui", 32)
    font_bullet_large = get_font("segoeui", 26)
    
    draw_mq.text((100, 80), "FreeSign PDF", fill="white", font=font_title_large)
    draw_mq.text((100, 165), "Complete PDF Signer & Multi-page Scanner", fill=(210, 210, 255, 255), font=font_subtitle_large)
    draw_mq.line([(100, 220), (820, 220)], fill=(120, 120, 255, 100), width=3)
    
    draw_bullet(draw_mq, 100, 250, "Electronic signatures & continuous document scanning", font_bullet_large, (240, 240, 255, 255))
    draw_bullet(draw_mq, 100, 305, "Freehand pencil drawing, white-out eraser & color picker", font_bullet_large, (240, 240, 255, 255))
    draw_bullet(draw_mq, 100, 360, "Long-press axis lock for drawing straight lines", font_bullet_large, (240, 240, 255, 255))
    draw_bullet(draw_mq, 100, 415, "Ad-free experience with maximum privacy offline", font_bullet_large, (240, 240, 255, 255))
    
    mq.convert("RGB").save(os.path.join(assets_dir, "marquee_promo_tile_1400x560.png"), "PNG", quality=95)
    print("Marquee Promo Tile saved!")
    
    # ----------------------------------------------------
    # 3. Small Promo Tile (440x280) - English Only
    # ----------------------------------------------------
    print("Generating Small Promo Tile (440x280)...")
    sp_w, sp_h = 440, 280
    bg_sp = bg_orig.resize((sp_w, sp_h), Image.Resampling.LANCZOS)
    
    sp = bg_sp.copy()
    draw_sp = ImageDraw.Draw(sp)
    
    # Load App Icon if available to place it in the center
    icon_path = os.path.join(assets_dir, "store_icon_512x512.png")
    if os.path.exists(icon_path):
        icon_img = Image.open(icon_path).convert("RGBA").resize((90, 90), Image.Resampling.LANCZOS)
        icon_shadow = add_shadow(icon_img, offset=(4, 4))
        sp.paste(icon_shadow, (170, 30), icon_shadow)
        
    font_title_small = get_font("segoeuib", 32)
    font_subtitle_small = get_font("segoeui", 18)
    
    # Draw centered texts (English)
    draw_sp.text((120, 140), "FreeSign PDF", fill="white", font=font_title_small)
    draw_sp.text((105, 195), "Secure PDF Editor & Signer", fill=(210, 210, 255, 255), font=font_subtitle_small)
    draw_sp.text((100, 225), "Sign, scan, and edit documents offline", fill=(180, 180, 255, 255), font=get_font("segoeui", 14))
    
    sp.convert("RGB").save(os.path.join(assets_dir, "small_promo_tile_440x280.png"), "PNG", quality=95)
    print("Small Promo Tile saved!")

if __name__ == "__main__":
    generate_graphics()
