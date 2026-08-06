---
name: oracle-team
description: "Stand up a maw agent team with the engine and model each member is supposed to get — and prove they got it. Covers the full lifecycle: up (tmux), down (teardown), lead (orchestrate), status (peek), dispatch (headless codex exec). Gate 0 is the part most teams get wrong: a charter's `engine:` is only a lookup key into `commands.<name>` in a config layer visible from the WORKER's directory, and a charter's `model:` is discarded outright — so an unregistered name silently boots a different engine with exit 0. Use for any of: '/oracle-team up|down|lead|status|dispatch', 'bring up the team', 'spawn coders', 'set up a codex team', or whenever a member booted with the wrong engine/model, a charter's model: had no effect, or you need per-member engine/model selection (codex vs claude, gpt vs opus) in one team. Path-agnostic — works from any oracle's repo."
argument-hint: "up [profile] [--only codex-N] | down [1,2,3] [--clean] | lead | status | dispatch [issue#] [--model X]"
---

# /oracle-team — Unified Codex Team Lifecycle

One skill, five verbs. Reads everything from the charter (`ψ/teams/*.yaml`).

```
/oracle-team up                       # spawn tmux panes from charter
/oracle-team up codex3                # spawn specific profile
/oracle-team up --only codex-3        # spawn one member
/oracle-team down                     # safe teardown all coders
/oracle-team down 1,2,3               # partial teardown
/oracle-team down --clean             # teardown + delete merged branches
/oracle-team lead                     # one peek/merge/dispatch/nudge cycle
/oracle-team status                   # peek all, no action
/oracle-team dispatch                 # headless codex exec all open issues
/oracle-team dispatch 1,2,3           # dispatch specific issues
/oracle-team dispatch --model o3      # override model
```

## Two modes

| Mode | Verb | How | Tracking |
|------|------|-----|----------|
| **tmux panes** | `up` | `maw team up` — persistent TUI coders | `maw peek` |
| **headless** | `dispatch` | background Agent → `codex exec` — fire-and-forget | harness notifies on completion |

Headless is the `/forward-bg` pattern: Haiku Agent wrapping `codex exec` with `run_in_background: true`.
Claude Code harness tracks it and notifies when done. No shell `&` (invisible to harness).

---

## Step 0: Init — resolve charter dynamically

```bash
date "+🕐 %H:%M %Z (%A %d %B %Y)"
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
```

If a profile name is given (e.g. `up codex3`), resolve charter:
```bash
CHARTER="$ROOT/ψ/teams/team-${PROFILE}.yaml"
```
Otherwise pick the first yaml:
```bash
CHARTER=$(ls "$ROOT"/ψ/teams/*.yaml 2>/dev/null | head -1)
```

```bash
SESSION=$(tmux display -p '#S' 2>/dev/null)
```

From the charter, extract:
- `name` → TEAM name (for `maw team up/down`)
- `project` → REPO slug (for `gh pr list`, `maw wake`)
- `members` → list of codex roles + engines
- `session` → override if set in charter
- `headless.model` → default model for dispatch
- `headless.reasoning_effort` → default reasoning effort
- `headless.engines` → per-coder codex exec command

Count coders (exclude lead where `worktree: false`):
```bash
CODERS=$(python3 -c "
import re
text = open('$CHARTER').read()
roles = re.findall(r'role:\s*(\S+)', text)
print(' '.join(r for r in roles if r != 'lead'))
")
```

Parse the subcommand from `$ARGUMENTS`:
- First token = verb (`up`, `down`, `lead`, `status`, `dispatch`)
- Remaining tokens = verb-specific args

---

## Verb: `up` — Spawn tmux panes from charter

Idempotent: skip live, relaunch dead, create missing.

### Gate 0: bind engine + model, then prove it (MANDATORY, before preflight)

