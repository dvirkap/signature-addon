import os
from PIL import Image

def process_assets():
    assets_dir = os.path.join("store_assets")
    if not os.path.exists(assets_dir):
        print(f"Error: {assets_dir} directory not found.")
        return

    print("Analyzing and correcting asset sizes...")
    
    # 1. Check & Correct App Icon (must be exactly 512x512)
    icon_path = os.path.join(assets_dir, "store_icon_512x512.png")
    if os.path.exists(icon_path):
        with Image.open(icon_path) as img:
            print(f"Icon dimensions: {img.size}")
            if img.size != (512, 512):
                print("Resizing icon to exactly 512x512...")
                resized = img.resize((512, 512), Image.Resampling.LANCZOS)
                resized.save(icon_path, "PNG")
                print("Icon resized successfully!")
    else:
        print("Warning: store_icon_512x512.png not found!")

    # 2. Check & Correct Feature Graphic (must be exactly 1024x500)
    # If the generated image was 1024x1024 or 1:1, we can crop/resize it to 1024x500 beautifully
    feature_path = os.path.join(assets_dir, "feature_graphic_1024x500.png")
    if os.path.exists(feature_path):
        with Image.open(feature_path) as img:
            print(f"Feature graphic dimensions: {img.size}")
            if img.size != (1024, 500):
                print("Correcting feature graphic to exactly 1024x500...")
                # If it's a square (like 1024x1024), we crop the center 1024x500 area
                w, h = img.size
                if w == h or abs(w - h) < 50:
                    # Let's crop from center
                    # We want to keep the center-top bias where the title and phone signed document are
                    # Center Y is h/2. We want a box of height 500.
                    # Let's take the middle-upper part to ensure we keep the phone and title:
                    # from y_start to y_start + 500
                    # Let's set y_start to keep the top 100px down to y=600, or center:
                    y_start = max(0, int((h - 500) / 2))
                    # Let's crop: (left, upper, right, lower)
                    cropped = img.crop((0, y_start, w, y_start + 500))
                    cropped.save(feature_path, "PNG")
                    print(f"Feature graphic cropped from center-y ({y_start} to {y_start + 500}) to 1024x500 successfully!")
                else:
                    # Otherwise, resize it directly
                    resized = img.resize((1024, 500), Image.Resampling.LANCZOS)
                    resized.save(feature_path, "PNG")
                    print("Feature graphic resized to 1024x500 successfully!")

    # 3. Check Phone Screenshots (must be between 320px and 3840px, aspect ratio 2:1 or similar)
    for file in os.listdir(assets_dir):
        if file.startswith("phone_screenshot_") and file.endswith(".png"):
            path = os.path.join(assets_dir, file)
            with Image.open(path) as img:
                print(f"Screenshot {file} dimensions: {img.size}")
                # Google Play allows screenshots up to 3840px. 
                # Let's ensure the screenshots are PNG format and optimized.
                # If they are too big (e.g. over 2000px), we can downscale them to a standard 1080x2400 (aspect ratio 9:20) or similar
                # to reduce file size and upload times, but original emulator dimensions are usually fine.
                w, h = img.size
                if w > 1920 or h > 1920:
                    # Downscale to fit within 1920 max dimension while keeping aspect ratio
                    max_dim = 1920
                    if w > h:
                        new_w = max_dim
                        new_h = int(h * (max_dim / w))
                    else:
                        new_h = max_dim
                        new_w = int(w * (max_dim / h))
                    print(f"Downscaling screenshot {file} from {img.size} to {(new_w, new_h)}...")
                    resized = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
                    resized.save(path, "PNG")

if __name__ == "__main__":
    process_assets()
