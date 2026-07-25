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

## Lesson 1: engine `codex` → auto-resolves to `codex-resume`
**Why:** maw detects prior codex session history in the worktree path and appends `-resume` suffix.
`codex-resume` is not a registered engine → error.
**Fix:** Use a fresh worktree (no prior session history) + named engine from maw known list.
`hound-codex-oracle` = `codex --model gpt-5.5 --ask-for-approval never --sandbox danger-full-access` ✓

## Lesson 2: Trust prompt despite global trust
**Why:** `/home/user` is trusted in `~/.codex/config.toml` but the worktree-local path still triggers the prompt.
**Fix:** `maw send-text <pane> "1"` immediately after spawn. Boot pitfall — always peek first.

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