> Path-agnostic — everything below computes from YOUR repo and YOUR team. Nothing here
> depends on another oracle's files or scripts. `[verified 2026-08-06 · maw-rs 325db65 ·
> proven end-to-end by booting two live workers onto two different models]`

**The one rule:** `engine:` in a charter is a *lookup key*, not a setting. It only takes
effect if `commands.<name>` exists in a config layer visible **from the directory the worker
runs in**. `model:` in a charter is parsed, validated, then **discarded** — `maw wake` has no
`--model` flag anywhere in the binary. **A model can only live inside the alias's command
string.** One alias name = one command = one model. Two members that name the same alias get
the same model, necessarily.

When the key is missing maw does **not** error. It falls through silently:
`commands.<engine>` → `commands.<window-name>` → `commands.<oracle>-oracle` → glob →
`commands.default`. Exit 0, no warning, and the pane boots a *working but wrong* engine.

#### 0a. Where the layer file goes

The layer must sit in an **ancestor of the worker's working directory** — not where you
happen to be typing. Find where your workers actually run, then pick:

| Your members' worktrees | Put the layer at |
|---|---|
| `<repo>/agents/<role>` (in-repo) | `<repo>/.maw/maw.config.60.json` — also in git, survives a machine move |
| `~/.maw-teams/<team>/<role>` | `~/.maw-teams/<team>/.maw/maw.config.60.json` |
| `${YOUR_STATE_ROOT}/<role>` | `${YOUR_STATE_ROOT}/.maw/maw.config.60.json` |

- **Filename must match `maw.config.<digits>.json`.** A plain `maw.config.json` (no digits)
  is **never read as a layer** — it is a legacy fallback used only when no numbered file
  exists anywhere. Editing it looks like it worked and changes nothing.
- **Pick N > 50.** Global user config is N=50; higher N merges later and wins. If two layers
  share the same N, the **deeper** one wins — you do not need a unique number.
- **Scope it exactly to the team.** Never put a layer at a directory that is an ancestor of
  *other* teams (e.g. `~/.maw-teams/.maw/`) — that silently binds engines for teams that
  never asked for them.
- **`maw config set` cannot do this** — it supports only `node|port`. Write the file.
- If you also use `maw team spawn` (not just `up`), that verb resolves from the **caller's
  cwd**, so the layer is needed in **both** places: your repo *and* the team state root.

```bash
mkdir -p "$LAYER_DIR"          # "$ROOT/.maw"  or  "$TEAM_STATE_ROOT/.maw"
cat > "$LAYER_DIR/maw.config.60.json" <<'JSON'
{ "commands": {
    "codex-hi":  "codex --model <MODEL-A> --ask-for-approval never --sandbox danger-full-access",
    "codex-lo":  "codex --model <MODEL-B> --ask-for-approval never --sandbox danger-full-access",
    "claude-hi": "claude --model <MODEL-C> --dangerously-skip-permissions"
} }
JSON
```

Charter then references the **alias name** — and `model:` is documentation only:

```yaml
members:
  - role: coder-1
    engine: codex-hi
  - role: reviewer
    engine: claude-hi
```

#### 0b. Prove it — a check that can actually fail

`maw team preflight` and `maw team up --dry-run` are **both green on this defect**. The
dry-run echoes the engine out of the charter you just wrote; it cannot fail. Ask maw what
will *really* launch, from the worker's own path:

```bash
cd "$MEMBER_DIR"                    # the directory that member will run in
maw config sources                  # your layer file MUST appear in this list
maw config explain commands.codex-hi   # "FINAL null" ⇒ not registered from here

