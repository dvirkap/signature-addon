import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

def draw_fake_signature(draw, offset_x, offset_y, scale=1.0):
    # Royalty blue color
    sig_color = (20, 60, 220, 255)
    
    # Define a smooth signature curve using a list of points (fictitious scribble)
    points = [
        (20, 50), (35, 30), (50, 65), (45, 80), (60, 40), 
        (75, 75), (90, 45), (105, 70), (120, 55), (150, 60), 
        (180, 58), (200, 60)
    ]
    
    # Scale points
    scaled_points = [(int(p[0] * scale + offset_x), int(p[1] * scale + offset_y)) for p in points]
    
    # Draw curves between points to make it look handwritten
    for i in range(len(scaled_points) - 1):
        p1 = scaled_points[i]
        p2 = scaled_points[i+1]
        draw.line([p1, p2], fill=sig_color, width=int(3 * scale))
        # Draw small round circles at joint to make it smoother
        draw.ellipse([p2[0]-int(1*scale), p2[1]-int(1*scale), p2[0]+int(1*scale), p2[1]+int(1*scale)], fill=sig_color)

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

def clean_and_generate():
    brain_dir = r"C:\Users\דביר\.gemini\antigravity-ide\brain\423b22ed-f546-4eca-9ecb-8eae1da52a67"
    assets_dir = "store_assets"
    os.makedirs(assets_dir, exist_ok=True)
    
    # Load fonts
    font_title = get_font("segoeuib", 14)
    font_subtitle = get_font("segoeuib", 10)
    font_body = get_font("segoeui", 8)
    
    # ----------------------------------------------------
    # 1. Clean & Generate user_editor_signed (Editor Screen)
    # ----------------------------------------------------
    print("Processing Editor Screen...")
    editor_path = os.path.join(brain_dir, "user_editor_signed.png")
    if os.path.exists(editor_path):
        img_editor = Image.open(editor_path).convert("RGBA")
        w, h = img_editor.size # 472x1024
        
        # Crop the floating menu from the original image (Y: 480 to 563, X: 80 to 349)
        # We will paste it back later
        floating_menu = img_editor.crop((80, 480, 350, 563))
        
        # Create a fresh white PDF document to cover the old one (Y: 120 to 850)
        # Note: the PDF page itself has a small gray margin at top/bottom, let's keep it clean
        draw_editor = ImageDraw.Draw(img_editor)
        draw_editor.rectangle([0, 120, w, 850], fill="white")
        
        # Draw fake PDF document content (English)
        draw_editor.text((40, 150), "PARTNERSHIP AGREEMENT", fill=(20, 20, 30, 255), font=font_title)
        draw_editor.text((40, 185), "This agreement is made on Oct 24, 2026, between the following parties:", fill=(60, 60, 70, 255), font=font_body)
        
        # Bullets
        draw_editor.text((40, 215), "1. Purpose and Scope of Collaboration", fill=(40, 40, 50, 255), font=font_subtitle)
        draw_editor.text((40, 230), "   The parties agree to cooperate in developing next-generation PDF utilities.", fill=(60, 60, 70, 255), font=font_body)
        
        draw_editor.text((40, 260), "2. Financial Arrangements & Commitments", fill=(40, 40, 50, 255), font=font_subtitle)
        draw_editor.text((40, 275), "   All development expenses shall be shared equally unless agreed otherwise.", fill=(60, 60, 70, 255), font=font_body)
        
        draw_editor.text((40, 305), "3. Intellectual Property Rights", fill=(40, 40, 50, 255), font=font_subtitle)
        draw_editor.text((40, 320), "   Each party retains ownership of its pre-existing proprietary technology.", fill=(60, 60, 70, 255), font=font_body)
        
        draw_editor.text((40, 350), "4. Confidentiality & Non-Disclosure", fill=(40, 40, 50, 255), font=font_subtitle)
        draw_editor.text((40, 365), "   Proprietary data disclosed during collaboration shall remain confidential.", fill=(60, 60, 70, 255), font=font_body)
        
        # Signatures section
        draw_editor.text((40, 420), "IN WITNESS WHEREOF, the parties sign this agreement:", fill=(60, 60, 70, 255), font=font_body)
        draw_editor.line([(40, 490), (200, 490)], fill=(150, 150, 160, 255), width=1)
        draw_editor.text((40, 495), "Witness Signature", fill=(100, 100, 110, 255), font=font_body)
        
        draw_editor.line([(270, 490), (430, 490)], fill=(150, 150, 160, 255), width=1)
        draw_editor.text((270, 495), "Partner Signature", fill=(100, 100, 110, 255), font=font_body)
        
        # Draw a beautiful fake signature in the selection box (selection box is X: 121 to 241, Y: 564 to 699)
        # Inside the box, let's draw signature at offset (130, 590) with scale 0.5
        draw_fake_signature(draw_editor, offset_x=130, offset_y=600, scale=0.45)
        
        # Re-draw the purple Selection Box border
        purple_color = (98, 0, 238, 255) # Material Purple
        draw_editor.rectangle([121, 564, 241, 699], outline=purple_color, width=2)
        
        # Re-draw Selection Box resize handle (bottom-right circle)
        handle_r = 7
        draw_editor.ellipse([241 - handle_r, 699 - handle_r, 241 + handle_r, 699 + handle_r], fill=purple_color)
        
        # Paste the floating action menu back
        img_editor.paste(floating_menu, (80, 480), floating_menu)
        
        # Save as phone_screenshot_2_editor.png
        img_editor.convert("RGB").save(os.path.join(assets_dir, "phone_screenshot_2_editor.png"), "PNG")
        print("Editor Screen saved successfully!")
    else:
        print("Error: user_editor_signed.png not found!")

    # ----------------------------------------------------
    # 2. Clean & Generate user_manage_signatures
    # ----------------------------------------------------
    print("Processing Manage Signatures...")
    manage_path = os.path.join(brain_dir, "user_manage_signatures.png")
    if os.path.exists(manage_path):
        img_manage = Image.open(manage_path).convert("RGBA")
        draw_manage = ImageDraw.Draw(img_manage)
        
        # Clear the original signature area inside the card
        # The card is around X: 25 to 220, Y: 130 to 330.
        # Signature Y bounds: 186 to 247. X bounds: 59 to 184.
        # Let's clear X: 50 to 195, Y: 175 to 270 with solid white (card bg)
        draw_manage.rectangle([45, 160, 205, 275], fill=(255, 255, 255, 255))
        
        # Draw fake signature inside the card
        draw_fake_signature(draw_manage, offset_x=55, offset_y=180, scale=0.6)
        
        # Save as phone_screenshot_5_state.png (which represents Manage Signatures screen in our list)
        img_manage.convert("RGB").save(os.path.join(assets_dir, "phone_screenshot_5_state.png"), "PNG")
        print("Manage Signatures Screen saved!")
    else:
        print("Error: user_manage_signatures.png not found!")

    # ----------------------------------------------------
    # 3. Clean & Generate user_page_editor (Multi-page editor)
    # ----------------------------------------------------
    print("Processing Page Editor (Multi-page)...")
    page_editor_path = os.path.join(brain_dir, "user_page_editor.png")
    if os.path.exists(page_editor_path):
        img_pe = Image.open(page_editor_path).convert("RGBA")
        draw_pe = ImageDraw.Draw(img_pe)
        
        # The signature in thumbnail of Page 4 is at X: 319 to 423, Y: 906 to 919.
        # Let's cover it with white and draw a tiny scribble
        draw_pe.rectangle([310, 895, 430, 930], fill="white")
        draw_fake_signature(draw_pe, offset_x=315, offset_y=902, scale=0.35)
        
        # Save as phone_screenshot_3_drawer.png (we can use this for multi-page scanner display!)
        img_pe.convert("RGB").save(os.path.join(assets_dir, "phone_screenshot_3_drawer.png"), "PNG")
        print("Page Editor Screen saved!")
    else:
        print("Error: user_page_editor.png not found!")

    # ----------------------------------------------------
    # 4. Clean & Save Dashboard & Camera
    # ----------------------------------------------------
    print("Processing Dashboard & Camera...")
    # Dashboard is clean
    dash_path = os.path.join(brain_dir, "user_dashboard.png")
    if os.path.exists(dash_path):
        img_dash = Image.open(dash_path).convert("RGB")
        img_dash.save(os.path.join(assets_dir, "phone_screenshot_1_dashboard.png"), "PNG")
        print("Dashboard Screen saved!")
        
    # Camera is clean (only shows a blank sheet)
    cam_path = os.path.join(brain_dir, "user_camera.png")
    if os.path.exists(cam_path):
        img_cam = Image.open(cam_path).convert("RGB")
        img_cam.save(os.path.join(assets_dir, "phone_screenshot_4_paywall.png"), "PNG")
        print("Camera Scanner Screen saved!")

    # ----------------------------------------------------
    # 5. Tablet Screenshot (1280x800)
    # ----------------------------------------------------
    print("Generating Tablet Screenshot...")
    # We will build a beautiful tablet layout (1280x800) using the same abstract background
    # and pasting our editor screenshot mockup in the middle/side, making it look super professional.
    bg_path = os.path.join(brain_dir, "premium_landscape_bg_1782192571420.png")
    if os.path.exists(bg_path):
        bg_tablet = Image.open(bg_path).convert("RGBA").resize((1280, 800), Image.Resampling.LANCZOS)
        draw_tab = ImageDraw.Draw(bg_tablet)
        
        # Mockup phone showing editor
        phone_editor = Image.open(os.path.join(assets_dir, "phone_screenshot_2_editor.png"))
        # Resize to fit height 700
        aspect = phone_editor.width / phone_editor.height
        pe_h = 700
        pe_w = int(pe_h * aspect)
        pe_resized = phone_editor.resize((pe_w, pe_h), Image.Resampling.LANCZOS)
        
        # Simple phone body mockup for tablet display
        phone_border = Image.new("RGBA", (pe_w + 16, pe_h + 16), (25, 25, 30, 255))
        phone_border.paste(pe_resized, (8, 8))
        
        # Paste phone on the right side of tablet background
        bg_tablet.paste(phone_border, (780, 50), phone_border)
        
        # Draw texts on the left side of tablet
        font_tab_title = get_font("segoeuib", 58)
        font_tab_sub = get_font("segoeui", 28)
        
        draw_tab.text((80, 180), "FreeSign PDF", fill="white", font=font_tab_title)
        draw_tab.text((80, 260), "Secure PDF Editor & Signer", fill=(210, 210, 255, 255), font=font_tab_sub)
        draw_tab.line([(80, 310), (700, 310)], fill=(120, 120, 255, 100), width=3)
        
        font_tab_bullet = get_font("segoeui", 22)
        bullets = [
            "✓ Secure electronic signatures on any contract",
            "✓ Continuous multi-page document scanner",
            "✓ Draw, add text, white-out eraser with ease",
            "✓ Horizontal axis lock for precision lines",
            "✓ 100% private - documents remain on your device"
        ]
        for idx, bullet in enumerate(bullets):
            draw_tab.text((80, 350 + idx * 60), bullet, fill=(240, 240, 255, 255), font=font_tab_bullet)
            
        bg_tablet.convert("RGB").save(os.path.join(assets_dir, "screenshot_1280x800.png"), "PNG")
        print("Tablet Screenshot saved!")

if __name__ == "__main__":
    clean_and_generate()
