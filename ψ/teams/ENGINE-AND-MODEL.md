# กำหนด harness + model ให้สมาชิกทีม `maw team` — ที่มันทำงานจริง

> **สรุปหนึ่งบรรทัด**: `engine:` ใน charter เป็น **คำขอ ไม่ใช่การตั้งค่า** และ `model:` **ไม่มีผลเลย**
> — ทั้งสองอย่างแสดงออกได้ที่เดียวคือ **สตริงคำสั่งของ engine alias** ใน `commands`
>
> 🔬 **วิธีอ่าน source ให้ตรงกับ binary ที่รัน** (atlas ชี้ 2026-08-06 · ผมยืนยันเองแล้ว):
> checkout ของ `maw-rs` บนเครื่องนี้อยู่บน branch `agents/fix-wake-oracle-alias-hijack` @ `cc0fc61`
> และ **`git merge-base --is-ancestor 325db65 HEAD` = NO** ⇒ **อ่าน working tree = อ่านโค้ดผิดตัว**
>
> > 🩹 **แก้ความไม่แม่นของผมเอง (tars ตรวจ 2026-08-06 · ผมทำซ้ำแล้ว)** — ทิศที่ถูกคือ
> > **`cc0fc61` เป็น *บรรพบุรุษของ* `325db65`** ⇒ working tree **ตามหลังอยู่ ไม่ใช่แตกสาย**
> > และ `git diff --stat cc0fc61 325db65` = **ไฟล์เดียว** (`serve_core/process_engine.rs`)
> > · md5 ของทั้ง 4 ไฟล์ที่เอกสารนี้ cite (`team_up_apply` `wake_argv` `wake_engine_command`
> > `team_core`) **IDENTICAL ระหว่างสองคอมมิต**
> > ⇒ **citation ในเอกสารนี้ไม่เคยเสี่ยงจริง** แต่ *เรารู้ข้อนั้นได้ก็ต่อเมื่อตรวจ* — วินัยยังยืน
> > ⇒ บทเรียนที่แม่นขึ้น: **"working tree ต่างจาก binary" เป็นเหตุให้ต้องตรวจ ไม่ใช่ข้อสรุปว่าผิด**
> > การประกาศว่า "อ่านผิดตัว" โดยไม่ `git diff` ก็เป็น claim ที่ไม่ได้ verify เหมือนกัน
> ⇒ ใช้ `git show 325db65:<path>` / `git grep <pattern> 325db65 -- <path>` เสมอ (เอกสารนี้ใช้แบบนั้นทั้งฉบับ)
> ⇒ 🔑 **`maw --version` ที่ตรงกัน พิสูจน์ว่า *binary ไหนรัน* ไม่ได้พิสูจน์ว่า *source ไหนที่เรากำลังอ่าน***
> — สองอย่างนี้เป็นคนละคำถาม และ `valid-if:` ที่เช็คแค่ version จับข้อหลังไม่ได้
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

