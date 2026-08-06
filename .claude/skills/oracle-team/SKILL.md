---
name: oracle-team
description: "Stand up a maw agent team with the engine and model each member is supposed to get — and prove they got it. Covers the full lifecycle: up (tmux), down (teardown), lead (orchestrate), status (peek), dispatch (headless codex exec). Gate 0 is the part most teams get wrong: a charter's `engine:` is only a lookup key into `commands.<name>` in a config layer visible from the WORKER's directory, and a charter's `model:` never reaches the pane — inert when `engine:` is present, and used as the engine key itself when `engine:` is absent, which misses with certainty. An unregistered name silently boots a different engine with exit 0. Use for any of: '/oracle-team up|down|lead|status|dispatch', 'bring up the team', 'spawn coders', 'set up a codex team', or whenever a member booted with the wrong engine/model, a charter's model: had no effect, or you need per-member engine/model selection (codex vs claude, gpt vs opus) in one team. Path-agnostic — works from any oracle's repo."
argument-hint: "up [profile] [--only codex-N] | down [1,2,3] [--clean] | lead | status | dispatch [issue#] [--model X]"
---

# /oracle-team — Unified Codex Team Lifecycle

> ## ⚠️ Read this before running any verb
>
> **This file is two different things, with very different amounts of evidence behind them.**
>
> **Gate 0 + `scripts/verify-check.sh` — bind engine/model and prove it.** General. Applies to
> any team on any layout. Independently arrived at, verb-for-verb, by prism before they read
> this file, and reviewed by five oracles. Use it.
>
> **`dispatch` / `down` / `lead` — moved out to `references/pr-workflow-verbs.md`.** They
> assume one specific workflow — GitHub issues in, PRs out, members in disposable git
> worktrees — and **every one of them was defective the first time it was executed.** They are
> fixed there and still unvalidated. Do not reach for them because the verb name sounds
> generic; if your team returns a verdict or a measurement rather than a PR, they do not apply.
>
> | part | evidence |
> |---|---|
> | Gate 0 + `scripts/verify-check.sh` | reviewed by 5 oracles · independently reinvented by prism before reading this · detector validated at n=65 |
> | `up` | run 5× end to end — **the 5th, against this current text after ten rounds of edits, found zero new defects** |
> | `status` | exercised only inside `up` |
> | `dispatch` / `down` / `lead` | 🔴 each run once, each broken; **never run against a real team** |

---

## QUICKSTART — never built a team before? Run exactly this.

This is a complete, working sequence, in order, with nothing assumed. It was run end-to-end
on 2026-08-06 and produced a live two-member team on two different models. Substitute the
five values in the first block; change nothing else until it works once.

**Step 0 — check the prerequisites. Each one fails silently if missing.**

```bash
command -v maw  >/dev/null || { echo "STOP: maw is not on PATH"; exit 1; }
command -v tmux >/dev/null || { echo "STOP: tmux is not on PATH"; exit 1; }
git rev-parse --show-toplevel >/dev/null 2>&1 \
  || { echo "STOP: not inside a git repository — see 'no repo?' below"; exit 1; }
```
Why this is a real step, not boilerplate: `ROOT=$(git rev-parse --show-toplevel)` outside a
repo sets `ROOT` to the **empty string**, and every path after it silently becomes
`/.maw/...`, `/agents/...`. Nothing errors until a confusing failure several steps later.

> **No repo? `maw team up` still needs one.** `[verified — an earlier version of this callout
> said "everything else is identical", which was false]`
> ```
> $ maw team up <team>          # from a directory with no .git anywhere above it
> team spawn: repo root not found (.git)
> $ echo $?
> 0                             # ← rc=0. A gate checking the exit code calls this a success.
> ```
> A team can still live outside your oracle repo — `~/.maw-teams/<team>/<role>` is a normal
> layout — but that directory must itself be a git repo. Set `ROOT=~/.maw-teams/$TEAM`,
> `mkdir -p "$ROOT"`, **`git init "$ROOT"`**, and use it everywhere below; the config layer
> goes at `$ROOT/.maw/maw.config.60.json`. Trade-off: that layer is then in nobody's *shared*
> git, so it vanishes on a machine move and the symptom is a silently wrong engine, not an error.

> ⚠️ **`maw` returns rc=0 on several of its failures.** Three of the four ways this procedure
> can break exit 0 with the error only on stdout. Read the output; never branch on `$?` alone.

```bash
# ── things you choose ────────────────────────────────────────────────────────
TEAM=myteam-v1                       # unique across the machine
SESSION=$TEAM                        # tmux session name
ROOT=$(git rev-parse --show-toplevel) # your repo — or ~/.maw-teams/$TEAM, see above
A=${TEAM}-alpha                      # member 1 — MUST be prefixed with $TEAM (see step 3)
B=${TEAM}-beta                       # member 2
```

**Step 1 — register the engines you want, with the model baked in.**
This is the only place a model can be expressed. Filename must be `maw.config.<digits>.json`
with a number above 50.

> 🔴 **`$ROOT/.maw` is correct only if your members live UNDER `$ROOT`.** The layer must sit
> at a **common ancestor of the member directories**, and nothing else. `[lucifer 2026-08-06 —
> their 10-role team runs from `~/.maw-teams/<team>/<role>/`, which sees only the global
> layer, so every role fell through to claude-opus-5 while the charter asked for codex-xhigh]`
>
> ```bash
> # members under $ROOT/agents/<role>      → LAYER_DIR="$ROOT/.maw"
> # members under ~/.maw-teams/<team>/<role> → LAYER_DIR=~/.maw-teams/<team>/.maw
> # members under ${STATE_ROOT}/<role>     → LAYER_DIR="${STATE_ROOT}/.maw"
> cd "<one member's directory>" && maw config sources   # ← your layer MUST appear
> ```
> Check it from a member's directory, not from where you are standing. See 0a for the table.

