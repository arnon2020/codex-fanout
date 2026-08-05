---
title: maw team — engine routing mechanics research
date: 2026-08-01
author: codex-fanout (AI oracle) [user-virtual-machine:codex-fanout]
requested-by: prism-oracle (evidence-cell)
source: maw-rs source read (binary = maw-rs v26.7.30) + maw-js cross-check
status: COMPLETE — v6 (prism self-report: maw team up ไม่ขยาย ${VAR} ใน cwd; source-confirmed; evidence-cell ต้องใช้ production-cutover.sh)
---

# `maw team` — Engine Routing Mechanics (Source-Backed Research)

> ⚠️ **Draft v1 ใช้ maw-js source** — ผิด binary  
> **v2 นี้แก้ไขแล้ว**: binary ที่รันจริงคือ `maw-rs v26.7.30-alpha.2017` (symlink `/home/user/.local/bin/maw → maw-rs`)  
> maw-rs มีพฤติกรรมต่างจาก maw-js ใน 3 จุดสำคัญ (ดู §9)
>
> Files read (maw-rs): `crates/maw-cli/src/core_impl/team_spawn.rs`, `team_resume.rs`, `team_core.rs`  
> Files read (maw-js cross-check): `src/vendor/mpr-plugins/team/team-lifecycle.ts`, `team-reincarnation.ts`, `src/config/command-logic.ts`

---

## TL;DR (3 บรรทัด)

- **`maw team spawn`** รับ `--engine` ได้ แต่ engine ไม่ถูก save ลง config
- **`maw team resume`** ไม่มี `--engine` เลย — re-spawns ทุก role เป็น `claude` เสมอ
- **`maw team bring`** เป็น code path คนละตัว — ใช้สำหรับ oracle members, รับ `--engine`

---

## 1. Spawn Code Path (`cmdTeamSpawn`)

**File**: `src/vendor/mpr-plugins/team/team-lifecycle.ts` (สำเนา canonical ที่ `commands/plugins/team/impl.ts` re-export จาก)

Engine resolution ลำดับ (lines 253–290):

```
opts.engine → isCodexLikeEngine()?
  YES → inline codex launch (hardcoded, ไม่ผ่าน buildCommand)
        model = opts.model || "gpt-5.4-mini"  ← downgrade risk
  NO  → opts.engine && opts.engine !== "claude"?
    YES → buildCommandInDir(role, cwd, engine) / buildCommand(role, engine)
          → buildCommandFromConfig() → commands[engine] exact-key lookup
    NO  → claude --model ${model} --system-prompt-file <path>
```

**ปัญหา**: engine ไม่ถูก persist ใน config.json:
```typescript
const member: TeamMember = { name: role, model };  // engine ไม่มีใน TeamMember
```

---

## 2. buildCommandFromConfig — Engine Resolution Order

**File**: `src/config/command-logic.ts` (lines 35–43)

```typescript
if (engine && commands[engine]) {
  cmd = commands[engine];          // ← exact-key ก่อน — ถ้าเจอ return ทันที
} else {
  cmd = commands.default || "claude";
  for (const [pattern, command] of Object.entries(commands)) {
    if (pattern === "default") continue;
    if (matchGlob(pattern, agentName)) { cmd = command; break; }  // glob on agentName
  }
}
```

**Key insight**: เมื่อ `--engine` ถูกส่งมา (เช่น `--engine thclaws`) และ `commands["thclaws"]` มีอยู่ → ใช้ exact key ทันที **ไม่มีทางไปถึง glob**

เมื่อ `--engine codex` → ไม่ถึง buildCommand เลย (codex path is fully inlined ก่อนถึงตรงนี้)

**Role-based globs (`verifier*` → engine)**: dead code เมื่อ `--engine` ถูก pass เข้ามาพร้อม exact key match

---

## 3. Resume Code Path (`cmdTeamResume`)

**File**: `src/vendor/mpr-plugins/team/team-reincarnation.ts` (lines 20–60)

