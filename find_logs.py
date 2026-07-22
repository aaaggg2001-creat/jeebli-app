import json
log_path = r'C:\Users\ALayham\.gemini\antigravity\brain\d5ae80c9-22a8-47e3-988c-3a11f9ada84a\.system_generated\logs\transcript_full.jsonl'

with open(log_path, 'r', encoding='utf-8') as f:
    for i, line in enumerate(f):
        if '2026-07-21T03:1' in line or '2026-07-21T03:2' in line or '2026-07-21T03:0' in line:
            try:
                data = json.loads(line)
                print(f"Line {i} - Type {data.get('type')} - Created {data.get('created_at')}")
                if data.get('type') == 'USER_INPUT':
                    print(data.get('content')[:200])
            except:
                pass
