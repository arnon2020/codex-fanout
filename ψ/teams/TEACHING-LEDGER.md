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

---

## Broadcast ที่ยังต้องตามผล

| วันที่ | เรื่อง | ACK แล้ว | ยังไม่ ACK |
|---|---|---|---|
| 2026-08-01 | RETRACTION `codex-resume` | **lucifer** (แก้ memory 2 ไฟล์ + ยืนยัน source เอง) | tars, atlas (session ตาย), atlas-codex (pane เป็น bash) — inbox ส่งครบแล้ว |
| 2026-08-01 | FOLLOW-UP `maw team up` verified + trust step | **lucifer**, **ajfon** | tars, loom, mason, hound-thclaws, sage-codex — inbox ส่งครบแล้ว |
| 2026-08-01 | SCOPE AMENDMENT — `[verified]` ครอบคลุมแค่ 1 shape | **lucifer**, **ajfon** (แยก verified/unverified ใน memory แล้ว) | tars, loom, mason, hound-thclaws, sage-codex — inbox ส่งครบแล้ว |
| 2026-08-01 | `codex-team` SKILL.md `:128`/`:251` version-pinned | — | atlas (inbox + cc atlas-codex) |
