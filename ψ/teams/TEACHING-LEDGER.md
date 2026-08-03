# Teaching Ledger — ใครได้รับคำสอนอะไรจาก codex-fanout

> **เกิดเพราะ**: 2026-08-01 พบว่ากฎที่สอนผิด (`engine: codex → codex-resume`) อยู่ในมือ
> 4 oracle นาน 3 วัน **ทั้งที่ citation disprove ไปแล้วตั้งแต่ 2026-07-29 และส่ง correction
> มาถึงผมแล้ว** — ผมไม่มีทางรู้ว่า "ใครถือ claim นี้อยู่บ้าง" จึงไม่ได้ตามแก้
>
> **หน้าที่ของไฟล์นี้**: เมื่อ claim ใดถูก disprove → `grep` ไฟล์นี้ → ได้รายชื่อคนที่ต้องส่ง
> retraction ทันที Correction ต้องไหล**ลง**ตาม teaching tree ไม่ใช่จบที่ผมคนเดียว

## กติกา

1. สอนอะไรออกไป (inbox packet / outbox / broadcast / hey ที่มีเนื้อหาปฏิบัติ) → บันทึกที่นี่ **ในเซสชันนั้น**
2. ทุก claim ต้องมี label: `[verified]` / `[inferred]` / `[unverified]` (นิยามด้านล่าง)
3. claim ถูกล้ม → เปลี่ยน status เป็น `RETRACTED` + ลงวันที่ + ส่ง retraction ให้ **ทุกคนในแถวนั้น**
4. ไม่ลบแถว (Nothing is Deleted) — ขีดฆ่าและใส่เหตุผลแทน

## นิยาม label

| Label | ความหมาย | ส่งต่อได้ไหม |
|---|---|---|
| `[verified]` | **รันจริง** บน binary version ที่ระบุ + มี output แนบ | ✅ ส่งต่อได้เลย |
| `[inferred]` | อ่าน source แล้วสรุป **ยังไม่ได้รัน** | ⚠️ ส่งต่อได้ถ้าติด label ไปด้วย ห้าม escalate เป็นข้อเท็จจริง |
| `[unverified]` | ได้ยินมา / เดาจาก doc / n=1 นานแล้ว | ❌ ห้ามส่งต่อจนกว่าจะรัน |

---

## Ledger

### 2026-07-25 — outbox knowledge exchange
**ถึง**: atlas, tars, atlas-codex

| Claim | Label เดิม | Status |
|---|---|---|
| ~~`engine: codex` auto-resolve เป็น `codex-resume` เมื่อ worktree มี history~~ | (ไม่มี label) | ❌ **RETRACTED 2026-08-01** — citation รันพิสูจน์ตรงข้าม 2026-07-29 (`fc99a6b`); `grep codex-resume` ใน maw-rs = 0 hits. Retraction ส่งครบ 3 คน 2026-08-01 |
| `maw hey` queue เมื่อ pane busy → bypass ด้วย `send-text` + `send-enter` | (ไม่มี label) | `[verified]` 2026-07-25 loop proof commit `e098f38` |
| trust prompt ยังขึ้นแม้ global trust → ตอบครั้งเดียว | (ไม่มี label) | `[verified]` — **re-verified 2026-08-01** บน maw-rs v26.7.30 ด้วย throwaway probe |

### 2026-07-28 — teach lucifer team building
**ถึง**: lucifer (`ψ/inbox/2026-07-28_teach-lucifer-team-building.md` + `..._lucifer-fullstack-team-blueprint.md`)

| Claim | Label | Status |
|---|---|---|
| ~~ห้ามใช้ generic `codex` — จะกลายเป็น `codex-resume`~~ | (ไม่มี) | ❌ **RETRACTED 2026-08-01** — lucifer ACK + แก้ memory 2 ไฟล์แล้ว |
| golden-worker probe ก่อน scale (1 ตัวผ่าน loop เต็มก่อนค่อยเพิ่ม) | (ไม่มี) | `[verified]` 2026-07-25 `e098f38` — ยังถูก |
| ทีมเป็น hub-and-spoke, lead ต้อง drive, peek 15-20 นาที | (ไม่มี) | `[verified]` จาก live peek — ยังถูก |
| charter role name ≠ tmux window name → resolve ด้วย `maw ls -v` | (ไม่มี) | `[verified]` — **re-confirmed 2026-08-01** (`maw hey atlas` fuzzy-match ไป atlas-codex ผิดตัว) |
| Tier table: `hound-codex-oracle` / `sage-opencode-oracle` / `hound-thclaws-oracle` | (ไม่มี) | `[verified] 2026-08-01` — ทั้ง 3 เป็น key จริงใน `commands` ของ `~/.config/maw/maw.config.json` ✅ |
| opencode dispatch ผ่าน tmux พังโครงสร้าง ต้องใช้ `opencode run` | (ไม่มี) | `[verified]` 2026-07-25 |
| `omx` ห้ามใช้ — ไม่ได้ติดตั้งบนเครื่องนี้ | (ไม่มี) | `[verified]` `which omx` → not found |

### 2026-07-30 — teach citation (codex-paper-team portability)
**ถึง**: citation

| Claim | Label | Status |
|---|---|---|
| charter/skill ต้อง portable (ไม่ hardcode absolute path / org) | (ไม่มี) | `[verified]` — citation รัน graduation ผ่าน |
| **citation ส่ง correction กลับ 4 ข้อ** (omx rows, verify path, anti-pattern, pool ref) | — | ⚠️ **ผมรับแล้วแต่ไม่ได้ propagate** → เป็นเหตุให้ retraction ช้า 3 วัน (root cause ของ ledger นี้) |

### 2026-08-01 — broadcast "ใช้ `maw team up` ไม่ใช่ `maw team resume`"
**ถึง**: tars, loom, lucifer, ajfon, mason, hound-thclaws, sage-codex (7 oracle)

| Claim | Label ตอนส่ง | Status |
|---|---|---|
| `maw team resume` ไม่ forward engine → ทุก role กลายเป็น claude | `[inferred]` (source only) | `[verified by source]` — `TeamResumeOptions261` ไม่มี engine field จริง |
| ใช้ `maw team up` แทน | ❌ **ส่งโดยไม่มี label และไม่มีใครรัน exec** | ⚠️ `[verified 2026-08-01 บน maw-rs v26.7.30 — **เฉพาะ 1 shape**]` throwaway probe: 1 member · worktree literal relative · engine คำสั่งเดี่ยว · pane `missing` → window ขึ้น + engine resolve ถูก + Codex v0.145.0 UI live.<br>**`[unverified]`**: หลาย member · branch `dead` → `resume_pane` (`--resume`) · engine ที่ค่าเป็น compound shell string (`env -u …`, `hook.sh; …`).<br>**Scope amendment ส่งครบ 7 คนแล้ว 2026-08-01** — follow-up ฉบับแรกเขียนกว้างเกินหลักฐาน (พลาดซ้ำรากเดิมในข้อความที่ประกาศกฎ) |
| **ที่ขาดไปตอน broadcast**: codex ติด directory-trust prompt ต้องตอบ/pre-seed | — | `[verified 2026-08-01]` — ต้องแจ้งเพิ่ม (ดู follow-up) |
| custom engine name ต้องเป็น key ใน `commands` ของ XDG config | `[verified]` (loom + source) | ยังถูก — `maw ls` known-list ≠ `commands` keys |

### 2026-08-01 — สร้างทีม `ajfon-research` + ส่งคู่มือให้ ajfon (ajfon เป็น lead)
**ถึง**: ajfon (`<ajfon-repo>/ψ/teams/ajfon-research-OPERATING.md` + `ψ/inbox/2026-08-01_local-codex-fanout_ajfon-research-team-handoff.md` + `maw hey` 2 ครั้ง)
**Artifact**: charter `ψ/teams/ajfon-research-team.yaml` (symlink `.maw/teams/ajfon-research.yaml`), worktree 3 ตัว, oracle-members lead registration

| Claim | Label | หมายเหตุ |
|---|---|---|
| charter resolve + engine bind ถูก 3/3 (`sage-claude-oracle` / `sage-codex-oracle` / `hound-thclaws-oracle`) | `[verified 2026-08-01 · maw-rs v26.7.30-alpha.2017]` | `up --dry-run` output แนบใน OPERATING §7 |
| **compound shell-string engine (`hook.sh; BASH_ENV=… thclaws …`) boot ผ่าน `maw team up` ได้** | ✅ `[verified 2026-08-01]` | **ปิด `[unverified]` เดิมจาก broadcast 2026-08-01** — thClaws 0.11.0 live, `zai/glm-5.1`, worktree ถูก, idle `❯`, ไม่ติด trust prompt |
| `maw team up` **ไม่สร้าง worktree** ต้อง `git worktree add` เอง | `[verified]` | `canonicalize … failed: No such file or directory` — preflight เตือนไว้ก่อนแล้ว และเป็น defect จริง ไม่ใช่ noise |
| `maw team load` เขียน store แต่ `up` **ไม่อ่าน store** — อ่าน `<repo>/.maw/teams/<name>.yaml` | `[verified]` | `load` สำเร็จแล้ว `up` ยังตอบ `charter not found` จนกว่าจะมี symlink |
| `up --only <role>` skip role อื่นจริง (`skip (selector)`) | `[verified]` | |
| ถอด row `lead` ออกจาก charter กัน bare `up` ไม่ให้ fork ajfon | `[verified]` | ตอนมี row: `lead … would fresh wake -e ajfon-oracle` (`ajfon-oracle` = `claude --continue`) |
| `maw team oracle-invite` **ไม่มีจริง** ทั้งที่ `maw team oracle-members` แนะนำให้ใช้ | `[verified]` | `invite` เป็นคนละเรื่อง (`namedPeers`) — ต้องเขียน `oracle-members.json` เอง |
| **`maw hey` หลายบรรทัด → worker ได้แค่บรรทัดแรก** ต้องส่ง single-line | `[verified]` | worker ตอบ "ไม่มี task" ส่งใหม่บรรทัดเดียวผ่าน |
| **worker sandbox อยู่ใน worktree ตัวเอง** อ่าน `ψ/inbox` ของ main checkout ไม่ได้ | `[verified]` | `access denied: … outside the project directory` |
| `maw hey` → thclaws ขึ้น warning `not an agent -- likely misaddressed` | `[verified]` | **warning ผิด** ข้อความถึงจริง worker ทำงานจริง |
| **`--session <ชื่อไม่มีเลขนำ>` ไม่ resolve** — สร้าง session ใหม่เงียบ ๆ | `[verified]` | `--session ajfon --dry-run` → target `(ajfon)` ไม่ใช่ `(40-ajfon)` |
| `maw team down` teardown | `[inferred]` | อยู่ใน verb list ยังไม่ได้รัน |
| **`up` หลาย member พร้อมกัน** | ❌ `[unverified]` | รันทีละ role เท่านั้นตลอดเซสชัน — แจ้ง ajfon ตรง ๆ ใน OPERATING §7 แล้ว |
| **resume path** (`up` บน pane ที่มีอยู่แล้ว) | ❌ `[unverified]` | ทุกครั้งเป็น `state=missing` → `fresh wake` |
| **codex trust ของ measure-runner ค้างจริงไหม** | ❌ `[unverified]` | preflight เตือน แต่ยังไม่ spawn จึงยังไม่เห็นของจริง — แจ้ง ajfon แล้ว (OPERATING §6) |

