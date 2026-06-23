import os
from PIL import Image

def process_new():
    brain_dir = r"C:\Users\דביר\.gemini\antigravity-ide\brain\423b22ed-f546-4eca-9ecb-8eae1da52a67"
    
    # New files from the last upload
    new_files = {
        "media__1782220449832.jpg": "new_camera.png",
        "media__1782220474450.jpg": "new_page_editor.png"
    }
    
    for filename, new_name in new_files.items():
        src_path = os.path.join(brain_dir, filename)
        dst_path = os.path.join(brain_dir, new_name)
        if os.path.exists(src_path):
            with Image.open(src_path) as img:
                print(f"{filename} -> {new_name} : size={img.size}, format={img.format}")
                img.save(dst_path, "PNG")
        else:
            print(f"File {filename} not found!")

if __name__ == "__main__":
    process_new()
