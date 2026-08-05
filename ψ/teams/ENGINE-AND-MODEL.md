# กำหนด harness + model ให้สมาชิกทีม `maw team` — ที่มันทำงานจริง

> **สรุปหนึ่งบรรทัด**: `engine:` ใน charter เป็น **คำขอ ไม่ใช่การตั้งค่า** และ `model:` **ไม่มีผลเลย**
> — ทั้งสองอย่างแสดงออกได้ที่เดียวคือ **สตริงคำสั่งของ engine alias** ใน `commands`
>
> `[verified 2026-08-06 · maw-rs 325db65 = binary ที่รันอยู่]`
> `valid-if:` `maw --version` ยังขึ้นต้นด้วย `325db65` และ
> `bash ψ/teams/scripts/verify-check.sh selftest` ยังตอบ `SELFTEST OK`

---

## อาการที่ fleet เจอ

สมาชิกใน fleet กำหนด harness/model ที่ต้องการไม่ได้ — บาง agent ได้ engine ที่ขอ บางตัวไม่ได้
**และไม่มีสัญญาณบอกว่าตัวไหนเป็นตัวไหน** ทุกอย่าง exit 0 · preflight เขียว · dry-run แสดงค่าที่ถูก

**นี่ไม่ใช่ความไม่แน่นอน** มันคือฟังก์ชันของ *ชื่อ window* กับ *สิ่งที่ลงทะเบียนไว้ใน `commands`*
ซึ่งต่างกันไปในแต่ละเครื่อง/แต่ละ oracle ⇒ คนละคนรัน charter เดียวกันได้คนละ engine

## repro ครบวง `[verified 2026-08-06]`

charter เขียนว่า `engine: codex-xhigh` · `model: gpt-5.6-sol` (ตอนที่ยังไม่มี alias):

```
$ maw team up enginemodel-probe --dry-run
role          identity      engine       state  action
codex-fanout  codex-fanout  codex-xhigh  live   skip live      ← รายงานว่าจะได้ codex-xhigh

$ maw wake codex-fanout --no-attach --dry-run -e codex-xhigh
  command: MAW_SESSION_WINDOW=codex-fanout claude --model claude-opus-5 --continue --dangerously-skip-permissions
```

⇒ **`team up --dry-run` พิมพ์ engine ที่มันจะ *ขอ* ไม่ใช่ engine ที่จะ *ได้*** — มันสะท้อน charter
กลับมาเฉย ๆ · และ `model: gpt-5.6-sol` **ไม่โผล่ที่ไหนเลย แม้แต่ในรายงาน**

การตรวจที่ยืนยัน claim ที่ตัวมันเองไม่ได้ทดสอบ — คลาสเดียวกับทั้งเล่มของ `VERIFY-THE-CHECK.md`

---

## ทำไม — 3 ข้อเท็จจริงจาก source

### 1. `model:` ถูก parse ถูก validate แล้วถูกทิ้ง

| จุด | เกิดอะไร | citation (325db65) |
|---|---|---|
| schema | `TeamCharterMember122` มี field `model` ครบ ⇒ parse ผ่าน ไม่ error | `team_core.rs:86-97` |
| `team up` | เอา `member.model` ไป **validate ว่าเป็น token ปลอดภัย** แล้วไม่ใช้ต่อ | `team_up_apply.rs:186-187` |
| argv ที่ส่งให้ wake | `["wake", identity, "--no-attach", "--session", s, "-e", engine]` — **ไม่มี `--model`** | `team_up_apply.rs:149` + unit test ยืนยัน argv นี้เป๊ะที่ `:251` |
| `maw wake` | **ไม่มีแฟลก `--model` เลย** ทั้ง `-e/--engine` เท่านั้น | `wake_argv.rs:38-53, 70-84` |

`maw team spawn --model X` มีอยู่จริง แต่เขียนลง `~/.claude/teams/<t>/config.json` เป็น metadata
เท่านั้น (`team_spawn.rs:97,188-191`) — ไม่ได้เข้าไปในคำสั่งที่ launch

### 2. `engines:` block ใน charter เป็น field ที่ตายแล้ว

`charter.engines` ถูกเขียนโดย parser (`team_core.rs:456,569`) และ **ไม่มีโค้ดอ่านมันไปใช้ที่ไหนเลย**
— `git grep '\.engines\b' crates/maw-cli` เจอแค่บรรทัดที่ประกาศกับใน unit test