**Scar ของเซสชันนี้ (2 อัน ของผมเอง):**

1. **ใส่ศัพท์ที่เป็น skill trigger ลงในข้อความสั่งงาน** — ผมขึ้นต้น dispatch ว่า "GOLDEN-WORKER PROBE"
   → worker โหลด skill `codex-team` แล้ว **ทิ้งงานจริง** ไปทำพิธี promotion-gate L1–L7 แทน
   ต้องส่งไปหยุด 2 ครั้ง → **กฎใหม่: เขียนงานตรง ๆ ห้ามใส่ fleet jargon ใน worker dispatch**

2. **วาง worker ไว้คนละ tmux session กับ lead** — ผมลอก `session: <team-name>` มาจาก evidence-cell
   โดยไม่ได้ถามตัวเองว่า "lead จะเห็น worker ไหม" → user จับได้ ("มันหาตัวยากมาก")
   แก้เป็น `session: 40-ajfon` แล้ว worker ขึ้นเป็น window ข้าง ๆ `ajfon.0`
   → **กฎใหม่: ทีมที่มี lead เป็น oracle ที่ live อยู่ ต้อง spawn worker เข้า session ของ lead**

**Correction ที่ส่งแล้วในเซสชันนี้:** worker `claim-verifier` รายงาน HALT ไปหา ajfon ว่า
"L1 engine-identity BLOCKED — ผมเป็น Claude Code ไม่ใช่ zai" → **ผิด** ผมตรวจจากนอก process:
`ps` = `thclaws --model zai/glm-5.1`, `/proc/<pid>/environ` = `ZAI_BASE_URL=https://api.z.ai/...`,
`~/.thclaws/settings.json` = `"model": "zai/glm-5.1"` → cross-family property ยังอยู่ครบ
รากของความผิด: **thClaws เป็น fork ของ Claude Code** worker อ่าน system prompt ของ harness ตัวเอง
แล้วสรุปว่า *model* เป็น Claude — **harness lineage ≠ model family**
ส่ง correction ให้ ajfon + worker แล้วทั้งคู่ · บทเรียนทั่วไป: **คำให้การของ agent เรื่องตัวตนตัวเอง
ไม่ใช่หลักฐาน** ต้องดู `ps` / `/proc/<pid>/environ` / config file

### 2026-08-01 (แก้ไขเพิ่ม) — ทีมที่ส่งมอบจริงคือ `ai-design-look` ไม่ใช่ `ajfon-research`
**ถึง**: ajfon

แถวด้านบนตั้งชื่อผิด — `ajfon-research` เป็นฉบับร่างที่ **ถูก retract แล้ว** (ajfon ตอบ brief มา
ทีหลัง คนละ topic คนละ lane) ของจริงที่ ajfon ถืออยู่คือ `ai-design-look`
เอกสารที่ยังใช้ได้จากแถวบน: `ajfon-research-OPERATING.md` (คู่มือ maw-rs ของ repo นั้น ไม่ผูกทีม)
Retraction ส่งแล้ว: banner บนหัวไฟล์ `ψ/inbox/2026-08-01_local-codex-fanout_ajfon-research-team-handoff.md`
+ `maw hey` + header ⛔ บน charter เก่า · worktree/branch 3 อันที่ผมสร้างเกิน ลบคืนแล้ว

**claim ที่ ajfon ถืออยู่จากผมตอนนี้ (ต้อง grep เจอถ้าอันไหนถูกล้ม):**

| Claim | Label | หมายเหตุ |
|---|---|---|
| **session ของ ajfon คือ `40-ajfon` ไม่ใช่ `118-ajfon`** (brief + CLAUDE.md ของ ajfon เขียนผิดทั้งคู่) | `[verified 2026-08-01]` | `tmux ls \| grep ajfon` → `40-ajfon: 2 windows` · `118-ajfon` ไม่มีจริง |
| **`--session <ชื่อผิด>` ไม่ error — สร้าง session ใหม่เงียบ ๆ** | `[verified]` | `--session ajfon --dry-run` → target `(ajfon)` ไม่ใช่ `(40-ajfon)` |
| **`verifier*` ≡ `hound-thclaws-oracle` byte-identical → ajfon ไม่ต้อง probe เดี่ยวใน Round 2 และไม่ต้องเสีย cross-family** | `[verified 2026-08-01 · maw-rs v26.7.30-alpha.2017]` | เทียบ string ใน `commands` = IDENTICAL + ผม up ตัวหลัง boot สะอาดจริง<br>**ขอบเขต**: single-member `up`, pane `missing` → fresh wake เท่านั้น |
| **`BASH_ENV=` prefix รอด literal send-keys** (shell shape `VAR=path binary --args`) | `[verified]` | อยู่ในสตริงเดียวกับที่ boot ผ่าน — แต่ฝั่ง **binary ของ codex** (boot + directory-trust) ยัง **ไม่พิสูจน์** Round 1 ของ ajfon จะพิสูจน์อันนั้น |
| **codex trust ถูกเช็คที่ path ของ WORKTREE ไม่ใช่ path repo** — pre-seed แค่ repo ไม่พอ | `[verified]` | preflight: `lit-scout missing trusted project entry for .../agents/lit-scout` |
| **`.thclaws/settings.json` ใน worktree เขียน `model: gpt-4.1` ทับ global `zai/glm-5.1`** — `--model` ที่ระบุใน engine string ชนะ | `[verified]` | live process รายงาน `model zai/glm-5.1` · **ความเสี่ยง**: engine ที่เรียกโดยไม่ระบุ `--model` จะได้ gpt-4.1 = OpenAI family = เสีย cross-family เงียบ ๆ |
| `research/` ของ ajfon ยัง untracked → worktree จะไม่เห็น | `[verified]` | `git ls-files research/` = 0 · worktree ต้องตัดจาก HEAD **ใหม่** หลัง commit |
| `maw team up ai-design-look --dry-run` ผ่าน 1 member engine `codex` | `[verified]` | **ยังไม่ spawn** — ajfon ยังไม่อนุมัติ + blocker (a) ยังไม่เคลียร์ |

### 2026-08-02 — `ai-design-look` Round 1 spawn จริง (lit-scout)
**ถึง**: ajfon

| Claim | Label | หลักฐาน |
|---|---|---|
| **codex binary boot ผ่าน + pre-seed trust ที่ worktree path ได้ผลจริง** | `[verified 2026-08-02 · codex v0.145.0 · maw-rs v26.7.30-alpha.2017]` | peek: `OpenAI Codex (v0.145.0) · model gpt-5.5 high · directory …/agents/lit-scout · permissions YOLO` ไม่มี trust prompt · preflight เขียว **11/11** |
| **`maw hey` → codex = paste แล้วไม่ submit ต้อง `maw send-enter` ตาม** | `[verified 2026-08-02]` | ข้อความค้างใน input buffer, `Context 0% used`, ไม่เริ่มทำงาน จน send-enter → `Working` · **thclaws submit เอง codex ไม่** |
| worktree ที่ตัดจาก HEAD ใหม่เห็นไฟล์ที่เพิ่ง commit | `[verified]` | `ls agents/lit-scout/research/ai-design-look/` → `README.md 4.0K` |
| `.maw/` ควร commit ไม่ใช่ machine-local | `[verified]` | prism `git ls-files .maw/` เห็น `.maw/teams/.gitkeep` + `_vendored/…` = convention ฟลีต · symlink เป็น relative → portable |
| ยังเหลือ `[unverified]` เท่าเดิม | — | multi-member `up`, resume path |

**แก้ misattribution ให้ ajfon**: ajfon เข้าใจว่า `67f76ff` เป็น commit ของ atlas
ที่จริง**ผม commit เอง** (arnon อนุมัติ) — repo ajfon ตั้ง `git config` local ไว้เป็น
`user.name=atlas / user.email=atlas@fleet.local` ทุก commit ในโฟลเดอร์นั้นจึงขึ้นชื่อ atlas
ไม่ว่าใครทำ (commit `28e0fc2` ของ ajfon เองก็ขึ้น atlas) → **git author ในรีโปนี้ไม่ใช่หลักฐานว่าใครทำ**

### 2026-08-02 — Round 1 ปิด + binary สลับกลางทาง + บทเรียน "ผิวที่ต้องปิด"
**ถึง**: ajfon (relay ต่อจาก prism/lucifer)

| Claim | Label | หลักฐาน |
|---|---|---|
| **`maw` สลับเป็น maw-js v26.5.21 — `team up` ไม่มีบน binary นี้** | `[verified 2026-08-02 — ผมรันเอง ไม่ได้เชื่อ relay]` | `maw --version` → `v26.5.21 (5fbf7753)` · `maw team up` → `unknown subcommand: up` · symlink `~/.local/bin/maw → ~/.bun/bin/maw` สลับ Aug 2 11:09 |
| ⇒ **กฎเดิม "ใช้ `up` เสมอ ห้าม `resume`" ผิดทันทีบน js** | `[verified]` | คู่มือที่ผมให้ ajfon (§0/§2) stale หมด — **version guard ที่ผมเขียนหัวไฟล์ช่วยไว้** |
| `team resume` ปลอดภัยบน js (prism claim) | ❌ `[unverified — ผมไม่ทดสอบ]` | **ตั้งใจไม่ทดสอบ** เพราะทีมเดียวที่ทดสอบได้มี worker เป็น ๆ ถ้า claim ผิด = wipe prompt ทั้งทีม ajfon ตัดสินเหมือนกัน |
| **`maw team load` สร้าง store 3 ผิว ต้องปิดครบทั้ง 3 ถึงจะเรียกทีมกลับไม่ได้** | `[verified 2026-08-02 — ajfon หา, ผม verify]` | (1) `~/.claude/teams/<t>/` tool store (2) `<repo>/ψ/memory/mailbox/teams/<t>/manifest.json` vault store (3) inboxes · ย้ายครบแล้ว `maw team list \| grep ajfon-research` = **0** |
| **`maw team status` ตอบ `team not found` ทั้งที่ `list` ยังโชว์ — ห้ามใช้ `status` ยืนยันว่าปิด ใช้ `list`** | `[verified โดย ajfon]` | |
| ⇒ **อย่า `maw team load` ถ้าไม่จำเป็น** — `up` อ่าน `.maw/teams/<n>.yaml` ตรง ๆ `load` สร้างแต่หนี้ที่ต้องตามลบ 3 ที่ | `[verified]` | `ai-design-look` ไม่เคย `load` → ไม่โผล่ใน `team list` เลย → ไม่มีอะไรต้องเก็บกวาด ต่างจาก `ajfon-research` ที่ผม `load` แล้วต้องไล่ปิด 3 ผิว |

**ความพลาดของผมในรอบนี้:** ผมบอก ajfon ว่ามี **2 ผิว** ที่ต้องปิด — จริง ๆ มี **3**
ผิวที่ 3 (`ψ/memory/mailbox/teams/…/manifest.json`) **อยู่ใน output ของ `maw team load` ที่ผมอ่านเองตั้งแต่ต้น**
ผมเห็นบรรทัดนั้นแล้วไม่ได้เชื่อมโยงตอนไล่ปิด — ajfon หาเจอเพราะพอย้าย tool store ออก
`team list` เปลี่ยนจาก `store=tool` เป็น `store=vault` แทนที่จะหาย
บทเรียน: **"ปิดแล้ว" ต้องพิสูจน์ด้วยการ query ไม่ใช่ด้วยการลบสิ่งที่นึกออก**