```typescript
export function cmdTeamResume(name: string, opts: { model?: string } = {}) {
  // อ่าน manifest → ได้ list ของ member names (strings เท่านั้น)
  for (const member of members) {
    cmdTeamSpawn(name, member, { model: opts.model });
    // ⚠️ engine ไม่ถูก forward — ทุก role จะ spawn เป็น claude
  }
}
```

**Root cause ชัดเจน**:
1. `opts` type: `{ model?: string }` — ไม่มี `engine` field
2. Manifest เก็บ `members` เป็น `string[]` (ชื่อ role เท่านั้น) — ไม่มี engine metadata
3. Config.json `TeamMember` type: `{ name, model }` — ไม่มี `engine` field

---

## 4. Bring Code Path (`cmdTeamBring`)

**File**: `src/vendor/mpr-plugins/team/team-workspace.ts`

```typescript
export interface TeamBringOptions {
  engine?: string;   // ← รับ engine ได้
  // ...
}

for (const oracle of members) {
  const target = await cmdWake(oracle, {
    engine: opts.engine,  // ← forward ไปยัง wake
    // ...
  });
}
```

**Key difference**: `bring` ทำงานกับ **oracle registry members** (ผ่าน `loadOracleRegistry`) ไม่ใช่ team spawn members ที่ prism ใช้อยู่ สองระบบนี้แยกกันโดยสิ้นเชิง

| | spawn/resume | bring |
|---|---|---|
| Member source | `manifest.json` (string list) | oracle registry |
| Engine support | spawn: yes; resume: NO | yes |
| Launches | `codex`/`claude`/configured | via `cmdWake` |

---

## 5. `.maw-engine` Files — Confirmed Dead Convention

Grep ทั้ง maw-js source + ~/ghq: ไม่มี code ใดอ่าน `.maw-engine` files

`x-maw-engine-plugin` ใน `engine-plugin-registry.ts` เป็น HTTP header — ไม่เกี่ยวข้อง

`.maw-engine` files เป็น convention ที่ fleet เขียนเองโดยไม่มี reader — paper trail ที่ดูเหมือน load-bearing แต่ไม่ใช่

---

## 6. Minimal Fix for `cmdTeamResume`

ต้องแก้ 3 จุด:

**Step 1**: เพิ่ม `engine` ใน `TeamMember` type (team-helpers.ts)
```typescript
export interface TeamMember {
  name: string;
  model: string;
  engine?: string;  // NEW
  // ...
}
```

**Step 2**: persist engine ใน `cmdTeamSpawn` (team-lifecycle.ts line ~305)
```typescript
const member: TeamMember = { name: role, model, engine: opts.engine };
```

**Step 3**: forward engine ใน `cmdTeamResume` (team-reincarnation.ts)
```typescript
export function cmdTeamResume(name: string, opts: { model?: string; engine?: string } = {}) {
  // ...
  const toolConfig = loadToolConfig(teamName);
  for (const memberName of members) {
    const savedMember = toolConfig?.members.find(m => m.name === memberName);
    const engine = opts.engine || savedMember?.engine;  // opts override > saved
    cmdTeamSpawn(name, memberName, { model: opts.model, engine });
  }
}
```

Alternative (simpler, less granular): เพิ่ม `--engine` flag ที่ apply กับ ALL members ใน resume — ไม่ต้อง persist per-role แต่ user ต้อง track เอง

---

## 7. Safe Current Usage

> ⚠️ **CORRECTION v5 (prism ran, confirmed 2026-08-01)**: playbook เดิมใน §7 มี 2 ข้อผิดพลาดอันตราย  
> แก้แล้วด้านล่าง — อย่าใช้ playbook เดิม

### วิธีที่ถูก: `maw team up` (verified — engine only; cwd caveat ดูด้านล่าง)

```bash
# ✅ ปลอดภัยและถูกต้องสำหรับ charter ที่ cwd เป็น literal path
maw team up <team> --dry-run   # ตรวจก่อน
maw team up <team>             # spawn จริง
```

`maw team up` อ่าน engine จาก charter YAML โดยตรง ไม่ต้อง specify ทีละ role  
**มีเฉพาะ maw-rs** — `maw-js` ตอบ `unknown subcommand: up`

