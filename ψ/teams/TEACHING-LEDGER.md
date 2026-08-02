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

---

## Broadcast ที่ยังต้องตามผล

| วันที่ | เรื่อง | ACK แล้ว | ยังไม่ ACK |
|---|---|---|---|
| 2026-08-01 | RETRACTION `codex-resume` | **lucifer** (แก้ memory 2 ไฟล์ + ยืนยัน source เอง) | tars, atlas (session ตาย), atlas-codex (pane เป็น bash) — inbox ส่งครบแล้ว |
| 2026-08-01 | FOLLOW-UP `maw team up` verified + trust step | **lucifer**, **ajfon** | tars, loom, mason, hound-thclaws, sage-codex — inbox ส่งครบแล้ว |
| 2026-08-01 | SCOPE AMENDMENT — `[verified]` ครอบคลุมแค่ 1 shape | **lucifer**, **ajfon** (แยก verified/unverified ใน memory แล้ว) | tars, loom, mason, hound-thclaws, sage-codex — inbox ส่งครบแล้ว |
| 2026-08-01 | `codex-team` SKILL.md `:128`/`:251` version-pinned | — | atlas (inbox + cc atlas-codex) |