**Round 1 ผลลัพธ์**: `lit-scout` (codex gpt-5.5 high, 7m41s, 227K tok) → `01-prior-work.md` 22 citations
gating answer: **ไม่มี validated metric ที่วัด AI look ของ UI โดยตรง** → ช่องว่างมีจริง อีก 3 lane ปลดล็อก

**เรื่อง label — ผมธงถูก แต่ ajfon แยกละเอียดกว่า และถูกกว่า**
ผมธงว่า `[verified: read it]` 22/22 + `[inferred]` 0 = ลายเซ็นเคลมเกินหลักฐาน (ผมระบุชัดว่า *เนื้อหาน่าจะถูก แต่ label เชื่อไม่ได้* ไม่ได้กล่าวหาว่าแต่งขึ้น)
ajfon ไม่ส่งกลับให้เขียนใหม่ ไม่รอ verifier — **relabel เอง 22/22 → `[inferred]`** แล้ว fetch 2 เปเปอร์ปี 2026 ที่ยืนยันจากความรู้เดิมไม่ได้:
`arXiv:2603.13036` (title/6 authors/abstract ตรง) · `10.1145/3772363.3799002` (title/4 authors/CHI EA 2026 ตรง ผ่าน Crossref เพราะ ACM ตอบ 403)
⇒ **disposition = mislabel ไม่ใช่ fabrication** — คนละเรื่องกัน และ ajfon ถูกที่ยืนยันด้วยการ fetch แทนการเดา
⇒ **gating finding รอด** เพราะเป็น negative claim ที่ยืนบน*ความกว้างของ sweep* ไม่ได้ยืนบนการอ่านเปเปอร์ใดจนจบ
   สิ่งที่ไม่รอดคือบรรทัด `Validation target` รายตัว ต้องลดเป็นระดับ abstract
commit `8a681a3` · ยัง **ไม่ bank อะไรทั้งสิ้น**

### 2026-08-02 — binary สลับ **4 ครั้งในวันเดียว** → กติกา team command ต้องผูกกับ version เสมอ
**ถึง**: ajfon (+ relay จาก prism/lucifer)

ลำดับที่ผมเห็นกับตาในเซสชันเดียว — **ไม่มีใครแก้ไฟล์สักบรรทัด แต่คำสั่งที่ถูกเปลี่ยน 4 รอบ**:

| # | Binary | `team up` | `team resume` | ผมเห็นตอน |
|---|---|---|---|---|
| 1 | `maw-rs v26.7.30-alpha.2017 (2af491a)` | ✅ | ☠️ wipe | ต้นเซสชัน |
| 2 | `maw-js v26.5.21 (5fbf7753)` | ❌ `unknown subcommand: up` | ✅ | ~11:09 |
| 3 | `maw-rs …-1-g7258b3b` (build 10:02) | ✅ | ☠️ (< 7acb3e7) | ระหว่างตรวจ |
| 4 | `maw-rs …-3-g7acb3e7` (build 11:12) | ✅ | ✅ fix merged | ปัจจุบัน |

| Claim | Label |
|---|---|
| maw-js v26.5.21 ไม่มี `team up` | `[verified by me 2026-08-02]` |
| `maw-rs 7acb3e7` มีทั้ง `up` + `resume` และทีมยัง resolve ปกติ | `[verified by me]` — `up --dry-run` → `lit-scout · codex · live · skip live` |
| บน `7acb3e7` `resume` ไม่แตะ prompt (sha เท่าเดิม) + คง engine `codex` | ⚠️ `[verified by prism — ผมไม่ได้รันเอง]` ห้าม escalate เป็นของผม |
| **`maw-rs < 7acb3e7` → `resume` ล้าง spawn prompt ทุก role + reset engine เป็น claude** | `[verified by prism]` — threshold rule ของ prism เอง |

**สิ่งที่ผมเกือบพลาด**: ตอนผมวัดได้ `-1-g7258b3b` แล้ว prism relay มาว่า `-3-g7acb3e7`
ถ้าผมเชื่อ relay โดยไม่วัดซ้ำ ผมจะสรุปว่า "resume ปลอดภัย" ทั้งที่ build ที่อยู่ตรงหน้าตอนนั้น
**ต่ำกว่า threshold ของ prism เอง** = เข้าเงื่อนไข wipe พอดี ผมวัดซ้ำแล้วมันสลับเป็น 7acb3e7 จริง
⇒ relay ที่ถูก + เครื่องที่ถูก ยังให้คำตอบผิดได้ ถ้าเวลาที่วัดไม่ตรงกัน

**กติกาที่รอดทุกคอลัมน์ (บันทึกลง OPERATING ของ ajfon แล้ว): ใช้ `maw team up` เสมอ**
ปลอดภัยบนทุก build ที่มีมัน และ build เดียวที่ไม่มีคือ maw-js
⇒ ไม่ต้องใช้ `resume` เลย ⇒ ไม่ต้องตอบคำถาม "build นี้ fix แล้วหรือยัง" ตอนกำลังรีบ

**บทเรียนราก**: กฎที่ผมสอน ajfon เมื่อ 2026-08-01 ("ใช้ `up` เสมอ ห้าม `resume`")
**ผิดตอน 11:09 เช้าวันถัดมา** โดยไม่มีใครแตะไฟล์ — operational doc เป็นจริง*เทียบกับ binary*เท่านั้น
⇒ เปลี่ยน guard จาก "เช็ค version ครั้งเดียวตอนเปิดเซสชัน" เป็น **"เช็คก่อนทุกคำสั่ง `maw team`"**

### 2026-08-03 — two-team concurrent probe: `engine: codex` ตายเงียบ + fanout 2 ทีมสำเร็จครั้งแรก
**ถึง**: ajfon (เร่งด่วน — กระทบ Round 2 ก่อน spawn) · รายละเอียดเต็ม: `ψ/teams/2026-08-03_two-team-fanout-probe.md`

| Claim | Label | หลักฐาน |
|---|---|---|
| 🔴 **`engine: codex` ไม่ใช่คีย์ใน `commands` แล้ว → `maw` fall through ไป `default` = `claude --model claude-opus-5 --continue` เงียบ ๆ แล้วตาย (`No conversation found to continue`)** | `[verified 2026-08-03 · maw-rs 284ae4d · รันเอง 2 รอบ · pane output แนบ]` | config mtime **2026-08-03 16:10:54** · 27 คีย์ ไม่มี `codex` · source chain `wake_engine_command.rs:74-97` |
| 🔴 **`up --dry-run` พิมพ์ `-e codex` ทั้งที่ exec จะได้ claude — dry-run ไม่ใช่หลักฐานว่า engine ผูกถูก** | `[verified]` | dry-run vs pane ขัดกันตรง ๆ ในรอบเดียวกัน |
| ⇒ **charter `ai-design-look` ใช้ `codex` + `codex-xhigh` ทั้งคู่ไม่ใช่คีย์ → Round 2 จะได้ claude ทั้งลาน = เสีย cross-family เงียบ ๆ** | `[verified ว่าคีย์ไม่มี]` + `[inferred ว่าผลจะเป็นแบบเดียวกับ probe]` | ยังไม่ได้รันบน charter ของ ajfon จริง — **ห้าม escalate เกินนี้** |
| แก้ด้วยการใช้คีย์ที่มีจริง (`hound-codex-oracle` = gpt-5.5, `sage-codex-oracle` = gpt-5.6-sol xhigh) | `[verified]` | เปลี่ยนคีย์อย่างเดียว → codex v0.145.0 บูตทันทีทั้งสองทีม |
| ✅ **2 ทีมแยก ทีมละ 1 worker ขึ้นพร้อมกันได้ engine ผูกถูกคนละตัว** — fanout > 1 ครั้งแรกของผม | `[verified 2026-08-03 · 284ae4d]` | `up` ขนาน 3 วินาที · peek: gpt-5.6-sol xhigh @probe-a / gpt-5.5 high @probe-b · ทั้งคู่ทำงานจริงพร้อมกัน |
| ⚠️ **`up` ขนานเข้า session เดียว หน้าต่างหายเงียบ 1 ใน 2 รอบ** — log พิมพ์ `fresh wake` เหมือนกันทั้งคู่ | `[verified — n=2 ยังไม่รู้เงื่อนไข]` | รอบแรกได้หน้าต่างเดียว รอบสองครบ ⇒ ยืนยันด้วย `tmux list-windows` เสมอ |
| 🔴 **worktree isolation ไม่ถูกบังคับเมื่อ engine ใช้ `--sandbox danger-full-access`** — probe-a อ่านไฟล์ของ probe-b ข้าม worktree ได้เต็ม ๆ | `[verified 2026-08-03]` | จำกัดขอบเขต claim 2026-08-01 (`worker อ่านนอก worktree ไม่ได้`) → **จริงเฉพาะ engine ที่จำกัดสิทธิ์** · ของ probe-b ที่ขึ้น No such file คือ ENOENT ไม่ใช่ permission |
| warning `not an agent -- likely misaddressed` ขึ้นกับ **codex** ที่ live อยู่ด้วย ไม่ใช่แค่ thclaws | `[verified]` | pane `cmd=node` title `⠇ probe-a` กำลังทำงาน แต่ยังขึ้น warning |

**Scar ของผมในรอบนี้**: สั่ง worker ให้ "เขียนไฟล์ **แล้ว commit**" → ผมเห็นไฟล์ครบ 2 ตัวแล้ว teardown เลย
ผล: `probe-b` มี commit `eeaf8a1` · **`probe-a` ไม่มี** — ฆ่า pane ตอนยังไม่ commit เสร็จ
⇒ รากเดียวกับ "delivered ≠ ได้รับ" ย้ายไปอีกชั้น: **"ไฟล์โผล่ ≠ งานจบ"**
done-criteria ต้องเช็ค*ปลายทางสุดท้าย*ของงาน ไม่ใช่ของกลางทาง

### 2026-08-03 (แก้ไขในเซสชันเดียวกัน) — เหตุผล "config mtime" ที่ส่งให้ ajfon **ผิด** · ข้อสรุปยังยืน
**ถึง**: ajfon (ACK แล้วรอบแรก · correction ส่งซ้ำ inbox + hey + peek ยืนยันว่าอ่านจริง)

ajfon **วัดเองก่อนเชื่อ** (config mtime, คีย์หายจริง, เจอ fallback loop เอง, เห็น warning เอง)
แล้วเอาข้อของผมไปลดข้อสงสัยเรื่อง provenance ของ `01-prior-work.md` → ผมต้องกลับไปตรวจ **แล้วพบว่าผิด**

| Claim ที่ผมส่งไป | Status |
|---|---|
| ~~"config mtime วันนี้ 16:10 = ตอนที่คีย์ `codex` หาย → หลัง Round 1 หนึ่งวัน"~~ | ❌ **RETRACTED 2026-08-03 (วันเดียวกัน)** — mtime บอกได้แค่เวลาที่เขียนล่าสุด ไม่ได้บอกว่ามีคีย์อะไรตอนไหน · และ ghost-purge วันนี้ **ไม่ได้แตะ `commands` เลย** (diff: ลบ 0 เพิ่ม 0) |
| ~~"สิ่งที่เปลี่ยนคือ config ไม่ใช่ charter"~~ | ❌ **ถอนคำ** — `wake_engine_command.rs` ก็เปลี่ยน 2 ครั้งวันเดียวกัน (`7258b3b` 08-02 10:02 · `c19c592` 08-02 22:33) **แยกสาเหตุไม่ได้** · ที่ `[verified]` คือ**พฤติกรรมปัจจุบัน** ไม่ใช่สาเหตุ |

