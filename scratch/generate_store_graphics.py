import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

def create_mockup(screenshot_path, height=400):
    # Load screenshot
    if not os.path.exists(screenshot_path):
        print(f"Warning: Screenshot {screenshot_path} not found. Creating a placeholder screen.")
        # Create a placeholder
        screen = Image.new("RGBA", (180, 390), (30, 30, 40, 255))
        draw = ImageDraw.Draw(screen)
        draw.text((20, 180), "Screenshot", fill="white")
    else:
        screen = Image.open(screenshot_path).convert("RGBA")
    
    # Calculate dimensions
    aspect = screen.width / screen.height
    screen_h = height - 20
    screen_w = int(screen_h * aspect)
    
    screen_resized = screen.resize((screen_w, screen_h), Image.Resampling.LANCZOS)
    
    # Create phone frame (with rounded corners)
    border = 8
    phone_w = screen_w + border * 2
    phone_h = screen_h + border * 2
    
    phone = Image.new("RGBA", (phone_w, phone_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(phone)
    
    # Draw dark gray phone body
    draw.rounded_rectangle(
        [0, 0, phone_w, phone_h],
        radius=20,
        fill=(25, 25, 30, 255),
        outline=(100, 100, 110, 255),
        width=2
    )
    
    # Paste screenshot onto the phone body
    phone.paste(screen_resized, (border, border), screen_resized)
    
    # Draw screen inner thin border
    draw.rounded_rectangle(
        [border, border, border + screen_w, border + screen_h],
        radius=14,
        outline=(40, 40, 45, 255),
        width=1
    )
    
    # Draw speaker notch at the top
    notch_w = 60
    notch_h = 6
    notch_x = (phone_w - notch_w) // 2
    draw.rounded_rectangle(
        [notch_x, border + 4, notch_x + notch_w, border + 4 + notch_h],
        radius=3,
        fill=(10, 10, 12, 255)
    )
    
    # Draw front camera punch hole
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
    # Create shadow mask
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    
    # Get alpha mask of the image
    alpha = img.getchannel('A')
    
    # Create shadow
    shadow_img = Image.new("RGBA", img.size, (0, 0, 0, 120)) # Dark shadow
    shadow_img.putalpha(alpha)
    
    # Blur the shadow
    shadow_blur = shadow_img.filter(ImageFilter.GaussianBlur(15))
    
    # Create final canvas
    canvas = Image.new("RGBA", (img.width + abs(offset[0]) * 2, img.height + abs(offset[1]) * 2), background_color)
    
    # Paste shadow with offset
    canvas.paste(shadow_blur, (offset[0] + abs(offset[0]), offset[1] + abs(offset[1])), shadow_blur)
    # Paste original image
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
    # Fallback to default
    return ImageFont.load_default()

def draw_bullet(draw, x, y, text, font, fill_color, check_icon_path=None):
    # Draw a cute green/purple checkmark or bullet point
    draw.text((x, y), "✓", fill=(100, 255, 150, 255), font=font)
    # Draw the text with a small indentation
    draw.text((x + 25, y), text, fill=fill_color, font=font)

def generate_graphics():
    # Paths
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
    
    # Load background image
    bg_orig = Image.open(bg_path).convert("RGBA")
    print(f"Original background size: {bg_orig.size}")
    
    # ----------------------------------------------------
    # 1. Feature Graphic (1024x500)
    # ----------------------------------------------------
    print("Generating Feature Graphic (1024x500)...")
    fg_w, fg_h = 1024, 500
    
    # Resize and crop background to fit 1024x500
    bg_fg = bg_orig.resize((fg_w, fg_h), Image.Resampling.LANCZOS)
    
    # --- HEBREW VERSION ---
    fg_he = bg_fg.copy()
    draw_he = ImageDraw.Draw(fg_he)
    
    # Create Phone Mockup (right-aligned for Hebrew layout)
    phone_screenshot_path = os.path.join(assets_dir, "phone_screenshot_2_editor.png")
    phone_img = create_mockup(phone_screenshot_path, height=410)
    phone_with_shadow = add_shadow(phone_img, offset=(10, 10))
    
    # Paste Phone on the Right (X: 720, Y: 30)
    fg_he.paste(phone_with_shadow, (700, 20), phone_with_shadow)
    
    # Draw texts on the Left (RTL feel)
    # App Title
    draw_he.text((80, 70), "FreeSign PDF", fill="white", font=font_title)
    
    # Subtitle
    draw_he.text((80, 140), "פשוט לחתום ולערוך מסמכי PDF", fill=(210, 210, 255, 255), font=font_subtitle)
    
    # Divider line
    draw_he.line([(80, 190), (620, 190)], fill=(120, 120, 255, 100), width=2)
    
    # Bullet points for key features (Hebrew, right-aligned layout relative to the left zone)
    draw_bullet(draw_he, 80, 220, "חתימה דיגיטלית מהירה ומאובטחת", font_bullet, (240, 240, 255, 255))
    draw_bullet(draw_he, 80, 265, "סריקה רציפה של מסמכים מרובי דפים", font_bullet, (240, 240, 255, 255))
    draw_bullet(draw_he, 80, 310, "עריכת טקסט, ציור בעיפרון ומחק מדויק", font_bullet, (240, 240, 255, 255))
    draw_bullet(draw_he, 80, 355, "נעילת ציר חכמה לשורות ישרות ומחיקה מדויקת", font_bullet, (240, 240, 255, 255))
    draw_bullet(draw_he, 80, 400, "100% פרטי ומאובטח - הכל נשמר מקומית", font_bullet, (240, 240, 255, 255))
    
    # Save Hebrew version as main feature graphic (since user is Israeli)
    fg_he_path = os.path.join(assets_dir, "feature_graphic_1024x500.png")
    fg_he.convert("RGB").save(fg_he_path, "PNG", quality=95)
    
    # Also save a backup with explicit naming
    fg_he.convert("RGB").save(os.path.join(assets_dir, "feature_graphic_1024x500_he.png"), "PNG")
    print("Hebrew Feature Graphic saved!")
    
    # --- ENGLISH VERSION ---
    fg_en = bg_fg.copy()
    draw_en = ImageDraw.Draw(fg_en)
    
    # Paste Phone on the Right
    fg_en.paste(phone_with_shadow, (700, 20), phone_with_shadow)
    
    # Draw texts on the Left (LTR layout)
    draw_en.text((80, 70), "FreeSign PDF", fill="white", font=font_title)
    draw_en.text((80, 140), "Simple, Fast PDF Editor & Signer", fill=(210, 210, 255, 255), font=font_subtitle)
    draw_en.line([(80, 190), (620, 190)], fill=(120, 120, 255, 100), width=2)
    
    draw_bullet(draw_en, 80, 220, "Secure electronic signatures on any contract", font_bullet, (240, 240, 255, 255))
    draw_bullet(draw_en, 80, 265, "Continuous multi-page document scanner", font_bullet, (240, 240, 255, 255))
    draw_bullet(draw_en, 80, 310, "Draw, add text, white-out eraser with ease", font_bullet, (240, 240, 255, 255))
    draw_bullet(draw_en, 80, 355, "Horizontal axis lock for precision lines", font_bullet, (240, 240, 255, 255))
    draw_bullet(draw_en, 80, 400, "100% private - documents remain on your device", font_bullet, (240, 240, 255, 255))
    
    fg_en.convert("RGB").save(os.path.join(assets_dir, "feature_graphic_1024x500_en.png"), "PNG")
    print("English Feature Graphic saved!")
    
    # ----------------------------------------------------
    # 2. Marquee Promo Tile (1400x560)
    # ----------------------------------------------------
    print("Generating Marquee Promo Tile (1400x560)...")
    mq_w, mq_h = 1400, 560
    bg_mq = bg_orig.resize((mq_w, mq_h), Image.Resampling.LANCZOS)
    
    # Create two phone mockups: one dashboard, one editor
    phone_dashboard_path = os.path.join(assets_dir, "phone_screenshot_1_dashboard.png")
    phone1 = create_mockup(phone_dashboard_path, height=460)
    phone2 = create_mockup(phone_screenshot_path, height=460)
    
    phone1_shadow = add_shadow(phone1, offset=(12, 12))
    phone2_shadow = add_shadow(phone2, offset=(12, 12))
    
    # --- HEBREW VERSION ---
    mq_he = bg_mq.copy()
    draw_mq_he = ImageDraw.Draw(mq_he)
    
    # Paste two phones on the right side
    mq_he.paste(phone1_shadow, (900, 40), phone1_shadow)
    mq_he.paste(phone2_shadow, (1110, 40), phone2_shadow)
    
    # Draw texts on the left
    font_title_large = get_font("segoeuib", 68)
    font_subtitle_large = get_font("segoeui", 32)
    font_bullet_large = get_font("segoeui", 26)
    
    draw_mq_he.text((100, 80), "FreeSign PDF", fill="white", font=font_title_large)
    draw_mq_he.text((100, 165), "פשוט לחתום ולערוך מסמכי PDF מהנייד", fill=(210, 210, 255, 255), font=font_subtitle_large)
    draw_mq_he.line([(100, 220), (820, 220)], fill=(120, 120, 255, 100), width=3)
    
    draw_bullet(draw_mq_he, 100, 250, "חתימה אלקטרונית וסריקת מסמכים רציפה", font_bullet_large, (240, 240, 255, 255))
    draw_bullet(draw_mq_he, 100, 305, "כלי ציור חופשי, מחק לבן חכם ודוגם צבע", font_bullet_large, (240, 240, 255, 255))
    draw_bullet(draw_mq_he, 100, 360, "נעילת ציר בגרירה ארוכה ליצירת שורות ישרות", font_bullet_large, (240, 240, 255, 255))
    draw_bullet(draw_mq_he, 100, 415, "ללא פרסומות ומאובטח במאה אחוזים לשימושך", font_bullet_large, (240, 240, 255, 255))
    
    mq_he_path = os.path.join(assets_dir, "marquee_promo_tile_1400x560.png")
    mq_he.convert("RGB").save(mq_he_path, "PNG", quality=95)
    mq_he.convert("RGB").save(os.path.join(assets_dir, "marquee_promo_tile_1400x560_he.png"), "PNG")
    print("Hebrew Marquee Promo Tile saved!")
    
    # ----------------------------------------------------
    # 3. Small Promo Tile (440x280)
    # ----------------------------------------------------
    print("Generating Small Promo Tile (440x280)...")
    sp_w, sp_h = 440, 280
    bg_sp = bg_orig.resize((sp_w, sp_h), Image.Resampling.LANCZOS)
    
    # Layout for small tile: App Icon on the left, Title/Subtitle on the right
    # OR centered design since it's very small. Let's make it centered and highly readable
    sp_he = bg_sp.copy()
    draw_sp_he = ImageDraw.Draw(sp_he)
    
    # Load App Icon if available to place it in the center
    icon_path = os.path.join(assets_dir, "store_icon_512x512.png")
    if os.path.exists(icon_path):
        icon_img = Image.open(icon_path).convert("RGBA").resize((90, 90), Image.Resampling.LANCZOS)
        # Add shadow to icon
        icon_shadow = add_shadow(icon_img, offset=(4, 4))
        sp_he.paste(icon_shadow, (170, 30), icon_shadow)
        
    font_title_small = get_font("segoeuib", 32)
    font_subtitle_small = get_font("segoeui", 18)
    
    # Draw centered texts
    draw_sp_he.text((120, 140), "FreeSign PDF", fill="white", font=font_title_small)
    draw_sp_he.text((115, 195), "פשוט לחתום ולערוך PDF", fill=(210, 210, 255, 255), font=font_subtitle_small)
    draw_sp_he.text((130, 225), "חתימה, סריקה ועריכה מהירה", fill=(180, 180, 255, 255), font=get_font("segoeui", 14))
    
    sp_he_path = os.path.join(assets_dir, "small_promo_tile_440x280.png")
    sp_he.convert("RGB").save(sp_he_path, "PNG", quality=95)
    print("Small Promo Tile saved!")

if __name__ == "__main__":
    generate_graphics()