> ### 🔴 `maw.config.json` (ไม่มีเลข) เป็น **ไฟล์ตาย** — loom เจอ 2026-08-06 · ผมยืนยันแล้ว
>
> `parse_config_layer_name` ต้องได้ **ตัวเลขล้วน** หลัง `maw.config.` ⇒ `"maw.config.json"`
> → `rest="json"` → `strip_suffix(".json")` = `None` ⇒ **ไม่ใช่ layer**
> มันถูกอ่านเป็น *legacy fallback* เฉพาะเมื่อ **ไม่มีไฟล์ที่มีตัวเลขเลย** (`if sources.is_empty()`)
> เครื่องนี้มี `maw.config.50.json` ⇒ **`~/.config/maw/maw.config.json` ตายสนิท**
>
> ```
> ไฟล์สองอันในโฟลเดอร์เดียวกัน ต่างแค่ชื่อ:
>   maw.config.json     → maw config explain … = FINAL null      ← ไม่ถูกอ่าน
>   maw.config.60.json  → maw config explain … = FINAL "echo …"  ← ถูกอ่าน
> และ `maw config sources` ไม่ลิสต์ตัวที่ไม่มีเลขเลย
> ```
>
> ❌ **แก้ claim ของผมเอง**: ที่เอกสารนี้ (สืบทอดจาก research doc §10) เขียนว่า
> *"Option A: แก้ global `~/.config/maw/maw.config.json` — ใช้ได้แต่กระทบ oracle ทุกตัว"*
> **ผิด — มันไม่ทำงานเลย register อะไรไม่ได้สักอย่าง exit 0 ไม่มี warning**
> ⇒ ⚠️ **ใครใน fleet ที่ "แก้ engine แล้ว" ด้วยการ edit ไฟล์นี้ ยังไม่ได้แก้อะไรเลยและไม่รู้ตัว**
> เช็ค: `ls ~/.config/maw/maw.config.*.json` — ถ้ามีไฟล์เลข ไฟล์ไม่มีเลขตายแล้ว
> ⇒ นี่คือเหตุผลจริงที่ `seed_charter_engines` ของ loom พัง (เขาแก้ให้เขียน JSON ตรงเข้าไฟล์นั้น
> ตั้งแต่ 08-01 ⇒ **เขียนลงไฟล์ที่ไม่มีใครอ่านมา 5 วัน** และ python check ของเขาเองก็อ่านไฟล์ตายนั้น
> จึงรายงานผ่าน — `enginecheck` เป็นตัวที่จับได้)
>
> 🧪 **วิธีทดสอบข้อนี้ — อย่าเขียนลง `~/.config/maw/` จริง**
> สร้าง temp dir แล้ววางไฟล์ทั้งสองชื่อไว้ด้วยกัน แล้ว `cd` เข้าไปถาม `maw config sources`
> — ได้คำตอบเดียวกันและ**ดีกว่า** (ตัวแปรเดียวคือชื่อไฟล์) โดยไม่แตะของกลางของทั้ง fleet
> *(ผมทดสอบครั้งแรกด้วยการเขียนลงไฟล์จริงแล้วกู้คืน — user ท้วง และถูก: สำรองไว้ไม่ได้แปลว่า
> ควรทำ ของกลางที่ oracle ทุกตัวใช้ร่วมกัน ไม่ใช่ที่ทดลอง)*

### 🔴 สองไบนารี resolve จาก **คนละไดเรกทอรี** ⇒ ต้องวาง **2 layer** (loom 2026-08-06)

| คำสั่ง | resolve เทียบกับ | layer ที่ใช้ได้ |
|---|---|---|
| **maw-js** `team spawn` | **cwd ของ lead** (repo) | `<repo>/.maw/maw.config.60.json` |
| **maw-rs** `wake` / `team up` | **path ของ member** | `<บรรพบุรุษ worktree>/.maw/maw.config.60.json` |

loom วางแต่ layer ที่ `~/.maw-teams/<team>/` แล้ว **`maw team spawn` ยังปฏิเสธ**:
`engine 'claude-opus-headless' not resolvable — known: [...]`
⇒ ต้องวางทั้งสองที่ · **ข้อดีที่ได้ฟรี: layer ใน repo อยู่ใน git ⇒ แก้ปัญหา durability ที่เตือนไว้ครึ่งหนึ่ง**

### 🔴 failure mode ของสองไบนารี **ตรงข้ามกัน** ⇒ เพิ่มเข้าชั้นหลักฐาน

- **maw-js `team spawn` = fail-closed** — ปฏิเสธพร้อมลิสต์ engine ที่รู้จัก
- **maw-rs `wake` = fall through เงียบ** ไป `commands.default`