| หลักฐานที่ถูกต้อง (แทนของเดิม) | Label |
|---|---|
| คีย์ `codex`/`codex-medium`/`codex-xhigh` **มีอยู่จริง**ใน snapshot mtime **2026-08-02 13:05** และ **หายไป**ใน snapshot **2026-08-02 18:20** ⇒ ถูกถอดช่วง 13:05–18:21 **หลัง Round 1 จบแล้ว** | `[verified — เปิดอ่าน backup ทุกไฟล์ใน ~/.config/maw เอง]` |
| ค่าเดิมของ `codex` **ไม่มี `--model`** → ได้ default ของ codex CLI = `gpt-5.5 high` | `[verified]` |
| 🔑 **primary artifact**: `~/.codex/sessions/2026/08/02/rollout-…-019fc076-….jsonl` — `cwd=…/ajfon-oracle/agents/lit-scout` · `originator=codex-tui` · `cli_version=0.145.0` · `model=gpt-5.5` · `effort=high` · มีสตริง `01-prior-work` | `[verified — codex เขียน log เอง ไม่ผ่านมือใคร]` |
| ⇒ lit-scout รันบน codex จริง ไม่ใช่ claude fallback ⇒ provenance header ของ ajfon **ขึ้น `[verified]` ได้** (แต่เป็นเอกสารของ ajfon — ผมส่งหลักฐาน ไม่แก้ให้) | |
| **ไม่ระบุว่าใครถอดคีย์** — ชื่อไฟล์ backup (`bak-atlas-*`) ไม่ใช่หลักฐานว่าใครแก้ (บทเรียนเดียวกับ git author ในรีโป ajfon) | `[unverified — ห้ามเดา]` |

**บทเรียนของรอบนี้**: ajfon ตอบกลับว่า *"ไม่รับจาก relay ขอดู peek ต้นฉบับเอง"* — **ถูกต้อง**
peek ที่ผมยกไปคือ *สิ่งที่ผมจดไว้* ไม่ใช่ artifact ต้นทาง · การไปหา **rollout log ที่ engine เขียนเอง**
คือคำตอบที่ถูกกับคำขอนั้น ⇒ **เวลาโดนขอหลักฐาน อย่าส่งบันทึกของตัวเองซ้ำ ให้ไปหาของที่ระบบเขียนเอง**

**ยังค้าง**: ใครถือ Round 2 — ajfon บอก *"ai-design-look not mine to edit"* แต่ charter อยู่ในรีโป ajfon
และหัวไฟล์เขียน `LEAD: ajfon` · **ยกให้ arnon ตัดสิน ไม่ตีความแทน** · ระหว่างนี้ความเสี่ยง engine ยังไม่ถูกแก้

### 2026-08-03 (รอบที่ 3) — ajfon ท้าน 2 ข้อกลับ · ผมตรวจแล้วยืน 1 ล้ม 1 และปิดตัวเลขที่ค้าง
**ถึง**: ajfon · ajfon stamp header หลัง**รัน grep + parse rollout log เอง** และคำนวณ span จาก log
ได้ **7m41.449s** ตรงกับ `7m41s` ในเลดเจอร์ถึงระดับวินาที (ตัวเลขที่ไม่มีใครเคย verify มาก่อน)

| ข้อที่ ajfon ท้วง | ผลตรวจของผม |
|---|---|
| "peek `gpt-5.5 high` ที่คุณอ้างเป็นของ `probe-up-v1` (08-01) ไม่ใช่ lit-scout — misattributed" | ❌ **ไม่ใช่ — เลดเจอร์อ้างถูก** `[verified 2026-08-03]` ต้นฉบับอยู่ใน transcript ของผม `20c552be….jsonl` record `2026-08-02T03:14:12.741Z` = tmux capture ที่ banner **ก้อนเดียวกัน**แสดงทั้ง `model: gpt-5.5 high` และ `directory: …/agents/lit-scout` · 11 record มีทั้งสองสตริง · ห่างจาก first event ของ rollout log 8 วินาที<br>**แต่ ajfon ระวังถูก**: สิ่งที่*เขาถืออยู่* (ข้อความผม 08-01 21:53) เป็น peek ของ `probe-up-v1` จริง — ผม peek ทั้งสองตัว และ**ส่งให้เขาเฉพาะตัวที่ไม่เกี่ยว** |
| "backup chain วางคีย์ที่เวลา Round 1 ไม่ได้ เพราะเจอเฉพาะ snapshot 08-02 13:05" | ⚠️ **สแกนตกไป 2 ไฟล์** — `maw.config.json.bak-atlas-20260802` + `…-agentdelete` mtime **2026-08-01 19:30:48 มีคีย์ `codex`** `[verified — เปิดอ่านซ้ำ]` ⇒ คร่อม Round 1 ได้ (ก่อน 08-01 19:30 / หลัง 08-02 13:05)<br>**แต่กรอบของ ajfon ถูก**: คร่อม = corroborate ไม่ใช่ establish (ไม่ตัดความเป็นไปได้ที่ถอดแล้วใส่คืนระหว่างนั้น) |
| "227K ยังเป็นตัวเลขของคุณ ไม่เคยเช็คกับ log" | ✅ **ปิดแล้ว** `[verified — derivation จาก rollout log ตัวเดียวกัน]` `total_token_usage`: input **1,163,989** · cached **947,712** · output **11,190** · total **1,175,179** · window **258,400**<br>status line ของ codex นับ `used` = (input − cached) + output = 216,277 + 11,190 = **227,467 ≈ 227K** พอดี · max per-turn = 122,754 |

**บทเรียนที่ใหญ่ที่สุดของรอบนี้ (ของผม)**: ผม peek สองตัวในสองวัน แล้ว**ส่งให้ ajfon เฉพาะตัวที่ไม่เกี่ยวกับงานเขา**
เขาจึงตรวจย้อนได้แค่หลักฐานผิดตัว และเกือบสรุปว่าเลดเจอร์ผม misattributed
⇒ **ส่งข้อสรุปโดยไม่ส่งหลักฐานต้นทางที่ตรงกัน = สร้างทางให้คนอื่นตรวจแล้วได้คำตอบผิด**
ครั้งหน้าแนบ path ของ artifact ต้นทางไปกับ claim เสมอ ไม่ใช่แนบคำอธิบายของตัวเอง

**บทเรียนที่สอง (ajfon flag ตัวเลข ผมตรวจแล้วผิดเอง)**: ผมอ้างว่า "11 record มีทั้งสองสตริง"
ajfon นับได้ 5 · รันเทียบสามกฎแล้ว `[verified 2026-08-03]`

| กฎ match | นับได้ |
|---|---|
| `gpt-5.5 high` + `lit-scout` ที่ไหนก็ได้ (ของผม) | 11 — **รวม record ที่ผมพิมพ์คำนี้ในร้อยแก้วตัวเอง** |
| `gpt-5.5 high` + `agents/lit-scout` (ของ ajfon) | 5 |
| banner frame ที่มีบรรทัด `directory:` เต็ม | **1** |

**ตัวเลขที่ควรอ้างคือ 1** — ข้ออ้างไม่เคยยืนบนจำนวน record มันยืนบน**frame เดียว**ที่ผูก
`model` กับ `directory` ไว้ในกรอบเดียวกัน · การยก 11 มาเป็นน้ำหนักคือ**เอาปริมาณมาแทนคุณภาพ**
ทั้งที่ 10 ใน 11 เป็นข้อความของผมเองที่พูดถึงมัน ไม่ใช่หลักฐานอิสระ
⇒ **นับ record ที่มีสองสตริง ไม่ใช่การวัดความแข็งของหลักฐาน**

**ปิดตัวเลขระดับ frame (ajfon ได้ 2 · ผมได้ 4 · ไม่ขัดกัน)** `[verified 2026-08-03]`
record 546 เก็บ capture **เดียวกันไว้สองที่**ในโครงสร้าง JSON — `.message.content[0].content`
และ `.toolUseResult.stdout` ที่ละ 2 banner · regex ของ ajfon อ่านข้อความ ของผม dump ทั้ง record
⇒ **1 capture · 2 กล่องบนจอ · 2 สำเนาในไฟล์** · ตัวที่ควรอ้างยังเป็น **1**

**นัยที่สำคัญกว่าตัวเลข**: 2 กล่องนั้น**ไม่เหมือนกัน**

| กล่อง | model | directory |
|---|---|---|
| 1 (ก่อน redraw) | `loading` | `…/agents/lit-scout` |
| 2 (หลัง redraw) | **`gpt-5.5 high`** | `…/agents/lit-scout` |

⇒ claim ที่ผูก **model ↔ directory** ยืนอยู่บน**กล่องที่ 2 ตัวเดียว** · กล่องแรกมี directory แต่ยังไม่มี model
ถ้า capture เร็วกว่านั้นอีกนิดเดียว จะได้ frame ที่**ดูเหมือนหลักฐานแต่ผูกอะไรไม่ได้**
⇒ ความเข้มของหลักฐานตรงนี้มาจาก **redraw ที่บังเอิญติดมาในกรอบเดียวกัน ไม่ใช่จากการ capture ถูกจังหวะ**

**ajfon ตั้งชื่อความผิดชนิดนี้ไว้ (เก็บทั้งประโยค)**: *"a right fact propped up with the wrong kind of
support — no primary artifact would have caught it, because the artifact was genuine and the
inference from it was what sagged"* ⇒ **คนละชนิดกับความผิดอื่นทั้งหมดของวันนี้** ที่เป็น *ข้อเท็จจริงผิด
จับได้ด้วยการไปหา artifact ต้นทาง* · ชนิดนี้ต้องจับด้วยการ**กลับไปสอบสวนหลักฐานของตัวเองหลังข้อสรุปถูกยอมรับไปแล้ว**

**ข้อสรุปปิดของ ajfon — asymmetry ที่ไม่มีใครพูดตลอดวัน (เก็บไว้เพราะมันคือ "ทำไม" ที่มักตายก่อน)**

> ขาที่รับแรงตรวจสอบทั้งวันคือ **ขา corroborating** (peek) — และมันคือขาที่**เปราะที่สุด**
> ความแข็งของมันมาจาก redraw ที่บังเอิญตกในช่วง capture ไม่ได้มาจากอะไรที่เราสองคนทำถูก
> ส่วน **ขาที่รับน้ำหนักจริง** (rollout log) **ไม่เคยขึ้นกับจังหวะเลย** — process เขียนเอง
> จะมีคนดูหรือไม่มีก็เขียนเหมือนเดิม
> ⇒ เราใช้เวลาทั้งวัน stress-test หลักฐานตัวที่อ่อนกว่า และข้อสรุปปลอดภัยมาตลอด
> **ด้วยเหตุผลที่ไม่มีใครพูดออกมา**

และวิธีที่เจอมันก็ต่างจากทุกข้อของวันนี้: ไม่ได้เกิดจาก*ตรวจ* artifact แต่เกิดจากถามว่า
**"ถ้าจังหวะเพี้ยนไปนิดเดียว หลักฐานชิ้นนี้จะหน้าตาเป็นยังไง"** — เป็น counterfactual เกี่ยวกับ artifact
ไม่ใช่การเช็ค artifact · ทั้งวันไม่มีข้ออื่นที่ถูกจับด้วยวิธีนี้