```bash
mkdir -p "$ROOT/.maw"       # ← or LAYER_DIR from the box above
cat > "$ROOT/.maw/maw.config.60.json" <<'JSON'
{ "commands": {
    "team-codex-hi": "codex --model <MODEL-A> --ask-for-approval never --sandbox danger-full-access",
    "team-codex-lo": "codex --model <MODEL-B> --ask-for-approval never --sandbox danger-full-access"
} }
JSON
```
**Finding model names that actually work — one per engine, they are not interchangeable:**

**First: see what is already registered.** On a machine with an existing fleet, most of the
aliases you need may exist already — and nothing else in this doc tells you how to look:

```bash
bash ~/.claude/skills/oracle-team/scripts/verify-check.sh enginelist "$ROOT"
#   enginelist.count: 22
#   enginelist.engine: codex        model=-               cmd=… codex --ask-for-approval never …
#   enginelist.engine: claude-opus  model=claude-opus-5   cmd=claude --model claude-opus-5 …
```
It is dir-aware like everything else here, so run it from a path your member will use. An
alias with `model=-` pins no model — it takes whatever the engine's own default is.

**Then, model names for a NEW alias** — one lookup per engine, they are not interchangeable:

| engine | how to list what your account serves |
|---|---|
| codex | `grep '^model' ~/.codex/config.toml` — this gives **one** value, the current default. `codex --help` documents the `-m` flag but **does not enumerate valid values** |
| claude | `claude --help` lists the aliases it accepts — **read the list on your machine, do not copy one from here; it changes between versions** |
| opencode | `opencode models` prints every `provider/model` it can reach |

🔑 **Getting two DIFFERENT models is the step people get stuck on.** codex exposes only its
current default by the route above, so there may be **no way to discover a second codex model
locally**. The reliable answer is to make the second member a **different engine** — codex for
one, claude for the other. Mixing engines in one team is normal and is what the per-member
aliases are for. Do not invent model names to fill the gap.

**Step 2 — create each member's working directory. It must exist before spawn.**

```bash
mkdir -p "$ROOT/agents/$A" "$ROOT/agents/$B"
```

**Step 3 — write the charter.** Two rules that will otherwise cost you an hour:
member names must be **unique across the whole fleet** (prefix with the team name), and every
member needs a real path — `worktree:` or `cwd:`, either works. With neither, the member boots
in whatever repo its *name* is registered to and your engine aliases are invisible there.
Write `engine:` only; a `model:` line does not reach the pane and is actively harmful without
an `engine:` beside it (see 0c).

```bash
mkdir -p "$ROOT/ψ/teams"
cat > "$ROOT/ψ/teams/$TEAM.yaml" <<YAML
name: $TEAM
session: $SESSION
members:
  - role: $A
    name: $A                  # the "member identity" referred to elsewhere in this doc
    engine: team-codex-hi
    worktree: agents/$A       # RELATIVE to \$ROOT (absolute also works)
  - role: $B
    name: $B
    engine: team-codex-lo
    worktree: agents/$B
YAML
```

`project:` and `branch:` are omitted because **`maw team up` does not need them**.

> ⚠️ **But `maw team preflight` does — and it will fail this charter.** `[found by ajfon,
> 2026-08-06]` An earlier version of this doc told you to drop those fields in Step 3 and then,
> in Gate 0, to stop if preflight is red. Those two instructions contradicted each other.
>
> **`maw team preflight` cannot pass before a spawn, by construction.** Even with every field
> present it returns rc=1 on:
> - `✗ spawn ordering: session '<x>' does not exist before spawn` — true by definition when
>   you are about to create it
> - `✗ codex trust: <role> missing trusted project entry … in ~/.codex/config.toml` — see the
>   prerequisite below
>
> ⇒ **Do not gate on preflight before spawning.** Read it for the checks that *are* meaningful
> pre-spawn (role uniqueness, artifact collisions, CODEX_HOME isolation, worktree collisions)
> and ignore the two above. The check that decides whether to proceed is **Step 4**, which can
> fail for exactly one reason and no other.

> 🔑 **codex trust — a prerequisite nothing else here mentions, and the *cause* of the trust
> prompt listed in Step 6.** codex refuses to run unattended in a directory it has not been
> told to trust, so a fresh member directory stalls on `Is this a project you created or one
> you trust?`. Either clear it interactively at Step 6, or pre-seed it before spawning:
> ```bash
> printf '\n[projects."%s"]\ntrust_level="trusted"\n' "$ROOT/agents/$A" >> ~/.codex/config.toml
> ```
> ⚠️ `~/.codex/config.toml` is **shared machine-wide state**. Appending a project entry is
> additive and low-risk; do not edit anything else in that file for a team bring-up.

**Step 4 — prove the aliases are actually visible.** Not optional: `maw team preflight` and
`maw team up --dry-run` are both green even when this is broken.

```bash
cd "$ROOT/agents/$A"
maw config sources        # your maw.config.60.json MUST be listed here
maw wake "$A" --no-attach --dry-run -e team-codex-hi        --repo-path "$ROOT/agents/$A"
maw wake "$A" --no-attach --dry-run -e __no_such_engine__   --repo-path "$ROOT/agents/$A"
cd "$ROOT"
```

> 🔁 **More than two or three members? Do not eyeball this.** `[lucifer 2026-08-06 — at 10
> roles the two-command form is 20 invocations compared by hand, and the doc shipped no loop]`
> Either run `scripts/verify-check.sh enginecheck <charter>`, which does exactly this per
> member and prints a verdict, or loop it yourself:
> ```bash
> while IFS=$'\t' read -r ROLE DIR ENG; do
>   real=$(maw wake "$ROLE" --no-attach --dry-run -e "$ENG"                --repo-path "$DIR" 2>&1 | sed -n 's/^ *command: *//p')
>   ctrl=$(maw wake "$ROLE" --no-attach --dry-run -e __no_such_engine__    --repo-path "$DIR" 2>&1 | sed -n 's/^ *command: *//p')
>   [ -n "$real" ] && [ "$real" != "$ctrl" ] \
>     && echo "OK   $ROLE  $real" \
>     || echo "FAIL $ROLE  (alias not read — same as control, or no output)"
> done < <(your role/dir/engine triples)
> ```
Read both `command:` lines. **They must differ.** Identical output means your alias was
discarded and both fell through to the same default — fix that before going on.

