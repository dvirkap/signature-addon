import re

def check_file(path):
    try:
        with open(path, 'r', encoding='utf-8') as f:
            code = f.read()
        match = re.search(r'const appSupportedLanguages\s*=\s*\{(.*?)\};', code, re.DOTALL)
        if match:
            # Match either single quotes or double quotes or unquoted word keys
            keys = re.findall(r"(?:'([^']+)'|\"([^\"]+)\"|([a-zA-Z0-9_]+))\s*:", match.group(1))
            flat_keys = [k[0] or k[1] or k[2] for k in keys if any(k)]
            print(f"{path} keys count: {len(flat_keys)}")
            print(f"First 10 keys: {flat_keys[:10]}")
        else:
            print(f"{path} appSupportedLanguages not found")
    except Exception as e:
        print(f"Error reading {path}: {e}")

check_file('translations.js')
check_file('assets/www/translations.js')
check_file('pwa/translations.js')
