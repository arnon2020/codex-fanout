import json, re, glob, os, collections

# every alias maw can actually resolve, from every layer that gets loaded anywhere
_HOME = os.path.expanduser('~')
_USER_LAYER = os.path.join(_HOME, '.config', 'maw') + os.sep
_TEAM_LAYER = os.path.join(_HOME, '.maw-teams') + os.sep
# 🩹 2026-08-07 — these were hardcoded to /home/user. On any other machine the user: and team:
#    branches of _reach() would never match and EVERY alias would mislabel as repo: — i.e. the
#    vantage bug D15.7 exists to prevent, shipped inside the tool that reports vantage.
#    Found by the retrospective's own file-analysis pass, not by a peer.
_DEFAULT_ROOTS = [
    os.path.join(_HOME, 'ghq', 'github.com', '*', '*', '.maw', 'maw.config.*.json'),
    os.path.join(_USER_LAYER, 'maw.config.*.json'),
    os.path.join(_TEAM_LAYER, '*', '.maw', 'maw.config.*.json'),
]
# 🔧 2026-08-07 (lucifer) — the globs used to be hardcoded, which made the names!=rows warning
#    below IMPOSSIBLE to test without writing colliding aliases into real shared config. Nobody
#    would ever do that, so "the warning has never fired" would have stayed true BY CONSTRUCTION
#    rather than by luck. 🔑 A check you cannot make fail is a check that cannot fail.
#    MAW_CENSUS_ROOTS (colon-separated globs) overrides for testing. Default is unchanged.
_roots = os.environ.get('MAW_CENSUS_ROOTS')
_roots = _roots.split(':') if _roots else _DEFAULT_ROOTS
files = [f for pat in _roots for f in glob.glob(pat)]
_custom = _roots is not _DEFAULT_ROOTS
# 🩹 2026-08-07 (lucifer) — when roots are overridden, EVERY line below is a statement about the
#    fixture, not about the fleet. Say so at the top, or someone copies a fixture-scoped sentence
#    into a fleet-scoped report. Same vantage problem as the REACH column, pointed the other way.
if _custom:
    print("⚠️  MAW_CENSUS_ROOTS is set — every number below describes THESE roots, not the fleet:")
    for r in _roots: print(f"      {r}")
    print()
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
    # 🩹 2026-08-07 — this used to index path segments by fixed position (f.split('/')[6]).
    #    It crashed with IndexError the FIRST time the script was run against a fixture root,
    #    i.e. the first time it was testable at all. The defect had been shipped and unseen
    #    because the only inputs it ever saw were the three hardcoded globs.
    #    ⇒ Derive the owner from the layer directory, never from a segment index.
    kinds = set()
    for f in paths:
        if f.startswith(_USER_LAYER):
            kinds.add('user:everyone')
        elif f.startswith(_TEAM_LAYER):
            kinds.add('team:' + os.path.relpath(f, _TEAM_LAYER).split(os.sep)[0])
        else:
            # <owner>/.maw/maw.config.NN.json  ->  owner is the dir containing .maw
            d = os.path.dirname(f)
            owner = os.path.basename(os.path.dirname(d)) if os.path.basename(d) == '.maw' \
                    else os.path.basename(d)
            kinds.add('repo:' + owner)
    return ','.join(sorted(kinds))

print(f"{len(cmds)} distinct aliases across {len(files)} layer files\n")
print("REACH — who can actually resolve each alias (definitions != availability):")
_universal = [k for k, ps in where.items() if any(p.startswith(_USER_LAYER) for p in ps)]
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

# 🔴 2026-08-07 (lucifer) — THREE different counts live here. Print all three, always, labelled.
#    Anyone quoting a bare number from this script is quoting one of these without saying which,
#    and two people can then quote different numbers and both be right.
#      names       = distinct alias names that pin effort
#      rows        = alias x distinct command string   <- what the counter above reports
#      definitions = every time such an alias is defined, across all layer files
#    Today names == rows **by coincidence**: no alias yet has two different command strings.
#    The day one does, these silently diverge — and that is the alias-name collision problem.
#    ✅ The warning below IS PROVEN TO FIRE. [verified 2026-08-07 by lucifer, then re-run by
#    codex-fanout, two arms via MAW_CENSUS_ROOTS against fixtures — no shared state touched]
#      negative control: one alias, two files, IDENTICAL string -> names1 rows1 defs2, silent
#      positive        : one alias, two files, DIFFERENT strings -> names1 rows2 defs2, fires
#    So its silence here is now evidence, which it was not an hour ago.
_names = {k for k in cmds if any(tier(v)[1] for v in cmds[k])}
_rows  = sum(1 for k, _, e in rows if e)
_defs  = sum(1 for k in _names for f in where[k]
             if (lambda c: any(tier(x)[1] for x in [c.get(k)] if isinstance(x, str)))(
                 json.load(open(f)).get('commands', {}) or {}))
print(f"\neffort counts — quote the label, never the bare number:")
print(f"   names       (distinct alias names)              : {len(_names)}")
print(f"   rows        (alias x distinct command string)   : {_rows}")
print(f"   definitions (times defined across layer files)  : {_defs}")
if len(_names) != _rows:
    print(f"   🔴 names != rows — an alias is defined with MORE THAN ONE command string.")
    for k in sorted(_names):
        if len(cmds[k]) > 1: print(f"      {k}: {len(cmds[k])} different commands -> {where[k]}")
else:
    _scope = "in these roots" if _custom else "fleet-wide today"
    print(f"   (names == rows {_scope}; no alias has two different command strings)")
nomodel = [k for k, m, e in rows if not m and not e]
print(f"\naliases pinning NEITHER model nor effort (ambient): {len(nomodel)}")
