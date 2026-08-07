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

print(f"{len(cmds)} distinct aliases across {len(files)} layer files\n")
mc = collections.Counter(m for _, m, _ in rows if m)
ec = collections.Counter(e for _, _, e in rows if e)
print("models requested by aliases:")
for m, n in mc.most_common(): print(f"   {n:3}  {m}")
print("\nreasoning effort requested:")
for e, n in ec.most_common(): print(f"   {n:3}  {e}")
nomodel = [k for k, m, e in rows if not m and not e]
print(f"\naliases pinning NEITHER model nor effort (ambient): {len(nomodel)}")
