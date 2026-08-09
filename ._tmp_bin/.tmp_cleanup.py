import io


def load(p):
    with io.open(p, 'rb') as f:
        raw = f.read()
    crlf = b'\r\n' in raw
    text = raw.decode('utf-8')
    return (text, crlf) if not crlf else (text.replace('\r\n', '\n'), crlf)


def save(p, text, crlf):
    out = text if not crlf else text.replace('\n', '\r\n')
    with io.open(p, 'wb') as f:
        f.write(out.encode('utf-8'))


# ── stats_screen.dart: drop _buildScreenTimeHero + _pillBadge ────────────────
p1 = r'C:\Users\anish\Documents\fravo\lib\screens\stats_screen.dart'
t, crlf = load(p1)

a = t.index('  Widget _buildScreenTimeHero(int remaining, int earned, int used) {')
b = t.index('\n\n  // ── Steps Card', a)
t = t[:a] + t[b + 2:]  # keep the '// ── Steps Card' comment block

c = t.index('  Widget _pillBadge(String text, Color color) {')
d = t.index('\n\n  Widget _errorBanner(String message) {', c)
t = t[:c] + t[d + 1:]  # keep the error banner
save(p1, t, crlf)
print('stats: removed hero + pillBadge')

# ── main.dart: remove the bottom metrics row ─────────────────────────────────
p2 = r'C:\Users\anish\Documents\fravo\lib\main.dart'
t2, crlf2 = load(p2)

m = t2.index('              // ── Metric Cards (Glass)')
n = t2.index('              if (_statusMessage != null)', m)
t2 = t2[:m] + t2[n:]
save(p2, t2, crlf2)
print('main: metric row removed')