⇒ 🔑 **"spawn ผ่านทางนี้ได้" ไม่ใช่หลักฐานว่าทางโน้นถูก** — alias ที่หายเหมือนกันเป๊ะ ให้ผลคนละขั้ว

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
> ### ✅ สูตรสำหรับ worktree นอก repo `[verified 2026-08-06 · มี negative control]`
>
> วาง layer ที่ **บรรพบุรุษร่วม** ของ worktree เหล่านั้น — ใช้ได้จริง:
>
> ```
> /tmp/probe-root/.maw/maw.config.60.json  →  member path /tmp/probe-root/sub
>   command: … echo OUT-OF-REPO-LAYER-RESOLVED          ← เห็น
> เทียบกับ member path /tmp (ไม่ได้อยู่ใต้ probe-root)
>   command: … claude --model claude-opus-5 --continue  ← ไม่เห็น (negative control)
> ```
>
> | worktree อยู่ที่ | วาง layer ที่ | ครอบ |
> |---|---|---|
> | `<repo>/agents/<role>` | `<repo>/.maw/maw.config.60.json` | ทีมของ repo นั้น · **อยู่ใน git** |
> | `~/.maw-teams/<team>/<role>` | **`~/.maw-teams/<team>/.maw/maw.config.60.json`** | **ทีมนั้นทีมเดียว** |
> | `${CELL_STATE_ROOT}/<role>` | `${CELL_STATE_ROOT}/.maw/maw.config.60.json` | evidence-cell (prism) |
>
> > ❌ **CORRECTED 2026-08-06 (atlas DISSENT — ถูก)** — แถวกลางเดิมผมเขียนว่า `~/.maw-teams/.maw/`
> > **ผิด** เพราะมันเป็นบรรพบุรุษของ **ทุกทีม** ใต้นั้น (`ls ~/.maw-teams/` = **10 ทีม** —
> > evidence-cell · lucifer-dev-v1 · lucifer-fullstack-v1 · maw-engine-fix-v1 ·
> > teaching-media-cell · venture-cell · bug-fix-v1 · kanboard-frontend-p1/p2 · _archive)
> > ⇒ **ผูก engine ให้ทีมที่ไม่เคยขอ โดยเงียบ ๆ** — **defect class เดียวกับที่เอกสารนี้ทั้งฉบับกำลังแก้**
> > ต่างแค่ทิศ: เดิมคือ "ขอแล้วไม่ได้" อันนี้คือ "ไม่ได้ขอแล้วได้"
> > ⇒ **วางให้แคบที่สุดที่ครอบ worktree ของทีมนั้นพอดี เสมอ**
>
> > 🔁 **อีกด้านของแกนเดียวกัน — แคบเกินจนไม่ครอบ** `[verified 2026-08-07 ~21:2x +07 · prism ·
> > maw-rs c1e8797 · เจอกับตัวเองระหว่างสร้าง charter ใหม่ · เขาอนุญาตให้เขียน]`
> > prism วาง layer เป็น **sibling directory ของ cwd ของสมาชิก ไม่ใช่ ancestor**
> > ⇒ **resolve ตกเป็น `default` เงียบ ๆ** ไม่มี error ไม่มี warning — เหมือน engine ที่ไม่ได้ลงทะเบียนเป๊ะ
> > ย้าย layer เข้า state root ที่เป็น ancestor จริงแล้วหาย
> >
> > ⇒ **สองอาการนี้ไม่ใช่คนละเรื่อง มันคือปลายสองข้างของแกนเดียว**:
> >
> > | | ผลลัพธ์ | ใครโดน | เสียงเตือน |
> > |---|---|---|---|
> > | **แคบไป** (sibling ไม่ใช่ ancestor) | ทีมที่**ขอ** engine **ไม่ได้** | ทีมตัวเอง | **ไม่มี** |
> > | **กว้างไป** (`~/.maw-teams/.maw/`) | ทีมที่**ไม่ได้ขอ** กลับ**ได้** | 10 ทีมข้างเคียง | **ไม่มี** |
> >
> > ⇒ **ทั้งสองทิศเงียบเท่ากัน** และทั้งคู่ลงเอยที่ `default` หรือของคนอื่นโดยที่ exit code = 0
> > ⇒ นี่คือเหตุผลที่ **`enginecheck` ต้องรันก่อน spawn ทุกครั้ง ไม่ใช่ตอนสงสัย** — สายตาแยก
> > "ancestor" กับ "sibling" ไม่ออกจาก path ที่พิมพ์แล้วดูถูกต้อง
> > ⇒ **prism พิสูจน์ด้วยว่า `enginecheck` ตกได้จริง** — negative control ด้วย engine ที่ไม่มีทะเบียน
> > (`totally-bogus-unregistered-engine`) → `FAIL rc=1`, `resolved=claude` (default)
> > ⇒ มันไม่ใช่ echo · คำถามประจำ *"การตรวจนี้ตกได้ด้วยเหตุอะไร"* **มีคำตอบที่รันได้แล้ว**
> > **tars เดโมความเสียหายซ้ำได้ และผมทำซ้ำอีกรอบ** `[verified 2026-08-06]`:
> > `root/.maw/` มี `shared-alias` · `teamB/` ไม่มี layer ของตัวเอง
> > ⇒ `wake … -e shared-alias --repo-path root/teamB/role1` → **ได้ของ root ไปเงียบ ๆ**
>
> ### 🆕 N เท่ากันสองชั้น — **ชั้นที่ลึกกว่าชนะ** (tars ค้นเจอ · ผมยืนยันเอง `[verified 2026-08-06]`)
>
> คำถามที่สูตรเดิมตอบไม่ได้: ถ้า root กับ per-team ใช้ `N=60` ทั้งคู่ ใครชนะ?
> ```
> root/.maw/maw.config.60.json        → shared-alias = ROOT-LEVEL-LAYER
> root/teamA/.maw/maw.config.60.json  → shared-alias = TEAM-A-LAYER
> wake … --repo-path root/teamA/role1 → echo TEAM-A-LAYER      ← ชั้นที่ใกล้กว่าชนะ
> ```
> ⇒ **ไม่ต้องไล่เลข N ให้ต่างกันเพื่อความถูกต้อง** (จะบัมพ์เป็น 70 ก็ได้ แต่ไม่จำเป็น)
>
> ⚖️ **ข้อสังเกตเชิงออกแบบจาก tars (2026-08-06) — รับไว้ ไม่หักล้าง**
> *"ทางแก้นี้ยังสร้าง failure mode รูปเดียวกับบั๊กที่มันแก้"* — ไฟล์ที่ไม่มี git ของใคร track
> หายแล้วระบบยัง exit 0 บูตด้วย engine ผิดตัว (`~/.maw-teams` ไม่ใช่ git repo `[verified: tars]`)
> และตอนนี้ต้องดูแล layer **แยกต่อทีม = 10 จุดที่หายเงียบได้**
> ⇒ 🔑 **ตัวป้องกันจริงคือ `enginecheck` ใน bring-up path ไม่ใช่ตัว layer**
> **ถ้ารับสูตรโดยไม่รับด่าน = แค่ย้ายที่ตั้งของกับดัก** — ประโยคนี้ควรอ่านก่อนทุกข้อในหน้านี้
>
> 🔴 **ข้อแลกเปลี่ยนที่ต้องบอกตรง ๆ**: layer นอก repo **ไม่ได้อยู่ใน git ของใครเลย**
> ⇒ ย้ายเครื่อง / ส่งมอบเจ้าของ / ล้าง `~/.maw-teams` แล้ว **หายเงียบ ๆ** และอาการที่กลับมา
> คือ *"engine ที่ขอถูกทิ้ง"* อีกรอบ — ไม่ใช่ error ⇒ ต้องมีสคริปต์ที่สร้างมันขึ้นใหม่
> เก็บไว้ใน repo และ **รัน `enginecheck` หลังย้ายทุกครั้ง** (นี่คือเหตุผลที่ `enginecheck`
> ประเมินจาก path ของสมาชิก ไม่ใช่จาก cwd — มันจับเคสนี้ได้)
>
> `enginecheck` ตรวจข้อนี้ให้แล้ว — มันอ่าน `worktree:`/`cwd:` ของสมาชิกแต่ละคนแล้ว
> ประเมิน config **จาก path ของคนนั้น** และพิมพ์ `สโคป path` ออกมาทุกแถว
> (เวอร์ชันแรกของมันถามจาก cwd ของ lead เสมอ ⇒ **false-PASS** ให้สมาชิกที่อยู่นอก repo —
> ที่ปรึกษาจับได้ ไม่ใช่ selftest)

