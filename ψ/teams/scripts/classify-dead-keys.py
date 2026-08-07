import json, os, subprocess, glob

dead = json.load(open('/home/user/.config/maw/maw.config.json')).get('commands', {})

# candidate vantage points: every repo on this machine that carries a .maw layer
roots = sorted({os.path.dirname(os.path.dirname(p))
                for p in glob.glob('/home/user/ghq/github.com/*/*/.maw/maw.config*.json')})
roots = ['/tmp'] + roots

keys = ['atlas-codex-oracle','cipher-codex-full-oracle','claude-opus-headless','codex-medium',
        'codex-xhigh','drift-oracle','echo-oracle','hound-codex-oracle','opencode-coder-serve']

def live_cmds(d):
    src = subprocess.run(['maw','config','sources'], cwd=d, capture_output=True, text=True).stdout
    out = {}
    for ln in src.splitlines():
        for tok in ln.split():
            if tok.startswith('/'):
                try: out.update(json.load(open(tok)).get('commands', {}) or {})
                except Exception: pass
    return out

seen = {k: {} for k in keys}
for d in roots:
    if not os.path.isdir(d): continue
    lc = live_cmds(d)
    for k in keys:
        if k in lc:
            seen[k].setdefault(lc[k], []).append(os.path.basename(d))

print('vantage points scanned: %d  (%s …)' % (len(roots), ', '.join(os.path.basename(r) for r in roots[:4])))
print()
for k in keys:
    if not seen[k]:
        print('(A) %-26s  live nowhere in scanned scope' % k)
    else:
        variants = list(seen[k].items())
        same = all(c == dead.get(k) for c, _ in variants)
        tag = 'same cmd' if same else '⚠ DIFFERENT cmd than dead file'
        print('(B) %-26s  live in %d repo(s): %s   [%s]'
              % (k, sum(len(v) for _, v in variants), ', '.join(sorted({r for _, v in variants for r in v})), tag))