# decisive: the real launch line, plus a control that is deliberately unregistered
maw wake <member-identity> --no-attach --dry-run -e codex-hi           --repo-path "$MEMBER_DIR"
maw wake <member-identity> --no-attach --dry-run -e __no_such_engine__ --repo-path "$MEMBER_DIR"
```

**If both commands print the same launch line, your alias is not being read** — the name was
discarded and both fell through to the same fallback. That comparison is the check that can
fail; a single green line on its own proves nothing.

After spawning, confirm on the engine's own UI (`maw peek <session>:<window>`) that the
status bar shows the model you asked for. That is the only layer of evidence that covers
whether the account can actually serve that model — nothing before it does.

#### 0c. Traps confirmed by running them

- **`maw team up -e <engine>` overrides every member's charter engine.** One flag flattens a
  mixed-engine team (`a=codex-hi, b=claude-hi` → both become the flag's value). Omit `-e`
  unless you mean "everyone on this one engine".
- **`maw team resume` respawns every role as `claude`** — it never forwards engine. Prefer
  `maw team up`, which reads the charter.
- **`engines:` inside a charter is a dead field.** maw's parser stores it; no code reads it.
  Engine commands belong in the config layer.
- **Member identities must already be wake-resolvable.** `maw team up` exits 1 with
  `wake: '<name>' was not found` for a member name that is not a known oracle/agent — you
  cannot invent arbitrary member names in a charter.
- **Reasoning effort does not come from the alias.** For codex it comes from
  `$CODEX_HOME/config.toml` (`model_reasoning_effort`); the status bar shows both
  (`<model> xhigh`). Pin it there or add the flag to the alias.
- **First boot can stall on codex's "Update available!" prompt** and never reach the engine
  UI. This is why the post-spawn peek below is mandatory, not optional.

> This is also the root cause of the "`Opus` in the status bar when the charter said codex"
> failure listed further down — carried here as a symptom for a long time without its cause.

```bash
maw team preflight "$CHARTER"
```

If preflight fails → stop.

With `--only`:
```bash
maw team up "$TEAM" --only "$ONLY_ROLE"
```

Without:
```bash
maw team up "$TEAM"
```

### Verify step (MANDATORY after spawn)

Wait 10s for engines to boot, then peek EVERY coder and check:

```bash
sleep 10
for ROLE in $CODERS; do
  echo "=== $ROLE ==="
  maw peek "${SESSION}:${ROLE}" 2>&1 | tail -12
done
```

For each coder, verify against charter:

| Check | How to verify | Bad sign |
|-------|---------------|----------|
| Engine correct? | peek shows `gpt-5.5` not `Opus` | Claude Code booted instead of codex/omx |
| Model right? | peek status bar: `gpt-5.5 xhigh` | `low` = prompt misunderstanding |
| Worktree right? | peek shows `agents/1-codex-N` | wrong dir or main checkout |
| Waiting for task? | idle prompt or "waiting for maw hey" | auto-exploring (whoami, inbox, oracle ls) |
| Alive? | status bar visible | bare shell `❯` = engine died |

**If any check fails:**
1. Kill the bad coder: `maw tmux kill "${SESSION}:${ROLE}"`
2. Clean worktree: `mv agents/1-${ROLE} /tmp/cleanup-...`
3. Fix root cause (config, engine name, reasoning_effort)
4. Relaunch: `maw team up "$TEAM" --only "$ROLE"`
5. Re-verify

**Common failures:**
- `Opus 4.8` / `Opus 5` in status bar when the charter asked for codex → **the engine name
  was not registered in `commands`, so it was silently discarded and resolution fell through
  to `commands.default` (which is claude).** Gate 0 catches this before you spawn; the old
  advice "use `codex-tN` instead" only worked because those names happened to be registered.
  `[verified 2026-08-06: wake coder-1 -e codex-xhigh → claude --model claude-opus-5]`
- `gpt-5.5 low` → CODEX_HOME config has `model_reasoning_effort = "low"` → set to `xhigh`
- Garbage files in worktree → model too dumb to parse prompt → fix reasoning_effort
- Auto-exploring → omx --madmax starts working immediately → need "WAIT for maw hey" in prompt

Report table: role, engine (expected vs actual), model, worktree, status (pass/fail).

---

## Verb: `dispatch` — Headless codex exec (background Agents)

The `/forward-bg` pattern: each coder runs as a **background Agent** wrapping `codex exec`.
Claude Code harness tracks them and notifies on completion — no shell `&`.

### Step 1: Resolve issues to dispatch

If specific issues given (e.g. `dispatch 1,2,3`):
```bash
ISSUES=$(echo "$ISSUE_ARGS" | tr ',' ' ')
```

If no issues given, get all open:
```bash
ISSUES=$(gh issue list --repo "$PROJECT" --state open --json number -q '.[].number' | head -N)
```

Where N = number of coders in charter.

### Step 2: Create worktrees (if not exist)

For each coder, ensure a worktree exists:
```bash
for N in $(seq 1 $NUM_CODERS); do
  wt="$ROOT/agents/coder-$N"
  [ -d "$wt" ] || git worktree add "$wt" -b "agents/coder-$N" HEAD
