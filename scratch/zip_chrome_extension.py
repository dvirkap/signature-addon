import os
import zipfile

def zip_extension():
    zip_filename = "FreeSign_PDF_Chrome_Extension.zip"
    
    # Files to include in the Chrome Extension bundle
    files_to_zip = [
        "manifest.json",
        "popup.html",
        "popup.js",
        "background.js",
        "editor.html",
        "editor.js",
        "editor.css",
        "translations.js"
    ]
    
    # Directory to include (icons)
    icons_dir = "icons"
    icon_files = [
        "icon16.png",
        "icon48.png",
        "icon128.png"
    ]
    
    print(f"Creating Chrome Extension bundle: {zip_filename}...")
    
    with zipfile.ZipFile(zip_filename, "w", zipfile.ZIP_DEFLATED) as zipf:
        # Add root files
        for file in files_to_zip:
            if os.path.exists(file):
                zipf.write(file)
                print(f"Added: {file}")
            else:
                print(f"Error: Required file {file} is missing!")
                
        # Add icons
        if os.path.exists(icons_dir):
            for icon in icon_files:
                icon_path = os.path.join(icons_dir, icon)
                if os.path.exists(icon_path):
                    # We store it inside the zip under icons/iconXX.png
                    zipf.write(icon_path)
                    print(f"Added: {icon_path}")
                else:
                    print(f"Error: Icon {icon_path} is missing!")
        else:
            print("Error: icons directory is missing!")
            
    print(f"Chrome Extension bundle created successfully! Path: {os.path.abspath(zip_filename)}")

if __name__ == "__main__":
    zip_extension()