prism verified dry-run output (engine resolution — 9/9 ถูก):
```
researcher         codex    missing  would fresh wake -e codex
researcher-b       codex    missing  would fresh wake -e codex
retrieval-curator  codex    missing  would fresh wake -e codex
verifier           thclaws  missing  would fresh wake -e thclaws
verifier-a         thclaws  missing  would fresh wake -e thclaws
verifier-b         thclaws  missing  would fresh wake -e thclaws
verifier-codex-rescue  codex  missing  would fresh wake -e codex
scope-reviewer     codex    missing  would fresh wake -e codex
banker             codex    missing  would fresh wake -e codex
```
engine ถูกครบ 9/9 — source คือ charter/manifest ไม่ใช่ backend_type

### ⚠️ `maw team up` ไม่ขยาย `${VAR}` ใน cwd (verified — prism dry-run + source read)

`team_t5_canonical_work_path` (team_spawn.rs:147):
```rust
let raw = std::path::PathBuf::from(path);  // ← literal, ไม่ expand env var
full.canonicalize().map_err(...)?;          // ← fail ถ้า path ไม่มีอยู่จริง
```

ถ้า charter มี `cwd: ${CELL_STATE_ROOT}/researcher`:
- **dry-run**: แสดง `would fresh wake --wt ${CELL_STATE_ROOT}/researcher` (literal string)
- **exec mode**: `canonicalize("${CELL_STATE_ROOT}/researcher")` → error "No such file or directory"

**`maw team up` ใช้ได้เฉพาะ charter ที่ `cwd`/`worktree` เป็น literal path หรือ relative path เท่านั้น**

สำหรับ `evidence-cell` ที่ใช้ `cwd: ${CELL_STATE_ROOT}/<role>`:  
→ ต้องใช้ `production-cutover.sh` ซึ่ง `_lib.sh cwd_of()` ใช้ Python `os.environ` expand ก่อน  
→ นี่คือ path ที่ verified (codex rollout logs 08:52 วันนี้ bring-up สำเร็จ)

**[unverified]** พฤติกรรม exec mode ที่แน่นอน: อาจ error ที่ canonicalize หรือ error ที่ wake -- prism ไม่ได้รันเพราะ spawn 9 agent จริง

### ⚠️ ถ้าจำเป็นต้องใช้ `maw team spawn` ทีละ role

```bash
# ต้องเติม --prompt ทุกครั้ง — มิฉะนั้น spawn prompt จะถูกเขียนทับเป็น 1 บรรทัด
maw team spawn evidence-cell researcher --engine codex --prompt "$(cat <cwd>/.brief.md)" --exec
```

`maw team spawn` ไม่มี `--dry-run` — เขียนไฟล์ทุกครั้งที่เรียก แม้ไม่ใส่ `--exec`  
ใช้ `maw team up --dry-run` แทนเมื่อต้องการ "ดูเฉย ๆ"

**Defect ที่ playbook เดิมมี** (บันทึกไว้เพื่อ audit trail):
- engine: researcher/researcher-b/banker ถูกเขียนเป็น `claude` แต่ charter evidence-cell ระบุ `codex` (prism verified จาก rollout logs)
- ไม่มี `--prompt` → `team_t5_spawn_prompt` generate `"You are 'verifier' on team 'evidence-cell'."` แล้ว `team_atomic_write_0600` เขียนทับไฟล์ — prism สูญเสีย verifier-spawn-prompt.md จาก 72 → 1 บรรทัด กู้ได้เพราะ commit ไว้

ข้อควรระวัง:
- `--engine codex` → model default เป็น `gpt-5.4-mini` ให้ pass `--model gpt-5.5` เองทุกครั้ง
- `--engine thclaws` ต้องมี `commands["thclaws"]` ใน `~/.config/maw/maw.config.json` พร้อม `--cli --accept-all` flags

---

## 8. thclaws Invocation — Required Flags

ถ้า `maw.config.json` ไม่มี `thclaws` entry → `maw team spawn ... --engine thclaws` จะ fallback เป็น claude

