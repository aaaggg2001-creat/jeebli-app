import os, json, datetime

history_dir = r'C:\Users\ALayham\AppData\Roaming\Code\User\History\-4533e631'
entries_file = os.path.join(history_dir, 'entries.json')
with open(entries_file, 'r', encoding='utf-8') as f:
    entries = json.load(f)

for e in entries.get('entries', []):
    ts = e.get('timestamp', 0)
    fname = e.get('id', '')
    dt = datetime.datetime.fromtimestamp(ts/1000, tz=datetime.timezone.utc).astimezone()
    size = 0
    fpath = os.path.join(history_dir, fname + '.dart')
    if os.path.exists(fpath):
        size = os.path.getsize(fpath)
    print(f"{dt.strftime('%Y-%m-%d %H:%M:%S %z')} => {fname}.dart ({size:,} bytes)")