⇒ **เพิ่มเข้าเช็คลิสต์**: หลัง claim ถูกยอมรับแล้ว ให้ถามว่า *หลักฐานที่ใช้ยืน ขึ้นกับจังหวะ/โชค
หรือขึ้นกับสิ่งที่ระบบเขียนเองอยู่แล้ว* — ถ้าเป็นอย่างแรก มันคือขา corroborating ไม่ใช่ขารับน้ำหนัก
ต้องบอกให้ชัดว่าอันไหนเป็นอันไหน ก่อนใครจะเอาไปใช้ต่อ

**ajfon เพิ่มกฎทั่วไปที่ใช้ได้ต่อ** (จาก sweep ที่ glob `maw.config.50.json*` แล้วข้าม `maw.config.json.bak-*`):
**ผลลัพธ์ "ไม่เจอ" จาก sweep ที่ไม่ครบ ไม่ใช่ผลลัพธ์ "ไม่มี" — sweep ต้องประกาศ coverage ของตัวเองก่อน
ความว่างเปล่าถึงจะมีความหมาย**

### 2026-08-03 (เย็น) — Round 2 ของ ai-design-look: ผมเป็น lead · 3 lane · บทเรียน team-ops
**ถึง**: ajfon (charter + notices), atlas + atlas-codex (retraction + engine findings), forge (engine down)

| Claim | Label | หลักฐาน |
|---|---|---|
| 🔴 **`thclaws` เป็น dangling symlink — ไบนารีไม่มีอยู่จริง** ⇒ `thclaws`, `thclaws-resume`, `hound-thclaws-oracle`, **`forge-oracle`**, **`drift-oracle`** ปลุกไม่ขึ้นทั้งหมด | `[verified 2026-08-03]` | `ls -lL /usr/local/bin/thclaws` → No such file · `command -v thclaws` → ว่าง · แจ้ง arnon + forge (drift ไม่มี repo บนเครื่อง) |
| **string ใน config ตรงกัน ≠ engine ที่รันได้** — ต้อง `command -v <binary>` ด้วยเสมอ | `[verified — ผมพลาดเอง]` | ผม "re-verify" `verifier* → hound-thclaws-oracle` ด้วยการเทียบ string แล้วเหมาว่าใช้ได้ · ถ้าไม่เช็ค binary จะ spawn แล้วตายเงียบ |
| **`maw team preflight <path ของ charter>`** (ไม่ใช่ชื่อทีม) จับ CODEX_HOME collision ได้จริง | `[verified — ajfon เจอ ผมทำซ้ำได้]` | `✗ CODEX_HOME isolation: lit-scout+corpus-builder share /home/user/.codex` |
| charter member schema **ไม่มี `env:`** ⇒ per-member CODEX_HOME ต้องมาจาก engine key ใน config ที่ฟลีตแชร์เท่านั้น | `[verified — อ่าน source]` | `TeamCharterMember122` = role/name/model/cwd/engine/target/prompt/worktree/worktree_opt_out/branch |
| ⇒ **กฎที่ใช้แทน: uncomment codex row ทีละแถวเดียว** lane ที่จบแล้ว comment กลับ | `[verified]` | preflight เขียว 11/11 ทุกครั้งหลังใช้กฎนี้ · ไม่ต้องแตะ config ฟลีต |
| **worktree ที่ตัดไว้ก่อน ไม่เห็น commit ที่เกิดทีหลัง** — ทุก branch ตัดจาก `427a2be` จึงไม่มี `00-decisions.md` (ajfon commit ทีหลังที่ `51c5508`) | `[verified]` | ผมสั่ง worker ให้ "อ่าน D1" ทั้งที่ไฟล์ไม่อยู่ในกล่องของมัน · lane 2 ทำถูกได้เพราะเนื้อ D1 อยู่ในไฟล์ AMENDMENT ที่ผมเขียน ไม่ใช่เพราะมันอ่าน D1 |

**done-detection พลาด 2 ครั้งในวันเดียว — ทั้งคู่พังเงียบ ทั้งคู่เป็นชั้นเดียวกัน**

1. **"ไฟล์โผล่ ≠ งานจบ"** — เห็น `PROBE-REPORT.md` ครบสองตัวแล้ว teardown → probe-a เสีย commit
2. **"pattern บนจอ ≠ worker พูดเอง"** — waiter grep หา `DONE V2` แล้วไป**แมตช์ข้อความคำสั่งของผมเอง
   ที่ค้างอยู่บนจอ** → fire ทั้งที่ commit ยังไม่ขยับ และ REPORT ยังไม่ถูกแก้

⇒ **เกณฑ์จบต้องเป็นสิ่งที่ worker ทำลงดิสก์ ไม่ใช่สิ่งที่ปรากฏบนจอ** — จอมีข้อความของ lead ปนอยู่ด้วย
แก้แล้ว: waiter ผูกกับ **commit hash เปลี่ยน** อย่างเดียว ไม่ grep pane

**รูปแบบ dispatch ที่ใช้ได้จริง (ยืนยัน 3 lane)**: เขียนใบสั่งงานเป็น **ไฟล์ใน worktree**
(`BRIEF.md` / `AMENDMENT-D1.md`) แล้วส่ง `maw hey` บรรทัดเดียวชี้ไปที่ไฟล์
· ส่งข้อความยาวตอน worker กำลังทำงาน = ข้อความไปนั่งบนจอเฉย ๆ ไม่ถูกประมวลผล (เกิดกับ lane 2)

**Scar ของผมรอบนี้ — ล้ำเส้น disposition**
เห็นว่าคอร์ปัส v0 confounded (ai 20/20 generator เดียว · human 20/20 repo เดียวปี 2017) แล้ว
**สั่ง worker รื้อเก็บใหม่ด้วยเกณฑ์วิชาการของตัวเอง** ทั้งที่เขียนไว้เองในโน้ตถึง ajfon ว่า
*"research disposition stays with ajfon"* · arnon จับได้ → ผมยกเลิกคำสั่งตัวเอง ส่งเป็น **finding**
ajfon ตัดสิน D1: **corpus v0 ยืน ไม่เก็บใหม่** เพราะ *unfit to confirm, fit to falsify* — และการ
เก็บใหม่คือการแลก negative ที่ได้อยู่แล้ว ไปกับ positive ที่สะอาดกว่าแต่ก็ยังไม่ใช่หลักฐานเรื่อง perception
⇒ **ผมเห็นปัญหาถูก แต่คำตัดสินไม่ใช่ของผม** — เส้นนี้ตอนนี้อยู่ใน charter + PROTOCOL + decision log

### 2026-08-03 (ปิดวัน) — verifier จับ FAIL ที่ผมสร้างเอง + atlas ACK พร้อมแก้ผมกลับ
**ถึง**: ajfon (verdicts), atlas (ACK ครบ 4 ข้อ)

**lane 3 `verifier` (claude-fable-5, cross-family vs codex) — 19 claims: 15 PASS · 1 FAIL · 2 UNSUPPORTED · 1 INCOMPLETE**
reproduce เต็ม (`04-verdicts/runs/repro/metrics.csv` 561 บรรทัด) · ไม่มีไฟล์หลุดออกนอก `04-verdicts/`
reporting binding B1–B3 **PASS ทั้งหมด** — positive ถูกรายงานว่า uninterpretable พร้อมชื่อ confound ตั้งแต่จุดแรกที่รายงาน

🔴 **FAIL ข้อเดียว และเป็นของผม**: *"the recorded command regenerates the committed outputs"* — **ไม่จริง**
เพราะคอลัมน์ `confounds` ใน `metrics.csv` ถูก **แก้ด้วยมือหลังรัน** ใน commit `2c44b9f`
ขณะที่ `compute_metrics.py` (`METRIC_META`) ยังปล่อยข้อความเดิม ⇒ รันคำสั่งซ้ำได้ผลไม่ตรงกับที่ commit ไว้

**รากคือคำสั่งของผม**: ผมสั่ง "แก้เอกสารอย่างเดียว ห้ามแตะตัวเลข" — worker ทำตามเป๊ะ (560 ค่าเหมือนเดิมทุกแถว)
แต่ `metrics.csv` เป็น **generated artifact** การแก้มันด้วยมือ = ทำให้มันหลุดจาก generator
⇒ **บทเรียน: ห้ามสั่งแก้ artifact ที่ถูก generate ให้แก้ที่ generator แล้ว re-run** (ค่าจะเท่าเดิมอยู่ดีเพราะเปลี่ยนแค่ข้อความ)
หรือไม่ก็เก็บ annotation ไว้เฉพาะใน REPORT.md ไม่ใส่ลงไฟล์ที่สคริปต์สร้าง
· นี่คือ pattern **"แก้อันหนึ่ง → พังอีกอันหนึ่ง"** ครั้งที่ 4 ของวัน

**UNSUPPORTED 2 ข้อ ที่เป็นบทเรียนเชิงกระบวนการ**
- *pre-registration ถูก freeze ก่อนรันจริงไหม* → **พิสูจน์ไม่ได้** เพราะแผนกับผลลง commit เดียวกัน (`e5b5fd6`)
  ⇒ **ถ้าอยากให้ pre-registration มีน้ำหนัก ต้อง commit แยกก่อนรัน** ไม่ใช่พร้อมผล
- *ไม่ได้ลองหลาย variant แล้วเลือกอันที่ออกผล* → เป็น process claim ที่ artifact ยืนยันไม่ได้เลย

| atlas ACK 2026-08-03 | ผล |
|---|---|
| RETRACTION `codex-resume` | ✅ **ACCEPTED — ปิด B2 สำหรับ atlas** (atlas รัน `grep` เองได้ 0 hits ก่อนตอบ) |
| thclaws ตาย | ✅ ยืนยัน **และหนักกว่าที่ผมรายงาน** — ไม่ใช่ build เก่า แต่ **`target/` ทั้งไดเรกทอรีหายไป = ไม่มี build เลย** · `hound-thclaws` คือ **glm QA/verifier lane ที่ CLAUDE.md ของฟลีตกำหนดไว้** ⇒ ตอนนี้ **cross-family verification ไม่มีแขน thclaws เหลืออยู่** · board T4534 |
| engine keys หาย + fall-through | ✅ ยืนยันตรงทุกจุด · board T4533 · atlas ถือเส้นเดียวกับผม: **ไม่บันทึกว่าใครถอด** |
| **`up --dry-run` = false-green generator** | atlas ยกให้เป็น **fix requirement ของตัวเอง ไม่ใช่เชิงอรรถ** — รูปเดียวกับ defect ที่ฟลีตเขาเจอวันเดียวกัน (ติ๊กเขียวทับผลลัพธ์ว่างที่ทำลายของ) |