done
```

### Step 3: Dispatch via background Agents

For each coder + issue pair, spawn a **background Agent** (model: haiku, run_in_background: true).

The Agent's job: run `codex exec` inside the worktree and report results.

**Agent prompt template** (one per coder):
```
You are a dispatch agent for coder-${N}. Run this command and report the full output:

cd ${ROOT}/agents/coder-${N} && \
CODEX_HOME=${CODEX_HOME} codex exec \
  --dangerously-bypass-approvals-and-sandbox \
  -m ${MODEL} \
  -c model_reasoning_effort="${REASONING}" \
  "${TASK_PROMPT}"

Report: what codex did, whether it committed, any errors.
```

Where TASK_PROMPT comes from the charter's `headless.prompt_template` with variables filled:
- `${task}` = issue title + body
- `${session}` = tmux session name
- `${n}` = coder number
- `${task_short}` = issue title

**Key**: use `Agent(run_in_background=true, model="haiku")` — Haiku is cheap,
it's just a wrapper. The real work is done by codex exec (gpt-5.5/o3).

### Step 4: Report dispatch

Print table of dispatched agents:
```
| Coder   | Issue | Worktree       | Model   | Status     |
|---------|-------|----------------|---------|------------|
| coder-1 | #1    | agents/coder-1 | gpt-5.5 | 🟡 running |
| coder-2 | #4    | agents/coder-2 | gpt-5.5 | 🟡 running |
| coder-3 | #7    | agents/coder-3 | gpt-5.5 | 🟡 running |
```

### Step 5: On completion notification

When the harness notifies an agent completed:
1. Check the worktree for commits: `git -C agents/coder-N log --oneline -3`
2. If committed → report success, optionally create PR
3. If no commits → report what happened (error? blocked?)
4. Dispatch next issue to that coder (NO-GAP)

### Model override

`--model o3` overrides the charter's `headless.model` for this dispatch.
`--reasoning high` overrides `headless.reasoning_effort`.

---

## Verb: `down` — Safe teardown

Built from hard-won lessons:
- `maw team down --only` is BROKEN (kills ALL) → use `maw tmux kill` per window
- Never `git worktree remove --force` → commit-save first
- Zsh brace quoting: always `"${SESSION}:name"` not `$SESSION:name`

**Args**: optional coder list (e.g. `down 1,2,3`). Default = all coders.
The lead window is NEVER touched.

```bash
TARGETS="${DOWN_ARGS:-$CODERS}"
TARGETS=$(echo "$TARGETS" | tr ',' ' ')
```

### Step 1: Kill coder windows (tmux mode)

```bash
for ROLE in $TARGETS; do
  maw tmux kill "${SESSION}:${ROLE}" 2>&1 | tail -1
done
maw ls -v 2>&1 | grep "${SESSION}:" | grep codex || echo "✓ no codex windows"
```

### Step 2: Save + remove worktrees

```bash
cd "$ROOT"
for ROLE in $TARGETS; do
  for wt in "agents/1-${ROLE}" "agents/${ROLE}" "agents/coder-${N}"; do
    [ -d "$wt" ] || continue
    git -C "$wt" add -A 2>/dev/null
    git -C "$wt" commit -q -m "wip: auto-save before team-down" 2>/dev/null
    git worktree remove "$wt" 2>&1 && echo "removed $wt" || echo "KEPT $wt (inspect)"
  done