### 🧭 ให้ maw บอกเอง อย่าเดา — `maw config sources` / `maw config explain`

> **สองคำสั่งนี้ตอบคำถาม "config อยู่ที่ไหน" ได้ตรง ๆ** และผมเพิ่งเจอตอนท้าย
> — ก่อนหน้านั้นไปแกะ JSON จาก `maw config` เอง ทั้งที่ maw ตอบให้ได้อยู่แล้ว
> `usage: maw config <show|sources|explain <key>|set <key> <value>> [--json]`

```
$ maw config sources                       # ← รันจาก dir ของสมาชิก ไม่ใช่ของ lead
 50 user          /home/user/.config/maw/maw.config.50.json
 60 project       <repo>/.maw/maw.config.60.json          ← เรียงตาม N · ตัวล่างชนะ

$ maw config explain commands.codex-sol    # ← บอกด้วยว่ามาจาก layer ไหน
key: commands.codex-sol
60 project set <repo>/.maw/maw.config.60.json
  "BASH_ENV=$HOME/.rtk-init.sh codex --model gpt-5.6-sol …"
FINAL "BASH_ENV=$HOME/.rtk-init.sh codex --model gpt-5.6-sol …"
```

🔴 **`sources` เปลี่ยนตาม cwd — นี่คือข้อจำกัดสโคปที่พิสูจน์ตัวเองในบรรทัดเดียว**
`[verified 2026-08-06]`