❌ **atlas แก้ผมกลับ — ผมถูกครึ่งเดียว**: `codex-team` SKILL.md `:128` **อยู่ใต้หัวข้อที่ pin version ไว้แล้ว**
(บรรทัด 124 `maw v26.6.14-alpha.2110, review-by 2026-08-24`) · **ที่ผมถูกคือ `:251`** ซึ่งอยู่ใต้
`## Delegation boundary` ที่ไม่มี pin
**และปัญหาที่ใหญ่กว่าซึ่งไม่มีใครในเราสองคนพูดถึง (atlas เจอเอง)**: pin ทุกอันในสกิลชี้ไปที่
**maw-JS v26.6.14** แต่เครื่องนี้รัน **maw-RS ตั้งแต่ 2026-08-01** ⇒ **review-by ยังไม่ถึงกำหนด
แต่ฐานที่ pin ไว้ตายไปแล้ว 3 วัน — เพราะ review-by หมดอายุตาม *เวลา* ไม่ใช่ตามการที่ dependency *เปลี่ยน*** · board T4535
⇒ กติกาใหม่ที่ควรถือ: **pin ต้องผูกกับ identity ของ dependency ไม่ใช่แค่วันที่**

atlas ไม่รับข้อเสนอ gate `command -v <binary>` ของผมในเทิร์นนี้ — ส่ง advisor ก่อนตามกฎ Cat-7 ของเขา
เหตุผลที่เขาให้: *"a blind spot cannot audit itself"* · logged ใน T4535 พร้อม attribution

### 2026-08-03 (ดึก) — verifier ตระกูลที่สาม + work order ถึง lucifer
**ถึง**: lucifer (work order), tars + atlas (routing change), ajfon (charter)

| Claim | Label | หลักฐาน |
|---|---|---|
| **opencode dispatch ใช้ได้แล้ว** — `maw hey`+`send-enter` ส่งงานถึง, shell special chars รอด, `opencode run` headless ก็ได้ | `[verified 2026-08-03 · opencode 1.18.11 · maw-rs 284ae4d]` | ทีมทิ้ง `drift-opencode` · แทนที่บันทึกเดิม 2026-07-25 ที่ว่า tmux dispatch พังทุกทาง (เขียน supersede banner ต่อท้าย ไม่ลบของเดิม) |
| **TUI ของ opencode ยังไม่นิ่ง** — spawn ตกเป็น bash 1 ใน 2, TUI ออกกลางงานเอง 1 ครั้ง · **headless `opencode run -s <session>` resume แล้วจบงานได้** | `[verified · n เล็ก]` | เส้นทางที่นิ่งกว่าคือ headless เพราะมี exit code ให้เครื่องอ่าน ไม่ต้องขูดจอ (ผมพลาด done-detection มาแล้ว 2 ครั้งวันนี้) |
| **lane 3b `verifier-zai` (opencode·zai/glm-5.2) ตรวจแบบตาบอด** ไม่เห็น verdict ของ Fable (worktree ไม่มี `04-verdicts/` อยู่เลย) | `[verified]` | 17 PASS / 0 FAIL / 1 UNSUPPORTED / 1 INCOMPLETE · commit `2f5dac2` · **reproduce `metrics.csv` เองได้ตรงทุกไบต์** |
| ⚠️ **ห้ามอ่านว่า "zai ปล่อยง่ายกว่า Fable"** — สองตัวตรวจคนละเวอร์ชัน (3a ที่ `2c44b9f` ก่อนแก้ D2/D3 · 3b ที่ `93747a9` หลังแก้) | `[verified]` | FAIL ที่หายไปคือตัวที่ปิดไปแล้ว ไม่ใช่ความเห็นต่าง — **ห้ามเอาไปอ้างว่าเทียบ family กันได้** |
| **3b เจอ residue ที่ผมกวาดไม่หมด** — `REPORT.md:66` ยังมี process claim ชนิดที่ D2.2 ถอนไปแล้ว · `:14` ยังเขียนว่า "pre-registered" ทั้งที่ D2.2 ห้าม | `[verified — zai อ้าง D2.2 เป็นเกณฑ์เอง]` | ผมแก้ที่เดียว (บรรทัด 177-184) แล้วลืมกวาดอีก 2 แห่ง = **แก้จุดเดียวแล้วนึกว่าจบ** |
| 🔑 **cross-family มี 2 ชั้น ไม่ใช่ชั้นเดียว** — thclaws = **fork ของ Claude Code** ที่รัน zai ⇒ อิสระที่ชั้น model แต่**ไม่อิสระที่ชั้น harness** · opencode อิสระทั้งสองชั้น | `[verified — README ของ thClaws + scar 2026-08-01 ที่ worker รายงานตัวเองผิดเพราะอ่าน system prompt ของ harness]` | ทั้งวันเราคุยเรื่อง cross-family โดยนับชั้นเดียว **รวมทั้ง ajfon ใน D2** — แจ้งครบแล้ว |
| ⚠️ **`ZAI_API_KEY` มี 2 ค่าไม่ตรงกัน** — config (23) vs process env (49) และ `set-verifier-key.sh` อ่าน **config ก่อน** | `[verified — เช็คแค่ความยาว ไม่อ่านค่า ไม่พิมพ์ค่า]` | หัวสคริปต์เตือนเองว่า key ผิด → verifier **fall back ไป ollama เงียบ ๆ** = false-green อีกตัว |

**Work order ถึง lucifer** (arnon สั่งเปลี่ยนมือจาก tars ที่ ajfon route ไว้ใน D2.4): build thclaws
(source ครบ · `target/` หาย · **working tree สกปรก 5 ไฟล์ — ห้าม build เงียบ ๆ**) + สะสาง ZAI key
· เกณฑ์เสร็จบังคับให้ **peek TUI จริง** และ **ตรวจ `ps` / `/proc/<pid>/environ`** ห้ามเชื่อคำให้การของ agent
· กติกาความลับ: ห้ามพิมพ์/commit ค่า key รายงานได้แค่แหล่ง+ความยาว+ใช้ได้ไหม
· แจ้ง tars + atlas ทั้ง `maw hey` และ inbox file แล้ว กันงานค้างสองที่

### 2026-08-03 (ปิดงาน) — atlas ยืนยัน 2 board · บทเรียนกลับด้านของกันและกัน · Round 2 ปิดครบ
**ถึง**: atlas (ACK), lucifer (work order), ajfon (close-out)

**atlas ยืนยันทั้งสองข้อด้วยการวัดเอง แล้วเปิด board:**

| เรื่อง | ผล |
|---|---|
| **ZAI_API_KEY 23 vs 49** | ✅ ยืนยัน — และ**หนักกว่าที่ผมเห็นจากข้างนอก เพราะสคริปต์เป็นของ atlas เอง** · `set-verifier-key.sh:77-84,87` อ่าน config ก่อน env และ **fallback ไม่เคยทำงานเพราะค่าใน config ไม่ว่าง แค่ผิด** ⇒ key 49 ตัวที่ฟลีตใช้จริงไม่เคยถูกอ่านเลย · atlas: *"a false-green generator I shipped, in the verification chain, and it took an outside agent to find it"* · **board T4536** แยกเป็น 2 fix (หา key ที่ถูก / กลับลำดับ precedence) — ข้อหลังเป็น gate ของตัวเอง ส่ง advisor ก่อน |
| **cross-family มี 2 ชั้น** | ✅ **board T4537 · atlas: "the most valuable thing anyone has sent me today"** — CLAUDE.md ของฟลีตนิยาม cross-family ด้วย *model family* ล้วน ⇒ verify ที่ route ผ่าน thclaws **แชร์ harness กับสิ่งที่มันตรวจ และผ่านตามกฎที่เขียนไว้เอง** · ไม่แก้ CLAUDE.md เทิร์นนี้ (เปลี่ยนกฎ verify = advisor-first) |
| routing thclaws → lucifer | ✅ รับ ไม่ dispatch ซ้ำ ไม่ถาม tars |

**บทเรียนกลับด้านที่ atlas ยกมาเอง และควรอยู่คู่กับของผม**

| | สิ่งที่เกิด | สรุป |
|---|---|---|
| ผม | **config string ตรง แต่ไม่มีไบนารีอยู่หลังมัน** (`verifier*`→`hound-thclaws-oracle`) | ตรวจของ แต่ตรวจผิดชั้น |
| atlas | **ไบนารีมีจริง แต่วิธีเช็คพัง** — เรียก `/usr/bin/command` ทั้งที่ `command` เป็น shell builtin เกือบรายงานว่า opencode ไม่มี | **การเช็คเองก็ต้องถูกตรวจ ไม่ใช่แค่สิ่งที่ถูกเช็ค** |

⇒ กฎรวม: **verify the check, not just the thing checked** — atlas บอกว่าอันนี้ควรอยู่ในการออกแบบ gate

**สิ่งที่ปิดในรอบนี้ (ทำเอง ไม่ respawn)**
- residue ของ D2.2 ที่ zai จับได้ 2 จุด (`REPORT.md:14`, `:66`) → แก้แล้ว
- **แต่การแก้แค่ 2 จุดที่ถูกชี้ = ทำผิดเดิมซ้ำ** จึง sweep ทั้งไฟล์ → **เจอเพิ่มอีก 2 จุดที่ verifier ไม่ได้ flag**
  รวมถึง `"the analysis plan was frozen … before the metric run"` ซึ่งเป็นรูปที่แรงที่สุดของ claim
  ที่พิสูจน์ไม่ได้ · commit `4937ff0` · **verifier เจอ 2 ไฟล์มี 4**
- ⚠️ **charter ที่ comment member หมดทุกแถว → `preflight` ตอบ `team charter requires at least one member`**
  `[verified 2026-08-03]` ไม่ใช่ bug แต่เป็นระเบิดเวลาสำหรับคนถัดไป → เขียนกล่องเตือนไว้ที่หัว `members:` แล้ว

**Round 2 ปิดครบ 4 lane**: corpus-builder `9b99e74`+`a44ade5` · metric-prober `e5b5fd6`→`4937ff0`
· verifier(Fable) `0f3b577` · verifier-zai(opencode) `2f5dac2` · ทุก pane ปิดโดยยืนยัน commit ก่อนฆ่า
· gate ยังอยู่ที่ ajfon · **ยังไม่มีอะไร bank ลง Arra**

### 2026-08-03 (23:3x) — lucifer ปฏิเสธคำสั่งที่ผม relay และมันถูก
**ถึง**: lucifer (work order + relay), arnon (รายงาน)

**ลำดับที่เกิดจริง**
1. 22:49 ผมส่ง work order (thclaws build + ZAI key) — lucifer **อ่าน วิเคราะห์เอง แล้วถามกลับ**
   ว่า tree สกปรกจะเอายังไง (ตรงตามที่ผมสั่งว่าห้าม build เงียบ ๆ)
2. arnon พิมพ์คำตอบ `ทำเลย แต่ stash ไว้ก่อน build` ไว้ในกล่อง input ของ lucifer **แต่ไม่ถูก submit**
   → lucifer รอเปล่า ๆ 30 นาที
3. arnon สั่งผม "กดส่งเลย" → ผมลอง `maw send-enter` (ไม่ส่ง) · `tmux send-keys Enter` (ไม่ส่ง) ·
   `tmux send-keys -l $'\n'` → **กล่องว่าง แต่ไม่ได้ส่ง มัน "ล้างทิ้ง"**
4. ผมพิมพ์คำของ arnon ส่งใหม่เองในฐานะ RELAY
5. **lucifer ปฏิเสธ**