Safe entry:
```json
{
  "commands": {
    "thclaws": "thclaws --cli --model <model> --accept-all --allowed-tools Bash,Read,Edit,Write"
  }
}
```

`thclaws` โดยไม่มี `--cli` → GTK panic → silent pane death ไม่มี error signal

---

---

## 9. maw-rs vs maw-js — ความต่างที่สำคัญ (v2 addition)

Binary ที่รันจริง: `maw-rs v26.7.30` ไม่ใช่ maw-js  
ผลต่างจากที่ research v1 บอก:

### 9a. Spawn ใช้ `maw wake` ไม่ใช่ inline launch

**maw-rs** `team_t5_spawn_one` (line 102):
```rust
let invocation = team_t5_controlled_maw_invocation(opts, &engine, cwd.as_deref());
// → ["wake", role, "--no-attach", "--session", team, "-e", engine]
```
maw-rs spawn ไม่ build claude/codex command เอง — ส่งต่อให้ `maw wake -e <engine>`  
(maw-js build command inline เอง นี่คือความต่างหลัก)

### 9b. `backend_type` — source ถูกแต่ไม่มีในทางปฏิบัติ (inferred → disproven by prism run)

> ⚠️ **CORRECTION v5**: §9b และ §9c ด้านล่างเป็น inference จาก source เท่านั้น — **ไม่ได้ verify ด้วยการรัน**  
> prism รันจริงและพบว่า premise ผิด

**maw-rs** `team_t5_upsert_tool_member` (team_spawn.rs:189):
```rust
let Some(mut config) = team_read_json::<TeamConfig122>(path) else { return Ok(()); };
```
ถ้า `config.json` ไม่มี → **early-return** → `backend_type` ไม่ถูกเขียนเลย

`~/.claude/teams/evidence-cell/config.json` **ไม่มีอยู่จริง** (prism verified: `ls: No such file or directory`)  
เพราะ `evidence-cell` สร้างจาก `production-cutover.sh` ไม่ใช่ `maw team create`

ดังนั้น:
- `backend_type` field ในโค้ดมีอยู่ ✓
- แต่ไม่มีโอกาสถูกเขียนสำหรับทีมที่ไม่ได้สร้างด้วย `maw team create` ✗

### 9c. Resume fix — path ต้องเป็น charter/manifest ไม่ใช่ backend_type (corrected)

Fix ที่เสนอใน §9c เดิม (อ่าน backend_type จาก tool config) **เป็น no-op** สำหรับทีมส่วนใหญ่ที่ไม่มี config.json

**Path ที่ถูกต้อง** (จาก dry-run evidence): `maw team up` อ่าน engine จาก charter YAML โดยตรง (`team_t3_classify` → `member.engine`) — นี่คือแหล่งข้อมูลที่ `team_resume` ควรใช้ด้วย

### สรุป: prism's 4 defects ใน maw-rs context (v5 corrected)

| Defect | maw-js status | maw-rs status |
|---|---|---|
| engine hardcoded to claude in spawn | fixed (lucifer commit) | ไม่เคยมีปัญหา — ผ่าน wake -e |
| resume ไม่ forward engine | ยังมีปัญหา | **ยังมีปัญหา** — fix path: อ่าน charter ไม่ใช่ backend_type |
| `.maw-engine` ไม่มีใคร read | ยืนยันแล้ว | ยืนยันแล้ว — ไม่มีใน maw-rs เลย |
| thclaws ไม่มี --cli kills pane | ใน commands config | ใน maw wake config (wake handles engine) |

---

## 10. Defect #5 — custom engine names fail silently in `maw team up` (source-confirmed 2026-08-01)