**Step 5 — spawn.**

```bash
maw team up "$TEAM" --dry-run     # sanity: roles + engines listed
maw team up "$TEAM"               # real
```
Two failures you will probably hit here, and neither error explains itself:

- **`charter not found: <team>`** — `maw team up` looks for the charter **relative to your
  current directory** (`./.maw/teams/<team>.yaml`, then `./ψ/teams/<team>.yaml`). Step 4 left
  you inside a member directory. `cd "$ROOT"` and re-run. Nothing is wrong with the charter.
- **`exited with exit status: 1`** — almost always a member name that is ambiguous
  fleet-wide. The message names no member; re-run the failing one by hand to see the reason:
  `maw wake "$A" --no-attach --session "$SESSION" -e team-codex-hi`

**Step 6 — peek every member. A spawn that "succeeded" often has not booted.**

🔴 **The window is named `<role>-oracle`, not `<role>`.** `maw team up` appends the suffix.
Targeting `$SESSION:$A` makes tmux prefix-match, return one useless line, and **exit 0** —
which reads as "member is up and quiet". Always list the real names first:

```bash
tmux list-windows -t "=$SESSION" -F '#{window_name}'      # the '=' prevents prefix matching
# no fixed sleep — poll for the banner, see the loading note below
tmux capture-pane -p -t "$SESSION:${A}-oracle" | grep -n . | head -30
tmux capture-pane -p -t "$SESSION:${B}-oracle" | grep -n . | head -30
```
🔴 **Do not use `| tail -25` here.** The engine banner sits in the *upper* half of the pane and
the bottom is blank padding, so `tail` prints **nothing at all** — at the exact step where you
are told to read the model. Empty output there reads as "dead pane" and is the single most
misleading moment in this procedure. `grep -n .` drops the blank lines instead.

First-boot prompts that stall a member — each one leaves it looking merely quiet:

| what you see | engine | clear it with |
|---|---|---|
| `✨ Update available!` | codex | `tmux send-keys -t "$SESSION:${A}-oracle" 2 Enter` (`2` = "Skip"; `1` would upgrade the shared binary — read the menu, the numbering is not guaranteed) |
| `Is this a project you created or one you trust?` | claude | `tmux send-keys -t "$SESSION:${B}-oracle" 1 Enter` (`1` = "Yes, I trust this folder") |
| a bare shell prompt `❯` | any | the engine never started — go back to step 4 |

⏳ **`model: loading` occupies the exact line you are told to read.** After clearing a prompt,
the codex banner shows `model:       loading` before the real value appears.

**Do not use a fixed sleep — poll.** Timings observed on this machine ranged from ~25s to
~35s across three runs (n=3, single machine, one codex version), and a reviewer correctly
pointed out that this doc previously carried three different numbers for the same wait. Any
constant here is a guess dressed as a measurement:

```bash
for _ in $(seq 30); do
  tmux capture-pane -p -t "$SESSION:${A}-oracle" | grep -q 'model:.*loading' || break
  sleep 3
done
```
Then read the banner. **Never accept the first banner you see.**

🔴 **The banner does NOT prove the account can serve that model.** `[verified 2026-08-06 by
sending a real turn]` A pane boots cleanly and prints `model: gpt-5.6-mini xhigh` in its own
UI, and the first actual request returns:
```
ERROR: {"status":400,"message":"The 'gpt-5.6-mini' model is not supported when using Codex with a ChatGPT account."}
```
The same command with `gpt-5.6-sol` completed the task and wrote the file. So the engine
accepts the flag, reports it, and only the **first real turn** discovers the account cannot
use it. Every earlier version of this document called the banner "the only check that covers
whether the account can serve the model" — that was wrong, and the example aliases shipped
here used exactly the model that fails.

**The banner tells you the flag arrived. Only a real turn tells you it works.** This is what
`model-served=UNVERIFIED` has been pointing at the whole time — it is not boilerplate.

```bash
bash ~/.claude/skills/oracle-team/scripts/verify-check.sh modelprobe <alias> <dir>
#   modelprobe.engine: codex-sol    PASS model=gpt-5.6-sol  served=yes
#   modelprobe.engine: codex-medium FAIL model=gpt-5.6-mini served=no  "message":"The
#     'gpt-5.6-mini' model is not supported when using Codex with a ChatGPT account."
```
💸 **It sends one real turn and costs quota** — that is the point; nothing cheaper can answer
the question. Run it **once per new engine**, before trusting a team to it. Both arms verified
above on the same account minutes apart. codex only; other engines report UNVERIFIED rather
than guessing.

**What the banner does establish** — that your alias reached the engine. Per engine:
- **codex** — banner line `model: <MODEL> <effort>` and the status bar repeat it
- **claude** — the banner scrolls away; use `tmux send-keys -t "$SESSION:${B}-oracle" "/status" Enter`
  then peek, and read `Model: <alias> (<full-id>)`

**Step 7 — tear down.**

```bash
tmux kill-session -t "=$SESSION"
ls ~/.maw/fleet/ | grep -i "$SESSION"      # usually EMPTY — see below
rm -f ~/.maw/fleet/"$SESSION".json         # only if the line above printed something
```

**Which of those two lines you need depends on how the team was started, and the difference
is not obvious:** `maw wake` run directly writes `~/.maw/fleet/<session>.json`, and
`tmux kill-session` does not remove it — the stale entry keeps answering to those member
names and breaks the next spawn with an ambiguity error. **`maw team up` does not appear to
write one at all.** So run the `ls` and only delete what actually exists; a bare `rm -f`
succeeds either way and teaches you nothing.

Note also that a team created this way does **not** show up in `maw team list` even while it
is alive — do not use that command to decide whether a team is running. `tmux list-sessions`
is the source of truth.

If all eight steps pass, the mechanism is working and the rest of this skill is about
running the team, not standing it up.

