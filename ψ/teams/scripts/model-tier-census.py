import json, re, glob, os, collections

# every alias maw can actually resolve, from every layer that gets loaded anywhere
files = glob.glob('/home/user/ghq/github.com/*/*/.maw/maw.config.*.json') \
      + glob.glob('/home/user/.config/maw/maw.config.*.json') \
      + glob.glob('/home/user/.maw-teams/*/.maw/maw.config.*.json')
# 🩹 2026-08-07 (loom): the third glob was missing — team layers under ~/.maw-teams/<team>/.maw/
#    were invisible. Today impact = 0 (aliases there duplicate repo-layer ones: 37/4/8 either way),
#    so this is LATENT, not active. It bites when a team layer defines an alias no repo defines —
#    which is exactly what ~/.maw-teams/ exists for. lucifer confirmed the same blind spot on
#    2026-08-07 from the other side: scoping to ~/ghq + /tmp undercounted live registrations.
# 🩹 CORRECTED 2026-08-07 16:2x (lucifer, on his own earlier number): the line here used to say
#    "codex-xhigh is live in THREE layers, not two". That was measured BEFORE the 6-key move.
#    Now: **2 loadable layers + 1 dead file** (the unnumbered maw.config.json, which this glob
#    correctly excludes). Reading "three loadable" overstates fleet readiness.
#    [verified 2026-08-07 16:2x: grep -l '"codex-xhigh"' across all three globs -> exactly
#     loom-oracle/.maw/maw.config.60.json and ~/.maw-teams/teaching-media-cell/.maw/maw.config.60.json]
cmds = {}
where = {}   # alias -> [layer files that define it]  (needed for the REACH report below)
for f in files:
    try: c = json.load(open(f)).get('commands', {}) or {}
    except Exception: continue
    for k, v in c.items():
        if isinstance(v, str):
            cmds.setdefault(k, set()).add(v)
            where.setdefault(k, []).append(f)

# 🩹 2026-08-07 [ajfon] regex เดิม `model_reasoning_effort=(\w+)` **มองไม่เห็นค่าที่ใส่ quote**
#    (`model_reasoning_effort="high"`) ซึ่ง **ถูกต้องตาม `-c` syntax ของ codex เอง**
#    (`--help` ยกตัวอย่าง `-c model="o3"`) ⇒ census นับว่า "ไม่ pin" ทั้งที่ pin จริง
#    ⇒ **blind spot คลาสเดียวกับที่ไล่จับกันทั้งวัน**: สคริปต์อ่านไฟล์ config ตรง ๆ
#      **ไม่ได้ผ่าน shell tokenization แบบตอน execute จริง** ⇒ เห็นสตริงคนละตัวกับที่ engine เห็น
#    ⇒ ไม่กระทบความปลอดภัย แต่ **undercount** ⇒ ตัวเลข "effort ถูกตั้งกี่ตัว" ต่ำกว่าจริงได้
def _unq(s):
    return s.strip().strip('"').strip("'") if s else s

def tier(cmd):
    m = re.search(r'--model[= ]("[^"]+"|\'[^\']+\'|[^\s]+)', cmd)
    model = _unq(m.group(1)) if m else None
    eff = re.search(r'model_reasoning_effort=("[^"]+"|\'[^\']+\'|[\w-]+)', cmd)
    return model, (_unq(eff.group(1)) if eff else None)

rows = []
for k, vs in cmds.items():
    for v in vs:
        model, eff = tier(v)
        rows.append((k, model, eff))

# 🔴 2026-08-07 (lucifer) — WHAT THIS SCRIPT DOES NOT ANSWER, and why the column below exists.
#    This counts DEFINITIONS. It does not say WHO CAN USE THEM. Those are different questions and
#    a single number cannot answer the second one.
#    Worked example, measured: `codex-xhigh` is defined in 2 layers, both of them loom's.
#      maw config explain commands.codex-xhigh, run from:
#        /tmp                              -> FINAL null
#        arnon2020/lucifer-oracle          -> FINAL null
#        arnon2020/codex-fanout            -> FINAL null   (renamed away from that key)
#        arnon2020/loom-oracle             -> FINAL "...model_reasoning_effort=xhigh..."
#        ~/.maw-teams/teaching-media-cell  -> FINAL "...model_reasoning_effort=xhigh..."
#    Census says "this alias pins xhigh" — true. maw says "null" for everyone standing anywhere
#    else — also true. ⇒ 🔑 **A claim from this script needs a VANTAGE, not only a timestamp.**
#    Without it, "9 names pin effort" reads as "the fleet is ready", which is false.
def _reach(paths):
    # user layer (~/.config/maw)  = every vantage sees it
    # repo layer (<repo>/.maw)    = only under that repo
    # team layer (~/.maw-teams/..)= only under that team's worktrees
    kinds = set()
    for f in paths:
        if f.startswith('/home/user/.config/maw/'): kinds.add('user:everyone')
        elif f.startswith('/home/user/.maw-teams/'): kinds.add('team:' + f.split('/')[4])
        else: kinds.add('repo:' + f.split('/')[6])
    return ','.join(sorted(kinds))

print(f"{len(cmds)} distinct aliases across {len(files)} layer files\n")
print("REACH — who can actually resolve each alias (definitions != availability):")
_universal = [k for k, ps in where.items() if any(p.startswith('/home/user/.config/maw/') for p in ps)]
print(f"   visible fleet-wide (user layer)      : {len(_universal)}")
print(f"   visible only under one repo or team  : {len(cmds) - len(_universal)}")
print("   effort-pinned aliases, with reach:")
for k in sorted(cmds):
    if any(tier(v)[1] for v in cmds[k]):
        print(f"      {k:34} {_reach(where[k])}")
print()
mc = collections.Counter(m for _, m, _ in rows if m)
ec = collections.Counter(e for _, _, e in rows if e)
print("models requested by aliases:")
for m, n in mc.most_common(): print(f"   {n:3}  {m}")
print("\nreasoning effort requested:")
for e, n in ec.most_common(): print(f"   {n:3}  {e}")
nomodel = [k for k, m, e in rows if not m and not e]
print(f"\naliases pinning NEITHER model nor effort (ambient): {len(nomodel)}")