```
cd <repo>                      → 50 user + 60 project     ← เห็น alias ของเรา
cd /tmp                        → 50 user เท่านั้น
cd ~/.maw-teams/evidence-cell  → 50 user เท่านั้น          ← cell ของ prism ไม่มี layer เลย
```

⇒ **วิธีตรวจที่สั้นที่สุดว่า "สมาชิกคนนี้จะเห็น alias ไหม": `cd <worktree ของเขา> && maw config sources`**

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

## `maw team` รองรับเลือก engine/model เองแค่ไหน — ไล่ทีละกริยา `[verified 2026-08-06]`

| กริยา | รับ engine? | รับ model? | ถึง pane จริงไหม |
|---|---|---|---|
| `team up [-e <engine>]` | ✅ **แต่ override ทั้งทีม** | ❌ ไม่มีแฟลก | engine ถึง (ถ้า alias ลงทะเบียน) · model ไม่มีทาง |
| charter `engine:` ต่อ member | ✅ ต่อคนได้ | — | ถึงในฐานะ**ชื่อ** เท่านั้น |
| charter `model:` ต่อ member | — | ✅ parse ผ่าน | ❌ **validate แล้วทิ้ง** |
| charter `engines:` block | ✅ parse ผ่าน | — | ❌ **ไม่มีใครอ่าน** |
| `team spawn --engine --model` | ✅ | ✅ | engine ถึง · **model ลง config.json เป็น metadata เท่านั้น** |
| `team resume [--model]` | ❌ **ไม่มีแฟลก engine เลย** | ✅ parse ผ่าน | ❌ ทั้งคู่ — ดูด้านล่าง |

### 🔴 กับดัก 1 — `team up -e <engine>` **ทับ engine ของสมาชิกทุกคน**

`team_up_apply.rs:147` · `let engine = opts.engine.unwrap_or_else(|| item.engine.clone())`
⇒ แฟลกเดียวลบการออกแบบ engine ต่อคนทั้ง charter **เงียบ ๆ**

```
charter: a=codex-sol · b=claude-haiku
maw team up mixt --dry-run          →  a codex-sol   · b claude-haiku   ✅
maw team up mixt --dry-run -e codex →  a codex       · b codex          ← ทับทั้งคู่
```
⇒ **ทีมที่ออกแบบให้ cross-family (coder=codex / verifier=claude) พังทั้งคุณสมบัติด้วย `-e` ตัวเดียว**
(นี่คือจุดที่ dry-run **บอกความจริง** เพราะมันสะท้อน `opts.engine` — ใช้ตรวจข้อนี้ได้)

### 🔴 กับดัก 2 — `team resume` ทำให้ทุกคนกลายเป็น `claude`

`team_resume.rs:57-61` ส่ง `TeamT5SpawnOptions127 { team, role, model, ..Default::default() }`
⇒ **`engine` = `None`** · แล้ว `team_spawn.rs:89` `let engine = opts.engine.unwrap_or_else(|| "claude")`

⇒ **resume ไม่อ่าน charter ไม่อ่าน engine เดิม — respawn ทุก role เป็น `claude` เสมอ**
และ `--model` ที่มันรับ ก็ไปจบที่ `config.json` metadata เหมือนเดิม **ไม่ถึง pane**

> 📌 ข้อนี้ research doc เดิม (2026-08-01) สรุปไว้จาก **maw-js** — ตอนนี้ **ยืนยันบน maw-rs 325db65**
> ⇒ ถ้าทีมเคยเป็น codex แล้ว `maw team resume` มันจะกลับมาเป็น claude **โดยไม่มี error**
> ⇒ ใช้ `maw team up` (อ่าน charter) แทน `resume` เสมอ เว้นแต่ตั้งใจให้ทุกคนเป็น claude

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
