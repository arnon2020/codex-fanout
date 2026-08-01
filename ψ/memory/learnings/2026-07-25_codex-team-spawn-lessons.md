---
pattern: "Codex team spawn (arnon2020 env): engine resolution, trust, queue bypass — proven loop"
date: 2026-07-25
source: codex-lead session
concepts: ["codex-team", "spawn", "maw", "engine", "worktree", "loop-proven"]
---

# Codex Team Spawn Lessons — 2026-07-25

## Loop proven
spawn → contract → task → implement → test → commit → push → report → merge

Coder: hound-codex-oracle (gpt-5.5 YOLO)
Commit: e098f38 "Add loop proof hello script" → cherry-picked to main

## ~~Lesson 1: engine `codex` → auto-resolves to `codex-resume`~~ — ❌ RETRACTED 2026-08-01

> **[disproven]** กฎนี้ผิด และถูกส่งต่อไปให้ atlas / tars / atlas-codex / lucifer
> ก่อนจะถูก disprove — retraction ส่งแล้ว 2026-08-01

**เดิมเขียนว่า:** "maw detects prior codex session history in the worktree path and appends
`-resume` suffix → `codex-resume` ไม่ registered → error"

**หลักฐานที่ล้ม:**
- `[verified]` citation-oracle รันจริง 2026-07-29: `engine: codex` + probe สำเร็จ (commit `fc99a6b`)
- `[verified]` `grep -rn "codex-resume" maw-rs/crates/` → **0 hits** ไม่มี logic ไหนดู path history
- `[verified]` `wake_default_engine` (wake.rs:1135): `if options.resume { return "codex" }` — คืน
  `"codex"` ไม่ใช่ `"codex-resume"`
- `[verified]` `codex-resume` มีเฉพาะใน `maw.config.50.json.bak-*` (config generation เก่า) ไม่มีใน live config
- `[verified]` lucifer ตรวจ source ยืนยันซ้ำ 2026-08-01 และแก้ memory 2 ไฟล์เป็น RETRACTED

**ความจริงที่ใช้แทน:**
- `engine: codex` ใช้ได้ปกติ — เป็น key จริงใน `~/.config/maw/maw.config.json` → `commands.codex`
- engine name resolve ผ่าน **`commands` block ของ XDG config เท่านั้น** ถ้าไม่มี key →
  maw เอาชื่อไปรันเป็น shell command ตรง ๆ → `command not found`
- **`maw ls` known-list ≠ `commands` keys** — ตรวจที่ config เท่านั้น
- ที่ต้องระวังจริงคือ **อย่าเพิ่ม pool config เอง** (citation's correction)

## Lesson 2: Trust prompt despite global trust — `[verified 2026-08-01 on maw-rs v26.7.30]`
**Why:** `/home/user` is trusted in `~/.codex/config.toml` but the worktree-local path still triggers the prompt.
**Fix:** `maw send-enter <pane>` immediately after spawn. Boot pitfall — always peek first.

**Re-verified 2026-08-01** ด้วย throwaway probe (`maw team up` exec, 1 member, engine `codex`):
maw รายงาน error ชัด `wake: engine is stuck at the directory-trust prompt ... — attach and
answer once, or pre-seed trust` → ตอบ prompt ครั้งเดียว → Codex v0.145.0 UI ขึ้นปกติ
(gpt-5.5 high, YOLO mode, worktree ถูก) นี่เป็น boot pitfall ที่ยัง**ต้องจัดการเองทุกครั้ง**
แม้จะใช้ `maw team up` (maw ไม่ pre-seed trust ให้)

## Lesson 3: `maw hey` queues when coder is "busy"
**Why:** Codex's polling loop keeps the pane in "working" state → maw considers it busy → queues.
**Fix:** `maw send-text <pane> "<task>"` + `maw send-enter <pane>` bypasses the queue check.
Note: queued messages DO auto-deliver eventually — just not within the polling window.

## Lesson 4: Codex default prompt noise
**Why:** Codex UI shows "Summarize recent commits" as placeholder. If Enter reaches the pane before
the contract is fully cleared, that default task gets submitted.
**Effect:** First done report was "summarized recent commits" (unexpected task) — not blocking but noise.
**Fix:** Peek after send-text/send-enter to confirm context% dropped (= contract ingested) before dispatching task.

## Lesson 5: Worktree naming — maw creates its own path
maw creates `agents/1-agentscodex-2` (not `agents/codex-2` as in charter).
The charter `worktree: agents/codex-2` → maw generates `agents/1-agentscodex-2`.
Pre-creating the worktree manually does NOT prevent maw from making a new one.
**Fix:** Accept maw's naming. Don't pre-create the worktree.

## Lesson 6: Coder's report-back target must be exact window name
Charter had `maw hey 117-codex-fanout:codex-fanout` — coder used it correctly.
Confirm with `maw ls -v` before dispatching contract.

## Charter that worked
```yaml
name: codex-fanout-team
project: arnon2020/codex-fanout
session: 117-codex-fanout
members:
  - role: codex-1
    name: codex-1
    engine: hound-codex-oracle   # ← key: named engine, not generic `codex`
    worktree: agents/codex-2     # ← maw creates agents/1-agentscodex-2 actually
    branch: agents/codex-2
    prompt: |
      Coder. WAIT for task via maw hey.
      Report: maw hey 117-codex-fanout:codex-fanout "done/blocked — <details>"
  - role: lead
    name: codex-fanout
    engine: claude
    worktree: false
    branch: alpha
lifecycle:
  worktree: true
  merge_on_shutdown: false
```