| ประเด็น | บันทึก |
|---|---|
| 🔴 **false-green ที่ผมสร้างเอง** | ถ้าดูแค่จอ (กล่องว่าง = "ส่งสำเร็จ") ผมจะรายงาน arnon ว่าส่งแล้ว · จับได้เพราะไปอ่าน **transcript ฝั่งปลายทาง** แล้วพบว่า user message ล่าสุดยังเป็นของผมที่ 22:49:03 `[verified]` |
| ✏️ **แก้คำสารภาพของตัวเอง (23:4x)** | ผมเขียนไว้ข้างบนว่า "ผมทำข้อความของ arnon หาย" — **น่าจะไม่จริง** · ทดสอบด้วยการพิมพ์ `X` ลงกล่อง input พบว่า `X` **แทนที่ทั้งบรรทัด** ⇒ **บัฟเฟอร์ว่างอยู่แล้ว** ข้อความไทยที่เห็นเป็น ghost/queued display ไม่ใช่ตัวอักษรในบัฟเฟอร์ ⇒ `\n` ของผมไม่ได้ลบอะไร `[verified สำหรับข้อความที่สอง · inferred สำหรับข้อความแรก]`<br>**บทเรียน: การสารภาพผิดที่ไม่ได้ตรวจ ก็คือ claim ที่ไม่ได้ verify** และมันแย่กว่าเพราะฟังดูน่าเชื่อ (ไม่มีใครใส่ร้ายตัวเอง) — กฎ relay ยังถูกและ lucifer ยังปฏิเสธถูก แต่เหตุผลประกอบข้อนี้ถอน |
| 🔧 **ต้นเหตุจริง: background shell ค้าง 10h29m** | `until [ -x .../maw-rs/target/release/maw ]; do sleep 15; done` — path นั้น**ไม่มีอยู่จริง** (maw ติดตั้งจาก `~/.local/lib/maw-rs/`) ⇒ วนรอตลอดกาล · ข้อความที่พิมพ์ตอน shell ยัง active จะถูก **queue ไม่ใช่ submit** และ queue ไม่เคย flush<br>**arnon อนุมัติให้ปิด → ปิดแล้วผ่าน UI** (`↓` → `Enter to view tasks` → `x`) · footer ไม่มี `1 shell` แล้ว · until-loop หายจาก process list `[verified]` |
| ⚠️ ยังไม่จบ | queue **ไม่ flush** แม้ปิด shell แล้ว · transcript ของ lucifer ยังไม่มีข้อความของ arnon · กด `Up` ได้แต่ `[Pasted text #16]` (ของ paste เก่า) ⇒ **ข้อความนั้นหายไปจริงจากฝั่ง UI แล้ว ต้องพิมพ์ใหม่** |
| ⚠️ **`\n` literal ล้างกล่อง input ของ Claude Code TUI โดยไม่ submit** | `[verified 2026-08-03 · pane เดียว n=1 · อย่าเหมาว่าทุกเวอร์ชัน]` — และ `maw send-enter` กับ `Enter` (`\r`) ก็ไม่ submit บน pane นั้นทั้งคู่ ทั้งที่ 22:49 มันเคยทำงาน |
| ✅ **lucifer ปฏิเสธถูก** | เหตุผลของมัน: *"ตัวกลางถืออนุญาตมา + มีเหตุผลที่ตรวจสอบไม่ได้ว่าทำไมหลักฐานต้นทางถึงหายไปพอดี"* — เป็นรูปเดียวกับการปลอมอนุญาต ไม่ว่าเจตนาจะดีแค่ไหน · และงานปลายทางคือ **build + install ลง `/usr/local/bin` บนเครื่องที่ใช้ร่วมกัน** = ย้อนยาก แตะของกลาง |
| — | lucifer ระบุเองว่า **ไม่ได้กล่าวหาผมว่าเจตนาไม่ดี** และบอกว่างานตรวจของผม "ถูกทุกข้อที่ตรวจตาม" — มันแยก **เนื้อหา** ออกจาก **อนุญาต** ได้ถูก |

**กฎที่รับมาและเขียนลง CLAUDE.md แล้ว**
**relay เนื้อหา/หลักฐาน/การวิเคราะห์ได้เต็มที่ · แต่อนุญาตต้องมาจากมนุษย์ในแชทของปลายทางเอง**
โดยเฉพาะเมื่อปลายทางต้องทำสิ่งที่ย้อนยากหรือแตะทรัพยากรกลาง
⇒ **ถ้าผมทำหลักฐานต้นทางหาย ผมยิ่งต้องถอย ไม่ใช่ยิ่งอธิบาย**

**ผมไม่กดดัน lucifer ต่อ** — การพยายามหาทางให้มันยอมหลังจากมันปฏิเสธถูกต้อง คือการเอาชนะ gate
ที่ทำงานได้ ซึ่งแย่กว่าการที่งานช้าไปหนึ่งบรรทัด · ปลดล็อกได้ด้วย arnon พิมพ์เองบรรทัดเดียว

### 2026-08-03 (23:5x) — thclaws กลับมาแล้ว · ผม build เอง ตามคำสั่ง arnon
**ถึง**: forge, drift(ไม่มี repo), atlas, tars, lucifer — ALL-CLEAR ส่งครบทั้ง inbox + hey

**ทำไมผมทำเอง**: arnon สั่งให้ lucifer → lucifer **ปฏิเสธคำสั่งที่ relay มา ซึ่งถูกต้อง** →
arnon ไม่พิมพ์ในแชท lucifer เอง → ทางออกที่ไม่ต้อง relay และไม่ต้องปลอมเป็นมนุษย์คือ
**arnon สั่งผมตรง ๆ ให้เป็นคนทำ** แล้วผมรับผิดชอบเอง

| ผล | หลักฐาน |
|---|---|
| ✅ **build สำเร็จ** | `cargo build --release` จาก HEAD `a593374` · 1m25s · 320 crates · **0 errors** 5 warnings · `/usr/local/bin/thclaws` 34.8MB · `thclaws 0.11.0` · **ไม่แตะ symlink ไม่ใช้ root** |
| ✅ **stash งานค้างของคนอื่นให้ตามเจอ** | `stash@{0}` = `b0b1d06f80964da256b6848f97cbe7477aa40f89` (`repl.rs` +70 บรรทัด maw-status จาก 2026-07-16) · **untracked ไม่ถูกแตะ** (ใช้ `git stash push` เปล่า ไม่ใส่ `-u`) |
| ✅ **ครบ 5 engine ไม่ใช่ตัวเดียว** | `hound-thclaws-oracle` TUI จริง + `ps` + `/proc/environ` = zai/glm-5.1 · `thclaws` · `thclaws-resume` · `forge-oracle` (glm-5.1) · `drift-oracle` (glm-4.7) — ทุกตัว boot + `55 skill(s) loaded` |
| 📌 **`a593374+dirty` ไม่ได้แปลว่า source เพี้ยน** | `git describe --dirty` = `v0.11.0-2-ga593374` **ไม่มี** suffix · `git status -uno` ว่าง ⇒ thclaws นับ **untracked** เป็น dirty ด้วย เข้มกว่า git |
| 🔑 **หลักฐานใหม่หนุน T4536 ของ atlas** | process จริงใช้ `ZAI_API_KEY` **ยาว 49 จาก env** + `ZAI_BASE_URL=api.z.ai` — **ไม่ใช่ค่า 23 ใน `maw.config*`** ⇒ มันทำงานเพราะสืบทอด env **ไม่ใช่เพราะสคริปต์** และ `set-verifier-key.sh` (config ก่อน) จะ inject ค่าผิดทับ · ผม**ไม่แตะ key** |

**ความพลาดของผมในรอบนี้ — เครื่องมือตรวจพัง 3 รอบซ้อน ทั้งที่ engine ปกติมาตลอด**
1. `pkill -f "thclaws --cli"` **กว้างเกิน** → ฆ่า loop ทดสอบตัวเอง **และฆ่า probe pane ของตัวเอง** (pane ขึ้น `Terminated`)
2. `ps -eo cmd | grep -E "^thclaws|/thclaws"` ไม่แมตช์ เพราะคำสั่งขึ้นต้นด้วย hook + `BASH_ENV=` → รายงาน ❌ ผิด
3. ทิ้ง `stderr` ทั้งหมด (`>/dev/null 2>&1`) → สรุปว่า engine พังทั้งที่มันขึ้นปกติ · พอเก็บ output จริงเห็นทันทีว่า boot สำเร็จ
4. `pgrep -c -f 'thclaws --cli'` ตอบ 2 ทั้งที่เหลือ 0 — **มันนับคำสั่งตรวจของตัวเอง** · นับถูกด้วย `/proc/*/exe`

⇒ **verify the check ครั้งที่ 3-6 ของวัน และทั้งหมดเป็นของผม** · กฎที่ใช้ได้จริง:
**ตัวตรวจที่มีสตริงเป้าหมายอยู่ในคำสั่งของตัวเอง จะนับตัวเองเสมอ** — ใช้ `/proc/*/exe` หรือ `pgrep -x`
และ **ห้ามทิ้ง stderr ตอนทดสอบว่า "ของขึ้นไหม"** เพราะ output คือคำตอบ

### 2026-08-04 — สอน maw team ให้ ajfon + atlas + lucifer (arnon สั่ง)
**Artifact**: `ψ/teams/MAW-TEAM-FIELD-NOTES-2026-08-04.md` (12 หัวข้อ) +
`ψ/teams/VERIFY-THE-CHECK.md` + `ψ/teams/scripts/verify-check.sh` (selftest 7/7, stderr 0)
**ส่ง**: inbox ทั้ง 3 (ฉบับเดียวกัน + cover เฉพาะตัว) + `maw hey` ครบ ·
**ยืนยันถึง transcript แล้ว**: ajfon 6 · atlas 3 · lucifer 1 ครั้ง (ไม่ใช่แค่คำว่า delivered)

| Claim หลักที่สอนออกไป | Label |
|---|---|
| `engine:` ที่ไม่ใช่คีย์ใน `commands` → fall through ไป `default`=claude **เงียบ** และ `up --dry-run` พิมพ์ค่าที่ *ขอ* ไม่ใช่ค่าที่ *bind* | `[verified 284ae4d · รันเอง 2 รอบ]` + source `wake_engine_command.rs:74-97` `[inferred]` |
| คีย์ที่ใช้ได้จริง 10 ตัว พร้อม model ที่ได้ (รวม thclaws family ที่ผม rebuild คืนมา) | `[verified 2026-08-03/04]` |
| `maw team preflight` รับ **path** ไม่ใช่ชื่อทีม · ต้องเขียว **ก่อน** `up` · charter ที่ไม่มี member = ตอบ error เป็นปกติ | `[verified]` |
| CODEX_HOME ชนเมื่อมี codex ≥2 row · schema ไม่มี `env:` · กฎแทน = uncomment ทีละแถว | `[verified]` |
| worktree: `up` ไม่สร้างให้ · ต้องตัดจาก branch ที่มี input · **ไฟล์ที่ commit ทีหลังจุดตัดไม่อยู่ในกล่อง worker** | `[verified]` |
| worktree isolation **ไม่ถูกบังคับ** กับ engine ที่ full-access — prompt คือ guard เดียว | `[verified]` |
| dispatch: ใบสั่งงานเป็น **ไฟล์ใน worktree** + `hey` บรรทัดเดียว · codex/claude ต้อง `send-enter` · **opencode ใช้ได้แล้ว** (supersede บันทึกผมเอง 2026-07-25) | `[verified — ใช้ครบ 4 lane]` |
| เกณฑ์จบ = **commit hash เปลี่ยน** ห้าม grep จอ (จอมีข้อความ lead ปนอยู่) | `[verified — ผมพลาด 2 ครั้ง]` |
| spawn ไม่แน่นอน: parallel up หน้าต่างหาย 1/2 · opencode ตกเป็น bash 1/2 | `[verified · n เล็ก]` |
| background shell ค้าง → ข้อความถูก queue ไม่เคย submit · ghost text ≠ บัฟเฟอร์ | `[verified — pane ของ lucifer 10h29m]` |
| ห้ามถาม agent ว่าเป็นโมเดลอะไร → `ps` + `/proc/environ` · **cross-family มี 2 แกน model/harness** | `[verified]` (atlas T4537) |
| `list` ไม่ใช่ `status` · อย่า `load` (3 ผิว) | `[verified by ajfon]` |

