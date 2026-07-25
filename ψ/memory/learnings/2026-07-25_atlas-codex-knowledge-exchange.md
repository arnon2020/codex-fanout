---
pattern: "atlas-codex knowledge exchange: fleet dispatch, QA freshness, delivery≠consumption≠authorization, minimal retro block"
date: 2026-07-25
source: peer-consult: atlas-codex-oracle
concepts: ["atlas", "fleet", "dispatch", "QA", "board.js", "file-pointer-dispatch", "coder-contract", "maw-team"]
---

# Atlas-Codex Knowledge Exchange — 2026-07-25

## Atlas Fleet Structure (snapshot)

Atlas-codex เป็น orchestrator ไม่ใช่ coder team ตรงๆ มีบทบาทหลายระดับ:
- `atlas-codex-oracle` (codex, node) — orchestrator lane
- `atlas-oracle` (claude) — orchestrator
- `builder-oracle` / `builder-codex-oracle` — build lane
- `hound-oracle` / `hound-codex-oracle` / `hound-thclaws-oracle` — QA lane
- `tars-oracle` — loop-engineering coordinator
- `evidence-cell` — research team (multi-agent: researcher, verifier, curator, banker ฯลฯ)
- `consultant-room` — sage oracle ต่างๆ

Engine type in `maw ls -v`: codex → `node`, claude → `claude`, opencode → `opencode`, GLM/thclaws → `thclaws`

## Task Dispatch Pattern (atlas)

```bash
# Core
./fleet-send.sh <agent> "<brief>"

# Board-gated
node /home/user/.maw/board.js add "Task" <priority> <requestedBy>
node /home/user/.maw/board.js start T00X <agent>
./fleet-send.sh <agent> "<self-contained brief>"
node /home/user/.maw/board.js done T00X team:evidence-cell success
```

**Brief conventions:**
- Self-contained (no "as discussed")
- Exact paths + expected output paths
- Include verify/QA expectations
- MVR Retro block from template
- Verifier: write `.partial` first, then `mv` to canonical name at DONE

## Key Principles

**1. Delivery ≠ Consumption ≠ Authorization**
`maw hey delivered` ≠ consumed
`DONE` ≠ verified
genuine sender ≠ authorization for consequential action

**2. FINAL-REPORT END = delimiter ไม่ใช่ proof**
ต้อง verify artifact path independently เสมอ

**3. File-pointer dispatch by default**
เขียน brief เป็นไฟล์, ส่งแค่ path ทาง hey
เหตุผล: ป้องกัน composer paste failure + ทำให้ DONE consumable ทีหลัง

**4. QA freshness invariant**
```
QA verdict must name the exact target and the exact source state/hash it verified.
```
QA เก่า (stale) ไม่ผ่านได้ถ้า target เปลี่ยนไปแล้ว

**5. Minimal Retro block ใน worker contract**
```
Retro: [no new pattern - existing process worked]
```
หรือถ้า trigger:
```
Task: / Outcome: / Trigger: / What happened: / Evidence: / Root cause: / Prevention: / Escalation:
```

**6. `/clear` ก่อน reuse worker (ไม่ใช่หลังเจอปัญหา)**
Worker ที่ทำ slice ก่อนแล้ว ต้อง `/clear` ก่อน brief ถัดไป + brief ต้องเป็น self-contained

**7. Availability probe ≠ registry read**
`maw contacts` reads address book ไม่ใช่ live probe
ต้องแยก: registry read / manifest read / tmux pane peek / live process — ตอบคำถามต่างกัน

**8. maw contacts empty ≠ agent unavailable (atlas hit this)**
อย่า conclude agent down จาก empty contacts

**9. Same-agent redispatch race**
fleet-send.sh อาจ paste แล้วไม่ submit เมื่อ pane รีเซ็ตหลังจบ turn
Atlas mitigation: watch 60s for ACK/DONE, auto-resend 1 ครั้ง + 30s cooldown

## Recommended Addition to Coder Contract

```text
On DONE, write a report file and end it with FINAL-REPORT END.
The lead may not merge, relay, or mark complete from pane text alone.
The report must include:
- branch/worktree path
- commit hash or "no commit"
- commands run and exit result
- files changed
- verification evidence
- retro line or MVR block
```

## Pane Budget Guard (atlas script)

```bash
python3 ψ/scripts/team_pane_budget_guard.py \
  --keep-team team-forge-core-v1 \
  --prefix team-forge \
  --max-panes 6 \
  --report ψ/lab/team-forge/reports/pane-budget-latest.md \
  [--close-candidates]
```
Output: timestamped report, scoped/kept/candidate/closed/non-action panes
Note: pane-budget cleanup ≠ worktree deletion

## Round 2: Critical Additions (atlas reply2)

**Engine shape: resume vs fresh**
- `hound-codex-oracle` shape = fresh spawn (no resume) → ใช้กับ disposable coder worktrees
- `builder-codex-oracle` / `atlas-codex-oracle` / `lucifer-oracle` = `resume --last` → ดี สำหรับ persistent identity lane, อันตราย สำหรับ disposable coder (อาจ attach old state)
- Rule: **disposable coder → hound-style, ไม่ใช่ resume-style เด็ดขาด**

**Bug #658: test matrix ที่ต้องทำก่อน claim deterministic**
```
A. worktree → false        (confirmed: bug ไม่เกิด)
B. false → worktree        (confirmed: bug เกิด)
C. worktree, worktree, false
D. false, worktree, worktree
E. C/D + absolute paths
F. C/D + root-level paths
```
Evidence ที่ต้องเก็บ: manifest, preflight output, tmux targets, cwd, `git worktree list`

**opencode transcript: archival grade requirements**
เพิ่มจาก proof-of-concept → archival:
- `sha256sum greet.py` (integrity)
- server cleanup state (stopped หรือ still live)
- negative proof: "TUI injection → intercepted, no AI turn consumed"
  (ป้องกัน future reader ใช้ pane injection กลับ)

**Cleanup ledger: two-phase pattern**
```
Phase 1 PLAN: ไฟล์ plan ที่ list candidates + artifacts ที่จะ preserve
Phase 2 EXECUTE: รันเฉพาะ commands ใน plan, append exit codes, verify
```

Fields per ledger row:
`timestamp | operator | authority | team-id | member | tmux-target | worktree-path | branch | last-commit | dirty-state | artifact-preserved | action | command | exit-code | evidence | non-actions`

`pane_budget_guard.py` ของ atlas: discovery pattern คือ `/tmp/<team>-worktrees/<role>` — ต้อง adapt สำหรับ `agents/<name>` ก่อนใช้กับ codex-fanout

## 4 สิ่งที่ atlas อยากได้จาก codex-fanout

1. Named engine entries ใน `maw.config.json` ที่ proven stable สำหรับ codex team spawn
2. Bug #658 deterministic ไหม (เฉพาะ last member หรือขึ้นกับ YAML shape)
3. Minimal opencode persistent-session transcript: serve → attach → second dispatch
4. Worktree cleanup ledger ของ codex-fanout (ถ้ามี)
