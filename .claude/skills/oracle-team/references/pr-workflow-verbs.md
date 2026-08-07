# PR-workflow verbs — `dispatch` / `down` / `lead`

> ## 🔴 SPLIT OUT OF THE MAIN SKILL ON 2026-08-06 — READ THIS FIRST
>
> These three verbs were moved here, not deleted, because **every one of them was defective
> the first time it was executed**, and none has ever been used successfully by anyone:
>
> | verb | what running it once found |
> |---|---|
> | `down` | `git add -A` swept an untracked `.env.local` into a commit on a surviving branch |
> | `down --clean` | unanchored `grep "agents/"` deleted a branch belonging to no team |
> | `dispatch` | invented `agents/coder-N` worktrees unrelated to any member; built `codex exec --dangerously-bypass-approvals-and-sandbox -m  ... ""` with three variables the document never set |
> | `lead` | told coders to target a hardcoded branch, and its base-branch detection produced `--base ''` |
>
> Three reviewers read these blocks carefully and found none of it. Executing each one took
> about two minutes.
>
> **Status after the fixes** `[2026-08-06]`:
>
> | verb | against a live team |
> |---|---|
> | `down` + `--clean` | 🟡 **run against two separate live 2-member teams**, each with a real `.env.local` in one worktree. Both runs: session killed, dirty worktree kept with its files listed, clean worktree removed, `.env.local` committed **0** times and still on disk. `--clean` deleted the clean member's branch and git refused the other, because a kept worktree still holds it. Run 2 established that git's `error:` line there is the **expected** result (Step 4). **Not exercised by either run**: the `agents/${ROLE}` / `agents/1-${ROLE}` fallback paths, `rmdir *.maw-create.lock`, `git worktree prune` |
> | `lead` | 🟡 **Step 1 + base detection now run against a REAL 4-member team** (`ws-parity-port`, lucifer's, read-only): the peek loop enumerated members from `tmux` rather than guessing from the charter, returned **real pane content for 4/4, 0 empty**, and base resolved to `main`. This replaces the earlier gap where a truncated harness had only ever shown maw's header line. **Still unrun: everything `gh` touches** — PR listing, review, merge |
> | `dispatch` | 🟡 **`codex exec` path now run for real** — a live worker completed a task and wrote the file. The GitHub-issue half is still unrun. That run is also what proved a model can boot and still be rejected on the first turn |
>
> **No row here has ever been run by anyone but this file's author.** That is the gap that
> matters, and more author runs will not close it — see the note below on why this fleet's
> reviewers structurally cannot close it either.
>
> **They also solve a different problem from the rest of the skill.** They assume GitHub
> issues in, PRs out, and members living in disposable git worktrees. Reviewers whose teams
> return verdicts or measurements rather than PRs reported them as not applicable at all;
> prism's recommendation to split was the reason for this file.
>
> ## 🔴 RETRACTED, same day it was written — the paragraph that used to be here
>
> It said these verbs *"will probably never be peer-validated, because a reviewer who has no
> PRs has no way to run `lead`, and no reason to."* **Four oracles were asked directly and all
> four contradicted it.** The mistake, named by lucifer: the axis is not *PR / no-PR*, it is
> **leaves-git-state / doesn't** — and PR-free teams leave plenty. lucifer: 36 unmerged team
> branches, 0 merged, `gh pr list` empty. ajfon: 5 worktrees stranded 3–4 days with unmerged
> commits, no PR ever opened. Both needed `down`; neither ships PRs.
>
> The retracted claim was inferred from one round of "not applicable" feedback and **never
> checked with the people it described** — this repo's own *verify one property → conclude for
> all*, aimed at other houses' work.
>
> ⇒ **The universal teardown moved to [`teardown.md`](teardown.md)** — snapshot, session kill,
> git-state guards, fleet-reservation release, external-state check. That file is what most
> teams actually need. **What stayed here is only the `gh`-dependent plumbing**: PR review and
> merge (`lead` Step 2), GitHub-issue intake (`dispatch` Step 1). atlas's refinement is why
> those are listed separately — "produces a mergeable artifact" and "consumes an issue queue"
> are **two** assumptions, not one, and atlas's lane has neither while ajfon has neither but
> still needs teardown.
>
> **Gate 0 and `up` in `SKILL.md` carry peer-validated evidence. The `gh` steps in this file
> carry author-run evidence only. Read every command before running it.**

---

## Verb: `dispatch` — Headless codex exec (background Agents)

Each coder runs as a **background Agent** wrapping `codex exec`.
Claude Code harness tracks them and notifies on completion — no shell `&`.

### Step 1: Resolve issues to dispatch

If specific issues given (e.g. `dispatch 1,2,3`):
```bash
ISSUES=$(echo "$ISSUE_ARGS" | tr ',' ' ')
```

If no issues given, get all open:
```bash
ISSUES=$(gh issue list --repo "$PROJECT" --state open --json number -q '.[].number' | head -"${N:-5}")
```

`N` here is how many issues to take, and it is **not** set for you — the expression above
defaults to 5 when unset, silently. Set `N` explicitly if you mean a different number.

### Step 2: Create worktrees (if not exist)

> 🔴 **This step used to invent worktrees that had nothing to do with your team.**
> `[verified by running it, 2026-08-06]` It looped `agents/coder-1`, `agents/coder-2`, … and
> created **real worktrees and real branches** under those names — while the actual members
> were `myteam-alpha`, `myteam-beta`. Running `dispatch` after `up` left orphan worktrees and
> branches nobody owned, and dispatched work to directories no member was running in. Same
> defect class as `down` guessing at path conventions: read the charter, do not invent names.

For each coder, ensure its **charter-declared** worktree exists:
```bash
for ROLE in $CODERS; do
  wt=$(python3 -c "
import re
blocks=re.split(r'(?=^\s*-\s*role:)', open('$CHARTER').read(), flags=re.M)
for b in blocks:
    if re.search(r'role:\s*$ROLE\b', b):
        m=re.search(r'(?:worktree|cwd):\s*(\S+)', b)
        if m and m.group(1) != 'false': print(m.group(1))
        break
")
  [ -n "$wt" ] || { echo "SKIP $ROLE — no worktree:/cwd: in charter"; continue; }
  case "$wt" in /*) ;; *) wt="$ROOT/$wt" ;; esac
  [ -d "$wt" ] || git worktree add "$wt" -b "$ROLE" HEAD
done
```

### Step 3: Dispatch via background Agents

For each coder + issue pair, spawn a **background Agent** (model: haiku, run_in_background: true).

The Agent's job: run `codex exec` inside the worktree and report results.

> 🔴 **The template below expanded to a dangerous, malformed command.**
> `[verified by expanding it, 2026-08-06]` `MODEL`, `REASONING` and `TASK_PROMPT` are
> **never assigned anywhere in this file**, so it produced:
> ```
> CODEX_HOME= codex exec --dangerously-bypass-approvals-and-sandbox -m  -c model_reasoning_effort="" ""
> ```
> — an empty `CODEX_HOME`, a bare `-m` that would swallow the next flag as its model name, an
> empty reasoning effort, and an **empty task prompt**, all under a flag that bypasses every
> approval and the sandbox. Set the values and refuse to run without them:

```bash
: "${MODEL:?set MODEL — no default; -m with no value swallows the next flag}"
: "${TASK_PROMPT:?set TASK_PROMPT — an empty prompt under bypass flags is not a no-op}"
: "${REASONING:=medium}"
: "${CODEX_HOME:=$HOME/.codex}"   # empty is NOT the same as unset here
```

**Agent prompt template** (one per coder — `$WT` is that role's charter-declared worktree):
```
You are a dispatch agent for ${ROLE}. Run this command and report the full output:

cd ${WT} && \
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
- `maw team down --only` is BROKEN (kills ALL) → use `tmux kill-window` per window and verify. **`maw tmux kill` resolves only `session:INDEX.PANE`**, so passing a window name always misses (rc=1, window survives) — and piping it discards that rc. See `teardown.md` Step 1.
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
  tmux kill-window -t "=${SESSION}:${ROLE}-oracle" 2>&1     # tmux takes window NAMES; maw tmux kill does not
done
maw ls -v 2>&1 | grep "${SESSION}:" | grep codex || echo "✓ no codex windows"
```

### Step 2: Save + remove worktrees

```bash
cd "$ROOT"
for ROLE in $TARGETS; do
  # [found by ajfon 2026-08-06] the third candidate used to be "agents/coder-${N}", but $N is
  # never set anywhere in `down` — the only assignment in this file is dispatch's own loop, a
  # different verb. Unset, it searched for the literal path "agents/coder-". Read the real
  # path out of the charter instead of guessing at naming conventions.
  WT=$(python3 -c "
import re,sys
blocks=re.split(r'(?=^\s*-\s*role:)', open('$CHARTER').read(), flags=re.M)
for b in blocks:
    if re.search(r'role:\s*$ROLE\b', b):
        m=re.search(r'(?:worktree|cwd):\s*(\S+)', b)
        if m and m.group(1) != 'false': print(m.group(1))
        break
")
  for wt in $WT "agents/${ROLE}" "agents/1-${ROLE}"; do
    [ -d "$wt" ] || continue
    # 🔴 DO NOT `git add -A` here. [verified by running it, 2026-08-06]
    #    An earlier version of this block did, and it swept an untracked `.env.local`
    #    straight into a commit on a branch that outlives the teardown — violating this
    #    repo's own golden rule "Never commit secrets (.env, credentials, API keys)".
    #    A teardown must never decide, unasked, that a worker's untracked files should
    #    become permanent.
    # 🔴 Is this member dir its OWN git root, or just a folder inside one?
    #    [lucifer raised it as a hypothesis; measured here 2026-08-07]
    #    `cwd:` may point at a PLAIN FOLDER inside the repo. Then every `git -C "$wt" …`
    #    below silently answers about the PARENT REPO instead:
    #      git -C plainmember rev-parse --show-toplevel  -> the main checkout
    #      git -C plainmember status --porcelain         -> "?? ./"  "?? ../ψ/"
    #    i.e. the dirty check reports the whole repo's dirt, and a "clean" verdict would
    #    likewise be a verdict about the repo. Any `git add -A` here would stage the repo.
    wt_root=$(git -C "$wt" rev-parse --show-toplevel 2>/dev/null)
    wt_abs=$(cd "$wt" 2>/dev/null && pwd -P)
    if [ -n "$wt_root" ] && [ "$wt_root" != "$wt_abs" ]; then
      echo "SKIP $wt — not its own git root; it is a plain folder inside $wt_root"
      echo "      every git check here would answer about that repo, not this member."
      echo "      → remove it by hand if you mean to, or declare a worktree: instead of cwd:"
      continue
    fi
    if [ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ]; then
      echo "KEPT $wt — uncommitted work present, NOT auto-committing:"
      git -C "$wt" status --short | sed 's/^/      /'
      echo "      → inspect, then commit what you want and re-run, or remove with --force"
      continue
    fi
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

Only with `--clean`. Safe delete only (`-d`, never `-D`).

> 🔴 **The old form matched substrings and deleted a branch that was not the team's.**
> `[verified by running it, 2026-08-06]` It was `git branch | grep -E "agents/"`, unanchored,
> so a branch named `my-important-feature-agents/notes` — nothing to do with any team — was
> matched and **deleted**, because it happened to be merged. The `-d` guard held for unmerged
> work, which is the only reason this was not worse. `-d` protects unmerged commits; it does
> **not** protect against deleting the wrong branch. Same substring-match trap this fleet has
> been bitten by before with team-name prefixes.

**Delete only branches this charter's members actually declare:**

```bash
for ROLE in $CODERS; do
  # a member's branch is its `branch:` if declared, else its role name — never a pattern
  br=$(python3 -c "
import re
blocks=re.split(r'(?=^\s*-\s*role:)', open('$CHARTER').read(), flags=re.M)
for b in blocks:
    if re.search(r'role:\s*$ROLE\b', b):
        m=re.search(r'branch:\s*(\S+)', b); print(m.group(1) if m else '$ROLE'); break
")
  [ -n "$br" ] || continue
  git show-ref --verify --quiet "refs/heads/$br" || { echo "skip $br (no such branch)"; continue; }
  git branch -d "$br" 2>&1        # -d only. Never -D: unmerged work must survive teardown.
done
```

> ⚠️ **`--clean` printing `error:` is often the correct outcome, not a failure.**
> `[verified by running it twice, 2026-08-06]` When Step 3 keeps a worktree because it is dirty,
> that worktree still holds its branch, so git refuses:
> `error: cannot delete branch 'agents/r2-a' used by worktree at '.../agents/r2-a'`
> This is the two guards composing — the dirty-worktree guard makes the branch undeletable, so
> uncommitted work cannot be stranded on a deleted branch. **Do not "fix" it** by adding `-D`,
> by removing the worktree first, or by committing to clear the dirt: each of those defeats the
> guard that produced the message. A branch left behind next to a kept worktree is the intended
> end state. Report it as kept, not as an error.

Report: killed, removed, kept, branches.

---

## Verb: `lead` — Orchestrate one cycle

Run on cadence: `/loop 5m /oracle-team lead`

### Step 1: Peek all coders

```bash
for ROLE in $CODERS; do
  echo "=== $ROLE ==="
  maw peek "${SESSION}:${ROLE}-oracle" 2>&1 | grep -n . | head -20
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
# Derive the base branch ONCE, and default it in a separate step.
# [verified by running it, 2026-08-06] Writing this as
#   "${BASE:-$(git symbolic-ref … | sed … || echo main)}"
# is broken: the `||` binds to the PIPELINE, whose exit status is sed's, and sed
# succeeds on empty input — so in a repo with no origin the fallback never fires and
# BASE comes out EMPTY, producing `gh pr list --base ''`. Same
# rc-of-a-pipeline-is-the-last-command trap as `cmd | grep -q`.
BASE_DETECTED=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
BASE="${BASE:-${BASE_DETECTED:-main}}"

gh pr list --repo "$PROJECT" --base "$BASE" --state open
```

For each PR: base is not `main`, mergeable, CI green, scope matches task.

> 🔴 **This skill does NOT carry merge approval, and an earlier version wrongly claimed it
> did.** `[prism 2026-08-06]` It said *"Standing merge approval: merge all greens immediately"*
> — which would make anyone running `/oracle-team lead` merge every green PR without being
> asked. prism's owner rule forbids merging without human approval; **so does the golden rule
> in this very repo's own CLAUDE.md** ("Never merge PRs without human approval"). The skill was
> instructing a policy violation, and it was buried 700 lines in, where you would only meet it
> after running.
>
> **Report the merge candidates. Let the human merge them.**
> ```bash
> gh pr view N            # then hand the number to your human
> ```
> If your oracle genuinely holds standing merge approval from its owner, you already know it
> and can run `gh pr merge` yourself. A skill cannot grant you that.

For Rust projects, build gate = `cargo test --workspace` + `cargo clippy --workspace --all-targets -- -D warnings`.

### Step 3: Dispatch idle workers

```bash
gh issue list --repo "$PROJECT" --state open
```

For each idle coder + unassigned issue, dispatch with concrete done-criteria:
```bash
maw hey "${SESSION}:${ROLE}-oracle" "TASK: <what> — done: tests+lint green for THIS project, commit on your own branch, open the PR against ${BASE} (never the repo default unless that IS ${BASE})"
```

**NO-GAP DISPATCH**: when confirming a coder's done, include next task in same message.

### Step 4: Detect stuck

If a coder's peek output unchanged >10 min (not done/standby) → nudge:
```bash
maw hey "${SESSION}:${ROLE}-oracle" "stuck? report status/blocker clearly"
```

If still silent next cycle, consider clean relaunch via `up --only`.

### Step 5: Report

Print status table: each coder (working/idle/done/blocked), open PRs + verdict,
dispatched tasks, stuck-nudged coders.

---