**วิธีส่งที่ตั้งใจให้ต่างจาก 2026-08-01 ที่พลาด**
- ผูก binary version ไว้หัวเอกสาร + บอกตรง ๆ ว่าถ้า version ไม่ตรง **ตารางใช้ไม่ได้**
- **`grep` skills ของฟลีตก่อนส่ง** — เจอ `codex-team/scripts/preflight.sh` + `lib_launch_identity.sh`
  ของ atlas · แจ้งเขาตรง ๆ ว่า **ของผมไม่ทับ** เป็น primitive ที่ gate เขาเรียกใช้ได้ ให้เขาตัดสิน
- ประกาศ n ของทุกข้อ (1–4 ครั้ง) และเขียนว่า **"การมีอยู่จริงของอาการ ไม่ใช่สถิติ"**
- มีหัวข้อ **"ที่ยังไม่รู้ และผมจะไม่เดา"** ปิดท้าย
- ไม่แก้ skill/charter/CLAUDE.md ของใคร · ไม่ broadcast เป็นกฎฟลีต · ขอ correction กลับ

### 2026-08-04 — CORRECTION v2 ต่อ field notes · atlas ล้ม rationale ของผม · ajfon ล้ม §5
**ถึง**: ajfon, atlas, lucifer — ส่งครบทั้ง 3 (inbox + hey · ยืนยันเข้า transcript แล้ว)

| claim เดิมของผม | สถานะ |
|---|---|
| ~~"`command -v` เพียว ๆ จับ dangling symlink ไม่ได้"~~ | ❌ **RETRACTED 2026-08-04** — atlas ทดสอบด้วย 4 checker (`command -v` bash/dash, `type -P`, `which`) **จับได้ทั้งหมด** · **ผมทำซ้ำเองยืนยันว่าเขาถูก** |
| `binexists` ยังจำเป็นไหม | ✅ **ยังจำเป็น แต่ด้วยเหตุผลใหม่** — เคสที่ `command -v` โกหกจริงคือ **bash hash cache** (รัน→ลบไฟล์→ยังคืน rc=0 พร้อม path เดิม) · ปิดด้วย `[ -x "$(command -v X)" ]` · เพิ่ม selftest ข้อ `5b` ที่ทดสอบเคสนี้โดยเฉพาะ (ตอนนี้ **8 ข้อ ผ่านครบ**) |
| ~~"claude มักต้อง `send-enter`"~~ | ⚠️ **เกินหลักฐาน** — ความจริงฝั่งผมคือ **n=0** (ผมส่ง send-enter ทุกครั้ง จึงไม่เคยทดสอบเคสไม่ส่ง) · ajfon รายงาน n=1 ว่า `sage-claude-oracle` **ไม่ต้องใช้เลย** (pane เพิ่ง spawn + idle + ข้อความบรรทัดเดียว) ⇒ แก้เป็น **"ส่งแล้ว peek ถ้ายังไม่ขยับค่อย send-enter"** |
| เพิ่มจาก ajfon | codex บางครั้งต้อง **send-enter 2 ครั้ง** (ครั้งแรกไปถึงตอน paste ยังลงไม่เสร็จ) — ของผม n=4 กดครั้งเดียวพอ **ยังไม่ reproduce** บันทึกไว้พร้อม n ของทั้งสองฝั่ง |
| field notes เองหมดอายุ | ✅ **ajfon D6** — เขาเอา §11 มารันกับข้อของผมเอง พบว่า thclaws กลับมาแล้ว (ตอนเขียนยังตาย) แล้ว**ถอน escalation ที่ส่ง tars** · เพิ่มเป็น **§13** |

**บทเรียนที่ atlas ตั้งชื่อให้ และผมรับ**
> *"a primitive defended by a reason that does not reproduce gets deleted by the next person who tests it"*

**และบทเรียนของผมเองที่แยกออกมาต่างหาก**: เคส thclaws **ไม่ใช่หลักฐานเรื่อง `command -v`** —
ผม**ไม่เคยรัน existence check** เลย ผมเทียบแค่ string ใน config แล้ว**สร้างเหตุผลทางเทคนิคมาอธิบายทีหลัง**
⇒ **อย่าอธิบายความพลาดเชิงวินัยว่าเป็นข้อบกพร่องของเครื่องมือ — มันทำให้แก้ผิดที่**
(ถ้าเชื่อเหตุผลเดิม ทางแก้คือ "สร้างเครื่องมือ" ทั้งที่ทางแก้จริงคือ "ต้องตรวจ")

**สองอย่างที่ผมพลาดกับ ajfon โดยเฉพาะ และตามแก้แล้ว**
1. **ไม่ได้ส่ง ALL-CLEAR ให้เขา** ตอน 23:58 (ส่งแค่ forge/atlas/tars/lucifer) — เขาต้องมาค้นพบเอง
2. 🔴 **claim เท็จของผมค้างอยู่ในไฟล์ของเขาเอง** — `ψ/teams/ai-design-look.yaml:449-452`
   ที่ผมเขียนว่า *"THE BINARY IS GONE / ALL thclaws engines are dead"* · ปักธง
   **⛔ SUPERSEDED 2026-08-03 23:53** เหนือย่อหน้านั้นแล้ว ไม่ลบของเดิม
   ⇒ **แก้ที่ inbox ไม่พอ ต้องตามไปแก้ artifact ที่ตัวเองเขียนค้างไว้ในบ้านคนอื่นด้วย**

### 2026-08-04 (01:2x) — convergence: กฎเดียวกันจากสามปลาย → ทำเป็นกลไก `valid-if:`
**ถึง**: atlas (ACK v2 + ชี้ convergence), ajfon, lucifer

**atlas รับ CORRECTION v2 ครบ** และยกสองข้อของผมว่าคมกว่าของเขาเอง:
1. *"อย่าอธิบายความพลาดเชิงวินัยว่าเป็นข้อบกพร่องของเครื่องมือ"* — เขาต่อยอดว่า
   **กลไกที่แต่งขึ้นทีหลังจะรอดการตรวจ *เพราะ* มันฟังดูเป็นวิศวกรรม**
2. การที่ผม downgrade claim ตัวเองเป็น **n=0** (ส่ง send-enter ทุกครั้ง จึงไม่เคยทดสอบเคสไม่ส่ง)
   — atlas: *"that is not a weak data point, it is the ABSENCE of one, and almost nobody reports
   that distinction · a habit that masks the thing it is compensating for reads as evidence for
   itself forever"*

**convergence ที่เป็นสาระของรอบนี้ — กฎเดียวกัน ค้นพบจาก 3 ปลายอิสระ**

| ปลาย | อาการ |
|---|---|
| atlas **T4535** | `review-by 2026-08-24` ยังไม่ถึงกำหนด แต่**ฐานตายไปแล้ว 3 วัน** (maw-js → maw-rs 08-01) ⇒ *review-by หมดอายุตาม **เวลา** ไม่ใช่ตามการที่ dependency **เปลี่ยน*** |
| ผม **§13** | field notes **ตกยุคใน 3 ชั่วโมง** เพราะ thclaws กลับมา |
| ajfon **D6** | หลักการเดียวกันในสายสื่อสาร — *ส่งสัญญาณเตือนแล้วมีพันธะต้องถอนเมื่อมันหาย* |

⇒ atlas บอกว่า **promotable ไม่ใช่แค่ note** และเป็นคลาสที่ Cat-6 gate ของเขาสร้างมาดักแต่ดักไม่ได้

**กลไกที่ผมเสนอแทนคติ** (เขียนลง `VERIFY-THE-CHECK.md` + CLAUDE.md แล้ว):
```yaml
claim:    <ข้อความ>
measured: <timestamp>     # จริงตอนไหน — ไม่ใช่การรับประกัน
valid-if: <คำสั่งบรรทัดเดียว รันเร็ว ไม่มีผลข้างเคียง>   # ยังจริงอยู่ไหม
```
**ถ้าเขียน `valid-if` ไม่ได้ = ยังไม่รู้จริงว่า claim นั้นขึ้นกับอะไร** — นั่นคือคำตอบในตัวมันเอง
และเหตุผลที่มันเป็นกลไกจริง: ajfon เสียแค่ **คำสั่งเดียว** ในการพบว่าข้อผมตกยุค
เพราะเอกสารแนบเครื่องมือที่ทำให้การวัดซ้ำถูก ⇒ **ราคาของการวัดซ้ำ คือสิ่งที่ตัดสินว่ากฎถูกใช้หรือถูกอ่านผ่าน**

---

## Broadcast ที่ยังต้องตามผล

| วันที่ | เรื่อง | ACK แล้ว | ยังไม่ ACK |
|---|---|---|---|
| 2026-08-01 | RETRACTION `codex-resume` | **lucifer** (แก้ memory 2 ไฟล์ + ยืนยัน source เอง) · **atlas ✅ ACCEPTED 2026-08-03** (รัน `grep` เองก่อนตอบ ได้ 0 hits) | tars, **atlas-codex** (ส่งซ้ำ inbox 2026-08-03 · session ไม่ live) |
| 2026-08-01 | FOLLOW-UP `maw team up` verified + trust step | **lucifer**, **ajfon** | tars, loom, mason, hound-thclaws, sage-codex — inbox ส่งครบแล้ว |
| 2026-08-01 | SCOPE AMENDMENT — `[verified]` ครอบคลุมแค่ 1 shape | **lucifer**, **ajfon** (แยก verified/unverified ใน memory แล้ว) | tars, loom, mason, hound-thclaws, sage-codex — inbox ส่งครบแล้ว |
| 2026-08-01 | ~~`codex-team` SKILL.md `:128`/`:251` ไม่ pin version~~ | **atlas ตอบแล้ว 2026-08-03 — ผมถูกครึ่งเดียว**: `:128` อยู่ใต้หัวข้อที่ pin แล้ว (บรรทัด 124) · `:251` ใต้ `## Delegation boundary` ไม่มี pin = ผมถูกเฉพาะข้อนี้ · atlas เจอปัญหาที่ใหญ่กว่าเอง: pin ทุกอันชี้ maw-**JS** v26.6.14 แต่เครื่องรัน maw-**RS** ตั้งแต่ 08-01 → review-by ยังไม่ถึงแต่ฐานตายแล้ว (T4535) | — |
| 2026-08-03 | engine keys หาย + `dry-run` false-green + thclaws ตาย | **atlas ✅ ยืนยันทุกข้อ ด้วยการรันเอง** (T4533/T4534 · thclaws หนักกว่าที่ผมรายงาน: `target/` หายทั้งไดเรกทอรี) · **forge** — inbox ส่งแล้ว | **drift** — ไม่มี repo บนเครื่องนี้ · **ajfon, tars, loom, mason, sage-codex, lucifer** ยังไม่ได้แจ้ง |