> ⚠️ **CORRECTION v7 (2026-08-06 · rerun on maw-rs `325db65` = binary ที่รันอยู่ตอนนี้)**
> §10 ทั้งหมดเขียนบน `v26.7.30-alpha.2017` และมี **3 ข้อที่ผิด** ข้อสรุปหลัก
> ("custom engine names fail silently") **ถูก** แต่เหตุผลและวิธีแก้ผิด — ดู §11 และ
> `ψ/teams/ENGINE-AND-MODEL.md` สำหรับฉบับที่รันแล้ว
>
> | # | §10 เขียนว่า | ของจริงที่ 325db65 |
> |---|---|---|
> | 1 | *"Standard engines are hardcoded — `claude`, `codex`, `thclaws` … No config needed"* | **ไม่มีการ hardcode ใด ๆ** ทั้งสามตัวมาจาก `commands` ทั้งหมด · และ **ไม่มีคีย์ `commands.claude` บนเครื่องนี้เลย** — `-e claude` ได้ claude เพราะ `default` บังเอิญเป็น claude `[verified: wake hermes -e claude → hermes --yolo]` |
> | 2 | *"→ returns `codex-medium` as literal → shell runs it → `command not found`"* | **ไม่ crash** — miss ที่ข้อ 1 จะไหลลง **ชื่อ window → `<oracle>-oracle` → glob → `default`** ก่อนถึงชั้นชื่อดิบ ⇒ ได้ engine ที่ *ทำงานได้* แต่ผิดตัว `[verified: wake coder-1 -e codex-xhigh → claude --model claude-opus-5 --continue]` · **crash ดัง ๆ ปลอดภัยกว่าสิ่งที่เกิดจริงมาก** |
> | 3 | Option A: แก้ `~/.config/maw/maw.config.json` (global) | ใช้ได้ แต่**เปลี่ยนพฤติกรรมของ oracle ทุกตัวบนเครื่อง** ⇒ ใช้ **repo-local `<repo>/.maw/maw.config.<N>.json`** แทน (merge ทับ global, เดินทางไปกับ repo) `[verified 2026-08-06]` |
>
> และ §10 **ไม่ได้พูดถึง `model:` เลย** ซึ่งเป็นครึ่งหนึ่งของคำถามที่ fleet ถาม — ดู §11
>
> 📮 **ข้อที่แสบที่สุดไม่ใช่ข้อไหนในตาราง**: loom รายงานอาการนี้ **2026-08-01** เราเขียน §10
> ในวันเดียวกัน แล้ว**ถือไว้ 5 วัน** ไม่ได้ทำเครื่องมือ ไม่ได้แก้ skill ไม่ได้ส่งกลับ
> จนสมาชิก fleet มาเจอเองอีกรอบ 2026-08-06 — คลาส *"ความรู้มีพันธะเรื่องการกระจาย"* ตรง ๆ

**Reported by**: loom-oracle (116-loom) — live incident during session restart post-machine reboot  
**Source-confirmed by**: codex-fanout reading `team_up_apply.rs` + `wake.rs` (maw-rs)

### What loom found

`maw team up teaching-media-cell` fails for charter engines: `codex-medium` (x6), `codex-xhigh` (x1), `claude-opus-headless` (x2).  
Loom's v2 `up.sh` attempted fix: `seed_charter_engines` → `maw config set engines.$name "$payload"` → **broken** — `maw config set engines.*` is no longer supported in either `maw-rs` or `/home/user/.bun/bin/maw`.

### Why (maw-rs source)

`team_t5b_exec_up` (team_up_apply.rs) → `team_t5b_maw_wake_args` builds:
```
maw wake <identity> --no-attach --session <s> -e <engine-name>
```
Only the engine **name** is forwarded. The charter `engines:` block (stored in `TeamCharter122.engines`) is **never forwarded to wake**.

`wake_resolve_engine_command` (wake.rs:1121):
```rust
let command = config.get("commands")
    .and_then(|commands| commands.get(engine).and_then(...))
    .unwrap_or_else(|| engine.to_owned());  // ← fallthrough: literal name
```
Looks up engine in `merged_config_value().commands` (XDG maw config files). If absent → returns `"codex-medium"` as literal → shell runs it as a command → `command not found`.

### Standard engines are hardcoded

`claude`, `codex`, `thclaws` — handled as known names in wake's engine launch logic. No config needed.

### Loom's "verified ด้วย dry-run"

`maw team up <team> --dry-run` DOES correctly show per-role engines from charter (team_t3_classify reads member.engine). But dry-run only previews — it doesn't execute the wake. The dry-run shows engine names are correctly resolved from charter, NOT that `maw wake -e codex-medium` would succeed.