done
rmdir agents/*.maw-create.lock 2>/dev/null
git worktree prune
```

### Step 3: Verify

```bash
maw ls -v 2>&1 | grep -E "${SESSION}:" | grep codex
git worktree list
ls "$ROOT/agents/" 2>&1
```

### Step 4: --clean (optional branch cleanup)

Only with `--clean`. Safe delete only (`-d`, never `-D`):

```bash
git branch | grep -E "agents/" | while read br; do
  git branch -d "$br" 2>&1
done
```

Report: killed, removed, kept, branches.

---

## Verb: `lead` — Orchestrate one cycle

Run on cadence: `/loop 5m /oracle-team lead`

### Step 1: Peek all coders

```bash
for ROLE in $CODERS; do
  echo "=== $ROLE ==="
  maw peek "${SESSION}:${ROLE}" 2>&1 | tail -10
done
```

Classify each:
- `Working (Nm…)` = busy → skip
- `starting` / `standby` = idle → dispatch
- `done <task>` = needs merge review
- `blocked:` = needs lead help
- bare shell `❯` = engine died → relaunch:
  ```bash
  maw team up "$TEAM" --only "$ROLE"
  ```

### Step 2: Review open PRs — merge greens

```bash
gh pr list --repo "$PROJECT" --base alpha --state open
```

For each PR: base is `alpha` (NEVER `main`), mergeable, CI green,
scope matches task. **Standing merge approval**: merge all greens immediately:
```bash
gh pr merge N --squash
```

For Rust projects, build gate = `cargo test --workspace` + `cargo clippy --workspace --all-targets -- -D warnings`.

### Step 3: Dispatch idle workers

```bash
gh issue list --repo "$PROJECT" --state open
```

For each idle coder + unassigned issue, dispatch with concrete done-criteria:
```bash
maw hey "${SESSION}:${ROLE}" "TASK: <what> — done: cargo test + cargo clippy green, commit on branch, PR --base alpha, never main"
```

**NO-GAP DISPATCH**: when confirming a coder's done, include next task in same message.

### Step 4: Detect stuck

If a coder's peek output unchanged >10 min (not done/standby) → nudge:
```bash
maw hey "${SESSION}:${ROLE}" "stuck? report status/blocker clearly"
```

If still silent next cycle, consider clean relaunch via `up --only`.

### Step 5: Report

Print status table: each coder (working/idle/done/blocked), open PRs + verdict,
dispatched tasks, stuck-nudged coders.

---

## Verb: `status` — Read-only peek

Same as `lead` Step 1 + Step 2 (peek + PR list), but takes NO action.
No dispatch, no merge, no nudge. Just report.

```bash
for ROLE in $CODERS; do
  echo "=== $ROLE ==="
  maw peek "${SESSION}:${ROLE}" 2>&1 | tail -5
done
echo "--- PRs ---"
gh pr list --repo "$PROJECT" --base alpha --state open 2>/dev/null || echo "no PRs"
```

---

## Principles

1. Lead orchestrates, coders code — lead NEVER writes code itself.
2. Charter is the source of truth — session, members, engines, headless config all from yaml.
3. `maw tmux kill` for windows — never `maw team down --only` (broken).
4. Never `git worktree remove --force` — commit-save first.
5. Branches survive worktree removal → committed work is never lost.
6. Always brace zsh vars: `"${SESSION}:${ROLE}"` not `$SESSION:$ROLE`.
7. PR → alpha only. Never push/merge to main.
8. Merge greens immediately (standing approval).
9. NO-GAP dispatch: next task in same message as done confirmation.
10. Never nag coders about context — omx auto-compacts.
11. SendMessage = silent no-op for omx — always use `maw hey`.
12. For Rust: build gate = `cargo test` + `cargo clippy -- -D warnings`.
13. Headless dispatch uses background Agent (run_in_background=true), NOT shell `&`.
14. Haiku wraps codex exec — cheap wrapper, real work is codex (gpt-5.5/o3).
15. Escalate to `/oracle-team up` (tmux panes) when headless coders need interactive debugging.