⇒ ใครที่นิยาม engine command ไว้ใน charter ใต้ `engines:` กำลังเขียนไฟล์ที่ไม่มีใครอ่าน
(นี่คือเหตุที่ loom เจอ `codex-medium` / `codex-xhigh` / `claude-opus-headless` พังเมื่อ 2026-08-01)

### 3. ลำดับการ resolve — จุดที่ engine ของ charter หายไปเงียบ ๆ

`wake_resolve_command_from_config` (`wake_engine_command.rs:67`) ไล่ตามลำดับ **หยุดที่ตัวแรกที่เจอ**:

| # | มองหา | หมายเหตุ |
|---|---|---|
| 1 | `commands.<engine>` | **ที่เดียวที่ `engine:` ของ charter มีผล** |
| 2 | `commands.<ชื่อ-window>` | ชื่อ window **ชนะ** engine ที่ขอ ถ้าข้อ 1 ไม่เจอ |
| 3 | `commands.<oracle>-oracle` | derive จากชื่อ window |
| 4 | glob บนชื่อ window | `banker*` `verifier*` `researcher*` `scope-reviewer*` … |
| 5 | `commands.<engine จาก defaults>` หรือ **ชื่อ engine ดิบ ๆ** | |
| 6 | `commands.default` | ของเครื่องนี้ = `claude --model claude-opus-5 --continue` |

**ข้อ 1 ไม่เจอ = ไม่มี error ไม่มี warning exit 0** แล้วไหลลงข้อ 2-6

หลักฐาน (`--dry-run` ทั้งหมด ไม่ได้ spawn อะไร):

```
maw wake coder-1 --dry-run -e codex-xhigh  → claude --model claude-opus-5 --continue   (ตกถึงข้อ 6)
maw wake hermes  --dry-run -e codex-xhigh  → hermes --yolo                             (ข้อ 2 ชนะ)
maw wake hermes  --dry-run -e codex        → codex --ask-for-approval never …          (ข้อ 1 ชนะ)
```

> 🔴 **`-e claude` ก็ไม่ได้ลงทะเบียน** — บนเครื่องนี้ไม่มีคีย์ `commands.claude`
> มันได้ claude เพราะ `default` บังเอิญเป็น claude เท่านั้น · `wake hermes -e claude` → `hermes --yolo`
> ⇒ **"มันเคยได้ engine ถูก" ไม่ใช่หลักฐานว่ามัน pin แล้ว**

---

## วิธีแก้ที่ใช้จริง — repo-local config layer

`maw config set` ตั้งได้แค่ `node|port` (`config.rs:36-52` — "native set currently supports node|port")
⇒ ลงทะเบียน alias ด้วย CLI ไม่ได้ ต้องเขียนไฟล์

**อย่าแก้ global** (`~/.config/maw/maw.config.50.json`) — มันเปลี่ยนพฤติกรรมของ oracle ทุกตัวบนเครื่อง

maw เดินขึ้นจาก cwd เก็บทุก `<ancestor>/.maw/maw.config.<N>.json` มา deep-merge เรียงตาม N
(`crates/maw-xdg/src/config.rs :: discover_config_layers` + `parse_config_layer_name`)
⇒ **`<repo>/.maw/maw.config.60.json` ชนะ global (N=50) และเดินทางไปกับ repo**

ชื่อไฟล์ **ต้อง** ตรงรูป `maw.config.<ตัวเลข>.json` — ชื่ออื่นถูกข้ามเงียบ ๆ รวมถึง `maw.config.json` เปล่า ๆ

