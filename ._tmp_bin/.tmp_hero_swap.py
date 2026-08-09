import io

p = r'C:\Users\anish\Documents\fravo\lib\main.dart'
with io.open(p, 'rb') as f:
    raw = f.read()

crlf = b'\r\n' in raw
text = raw.decode('utf-8')
if crlf:
    text = text.replace('\r\n', '\n')

START = '              // ── Main Hero Row (Screen Time Left & Blocked Apps side-by-side) ──'
END = '\n              const SizedBox(height: 24),\n'

i = text.index(START)
j = text.index(END, i) + len(END)
print('slice', i, j, 'block_len', j - i)

new_block = '''              // ── Hero: Screen-Time Ring ──────────────────────────────────────
              _TimeHeroCard(
                remaining: remaining,
                earned: earned,
                used: used,
              ),
              const SizedBox(height: 16),

              // ── Blocked Apps ──────────────────────────────────────────
              _BlockedAppsCard(
                apps: blockedApps,
                timeBank: _timeBank,
                blockerService: _blockerService,
                onManage: _openAppSelector,
              ),
              const SizedBox(height: 24),
'''

text = text[:i] + new_block + text[j:]
if crlf:
    text = text.replace('\n', '\r\n')

with io.open(p, 'wb') as f:
    f.write(text.encode('utf-8'))
print('OK')