import os
import shutil
from PIL import Image

def inspect():
    brain_dir = r"C:\Users\דביר\.gemini\antigravity-ide\brain\423b22ed-f546-4eca-9ecb-8eae1da52a67"
    user_files = [
        "media__1782219523306.jpg",
        "media__1782219523309.jpg",
        "media__1782219523326.jpg",
        "media__1782219523340.jpg",
        "media__1782219523355.jpg"
    ]
    
    mapping = {
        "media__1782219523306.jpg": "user_page_editor.png",
        "media__1782219523309.jpg": "user_dashboard.png",
        "media__1782219523326.jpg": "user_manage_signatures.png",
        "media__1782219523340.jpg": "user_camera.png",
        "media__1782219523355.jpg": "user_editor_signed.png"
    }
    
    for filename, new_name in mapping.items():
        src_path = os.path.join(brain_dir, filename)
        dst_path = os.path.join(brain_dir, new_name)
        if os.path.exists(src_path):
            with Image.open(src_path) as img:
                print(f"{filename} -> {new_name} : size={img.size}, format={img.format}")
                # Convert and save as PNG
                img.save(dst_path, "PNG")
        else:
            print(f"File {filename} not found!")

if __name__ == "__main__":
    inspect()
