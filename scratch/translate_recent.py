import re
import os

translations = {
    'af': 'Onlangse dokumente',
    'am': 'የቅርብ ጊዜ ሰነዶች',
    'ar': 'المستندات الأخيرة',
    'az': 'Son sənədlər',
    'be': 'Нядаўнія дакументы',
    'bg': 'Скорошни документи',
    'bn': 'সাম্প্রতিক নথি',
    'bs': 'Nedavni dokumenti',
    'ca': 'Documents recents',
    'cs': 'Nedávné dokumenty',
    'cy': 'Dogfennau Diweddar',
    'da': 'Seneste dokumenter',
    'de': 'Letzte Dokumente',
    'el': 'Πρόσφατα έγγραφα',
    'en': 'Recent Documents',
    'eo': 'Lastatempaj dokumentoj',
    'es': 'Documentos recientes',
    'et': 'Viimased dokumendid',
    'eu': 'Azken dokumentuak',
    'fa': 'اسناد اخیر',
    'fi': 'Viimeisimmät asiakirjat',
    'fr': 'Documents récents',
    'ga': 'Doiciméid le Déanaí',
    'gl': 'Documentos recentes',
    'gu': 'તાજેતરના દસ્તાવેજો',
    'he': 'מסמכים אחרונים',
    'hi': 'हाल के दस्तावेज़',
    'hr': 'Nedavni dokumenti',
    'hu': 'Legutóbbi dokumentumok',
    'hy': 'Վերջին փաստาթղթերը',
    'id': 'Dokumen baru-baru ini',
    'is': 'Nýleg skjöl',
    'it': 'Documenti recenti',
    'ja': '最近のドキュメント',
    'ka': 'ბოლო დოკუმენტები',
    'kk': 'Соңғы құжаттар',
    'kn': 'ಇತ್ತೀಚಿನ ದಾಖಲೆಗಳು',
    'ko': '최근 문서',
    'ky': 'Акыркы документтер',
    'la': 'Documenta recentia',
    'lt': 'Naujausi dokumentai',
    'lv': 'Nesenie dokumenti',
    'mk': 'Неодамнешни документи',
    'ml': 'സമീപകാല രേഖകൾ',
    'mn': 'Сүүлийн үеийн баримт бичиг',
    'mr': 'अलीकडील दस्तऐवज',
    'ms': 'Dokumen terkini',
    'ne': 'भर्खरका कागजातहरू',
    'nl': 'Recente documenten',
    'no': 'Nylige dokumenter',
    'pa': 'ਹਾਲ ਹੀ ਦੇ ਦਸਤਾਵੇਜ਼',
    'pl': 'Ostatnie dokumenty',
    'pt': 'Documentos recentes',
    'ro': 'Documente recente',
    'ru': 'Недавние документы',
    'si': 'මෑත ලිපි ලේඛන',
    'sk': 'Nedávne dokumenty',
    'sl': 'Nedavni dokumenti',
    'sq': 'Dokumentet e fundit',
    'sr': 'Недавна документа',
    'sv': 'Senaste dokument',
    'sw': 'Nyaraka za hivi karibuni',
    'ta': 'சமீபத்திய ஆவணங்கள்',
    'te': 'ఇటీవలి పత్రాలు',
    'tg': 'Ҳуҷҷатҳои охирин',
    'th': 'เอกสารล่าสุด',
    'tl': 'Mga Kamakailang Dokumento',
    'tr': 'Son Belgeler',
    'uk': 'Останні документи',
    'ur': 'حالیہ دستاویزات',
    'uz': 'Yaqinda foydalanilgan hujjatlar',
    'vi': 'Tài liệu gần đây',
    'zh': '最近的文档',
    'zh_TW': '繁體中文 (Recent Documents)'
}

file_path = 'lib/translations.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Let's find each language block like:
#   'af': {
#     "app_title": "Teken net",
# We want to insert `"recent_documents": "Onlangse dokumente",\n` right after the opening brace.

for lang, val in translations.items():
    # Escape quotes for safety
    val_escaped = val.replace('"', '\\"')
    # Match: 'lang': {
    # Followed by any whitespace
    pattern = rf"'{lang}':\s*\{{"
    replacement = f"'{lang}': {{\n    \"recent_documents\": \"{val_escaped}\","
    content = re.sub(pattern, replacement, content)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Translations successfully updated!")