> 🔴 **ข้อจำกัดที่สำคัญที่สุดของวิธีนี้ — layer ไม่ได้เดินทางไปทุกที่**
> maw resolve `commands` แบบ **dir-aware เทียบ path ของสมาชิกคนนั้น** ไม่ใช่ cwd ของคนสั่ง
> (`wake_engine_command.rs:17,135-137` · #600) ⇒ layer จะถูกเห็นก็ต่อเมื่อไฟล์อยู่ที่
> **บรรพบุรุษของ worktree/cwd ของสมาชิก**
>
> ```
> maw wake … -e codex-sol                  → codex --model gpt-5.6-sol       ← worktree ใน repo
> maw wake … -e codex-sol --repo-path /tmp → claude --model claude-opus-5    ← นอก repo หายเลย
> ```
> `[verified 2026-08-06]`
>
> ⇒ **worktree ใน repo** (`agents/<role>`) ใช้ได้ · **worktree นอก repo**
> (`~/.maw-teams/<team>/<role>` · `${CELL_STATE_ROOT}/<role>` แบบที่ evidence-cell ใช้)
> **ใช้ไม่ได้** ต้องวาง layer ที่บรรพบุรุษของ path นั้นแทน (หรือยอมแก้ global)
>
> `enginecheck` ตรวจข้อนี้ให้แล้ว — มันอ่าน `worktree:`/`cwd:` ของสมาชิกแต่ละคนแล้ว
> ประเมิน config **จาก path ของคนนั้น** และพิมพ์ `สโคป path` ออกมาทุกแถว
> (เวอร์ชันแรกของมันถามจาก cwd ของ lead เสมอ ⇒ **false-PASS** ให้สมาชิกที่อยู่นอก repo —
> ที่ปรึกษาจับได้ ไม่ใช่ selftest)

ไฟล์ของ repo นี้: [`.maw/maw.config.60.json`](../../.maw/maw.config.60.json)

```json
{ "commands": {
    "codex-sol":     "BASH_ENV=$HOME/.rtk-init.sh codex --model gpt-5.6-sol --ask-for-approval never --sandbox danger-full-access",
    "claude-haiku":  "claude --model claude-haiku-4-5-20251001 --dangerously-skip-permissions",
    "opencode-glm":  "opencode --model zai/glm-5.2 --auto"
} }
```

แล้ว charter อ้าง **ชื่อ alias** ตรง ๆ:

```yaml
members:
  - role: coder-1
    engine: codex-sol            # ← harness + model อยู่ในนี้ทั้งคู่
    model: gpt-5.6-sol           # ← เขียนไว้เป็นเอกสาร/ให้ enginecheck ตรวจ maw ไม่อ่าน
```

`model:` ยังควรเขียนไว้ **เพื่อให้ `enginecheck` ตรวจได้ว่า alias กับเจตนาตรงกัน** — แต่ต้องรู้ว่า
maw ไม่ได้อ่านมัน ถ้ามันตรงกัน นั่นเพราะมีคนทำให้ตรง ไม่ใช่เพราะ maw บังคับ

## ตรวจก่อน spawn — บังคับ

```bash
bash ψ/teams/scripts/verify-check.sh enginecheck <charter|team-name>
```

ตรวจให้ทีละสมาชิก: engine ลงทะเบียนหรือยัง · คำสั่งที่จะรันจริงคืออะไร · model ที่ charter ขอ
อยู่ในคำสั่งนั้นไหม — และ **ตกดัง ๆ** เมื่อไม่ตรง แทนที่จะปล่อยผ่านแบบ `team up --dry-run`

```
  coder-1
    charter ขอ : engine=codex-sol model=gpt-5.6-sol
    จะรันจริง  : BASH_ENV=$HOME/.rtk-init.sh codex --model gpt-5.6-sol --ask-for-approval never …
    ✅ PASS    engine ถูก · model "gpt-5.6-sol" อยู่ในคำสั่งจริง
```

### ขอบเขตที่ `enginecheck` ตอบไม่ได้ (มันพิมพ์เองทุกครั้ง ไม่เงียบ)

- **ตอบไม่ได้ว่าบัญชีเสิร์ฟ model นั้นได้จริงไหม** — ชื่อ model ผิดจะพัง *ข้างใน* engine หลัง pane ขึ้นแล้ว
  ⇒ boot worker ตัวเดียวก่อนเสมอ ก่อนปล่อยทั้ง fleet (SPAWN GATE เดิมยังใช้)
- **ตอบไม่ได้ว่า worker ได้รับ prompt ไหม** — `team up` ไม่ส่ง prompt เลย ดู
  `ψ/memory/learnings/2026-08-04_charter-field-parsed-but-never-read.md`
- charter/vault อ่านเทียบ CWD ⇒ ถามถึงทีมของ oracle อื่นไม่ได้

---

## ตารางสรุปสำหรับคนที่มาอ่านทีหลัง

| อยากทำ | เขียนที่ไหน | ได้ผลไหม |
|---|---|---|
| กำหนด harness | `engine:` ใน charter **+ ลงทะเบียน alias** | ✅ ต้องมีทั้งคู่ |
| กำหนด harness เฉย ๆ ไม่ลงทะเบียน | `engine:` อย่างเดียว | ❌ ทิ้งเงียบ ๆ ตกไปตามชื่อ window |
| กำหนด model | ในสตริงคำสั่งของ alias | ✅ ที่เดียวที่ได้ผล |
| กำหนด model | `model:` ใน charter | ❌ parse แล้วทิ้ง |
| กำหนด model | `maw team spawn --model X` | ❌ เขียนลง config.json เป็น metadata ไม่เข้าคำสั่ง |
| นิยาม engine command | `engines:` ใน charter | ❌ field ตาย ไม่มีใครอ่าน |
| ลงทะเบียน alias | `maw config set commands.X` | ❌ รองรับแค่ `node\|port` |
| ลงทะเบียน alias | `<repo>/.maw/maw.config.60.json` | ✅ **วิธีที่ใช้** |

---

## ผลสแกน charter ทั้งหมดใน repo นี้ `[verified 2026-08-06]`

รันครั้งแรกที่มีเครื่องมือ — **4 ใน 5 charter ขอ engine ที่ไม่เคยลงทะเบียน**

| charter | engine ที่ขอ | สถานะ |
|---|---|---|
| `codex-fanout-team.yaml` | `sage-opencode-oracle` | ✅ แก้แล้ว — ลงทะเบียนตามที่ **YAML comment ของมันเองบอกไว้ตั้งแต่ 2026-07-25** |
| `drift-opencode.yaml` | (ลงทะเบียนแล้ว) | ✅ |
| `drift-fanout-a.yaml` | `sage-codex-oracle` | ❌ ยังไม่แก้ |
| `drift-fanout-b.yaml` | `hound-codex-oracle` | ❌ ยังไม่แก้ |
| `drift-thclaws.yaml` | `hound-thclaws-oracle` | ❌ ยังไม่แก้ |

สามตัวท้ายขอ **ชื่อ oracle** มาเป็นชื่อ engine (`<name>-oracle`) — ซึ่งเป็นรูปที่ resolution
ข้อ 3 ใช้กับ *ชื่อ window* ไม่ใช่กับ `engine:` ⇒ เดาได้ว่าคนเขียนคิดว่า "ใช้ engine ของ oracle ตัวนั้น"

**จงใจไม่ลงทะเบียนให้**: ผมไม่รู้ว่า oracle เหล่านั้นบูตด้วยคำสั่งอะไรจริง ๆ การเดาคำสั่ง
launch แล้วเขียนลงไฟล์ = operational claim ที่ไม่มีหลักฐาน ซึ่งเป็นความผิดคลาสเดียวกับที่
เอกสารนี้ทั้งฉบับกำลังแก้ ⇒ **ต้องให้เจ้าของ charter ตัดสินว่าสามตัวนั้นควรชี้ไปที่อะไร**
(charter พวกนี้เป็นของรอบ drift test — อาจเลิกใช้แล้ว ถ้าเลิกใช้ให้ย้ายไป `archive/` ไม่ใช่ลบ)

---

## ยังไม่ได้แก้ที่ต้นน้ำ

พฤติกรรมที่ควรเปิดกับ maw-rs (ทำนองเดียวกับ #658 ที่เราเคยยิงไป):

1. `team up` ควร **เตือน** เมื่อ `engine:` ของ charter ไม่มีใน `commands` แทนที่จะไหลลงเงียบ ๆ
2. `team up --dry-run` ควรแสดง **คำสั่งที่จะรันจริง** ไม่ใช่ชื่อ engine ที่สะท้อนจาก charter
3. `member.model` ควรถูกส่งต่อ หรือไม่ก็ **ปฏิเสธตั้งแต่ preflight** ว่าเป็น field ที่ไม่รองรับ —
   สถานะปัจจุบัน (validate แล้วทิ้ง) เป็นสถานะที่หลอกคนมากที่สุด
4. `charter.engines` ควรถูกใช้ หรือถูกลบ — field ที่ parse ผ่านแต่ไม่มีใครอ่านคือกับดัก

เชื่อมกับ [[verify-the-check]] · [[teaching-ledger]] · `maw-team-engine-mechanics-research.md` §10-11
