import re
import os
import json

def parse_translations():
    dart_file_path = os.path.join("lib", "translations.dart")
    
    with open(dart_file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. Extract appSupportedLanguages
    supported_langs = {}
    langs_match = re.search(r"final\s+Map<String,\s*String>\s+appSupportedLanguages\s*=\s*\{(.*?)\};", content, re.DOTALL)
    if langs_match:
        # Match pattern like: 'af': 'Afrikaans (Afrikaans)',
        pairs = re.findall(r"['\"]([^'\"]+)['\"]\s*:\s*['\"]((?:[^'\"]|\\')*)['\"]", langs_match.group(1))
        for key, val in pairs:
            # unescape single quotes
            val = val.replace("\\'", "'")
            supported_langs[key] = val

    # 2. Extract localizedValues
    # We find localizedValues block
    localized_match = re.search(r"const\s+Map<String,\s*Map<String,\s*String>>\s+localizedValues\s*=\s*\{(.*?)\};\s*$", content, re.DOTALL)
    if not localized_match:
        print("Error: localizedValues not found!")
        return supported_langs, {}

    localized_content = localized_match.group(1)
    
    # We want to extract each language block. A language block looks like:
    # 'af': {
    #   "key": "value",
    #   ...
    # },
    # We can split the content by lines and extract blocks
    lang_blocks = {}
    
    # Let's find matches for each language code and its corresponding block inside braces
    # Using re.finditer to parse blocks recursively or sequentially
    block_pattern = r"['\"]([a-zA-Z_]+)['\"]\s*:\s*\{(.*?)\}\s*,\s*\n"
    matches = re.findall(block_pattern, localized_content, re.DOTALL)
    
    for lang_code, block_str in matches:
        lang_dict = {}
        # Parse key-value pairs inside block_str
        # Pattern like: "app_title": "Teken net",
        kv_pairs = re.findall(r"\"([^\"]+)\"\s*:\s*\"((?:[^\"]|\\\")*)\"", block_str)
        for k, v in kv_pairs:
            # unescape characters
            v = v.replace('\\"', '"').replace('\\n', '\n')
            lang_dict[k] = v
        lang_blocks[lang_code] = lang_dict

    return supported_langs, lang_blocks

# Base translations for Hebrew and English to preserve their original high-quality strings
HE_BASE = {
    "appName": "FreeSign PDF - פשוט לחתום",
    "loadPdf": "📁 טעינת PDF",
    "saveDownloadPdf": "💾 שמירה והורדת PDF",
    "noFileLoaded": "לא נטען קובץ PDF",
    "pageOf": "עמוד {current} מתוך {total}",
    "mySignatures": "החתימות שלי",
    "newSignature": "חתימה חדשה",
    "subtabDraw": "ציור",
    "subtabType": "הקלדה",
    "subtabUpload": "העלאה",
    "sigColor": "צבע החתימה:",
    "lineWidth": "עובי קו:",
    "drawThin": "דק",
    "drawMedium": "בינוני",
    "drawThick": "עבה",
    "sigNameLabel": "שם החתימה:",
    "drawPlaceholder": 'לדוגמה: "חתימה רשמית"',
    "clearBtn": "ניקוי",
    "saveBtn": "שמירת חתימה",
    "alertDrawSomething": "בבקשה צייר משהו לפני השמירה!",
    "typeInputLabel": "הקלד טקסט לחתימה:",
    "typePlaceholder": "הקלד את שמך כאן...",
    "typeSigNamePlaceholder": 'לדוגמה: "חתימת טקסט"',
    "fontStyleLabel": "סגנון כתב:",
    "uploadLabel": "גרור תמונה או לחץ להעלאת קובץ",
    "uploadSubtext": "תומך ב-PNG, JPG, SVG",
    "previewTitle": "תצוגה מקדימה:",
    "removeBgLabel": "הסרת רקע לבן (הפיכה לשקוף)",
    "bgThresholdLabel": "רגישות הסרה:",
    "uploadNamePlaceholder": 'לדוגמה: "חתימה סרוקה"',
    "emptyState": "עדיין אין חתימות שמורות. לחץ על הלשונית \"חתימה חדשה\" כדי ליצור חתימה.",
    "maxQuota": "הגעת למכסה המרבית של 15 חתימות.",
    "deleteConfirm": 'האם למחוק את "{name}"?',
    "loadPdfFirst": "יש לטעון קובץ PDF תחילה!",
    "loadingPdfText": "טוען קובץ PDF...",
    "loadingError": "שגיאת טעינה",
    "loadPdfFailed": "טעינת ה-PDF נכשלה. אנא הורד את הקובץ וגרור אותו לכאן.",
    "loadingPdfAlert": "שגיאה בטעינת ה-PDF.",
    "creatingFile": "⚙️ מייצר קובץ...",
    "signingError": "שגיאה ביצירת ה-PDF החתום.",
    "snapTooltip": "גרור כדי לסובב את החתימה",
    "deleteTooltip": "מחיקה",
    "creditText": 'האפליקציה נוצרה כשירות ע"י <strong>דביר קפלן</strong> למען אנשי החינוך ❤️',
    "themeLabel": "עיצוב:",
    "themeLight": "קלאסי בהיר",
    "themeWarm": "נייר חמים",
    "themeChalkboard": "לוח כיתה",
    "themeDark": "עיצוב כהה",
    "dropZoneHeader": "גרור ושחרר קובץ PDF לכאן",
    "dropZoneSub": 'או לחץ על "טעינת PDF" כדי לבחור קובץ',
    "langLabel": "שפה / Lang:",
    "exportSigs": "📤 ייצוא גיבוי",
    "importSigs": "📥 ייבוא גיבוי",
    "confirmImport": "האם אתה בטוח שברצונך לייבא חתימות מקובץ זה? פעולה זו תדרוס חתימות קיימות בעלות מזהה זהה.",
    "importSuccess": "החתימות יובאו בהצלחה!",
    "importError": "ייבוא הגיבוי נכשל! בדוק שהקובץ תקין."
}

EN_BASE = {
    "appName": "FreeSign PDF",
    "loadPdf": "📁 Load PDF",
    "saveDownloadPdf": "💾 Save & Download PDF",
    "noFileLoaded": "No PDF file loaded",
    "pageOf": "Page {current} of {total}",
    "mySignatures": "My Signatures",
    "newSignature": "New Signature",
    "subtabDraw": "Draw",
    "subtabType": "Type",
    "subtabUpload": "Upload",
    "sigColor": "Signature Color:",
    "lineWidth": "Line Width:",
    "drawThin": "Thin",
    "drawMedium": "Medium",
    "drawThick": "Thick",
    "sigNameLabel": "Signature Name:",
    "drawPlaceholder": 'e.g. "Official Signature"',
    "clearBtn": "Clear",
    "saveBtn": "Save Signature",
    "alertDrawSomething": "Please draw something before saving!",
    "typeInputLabel": "Type text for signature:",
    "typePlaceholder": "Type your name here...",
    "typeSigNamePlaceholder": 'e.g. "Digital Signature"',
    "fontStyleLabel": "Choose font style:",
    "uploadLabel": "Click to upload signature image",
    "uploadSubtext": "Supports PNG, JPG, SVG",
    "previewTitle": "Preview:",
    "removeBgLabel": "Remove white background (make transparent)",
    "bgThresholdLabel": "Removal sensitivity:",
    "uploadNamePlaceholder": 'e.g. "Scanned Signature"',
    "emptyState": "No saved signatures. Click the \"New Signature\" tab to create one.",
    "maxQuota": "Maximum quota of 15 signatures reached.",
    "deleteConfirm": 'Delete "{name}"?',
    "loadPdfFirst": "Load PDF first!",
    "loadingPdfText": "Loading PDF...",
    "loadingError": "Loading Error",
    "loadPdfFailed": "Failed to load PDF from URL. Please save the file and drag it here.",
    "loadingPdfAlert": "Error loading PDF.",
    "creatingFile": "⚙️ Creating file...",
    "signingError": "Error generating signed PDF.",
    "snapTooltip": "Drag to rotate signature",
    "deleteTooltip": "Delete",
    "creditText": "App created as a service by <strong>Dvir Kaplan</strong> for educators ❤️",
    "themeLabel": "Theme:",
    "themeLight": "Classic Light",
    "themeWarm": "Warm Paper",
    "themeChalkboard": "Classroom Chalkboard",
    "themeDark": "Sleek Dark",
    "dropZoneHeader": "Drag and drop PDF file here",
    "dropZoneSub": "or click \"Load PDF\" in the top bar",
    "langLabel": "Language:",
    "exportSigs": "📤 Export Backup",
    "importSigs": "📥 Import Backup",
    "confirmImport": "Are you sure you want to import signatures from this file? Existing signatures with identical IDs will be overwritten.",
    "importSuccess": "Signatures imported successfully!",
    "importError": "Import failed! Verify the backup file format is correct."
}

MAPPING = {
    "appName": "app_title",
    "loadPdf": lambda l: f"📁 {l.get('pick_file_to_load', l.get('pick_pdf', 'Load PDF'))}",
    "saveDownloadPdf": lambda l: f"💾 {l.get('save_confirm', l.get('save', 'Save'))}",
    "noFileLoaded": "no_archived_files",
    "pageOf": "page_indicator",
    "mySignatures": "manage_my_signatures",
    "newSignature": "add_signature_stamp",
    "subtabDraw": "ink_original",
    "subtabType": "free_text",
    "subtabUpload": "gallery",
    "sigColor": "select_ink_color",
    "lineWidth": "text_size",
    "drawThin": "ink_original",
    "drawMedium": "ink_black",
    "drawThick": "ink_blue",
    "sigNameLabel": "signature_label",
    "drawPlaceholder": "stamp_label_prompt_hint",
    "clearBtn": "cancel",
    "saveBtn": "save",
    "alertDrawSomething": lambda l: l.get("click_to_add", "Please draw something before saving!"),
    "typeInputLabel": "choose_text_type",
    "typePlaceholder": "enter_text_hint",
    "typeSigNamePlaceholder": "stamp_label_prompt_hint",
    "fontStyleLabel": "choose_text_type",
    "uploadLabel": "add_from_gallery",
    "uploadSubtext": "gallery",
    "previewTitle": "preview_transparent",
    "removeBgLabel": "crop_clean_title",
    "bgThresholdLabel": "sensitivity",
    "uploadNamePlaceholder": "stamp_label_prompt_hint",
    "emptyState": "no_saved_signatures",
    "maxQuota": "no_saved_device",
    "deleteConfirm": "confirm_delete_signature",
    "loadPdfFirst": "pick_file_to_load",
    "loadingPdfText": "saving_cleaning",
    "loadingError": "error_baking",
    "loadPdfFailed": "error_baking",
    "loadingPdfAlert": "error_baking",
    "creatingFile": "saving_cleaning",
    "signingError": "error_baking",
    "snapTooltip": "signature_label",
    "deleteTooltip": "delete",
    "creditText": "about_desc",
    "themeLabel": "text_color",
    "themeLight": "ink_original",
    "themeWarm": "printed_name_saved",
    "themeChalkboard": "printed_name",
    "themeDark": "ink_black",
    "dropZoneHeader": "pick_pdf",
    "dropZoneSub": "pick_file_to_load",
    "langLabel": "language",
    "exportSigs": lambda l: f"📤 {l.get('save_share', 'Export Backup')}",
    "importSigs": lambda l: f"📥 {l.get('pick_file_to_load', 'Import Backup')}",
    "confirmImport": "confirm_delete_signature",
    "importSuccess": "printed_name_saved",
    "importError": "error_baking"
}

def generate_js_translations():
    supported_langs, lang_blocks = parse_translations()
    
    # We build the translations dictionary for JavaScript
    js_translations = {}
    
    # Hebrew and English are hardcoded to HE_BASE and EN_BASE
    js_translations["he"] = HE_BASE
    js_translations["en"] = EN_BASE
    
    # For all other languages, we map the keys
    for code, lang_dict in lang_blocks.items():
        if code in ["he", "en"]:
            continue
            
        mapped_dict = {}
        for web_key, dart_key_or_fn in MAPPING.items():
            if callable(dart_key_or_fn):
                mapped_dict[web_key] = dart_key_or_fn(lang_dict)
            else:
                mapped_dict[web_key] = lang_dict.get(dart_key_or_fn, EN_BASE[web_key])
                
        js_translations[code] = mapped_dict

    # Write translations.js
    output_js = f"""// Automatically generated translations for 70+ languages from translations.dart
const appSupportedLanguages = {json.dumps(supported_langs, ensure_ascii=False, indent=2)};

const translations = {json.dumps(js_translations, ensure_ascii=False, indent=2)};
"""

    targets = [
        "translations.js",
        os.path.join("pwa", "translations.js"),
        os.path.join("assets", "www", "translations.js")
    ]
    
    for target in targets:
        os.makedirs(os.path.dirname(target) if os.path.dirname(target) else ".", exist_ok=True)
        with open(target, "w", encoding="utf-8") as f:
            f.write(output_js)
        print(f"Generated: {target}")

if __name__ == "__main__":
    generate_js_translations()