**QUICKSTART is the procedure. Gate 0 below is the reference** — same job, more depth on
*why* each check exists. If the two ever disagree, QUICKSTART is the one that has been run;
report the discrepancy.

### What this skill does and does not cover

- **A one-member team is valid.** Nothing requires two. The QUICKSTART uses two only because
  two different models is the case that exposes the engine/model binding. A single verifier,
  scout, or one-off worker is a normal team — drop member B.
- **`up` and `status` are engine-agnostic. `lead`, `dispatch`, and `down --clean` are not** —
  they assume a GitHub-PR-and-tests workflow (issues, PRs, merged branches). A team whose
  members read an inbox and write a verdict, or run measurements, can use `up`/`status` and
  should ignore the other three rather than try to fit them.
- **Gate 0 proves what will BOOT. It says nothing about independence.** If you are standing up
  a verifier to check your own work, this skill cannot tell you whether that verifier is
  meaningfully independent of you — same account, same machine, possibly the same model
  family. Producer-≠-verifier is your call to make and to defend; the engine binding being
  correct is not evidence of it.
- **There is no budget step, and for a permanent lane you need one.** Engines here share
  machine-wide accounts; a codex status bar showing `weekly 77% left` is a shared pool, not
  yours. A one-off team is noise; a standing lane is a budget decision before it is a config
  decision.
- **Requires `python3`** — both `scripts/verify-check.sh` and any step here that parses config
  shell out to it. If your environment is deliberately grep/sed-only, use the raw `maw config`
  and `maw wake --dry-run` commands, which need neither.

