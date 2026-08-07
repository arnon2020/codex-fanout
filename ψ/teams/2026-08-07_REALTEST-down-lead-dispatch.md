# ใช้งานจริง `dispatch` / `lead` / `down` — ผลตามที่ arnon สั่ง (ผ่าน ajfon)

> arnon: *"ถ้าไม่ทดสอบใช้งานจริงก็ไม่มีวันเจอปัญหา ถ้าไม่เจอปัญหาก็ไม่รู้ว่าสิ่งที่สร้างขึ้นมา
> อยู่ในสภาพไหนจริง ๆ"* · `up` พิสูจน์แล้วโดย ajfon · นี่คือส่วนที่เหลือ

**ทีม**: `realtest-verbs-v1` · 2 worker (opencode/GLM-5.2) + lead · charter `ψ/teams/realtest-verbs-v1.yaml`
**enginecheck ก่อน spawn**: PASS ทั้ง 3 · `unverified:` ว่าง (ไม่มี unpinned alias)
**เก็บครบแล้ว**: `teamclosed` = CLOSED · `agents/` ว่าง · worktree 0 · **branch เก็บไว้ commit ครบ**

---

## ✅ ผ่านจริง — `dispatch` และ `lead`

worker ทั้งสองรับงาน ทำ commit และรายงานกลับเอง · **ground truth ตรงกับที่รายงาน**

| worker | อ้างว่า | ตรวจจริง |
|---|---|---|
| worker-a | `94df4ae` "proof: worker-a" | ✅ `PROOF.md` 15B · commit ตรง sha |
| worker-b | `212af3a` "proof: worker-b" | ✅ `PROOF.md` 15B · commit ตรง sha |

ไม่มีการแตะ worktree ข้ามกัน · รายงานกลับถึง lead ด้วยเนื้อความจริง (**ชั้น 4**)

---

## 🔴 `down` — ข้อที่แพงที่สุด และเป็นข้อที่ arnon ทำนายไว้

### D1 · `up` สร้าง `<name>-oracle` · `down` มองหา `<name>` — **round trip พังในเครื่องมือเดียวกัน**

```
charter: role/name = worker-a
up สร้างจริง       : window "worker-a-oracle"
down มองหา         : "worker-a"
⇒ maw team down realtest-verbs-v1
  rc=1  team down refuse missing target before teardown: realtest-verbs-v1:worker-a
```
⇒ **ทีมที่สร้างด้วย `maw team up` ปิดด้วย `maw team down` ไม่ได้** จนกว่าจะ `tmux rename-window` เอง
⇒ นี่คือ golden rule เดิม *"charter role names ≠ tmux window names"* แต่คราวนี้เป็น
**ข้อบกพร่องภายใน maw เอง ไม่ใช่กับดักของผู้ใช้**

### D2 · 🔴 หลัง rename แล้ว `down` คืน **rc=0 พร้อมตารางสวย — แต่ไม่ได้ปิดอะไรเลย**

```
rc=0
role      state    action
worker-a  dead     skip dead
worker-b  dead     skip dead
lead      missing  keep (lead)
```
**สภาพจริงทันทีหลังจากนั้น** `[verified: tmux list-windows -F '#{pane_current_command} #{pane_dead}']`
```
worker-a  cmd=opencode  dead=0     ← ยังรันอยู่
worker-b  cmd=opencode  dead=0     ← ยังรันอยู่
session realtest-verbs-v1: มีอยู่ 2 windows · worktree 2 · branch 2
```
⇒ **`down` อ่าน pane ที่ยังรัน `opencode` อยู่ว่า `dead` แล้ว `skip dead` ⇒ "สำเร็จ" ของมัน
สร้างอยู่บนการอ่านสถานะที่ผิด** ⇒ **rc=0 + ตารางสะอาด = ไม่ได้ทำอะไรเลย**
⇒ นี่คือรูปที่ arnon ชี้พอดี และเป็นเหตุผลเชิงโครงสร้างว่าทำไมวิธีของ lucifer
(**ปิดทีละ window ⇒ session จบเอง**) ไม่ใช่แค่ "ดีกว่า" แต่ **จำเป็น**
`[verified: ปิดทีละ window → session หายเอง ไม่ต้อง kill-session]`

### D3 · `teamclosed` จับได้สิ่งที่ rc ของเครื่องมือเองจับไม่ได้

หลัง `down` rc=0 → `verify-check.sh teamclosed` รายงาน **`LIVE ... 2 windows`** ตรงความจริง
⇒ กฎใน CLAUDE.md ที่ห้ามเชื่อ `maw team list` / `status` **ต้องขยายให้ครอบ `maw team down` ด้วย**

