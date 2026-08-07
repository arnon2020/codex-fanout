import json, re, glob, os, collections

# every alias maw can actually resolve, from every layer that gets loaded anywhere
files = glob.glob('/home/user/ghq/github.com/*/*/.maw/maw.config.*.json') \
      + glob.glob('/home/user/.config/maw/maw.config.*.json')
cmds = {}
for f in files:
    try: c = json.load(open(f)).get('commands', {}) or {}
    except Exception: continue
    for k, v in c.items():
        if isinstance(v, str): cmds.setdefault(k, set()).add(v)

def tier(cmd):
    m = re.search(r'--model[= ]([^\s]+)', cmd)
    model = m.group(1) if m else None
    eff = re.search(r'model_reasoning_effort=(\w+)', cmd)
    return model, (eff.group(1) if eff else None)

rows = []
for k, vs in cmds.items():
    for v in vs:
        model, eff = tier(v)
        rows.append((k, model, eff))

print(f"{len(cmds)} distinct aliases across {len(files)} layer files\n")
mc = collections.Counter(m for _, m, _ in rows if m)
ec = collections.Counter(e for _, _, e in rows if e)
print("models requested by aliases:")
for m, n in mc.most_common(): print(f"   {n:3}  {m}")
print("\nreasoning effort requested:")
for e, n in ec.most_common(): print(f"   {n:3}  {e}")
nomodel = [k for k, m, e in rows if not m and not e]
print(f"\naliases pinning NEITHER model nor effort (ambient): {len(nomodel)}")
