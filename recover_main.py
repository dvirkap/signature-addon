import json

transcript_path = r'C:\Users\דביר\.gemini\antigravity-ide\brain\423b22ed-f546-4eca-9ecb-8eae1da52a67\.system_generated\logs\transcript.jsonl'
target_file_content = None

with open(transcript_path, encoding='utf-8') as f:
    for line in f:
        try:
            data = json.loads(line)
        except: continue
        
        # Look for the response of view_file
        if data.get('type') == 'TOOL_RESPONSE' and data.get('tool_name') == 'view_file':
            output = data.get('content', '')
            if 'import \'dart:async\';' in output and 'class PdfEditorScreen' in output and '_pendingSignatures' not in output:
                target_file_content = output
                print(f"Found candidate at step {data.get('step_index')}")

if target_file_content:
    with open('lib/main.dart', 'w', encoding='utf-8') as f:
        f.write(target_file_content)
    print('Successfully recovered main.dart!')
else:
    print('No suitable main.dart found in logs.')