---

## 🟡 `up` — สองข้อที่เจอระหว่างทาง (ajfon พิสูจน์ `up` มาแล้ว นี่คือส่วนเพิ่ม)

### U1 · `lifecycle: worktree: true` **ไม่ได้สร้าง worktree**
```
maw team up realtest-verbs-v1
→ team spawn: canonicalize .../agents/realtest-worker-a failed: No such file or directory
```
⇒ `up` **canonicalize ก่อนสร้าง** ⇒ ต้อง `git worktree add` เองก่อน ไม่งั้นล้มทันที

### U2 · `up` คืน rc=1 **ทั้งที่สร้าง session + worker ขึ้นครบแล้ว**
ข้อความทั้งหมดที่ได้คือ `team up: maw wake exited with exit status: 1`
— **ไม่บอกว่าสมาชิกไหน ไม่บอกสาเหตุ** · ที่ล้มจริงคือ `lead` · worker 2 ตัวขึ้นและทำงานได้ปกติ
⇒ ผู้ปฏิบัติที่อ่าน rc=1 จะเข้าใจว่าทีมไม่ขึ้น **แล้วทิ้ง session ที่มีชีวิตไว้เป็น orphan**

### U3 · `maw wake <role>` แนะนำเป้าหมายที่ **ไม่มีอยู่จริง**
```
maw wake worker-a  →  rc=1
  wake: 'worker-a' was not found exactly. Found nearby:
    1. session ws-parity-rs (Fuzzy)
```
`[verified: tmux has-session -t "=ws-parity-rs" → can't find session]`
⇒ ของจริงที่ควรแนะนำคือ `worker-a-oracle` (มีอยู่ตรงนั้น) · ที่มันแนะนำคือ **session ผี**
⇒ ต่อยอด golden rule เรื่อง fuzzy-match: **ปัญหาไม่ใช่แค่ "จับผิดตัว" แต่ "จับตัวที่ไม่มีอยู่"**

---

## 🪞 ความผิดของผมเองระหว่างทดสอบ — สองข้อ ทั้งคู่มีเขียนไว้ใน CLAUDE.md แล้ว

1. **อ่าน `$?` หลัง pipe** → รายงานกับตัวเองว่า `up` คืน rc=0 ทั้งที่เป็น rc ของ `tail`
   ของจริง rc=1 · จับได้ในขั้นถัดไป **แต่ถ้าไม่รันซ้ำก็จะกลายเป็น finding เท็จ**
2. **เขียน `pgrep -f` เอง** → มัน **แมตช์ command line ของตัวเอง** แล้วรายงานว่ายังมี process ค้าง
   ⇒ ทั้งสองข้อคือ scar ที่เขียนไว้แล้วและ **ยังพลาดซ้ำภายใน 20 นาที** — การเขียนกฎไม่ใช่การแก้

## 📌 ข้อข้าง — charter production ของเราเองก็ผิด
`ψ/teams/codex-fanout-team.yaml` ระบุ `session: 117-codex-fanout` · ของจริง session ผมคือ
**`114-codex-fanout`** และ **`117` เป็นของ prism** `[verified: tmux display-message -p '#S' · maw ls -v]`

---

## สถานะที่ซื่อสัตย์ของ verb ทั้งชุด

| verb | สถานะ | โดย |
|---|---|---|
| `up` | ✅ พิสูจน์ด้วยการใช้จริง (+ U1/U2/U3 เพิ่ม) | ajfon · codex-fanout |
| `dispatch` | ✅ **พิสูจน์ด้วยการใช้จริงแล้ว** ground truth ตรง | codex-fanout 2026-08-07 |
| `lead` (peek/report loop) | ✅ **พิสูจน์ด้วยการใช้จริงแล้ว** | codex-fanout 2026-08-07 |
| `down` | 🔴 **ใช้ไม่ได้** — D1 ปฏิเสธ · D2 rc=0 แต่ไม่ทำอะไร | codex-fanout 2026-08-07 |
| `status` / `list` | 🔴 ห้ามเชื่อ (กฎเดิม) | ก่อนหน้า |

⇒ **ยังปิดงานนี้ว่า "เสร็จ" ไม่ได้** — `down` ต้องแก้ก่อน และหลังแก้ต้องมีคนใช้จริงอีกรอบ
เพราะแพทเทิร์นทั้งวันคือ **ทุกรอบที่แก้ มักมีบั๊กรอบถัดไปซ่อนอยู่ในตัวแก้เอง**

*— codex-fanout 🛰️ (AI-generated; Rule 6)*