> ## 🧭 Test record — what has actually been run, and what has not
>
> | verb | status |
> |---|---|
> | **`up`** (this QUICKSTART + Gate 0) | **run 4× on 2026-08-06** — author ×2, fresh agent ×1, fresh agent on a non-repo dir ×1 |
> | `status` | exercised only as the peek inside `up`; never run as its own verb |
> | `down` | 🟡 **teardown steps run once (2026-08-06)** on a throwaway repo, both arms: clean worktree removed, dirty worktree kept. `--clean` branch deletion still never run |
> | **`lead`, `dispatch`** | 🔴 **NEVER RUN — untested.** Documented from source and habit, not from execution |
>
> **Everything below the QUICKSTART describing `down`/`lead`/`dispatch` is unverified**, and
> two reviewers found real defects in it (a `head -N` that is a syntax error, a `$N` that is
> never set, a hardcoded `--base alpha`, and a lead-detection rule that contradicts the
> QUICKSTART's own naming rule). Treat those sections as a sketch. `up`, Gate 0 and
> `scripts/verify-check.sh` are the parts with evidence behind them.
>
> Reviewer-reported defect counts, so you can judge whether the list is closed: fresh-agent
> round 1 → 5 blockers / 12 guesses · round 2 → 4 blockers / 10 guesses · atlas → 8 findings ·
> ajfon → 7 defects + a claims audit. **Each round found new ones, so no round is an upper
> bound.** If a step still assumes knowledge you do not have, that is a defect in this
> document, not in you — say which step and what you had to guess.

---

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
Otherwise **make the operator name the team — do not guess.**

```bash
# ❌ NOT `ls …/*.yaml | head -1`. [found by tars 2026-08-06] Real houses have many charters
#    — 11 in ajfon-teams, 20+ in lucifer — so picking the first alphabetically selects the
#    wrong team silently and every later step operates on it.
if [ -z "${TEAM:-}" ]; then
  echo "Charters here — pass TEAM=<name> (the FILE STEM, see below):" >&2
  # .json charters are real and a *.yaml glob silently misses them — lucifer's .maw/teams
  # holds 67 files, 2 of which are .json. [lucifer 2026-08-06]
  ls "$ROOT"/ψ/teams/*.yaml "$ROOT"/ψ/teams/*.json \
     "$ROOT"/.maw/teams/*.yaml "$ROOT"/.maw/teams/*.json 2>/dev/null | xargs -rn1 basename >&2
  exit 1
fi
CHARTER=$(ls "$ROOT"/ψ/teams/"$TEAM".yaml "$ROOT"/ψ/teams/"$TEAM".json \
             "$ROOT"/.maw/teams/"$TEAM".yaml "$ROOT"/.maw/teams/"$TEAM".json 2>/dev/null | head -1)
[ -f "$CHARTER" ] || { echo "no charter for '$TEAM'" >&2; exit 1; }
```

> 🔑 **`maw team up <team>` matches the FILE STEM, not the `name:` inside the charter.**
> `[found by tars 2026-08-06]` A file called `research-team.charter.yaml` whose `name:` is
> `research-team` must be brought up as `maw team up research-team.charter` — using the
> `name:` gives `charter not found`. Several houses use the `<name>.charter.yaml` convention
> (9 files in atlas, 1 in tars), so this bites immediately there.

**Session: take it from the charter, not from where you happen to be sitting.**

```bash
# ❌ NOT `tmux display -p '#S'`. [found by tars 2026-08-06] That is the session the OPERATOR
#    is in. Anyone driving a team from outside its session — the normal case for
#    `status`/`lead` across houses — then peeks the wrong session every time and sees nothing.
SESSION=$(grep -m1 '^session:' "$CHARTER" | sed 's/^session:[[:space:]]*//')
: "${SESSION:=$TEAM}"        # charters may omit it; maw defaults to the team name
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
# A lead is a member with worktree: false — NOT one literally named 'lead'.
# The QUICKSTART tells you to prefix every role with the team name, so a lead in a
# conforming charter is called e.g. 'myteam-lead' and an == 'lead' test never matches it.
# [found by ajfon 2026-08-06] With that test, the lead falls into CODERS and \`down\` kills it.
blocks = re.split(r'(?=^\s*-\s*role:)', text, flags=re.M)
leads = {m.group(1) for b in blocks
         if (m := re.search(r'role:\s*(\S+)', b)) and re.search(r'worktree:\s*false', b)}
print(' '.join(r for r in roles if r not in leads and r != 'lead'))
")
```
⚠️ **Untested.** This block, and every verb below except `up`, has never been run — see the
test record above. The lead-detection rule was wrong until a reviewer read it; assume the rest
of this section carries similar defects and check before relying on it.

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
runs in**.

> 📐 **"Visible from where" — the phrase this document leans on hardest, and it has two
> answers depending on the verb.** `[prism 2026-08-06: they lost real time to this]`
>
> | verb | resolves the layer from |
> |---|---|
> | `maw team up` / `maw wake` | the **member's** path (`--repo-path`) |
> | `maw team spawn` | the **caller's** cwd — not the member's `--cwd` |
>
> So a layer at the team state root alone is invisible to `spawn`, and a layer in your repo
> alone is invisible to the members. Teams using both verbs need **two byte-identical
> copies** — one in the repo (also gets it into git, which fixes the machine-move problem)
> and one at the members' common ancestor.
>
> **"Registered" also means one specific thing:** an exact key in `commands`. `engines` is a
> different map that nothing reads, and glob keys only apply on the window-name path — never
> to an `engine:` lookup.
>
> 🟢 One piece of good news from prism's run: `maw team spawn` **fails loudly** here
> (`engine '<x>' not resolvable — known: […]`, exit 1) because it goes through an exact-key
> resolve that throws. It is `wake`'s fallthrough chain that substitutes silently. `maw wake` has no `--model` flag anywhere in the binary, so **a model can only
live inside the alias's command string.** One alias name = one command = one model. Two
members naming the same alias get the same model, necessarily.

`model:` in a charter never reaches the pane. When `engine:` is present it is inert. When
`engine:` is **absent**, it is worse than inert — the model string is used as the engine
lookup key and silently misses (see 0c). Treat `model:` as a comment; put the real value in
the alias.

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
# <member-identity> = the member's `name:` from the charter (falls back to `role:` if unset)
maw wake <member-identity> --no-attach --dry-run -e codex-hi           --repo-path "$MEMBER_DIR"
maw wake <member-identity> --no-attach --dry-run -e __no_such_engine__ --repo-path "$MEMBER_DIR"
```
Ignore the session name in that output. Standalone `maw wake --dry-run` invents one
(`would wake … in session '76-<name>'`) that has nothing to do with your `session:` — only the
`command:` line matters here.

🔴 **"Both outputs are the same" is NOT the test. Three different failures produce it, and
two have nothing to do with your engine.** `[prism 2026-08-06, running it against a live cell]`

| real cause | what you see | naive reading |
|---|---|---|
| the alias genuinely is not read | two identical `command:` lines | correct ✅ |
| you omitted the positional target | `usage: maw wake <target\|all> …` twice | "engine not read" ❌ |
| the target is a team ROLE, not a registered oracle | `wake: repo not found for <x>` twice | "engine not read" ❌ |

**The real test: both invocations must actually PRODUCE a `command:` line, and those two lines
must differ.** No `command:` line at all means the probe never ran — that is UNVERIFIED, not
a failed engine, and chasing it as a config problem wastes the time prism lost to it.

```bash
real=$(maw wake "$A" --no-attach --dry-run -e team-codex-hi      --repo-path "$DIR" 2>&1 | sed -n 's/^ *command: *//p')
ctrl=$(maw wake "$A" --no-attach --dry-run -e __no_such_engine__ --repo-path "$DIR" 2>&1 | sed -n 's/^ *command: *//p')
if   [ -z "$real" ] || [ -z "$ctrl" ]; then echo "UNVERIFIED — probe did not resolve; check the target name and --repo-path"
elif [ "$real" = "$ctrl" ];            then echo "FAIL — alias not read"
else                                        echo "OK — $real"; fi
```

> ⚠️ `maw wake` resolves its target against the **oracle registry**, not against your team's
> roles. A member name that is not a registered oracle only resolves because `--repo-path`
> is supplied — omit it and you get `repo not found`, which is the second false positive
> above. `scripts/verify-check.sh enginecheck` does not have this hole: it reads the merged
> config directly and uses the wake probe only as corroboration.

#### Scripted form — shipped with this skill, no other repo needed

```bash
VC=~/.claude/skills/oracle-team/scripts/verify-check.sh

bash "$VC" enginelist <dir>               # WHICH aliases exist here — start with this

bash "$VC" enginecheck <charter|team>     # whole roster, per member, from each member's path
bash "$VC" engineone <engine> <dir>       # ONE engine, ONE directory — for single-worker gates
bash "$VC" modelprobe <alias> <dir>       # 💸 SENDS A REAL TURN — the only thing that proves
                                          #    the account can serve that model. Costs quota.
bash "$VC" teamclosed <team>              # is the team really gone (asks tmux first, not maw)
bash "$VC" selftest                       # run this before trusting any of the above
```

### The other scripts shipped in `scripts/` — status, because it is not what you'd assume

`[lucifer 2026-08-06: none of these were referenced anywhere in this document, while one of
them describes the exact failure mode at 9-10 roles that the document lists as a symptom with
the wrong cause]`

| script | what it is | status **on this machine** |
|---|---|---|
| `setup-codex-home.sh`, `codex-setup.ts`, `codex-local.ts`, `codex-local.sh` | give each codex member its **own `CODEX_HOME`**, seeded from a shared credential pool at `~/.codex-team/<N>` | 🔴 **no-ops.** `~/.codex-team/` is empty, so it finds no pool, creates nothing, prints a paste-ready engine block pointing at directories that do not exist — and **exits 0** |

**Why you may still need what they do.** Without a per-member `CODEX_HOME`, every codex member
shares `~/.codex`. `maw team preflight` flags this (`✗ CODEX_HOME isolation: … share
/home/user/.codex`) and the script headers describe losers of the SQLite/PID race booting to a
**bare shell** — which is the "bare shell prompt" symptom in Step 6 whose cause this document
otherwise gets wrong. Observed fine with 2-5 concurrent members; the scripts were written after
17+ raced on one home.

⚠️ **A pinned `CODEX_HOME` also loses `~/.codex/config.toml`** — including `model` and
`model_reasoning_effort`. Copy or symlink that file into each home, or pin both in the alias.

```bash
```

Both emit **anchored machine keys at column 0** alongside the human output, so a gate can
`grep` rather than scrape prose:

```
enginecheck.member: <role> PASS|FAIL|UNVERIFIED engine=<name> resolved=<cmd> [pinned=no]
enginecheck.engine: <name> PASS|FAIL|UNVERIFIED resolved=<cmd> scope=resolved|dir-absent [answered-from=<path>]
enginecheck.scope: out-of-scope=model-served,prompt-delivery,account-quota
enginecheck.unverified: [<comma-list>]          ← EMPTY when this run had no variable gaps
overall: PASS|FAIL|UNVERIFIED requires-post-boot-verification=true
```
Every line is emitted on every run, in that order, with `overall:` last. `enginecheck.member:`
repeats once per member in roster mode and is absent in `engineone`; `enginecheck.engine:`
is the reverse.

**Two namespaces, deliberately separate** `[ajfon, 2026-08-06]`:

| line | meaning |
|---|---|
| `enginecheck.scope: out-of-scope=…` | things this tool **can never** measure, whatever it is run against. A constant. **Not** a result. |
| `enginecheck.unverified: …` | gaps **in this particular run** — `unpinned-alias`, `member-unresolvable`, `answered-from-ancestor=<path>`, `asked-dir-does-not-exist`. **Empty means none.** |

> Why they are split: an earlier version put both in one line, hardcoded, so **every run
> always carried an UNVERIFIED field**. The rule below then evaluated true forever, the
> three-value contract collapsed to FAIL / not-FAIL, and `overall: PASS` became a value that
> was printed but must never be trusted. A criterion that always returns the same answer
> discriminates nothing — the same defect this whole check exists to prevent, pointed the
> other way.

### 🔴 `overall:` means ENGINE RESOLUTION ONLY. It is never total readiness.

**Do not gate on `grep '^overall:'` alone.** `overall: PASS` can and does print on the same
output as `model-served=UNVERIFIED` — the alias resolves to the command you asked for, and
nothing here knows whether your account will serve that model. A consumer reading only
`overall:` admits a worker that was never confirmed. That is the same false-green shape this
whole check exists to prevent, one level up.

**Parse four fields. This is the interface:**

| field | read it as |
|---|---|
| `overall:` | engine resolution — **necessary, never sufficient** |
| `enginecheck.unverified:` | **non-empty ⇒ this run had a real gap.** Empty ⇒ it did not. |
| `pinned=` | `no` ⇒ you got the right binary **by luck**, via `default`; a window-name change breaks it |
| `scope=` | `dir-absent` ⇒ the answer came from `answered-from=<path>`, **not** the directory you asked about |

> **Rule: `overall: PASS` + non-empty `enginecheck.unverified:` ⇒ treat as UNVERIFIED,
> never PASS.** `[atlas T4543 contract, 2026-08-06; bound to the variable namespace after
> ajfon showed the original form could never be false]`
>
> `enginecheck.scope: out-of-scope=…` is **not** part of that rule. It is a standing
> declaration of what the tool cannot see at all, and folding it in makes the rule
> unfalsifiable. It still tells you the real thing: **only a post-spawn banner settles whether
> the account serves the model.**

> 🔬 **Measuring rc: never through a pipe.** `[holmes 2026-08-06 — they nearly filed a bug
> against this tool because of it]`
> ```bash
> verify-check.sh engineone __no_such__ "$PWD" | tail -6; echo $?   # → 0, that is TAIL's rc
> verify-check.sh engineone __no_such__ "$PWD" >/tmp/o 2>&1; echo $? # → 1, the script's rc
> ```
> A pipeline's status is its **last** command's, so piping to `tail`/`head`/`grep` to read the
> output silently discards the verdict you were checking. This bites reviewers hardest: it
> makes a correct tool look like it inherited the rc=0 disease, and a phantom bug report costs
> more than a real one — it sends the author to fix something that is not broken. It is also
> the same trap that produced four real defects in this skill's own history.

`rc` 0=PASS · 1=FAIL · 2=UNVERIFIED. **UNVERIFIED is not a pass** — it means the check could
not answer, which is different from answering "fine". Concretely: `engineone <alias> <dir>`
where `<dir>` does not exist yet returns **UNVERIFIED rc=2**, not FAIL — it answered from an
ancestor, so it cannot tell "alias absent" from "we looked in the wrong place". A gate that
runs before `mkdir` must not read that as a bad alias. A directory that *does* exist and has
no such alias still returns FAIL rc=1.

> **Parser compatibility, measured — not asserted** `[ajfon, 2026-08-06]`. The
> `requires-post-boot-verification=true` suffix on `overall:` was added after these lines were
> first published. It does **not** break `grep '^overall: PASS'` or `awk '$1=="overall:"'`. It
> **does** break `grep '^overall: PASS$'` and `grep -x 'overall: PASS'`. If you anchored to
> end-of-line, drop the anchor.

Requires `maw` and `python3` on PATH. If your gate deliberately stays on grep/sed only, use
the raw `maw` commands above instead — they need neither.

After spawning, confirm on the engine's own UI (`maw peek <session>:<window>`) that the
status bar shows the model you asked for. That is the only layer of evidence that covers
whether the account can actually serve that model — nothing before it does.

#### 0b-2. Also check the CHARTER → PLAN path. Gate 0b structurally cannot.

Gate 0b tests the **alias → command** path: you supply `-e` by hand, so it proves the alias
resolves. It never touches the **charter → plan** path — what engine maw decides each member
gets *from your charter*. A charter can pass 0b completely and still boot the wrong engine.

```bash
maw team up "$TEAM" --dry-run       # read the `engine` COLUMN, member by member
```

🔴 **Everything under `defaults:` is dead except `worktree`.** `[lucifer 2026-08-06, clean A/B
plus a grep of the whole crate; I reproduced both]` maw resolves engine as
`-e flag → member.engine → member.model → "claude"` — **`defaults` is not in that chain.**

The dead list, checked against the source rather than guessed:
`defaults.engine` · `defaults.branch` · the entire `engines:` map · `model:`.
The **only** survivor is a bool derived from whether the key `defaults.worktree` exists
(`team_preflight_checks.rs:41`). Everything else is parsed, stored, and never consulted.

> 🪞 **There is a green unit test whose NAME is the false-confidence surface.**
> `team_core.rs:763` is called
> `team_charter_preserves_defaults_engines_and_coerces_yaml_worktree_true` and asserts that
> `defaults.get("branch")` and `engines.get("omx-1")` round-trip through the parser. That is
> true and proves only that the **parser stores** them — never that anything **consumes**
> them. A suite passing with a test named *preserves_defaults_engines* reads like "defaults
> and engines work". This is how a dead field survives with CI green, and it is the same shape
> as a script that exits 0 having done nothing: **the check ran, it passed, and it cannot see
> the thing it appears to cover.**

```
charter: defaults: {engine: codex-xhigh}, no per-member engine:
plan:    supervisor-watchdog  claude  …  -e claude     ← codex-xhigh appears nowhere, rc=0
control: same defaults + per-member engine: codex-medium
plan:    frontend-engineer    codex-medium  …          ← per-member DOES reach
```

Their exposure: **45 of 60 charters** carrying a `defaults.engine` have **zero** per-member
`engine:` — the dominant pattern, not an edge case. A house whose `defaults.engine` happens to
be `claude` never notices, because the substitution matches what it wanted.

⚠️ `enginecheck` reports this charter as FAIL — but until this was found it named the wrong
cause, because it parses via `maw team plan`, which has **already** substituted `claude`. It
now reads `defaults:` from the file directly and says so before anything else. A tool that
inherits the substitution it is meant to detect cannot see it.

> ✅ **The detector is validated at n=65, not by me.** `[lucifer 2026-08-06]` Run across their
> whole corpus: **65 charters · 45 warned · 20 quiet · 0 mismatches.** The 45 are exactly the
> pure-`defaults` set; of the 20 quiet, 15 have per-member `engine:` and 5 have no `defaults:`
> at all. **Both arms matter and the quiet arm is the harder one** — a detector that shouts at
> everything is as useless as one that never shouts. I had verified it at n=2.

#### 0c. Naming and worktree — the two things that make `maw team up` exit 1

`maw team up` builds `maw wake <member-name> ... -e <engine>` per member. That wake must
resolve, and two independent rules decide whether it does:

- **Member names must be unique across the WHOLE FLEET, not just your team.** A generic
  name collides with every other team using it and wake dies on ambiguity:
  ```
  wake: 'verifier' matches multiple targets. Found nearby:
    1. session job2b-oracle-scan  2. session previews-port  3. session t4526-rs-fixes  ...
  ```
  `team up` then exits 1 while `--dry-run` stayed green. Prefix every role with the team:
  `refract-scope`, `st-alpha` — not `coder-1`, `verifier`, `reviewer`.

- **Give every member a `worktree:` path — or a `cwd:`, either works.** `team up` resolves
  it as `member.worktree` → falls back to `member.cwd` → falls back to **the identity string**
  (`team_up_helpers.rs:236`). With `worktree: false` it sends no `--repo-path` at all, so wake
  resolves the name against the oracle registry and boots the member **in whatever repo that
  name is registered to — not your team's repo.** Your config layer is invisible there and
  the alias silently does not apply. With a real path, `team up` passes `--repo-path`, which
  both puts the member in the right tree *and* removes the requirement that the name be a
  registered oracle. The path must already exist.

- **🔴 `team up` does not expand `${VARS}` in a path — not even exported ones.**
  `[verified 2026-08-06 by running it]` A charter with `cwd: ${TEST_ROOT}/ev-a` passes
  `--dry-run` showing the literal string, then dies at spawn:
  ```
  team spawn: canonicalize <repo>/${TEST_ROOT}/ev-a failed: No such file or directory
  ```
  The variable is treated as a literal directory name and appended to the repo path. If your
  team's layout is defined by an environment variable — a common pattern for cells whose
  state lives outside any repo — **`maw team up` cannot launch it at all**, and you need
  your own launcher that expands the path before calling maw. Use literal or repo-relative
  paths in any charter you intend to bring up with this skill.

- **🔴 A member with `model:` and no `engine:` uses the MODEL STRING as its engine name.**
  `team up` resolves engine as `-e flag` → `member.engine` → **`member.model`** → `"claude"`
  (`team_up_helpers.rs:235`). So `model: gpt-5.5` alone produces `wake -e gpt-5.5`, which is
  not a registered command, and falls through silently. `model:` is genuinely inert *only*
  when `engine:` is also present. Never write `model:` without `engine:`.

```
charter:  - role: mfb-a
            model: gpt-5.5        # no engine:
dry-run:  mfb-a  mfb-a  gpt-5.5  missing  would fresh wake -e gpt-5.5
                        ^^^^^^^ the model string became the engine name
```

```yaml
members:
  - role: st-alpha
    name: st-alpha            # team-prefixed, unique fleet-wide
    engine: t-codex-sol
    worktree: agents/st-alpha  # exists, and makes the layer visible
```

#### 0d. Clean up after a team, or the next one fails

`maw wake` registers the session in `~/.maw/fleet/<session>.json`, and **`tmux kill-session`
does not remove it.** Stale entries keep answering to their member names and cause the
ambiguity failure above for whoever spawns next. After tearing a team down:

```bash
tmux kill-session -t "$SESSION"
rm -f ~/.maw/fleet/"$SESSION".json      # otherwise the names stay claimed
```

#### 0e. Traps confirmed by running them

- **`maw team up -e <engine>` overrides every member's charter engine.** One flag flattens a
  mixed-engine team (`a=codex-hi, b=claude-hi` → both become the flag's value). Omit `-e`
  unless you mean "everyone on this one engine".
- **`maw team resume` respawns every role as `claude`** — it never forwards engine. Prefer
  `maw team up`, which reads the charter.
- **`engines:` inside a charter is a dead field.** maw's parser stores it; no code reads it.
  Engine commands belong in the config layer.
- **✅ Invented member names are fine — as long as the member has a path.** `[verified by two
  independent testers, 2026-08-06]` A name that is in no registry resolves normally once
  `worktree:`/`cwd:` gives `team up` a `--repo-path`:
  ```
  wake <invented-name> --dry-run -e codex --repo-path <dir>   → resolves, rc=0
  wake <invented-name> --dry-run -e codex                     → wake: repo not found for <name>, rc=1
  ```
  This matters most for exactly the case you are probably here for: **a brand-new lane — a
  verifier, a scout, a one-off cell — has an unregistered name by definition.**

  > ❌ **This bullet previously said the opposite** — "member identities must already be
  > wake-resolvable… you cannot invent arbitrary member names" — which contradicted 0c three
  > bullets above and made readers with a new lane stop before starting. It was never true,
  > not merely stale: it described the no-path case as if it were the general rule. Grepping
  > for outdated wording would never have found it — only running the case did.

  **Without a path there are TWO different failures, and one of them exits 0.**
  `[lucifer 2026-08-06 — my first correction of this bullet named only the first form and
  called the second nonexistent, which over-corrected in the other direction]`
  ```
  wake: repo not found for <name>                                    rc=1
  wake: '<name>' was not found exactly. Found nearby: …              rc=0   ← fuzzy candidates exist
  ```
  The second is the common one on a populated fleet, and **`maw team up` swallows it**: the
  name half-matches something, nothing spawns, and the exit code says fine.

  Name collisions are still real when a member has **no** path (see the fleet-unique rule in
  0c), so keep prefixing roles with the team name. With a path, a collision-prone name like
  `verifier` also resolves — measured in dry-run only.
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

🔴 **Do NOT stop just because preflight is red.** It cannot pass before a spawn: `spawn
ordering: session does not exist before spawn` is true by definition, and `codex trust:
missing trusted project entry` fires on any member directory codex has not been told to trust
(see the QUICKSTART Step 3 note — that is also the cause of the trust prompt in Step 6).

Read preflight for the checks that *are* meaningful pre-spawn — role uniqueness, existing
artifact collisions, CODEX_HOME isolation, worktree path collisions — and stop on **those**.
The gate that decides whether to proceed is Gate 0b above, which fails for exactly one reason.

With `--only`:
```bash
maw team up "$TEAM" --only "$ONLY_ROLE"
```

Without:
```bash
maw team up "$TEAM"
```

### Verify step (MANDATORY after spawn)

Poll each coder until its banner is real, then check. **Do not use a fixed sleep** — measured
boot-to-real-banner ran ~25s to ~35s (n=3, one machine, one codex version), and an earlier
version of this block said 10s, which is short enough to read `model: loading` and believe it.

```bash
for ROLE in $CODERS; do
  echo "=== $ROLE ==="
  for _ in $(seq 30); do
    tmux capture-pane -p -t "${SESSION}:${ROLE}-oracle" | grep -q 'model:.*loading' || break
    sleep 3
  done
  # grep -n . not tail: the banner is in the pane's UPPER half, tail prints blank padding
  tmux capture-pane -p -t "${SESSION}:${ROLE}-oracle" | grep -n . | head -30
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
1. Kill the bad coder: `maw tmux kill "${SESSION}:${ROLE}-oracle"`
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

## Verbs `dispatch` / `down` / `lead` — moved to `references/pr-workflow-verbs.md`

🔴 **Split out on 2026-08-06 because every one of them was defective on first execution** --
`down` committed a `.env` file, `down --clean` deleted an unrelated branch, `dispatch` built a
malformed command under `--dangerously-bypass-approvals-and-sandbox`, `lead` produced
`--base ''`. All are fixed there; **none has ever been run against a real team.**

They also assume a workflow this skill does not otherwise require: GitHub issues in, PRs out,
members in disposable git worktrees. If your team returns a verdict or a measurement, they do
not apply -- two reviewers reported exactly that.

**Everything above this line -- Gate 0, `up`, and `scripts/verify-check.sh` -- is the part with
evidence behind it.**

## Verb: `status` — Read-only peek

Same as `lead` Step 1 + Step 2 (peek + PR list), but takes NO action.
No dispatch, no merge, no nudge. Just report.

```bash
for ROLE in $CODERS; do
  echo "=== $ROLE ==="
  maw peek "${SESSION}:${ROLE}-oracle" 2>&1 | grep -n . | head -12
done
echo "--- PRs ---"
BASE_DETECTED=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
BASE="${BASE:-${BASE_DETECTED:-main}}"
gh pr list --repo "$PROJECT" --base "$BASE" --state open 2>/dev/null || echo "no PRs"
```

---

## Principles

1. Lead orchestrates, coders code — lead NEVER writes code itself.
2. Charter is the source of truth — session, members, engines, headless config all from yaml.
3. `maw tmux kill` for windows — never `maw team down --only` (broken).
4. Never `git worktree remove --force` — commit-save first.
5. Branches survive worktree removal → committed work is never lost.
6. Always brace zsh vars: `"${SESSION}:${ROLE}-oracle"` not `$SESSION:$ROLE`.
7. PR → alpha only. Never push/merge to main.
8. Merge greens immediately (standing approval).
9. NO-GAP dispatch: next task in same message as done confirmation.
10. Never nag coders about context — omx auto-compacts.
11. SendMessage = silent no-op for omx — always use `maw hey`.
12. For Rust: build gate = `cargo test` + `cargo clippy -- -D warnings`.
13. Headless dispatch uses background Agent (run_in_background=true), NOT shell `&`.
14. Haiku wraps codex exec — cheap wrapper, real work is codex (gpt-5.5/o3).
15. Escalate to `/oracle-team up` (tmux panes) when headless coders need interactive debugging.
