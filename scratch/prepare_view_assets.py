import os
import shutil

def prepare():
    src = "store_assets"
    dst = r"C:\Users\דביר\.gemini\antigravity-ide\brain\423b22ed-f546-4eca-9ecb-8eae1da52a67"
    if not os.path.exists(src):
        print(f"Error: {src} not found")
        return
        
    # Copy all files
    files = [
        'phone_screenshot_1_dashboard.png',
        'phone_screenshot_2_editor.png',
        'phone_screenshot_3_drawer.png',
        'phone_screenshot_4_paywall.png',
        'phone_screenshot_5_state.png',
        'screenshot_1280x800.png',
        'feature_graphic_1024x500.png',
        'marquee_promo_tile_1400x560.png',
        'small_promo_tile_440x280.png',
        'store_icon_512x512.png'
    ]
    
    for f in files:
        src_file = os.path.join(src, f)
        if os.path.exists(src_file):
            shutil.copy(src_file, os.path.join(dst, f))

    # Create HTML
    html_content = "<html><body style=\"background:#1e1e24; color:#fff; font-family:sans-serif; text-align:center; padding:20px;\">"
    html_content += "<h1 style=\"color:#a0a0ff;\">FreeSign PDF - App Store Marketing Assets (English & Fictitious)</h1>"
    html_content += "<p style=\"color:#ccc;\">All assets have been successfully cleaned: personal signatures removed, agreements replaced with fictitious English documents, and titles rewritten in clean LTR English layout.</p>"
    
    # Banners section
    html_content += "<h2 style=\"border-bottom:1px solid #444; padding-bottom:10px; margin-top:40px;\">Banners & Promotional Tiles</h2>"
    html_content += "<div style=\"display:flex; flex-direction:column; align-items:center; gap:20px;\">"
    html_content += "  <div><h3>Feature Graphic (1024x500)</h3><img src=\"feature_graphic_1024x500.png\" style=\"max-width:800px; border:2px solid #666; border-radius:8px; box-shadow:0 4px 8px rgba(0,0,0,0.5);\" /></div>"
    html_content += "  <div><h3>Marquee Promo Tile (1400x560)</h3><img src=\"marquee_promo_tile_1400x560.png\" style=\"max-width:800px; border:2px solid #666; border-radius:8px; box-shadow:0 4px 8px rgba(0,0,0,0.5);\" /></div>"
    html_content += "  <div><h3>Small Promo Tile (440x280)</h3><img src=\"small_promo_tile_440x280.png\" style=\"max-width:300px; border:2px solid #666; border-radius:8px; box-shadow:0 4px 8px rgba(0,0,0,0.5);\" /></div>"
    html_content += "</div>"
    
    # Screenshots section
    html_content += "<h2 style=\"border-bottom:1px solid #444; padding-bottom:10px; margin-top:40px;\">Cleaned Phone & Tablet Screenshots</h2>"
    html_content += "<div style=\"display:flex; flex-wrap:wrap; justify-content:center; gap:20px;\">"
    for f in files[:6]:
        html_content += f"<div style=\"margin:10px; border:2px solid #555; padding:10px; background:#2a2a35; border-radius:8px; width:260px;\"><h4>{f}</h4><img src=\"{f}\" style=\"max-height:400px; max-width:100%;\" /></div>"
    html_content += "</div>"
    
    html_content += "</body></html>"

    html_path = os.path.join(dst, "view_assets.html")
    with open(html_path, "w", encoding="utf-8") as html_file:
        html_file.write(html_content)

    print(f"Updated view_assets.html successfully at {html_path}")

if __name__ == "__main__":
    prepare()