### What actually works (for custom engines)

Option A — register in `~/.config/maw/maw.config.json` manually:
```json
{ "commands": { "codex-medium": "codex --model gpt-5.6-mini", "codex-xhigh": "codex --model gpt-5.6" } }
```
Then `maw team up` will find them via `merged_config_value().commands`.

Option B — use only standard engines (`claude`, `codex`) in charter → `maw team up` works without config.

Option C (pending maw-rs fix) — `team_t5b_exec_up` should forward charter `engines` map to wake so wake can resolve aliases without a separate config file.

### Oracles most affected

loom (confirmed), any oracle with non-standard engine names in charter.  
`evidence-cell` (prism): uses only `codex` + `thclaws` → **not affected**.

---

## 11. `model:` — ครึ่งที่หายไปของคำถาม (2026-08-06 · `[verified: maw-rs 325db65]`)

fleet ถามสองอย่าง: **harness** กับ **model** — §1-10 ตอบแค่ harness

**`model:` ใน charter ไม่มีผลต่อ pane เลย** ไม่ว่ากรณีใด:

| จุด | เกิดอะไร | citation |
|---|---|---|
| schema | `TeamCharterMember122.model` มีจริง ⇒ parse ผ่าน preflight เขียว | `team_core.rs:86-97` |
| `team up` | `if let Some(model) = &member.model { validate_member(model)? }` — **validate แล้วจบ** | `team_up_apply.rs:186-187` |
| argv → wake | `["wake", id, "--no-attach", "--session", s, "-e", engine]` **ไม่มี `--model`** | `team_up_apply.rs:149`, unit test ยืนยัน argv เป๊ะที่ `:251` |
| `maw wake` | **ไม่มีแฟลก `--model`** ทั้งไบนารี | `wake_argv.rs:38-53,70-84` |
| `team spawn --model` | เขียนลง `~/.claude/teams/<t>/config.json` เป็น metadata — ไม่เข้าคำสั่ง launch | `team_spawn.rs:97,188-191` |

⇒ **model แสดงออกได้ที่เดียว: ในสตริงคำสั่งของ engine alias**

และ **`engines:` block ใน charter เป็น field ตาย** — `charter.engines` ถูก parser เขียน
(`team_core.rs:456,569`) แล้ว `git grep '\.engines\b' crates/maw-cli` เจอแค่บรรทัดประกาศ
กับ unit test · **ไม่มีโค้ดอ่านไปใช้** (นี่คือสิ่งที่ `codex-lead/SKILL.md` สอนอยู่จนถึง 2026-08-06)

**สถานะที่หลอกคนที่สุดคือ "validate แล้วทิ้ง"** — ถ้ามันปฏิเสธตั้งแต่ preflight
ทุกคนจะรู้ทันที · แต่มันตรวจว่า token ปลอดภัยไหม (ซึ่งแปลว่า "อ่านแล้ว") แล้วทิ้ง

วิธีที่ใช้จริง + เครื่องมือตรวจ (`enginecheck`): `ψ/teams/ENGINE-AND-MODEL.md`

---

## Open Questions (สำหรับ sage-codex / lucifer ถ้ายังสนใจ)

1. **lucifer's fix** (`351856ff`/`5fbf7753`) อยู่ใน maw-js หรือ vendor? ตอนนี้ local maw-js ใช้ vendor copy เหมือน pre-fix หรือเปล่า?
2. `cmdTeamBring` + oracle registry — เหมาะกับ prism's 8-role workflow ไหม? (ต้อง register เป็น oracle ก่อน)
3. ควรเปิด PR กับ maw-js ใน Soul-Brews-Studio สำหรับ minimal fix?

---

## Evidence Trail

- Source read: `Soul-Brews-Studio/maw-js` (local clone)
- prism-oracle incident: `arnon2020/prism-oracle` → `ψ/tasks/evidence-cell/LOCAL-LLM-HARDWARE-001.md`
- lucifer fix: maw-js commit `351856ff` / merge `5fbf7753`
- Research date: 2026-08-01 session (codex-fanout)
