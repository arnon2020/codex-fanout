---
name: oracle-team
description: "Stand up a maw agent team with the engine and model each member is supposed to get — and prove they got it. Covers the full lifecycle: up (tmux), down (teardown), lead (orchestrate), status (peek), dispatch (headless codex exec). Gate 0 is the part most teams get wrong: a charter's `engine:` is only a lookup key into `commands.<name>` in a config layer visible from the WORKER's directory, and a charter's `model:` never reaches the pane — inert when `engine:` is present, and used as the engine key itself when `engine:` is absent, which misses with certainty. An unregistered name silently boots a different engine with exit 0. Use for any of: '/oracle-team up|down|lead|status|dispatch', 'bring up the team', 'spawn coders', 'set up a codex team', or whenever a member booted with the wrong engine/model, a charter's model: had no effect, or you need per-member engine/model selection (codex vs claude, gpt vs opus) in one team. Path-agnostic — works from any oracle's repo."
argument-hint: "up [profile] [--only codex-N] | down [1,2,3] [--clean] | lead | status | dispatch [issue#] [--model X]"
---

# /oracle-team — Unified Codex Team Lifecycle

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

```bash
mkdir -p "$ROOT/.maw"
cat > "$ROOT/.maw/maw.config.60.json" <<'JSON'
{ "commands": {
    "team-codex-hi": "codex --model <MODEL-A> --ask-for-approval never --sandbox danger-full-access",
    "team-codex-lo": "codex --model <MODEL-B> --ask-for-approval never --sandbox danger-full-access"
} }
JSON
```
**Finding model names that actually work — one per engine, they are not interchangeable:**

| engine | how to list what your account serves |
|---|---|
| codex | `grep '^model' ~/.codex/config.toml` gives the current default · `codex --help` for the flag |
| claude | `claude --help` lists the aliases (`opus`, `sonnet`, `haiku`) — an alias is fine in the command |
| opencode | `opencode models` prints every `provider/model` it can reach |

Do not invent names. If you need **two different models**, note that `~/.codex/config.toml`
holds only one default — you either name a second codex model explicitly, or make the second
member a different engine entirely (mixing codex and claude in one team is normal and is what
the aliases above are for).

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

Fields deliberately omitted, because they are not needed and their absence confuses people
who copy fuller examples: `project: <owner>/<repo>` is validated by `maw team preflight` but
is not required by `maw team up`; `branch:` is likewise not consulted when bringing a team
up. Add them only if some other verb you use needs them.

**Step 4 — prove the aliases are actually visible.** Not optional: `maw team preflight` and
`maw team up --dry-run` are both green even when this is broken.

```bash
cd "$ROOT/agents/$A"
maw config sources        # your maw.config.60.json MUST be listed here
maw wake "$A" --no-attach --dry-run -e team-codex-hi        --repo-path "$ROOT/agents/$A"
maw wake "$A" --no-attach --dry-run -e __no_such_engine__   --repo-path "$ROOT/agents/$A"
cd "$ROOT"
```
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
sleep 40                                                   # see the loading note below
tmux capture-pane -p -t "$SESSION:${A}-oracle" | tail -25
tmux capture-pane -p -t "$SESSION:${B}-oracle" | tail -25
```

First-boot prompts that stall a member — each one leaves it looking merely quiet:

| what you see | engine | clear it with |
|---|---|---|
| `✨ Update available!` | codex | `tmux send-keys -t "$SESSION:${A}-oracle" 2 Enter` |
| `Is this a project you created or one you trust?` | claude | `tmux send-keys -t "$SESSION:${B}-oracle" 1 Enter` — **[reported by a tester, not reproduced by this doc's author]** |
| a bare shell prompt `❯` | any | the engine never started — go back to step 4 |

⏳ **`model: loading` occupies the exact line you are told to read.** After clearing a prompt
the codex banner shows `model:       loading` for ~25 more seconds before the real value
appears. Do not accept the first banner you see — re-peek until the value is not `loading`.

**Expected, and the only check that covers whether the account can actually serve the model:**
the engine's own banner naming it. Per engine:
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

> **Test record.** Run start-to-finish twice: once by its author, once by an agent given only
> this skill and no other context. The second run **succeeded but reported 5 blockers and 12
> guesses** — every one of them is now fixed or documented above, including the two that
> mattered most: `maw team up` requires a git repo even outside your oracle's repo (the
> earlier "everything else is identical" line here was simply false), and the tmux window is
> `<role>-oracle`, so the peek command in the old Step 6 silently targeted nothing.
> **Three of the four failure modes that run hit returned rc=0.**
>
> If a step still assumes knowledge you do not have, that is a defect in this document, not in
> you. Say which step and what you had to guess.

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
runs in**. `maw wake` has no `--model` flag anywhere in the binary, so **a model can only
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

**If both commands print the same launch line, your alias is not being read** — the name was
discarded and both fell through to the same fallback. That comparison is the check that can
fail; a single green line on its own proves nothing.

#### Scripted form — shipped with this skill, no other repo needed

```bash
VC=~/.claude/skills/oracle-team/scripts/verify-check.sh

bash "$VC" enginecheck <charter|team>     # whole roster, per member, from each member's path
bash "$VC" engineone <engine> <dir>       # ONE engine, ONE directory — for single-worker gates
bash "$VC" selftest                       # run this before trusting either of the above
```

Both emit **anchored machine keys at column 0** alongside the human output, so a gate can
`grep` rather than scrape prose:

```
enginecheck.member: <role> PASS|FAIL|UNVERIFIED engine=<name> resolved=<command> [pinned=no]
overall: PASS|FAIL|UNVERIFIED
```
`rc` 0=PASS · 1=FAIL · 2=UNVERIFIED. **UNVERIFIED is not a pass** — it means the check could
not answer, which is a different thing from answering "fine". `pinned=no` marks the case where
an unregistered engine currently resolves to the right binary by luck via `default`.

Requires `maw` and `python3` on PATH. If your gate deliberately stays on grep/sed only, use
the raw `maw` commands above instead — they need neither.

After spawning, confirm on the engine's own UI (`maw peek <session>:<window>`) that the
status bar shows the model you asked for. That is the only layer of evidence that covers
whether the account can actually serve that model — nothing before it does.

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
