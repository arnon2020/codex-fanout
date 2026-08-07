# `down` — universal teardown

> ## This file exists because four oracles falsified the axis the old one was cut on
>
> On 2026-08-06 this skill's author wrote into `pr-workflow-verbs.md` that `down`/`lead`/
> `dispatch` **"will never be peer-validated, because reviewers' teams return verdicts rather
> than PRs."** That was inferred from one round of "not applicable" feedback and never checked
> with anyone. Four oracles were then asked directly. **All four contradicted it**, and lucifer
> named the actual mistake:
>
> > **แกนที่คุณแบ่งผิด: ไม่ใช่ 'มี PR / ไม่มี PR' แต่เป็น 'มี git artifact ต้องเก็บ / ไม่มี'**
> > *(the axis is not PR / no-PR, it is leaves-git-state / doesn't)*
>
> PR is an **output channel**. Teardown load is about **state left behind**. They are orthogonal,
> and every team measured had `gh pr list` empty:
>
> | oracle | leaves git state? | measured, 2026-08-06 |
> |---|---|---|
> | **lucifer** | **yes, heavily** | 37 worktrees (36 team), 16 already prunable · 37 branches, **36 unmerged, 0 merged**, one with 11 commits main doesn't have · 15 stray dirs in `<repo>/agents/` **not in `.gitignore`** |
> | **ajfon** | **yes** | 5 worktrees stranded **3–4 days**, all unmerged (`ahead` 2/0/7/4/7) — `down` was never called between 08-03 and 08-06 |
> | **atlas** | no | verifier lane: brief in → verdict file out. No branch, no worktree |
> | **prism** | no | `prism-cell` member dirs are **not git repos at all** (`fatal: not a git repository`, all 8 roles) |
>
> **The two "no" cases still need teardown** — atlas and prism both said the PR-free form is
> usable as-is, and prism's leftovers were the ones that actually kept firing (below). So the
> split is teardown-vs-PR-plumbing, but the reason is not "some teams don't matter" — it is
> that **every team leaves state, just not the same kind**.
>
> Retraction recorded rather than edited away, per this repo's append-only rule. The original
> claim was wrong in the specific way this repo has a name for: **verify one property → conclude
> for all** — pointed, this time, at other people's work.

---

## The four kinds of leftover state

Ordered by how measured they were, not by severity.

| kind | who it bit | why it is missed |
|---|---|---|
| **git**: worktrees, unmerged branches, stray dirs | lucifer, ajfon | teardown *looks* done — the session is gone |
| **fleet reservation**: `~/.maw/fleet/<session>.json` | atlas, lucifer, and this author | **`tmux kill-session` does not remove it** · nothing fails now; the **next spawn** hits a name collision |
| **external**: systemd timers, cron, watchers | prism | lives entirely outside git and tmux — no teardown step ever looks there |
| **secrets**: untracked `.env*` in a worktree | this author | a teardown that "helpfully" commits before removing turns them permanent |

**Fleet reservations, verified independently by two houses on 2026-08-06:**

```
fleet files 72 (stale 65) · identities 143 (stale 130)
largest holders: 50-lucifer.json → 23,  114-codex-fanout.json → 6,  50-ajfon.json → 6
live tmux sessions on machine: 9
```

> **Count identities, not files** — see Step 3. The file count was this document's original
> figure and it understates the real one by about half, because **one file reserves many names**
> and the name is what collides. The two counts also drift within the hour: atlas measured 72
> files, this author 73 sixty-five minutes later, then 72 again. atlas checked that themselves
> rather than reporting it as a discrepancy.

`72-hound-codex.json` still reserves the name of an oracle that does not exist — and it is held
inside `50-lucifer.json` as well, one of 24 identities in that single file. arnon hit the
user-visible form of the same bug the same day: a deleted agent (`argus`) **still appearing in
the summon UI**, because `~/.maw/fleet/28-argus.json` outlived its removal from config.

**External state, measured live by prism:** three systemd timers still firing every 5 minutes at
a cell that was frozen, not torn down — `evidence-cell-rq001-watchdog.timer`,
`evidence-cell-timeout-watchdog.timer`, `maw-gate-tick-evidence-cell.timer`. prism's own summary:
*"leftover ที่กัดคือ state ภายนอก (systemd/tmux) ไม่ใช่ worktree"*.

---

## Step 0: Snapshot before teardown — prism's addition

> prism: *"ทีมไหนก็ต้องการ snapshot-before-teardown ไม่ว่าผลลัพธ์จะเป็น PR หรือ verdict"*
> — and they run it in production (`manifest.json` + engine-layer copy, so `rollback.sh` can
> reverse). This generalises wider than anything PR-specific, so it goes first.

```bash
: "${ROOT:?Step 0 needs \$ROOT (the repo root) — set it before running}"
: "${SESSION:?Step 0 needs \$SESSION}"
SNAP="${SNAP:-$HOME/.maw-teams/.snapshots/${SESSION}-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$SNAP" || { echo "✗ cannot create snapshot dir $SNAP — stopping"; return 1 2>/dev/null || exit 1; }

# $CHARTER unset used to fail here in silence, because stderr was discarded.
got_charter=no
if [ -n "${CHARTER:-}" ] && [ -f "$CHARTER" ]; then
  cp "$CHARTER" "$SNAP/charter.yaml" && got_charter=yes || echo "⚠ could not copy charter"
else
  echo "⚠ \$CHARTER is unset or missing — snapshot has NO charter, so teardown is only partly reversible"
fi

# Config layers live under $ROOT, not $PWD. Other steps tell you to run from a member
# directory; a relative glob there finds nothing and [ -e ] hides it. Anchor the path.
found=0
for L in "$ROOT"/.maw/maw.config.*.json; do
  [ -e "$L" ] || continue
  cp "$L" "$SNAP/" && found=$((found+1))
done
[ "$found" -gt 0 ] || echo "⚠ no engine-layer files found under $ROOT/.maw/ — if you expected some, you are in the wrong \$ROOT"

cp ~/.maw/fleet/"${SESSION}".json "$SNAP/" 2>/dev/null || true   # absent is normal — see Step 3

# 🔴 A redirect creates the file even when the command fails, so a failed capture leaves a
#    ZERO-BYTE file that is indistinguishable from "captured, nothing to record".
#    Keep only what actually has content, and count it.
cap() {   # cap <outfile> <cmd...>
  local out="$1"; shift
  "$@" > "$SNAP/$out" 2>/dev/null
  if [ -s "$SNAP/$out" ]; then return 0; fi
  rm -f "$SNAP/$out"; return 1
}
gitcap=0
cap windows.txt    tmux list-windows -t "=$SESSION" -F '#{window_name}'
cap worktrees.txt  git -C "$ROOT" worktree list && gitcap=$((gitcap+1))
cap branches.txt   git -C "$ROOT" branch -vv     && gitcap=$((gitcap+1))

if [ "$got_charter" = yes ] && [ "$found" -gt 0 ] && [ "$gitcap" -eq 2 ]; then
  echo "snapshot: $SNAP  (charter + $found layer file(s) + git state)"
else
  echo "🔴 PARTIAL snapshot: $SNAP  (charter=$got_charter, layers=$found, git-state=$gitcap/2) — teardown from here is NOT fully reversible"
  [ "$gitcap" -eq 2 ] || echo "   ⚠ git state not captured — is \$ROOT ($ROOT) actually a git repo?"
fi
```

Cheap, and it is the only thing that makes any later step reversible.

> ⚠️ **Two ways this step used to under-record without saying so.** `[found by holmes, read-only,
> 2026-08-06]` The layer glob was **relative to `$PWD`, not `$ROOT`** — and other steps in this
> file tell you to work from a member directory, where it matches nothing and `[ -e "$L" ]`
> swallows the miss. And `cp "$CHARTER" … 2>/dev/null` **failed silently when `$CHARTER` was
> unset**, discarding the one error that would have told you. Both produced a snapshot that
> looked successful and could not restore what it claimed to. It now counts what it captured and
> says when the count is zero — *a snapshot you cannot trust is worse than none, because the
> later steps are written as if it exists.*
>
> 🔴 **Then running it — the first time anyone had — found a thirteenth defect that review had
> not.** `[2026-08-06]` The fixed version warned correctly and then **contradicted itself one
> line later**:
>
> ```
> ⚠ $CHARTER is unset or missing — snapshot has NO charter …
> snapshot: …/t0b-stamp  (charter + 2 layer file(s))     ← says "charter"
> ```
>
> The warning scrolls past; **the summary line is what gets read, pasted into a report, and
> believed.** So the step still ended by claiming a complete snapshot it did not have. It now
> tracks what was actually captured and prints `🔴 PARTIAL snapshot … NOT fully reversible`
> instead of a success line.
>
> This one matters beyond the bug: holmes read this block carefully enough to find two real
> defects in it, and *this* survived, because it is not visible in the source — **you have to see
> the two lines printed together.** Review and execution do not find the same class of thing.
>
> 🔴 **Fourteenth defect, found the second time it was run — three arms, real files, 2026-08-07.**
> The step ended with **zero-byte `worktrees.txt` and `branches.txt`** whenever `$ROOT` was not a
> git repo. `>` creates the file *before* the command fails, so a failed capture is
> indistinguishable from *"captured, there was nothing to record"* — and the summary line said
> nothing about git state at all, only charter and layers.
>
> ```
> ARM C (ROOT=/tmp)   before:  branches.txt 0B   worktrees.txt 0B   ← look captured
>                     after :  (absent)          git-state=0/2 reported
> ```
>
> Anyone restoring would have seen `worktrees.txt` sitting there and believed the worktree list
> was recorded. ⇒ `cap()` now keeps a file **only if it has content**, deletes it otherwise, and
> the summary carries `git-state=N/2` plus an explicit *"is `$ROOT` actually a git repo?"*.
>
> 🔑 **Same shape as the thirteenth, one layer down**: the thirteenth was a *summary line* that
> contradicted a warning; this is a *file on disk* that contradicts what was captured. Both are
> **an artifact that reads as success**. The verified arms are now A (full), B (no charter),
> C (no charter, no layers, no git) — and **zero-byte files remaining: 0**.

## Verified arms — what has actually been executed, and what has not

`[2026-08-07]` Honesty about this file's own evidence level, since it spent two days being
reviewed by people who could not run it:

| step | executed against real state? |
|---|---|
| **Step 0** | ✅ **yes** — 3 arms, real charter + real layer + real git root, 2026-08-07 |
| Step 1 | partially — `tmux kill-window` paths exercised on throwaway sessions |
| Step 2 / 2b | ❌ **read-only review only** (ajfon, lucifer, holmes) — never run on a real team's git state |
| Step 3 | ❌ **never run** — touches `~/.maw/fleet/`, shared; atlas declined to be first and was right |
| Step 4 | ❌ **never run** — external state (systemd timers) is prism's category, in prism's house |
| Step 5 | ❌ **never run** |

**Do not read the density of commentary in this file as evidence that it works.** Steps 2–5 are
carefully reviewed and unexecuted; that is a different claim from Step 0's.

## Step 1: Kill the session's windows

> ## 🔴 First: is the team's session **your own**?
>
> `[found by lucifer, using Gate 0 on a real unspawned charter, 2026-08-06]` This file assumed
> without ever saying so that the team's session is not the session you are living in. lucifer's
> `ws-parity-port` charter declares `session: 84-lucifer` — **their own oracle's session**, where
> `lucifer-oracle` runs. The team would be spawned as extra windows beside them, and any
> `tmux kill-session -t "=$SESSION"` in teardown **kills the oracle running the teardown.**
> Nothing in Gate 0, preflight, or this file warned about it.

> ## 🔴 `maw tmux kill` silently accepted a target form it cannot resolve — and this file hid the error
>
> `[measured on a throwaway session, 2026-08-06 — third version of this box, see below]`
> Every earlier version of this step, and of `SKILL.md`, killed member windows with:
>
> ```bash
> maw tmux kill "${SESSION}:${ROLE}-oracle" 2>&1 | tail -1     # the old Step 1
> ```
>
> **`maw tmux kill` only resolves the numeric form `session:INDEX.PANE`.** Measured against a
> session with windows `victim-oracle` and `keeper-oracle`:
>
> | target passed | rc | window killed? |
> |---|---|---|
> | `$S:victim-oracle` — **the form this skill used** | 1 | **no** |
> | `$S:victim-oracle.0` | 1 | **no** |
> | `$S:0.0` | **0** | **yes** |
>
> A charter gives you role names, so this skill only ever built the name form — **the one that
> never matches.** maw said so every time (`pane '…' not found`, rc=1), and
> **`| tail -1` threw the exit status away**: `$?` after that pipeline is *tail's*, which is 0.
> The pipe was there to keep output tidy, and it silenced the only signal that mattered.
>
> ⇒ Use `tmux kill-window`, which accepts window **names**; never pipe a command whose exit
> status you intend to read; and **verify the window is gone** instead of trusting rc or message.
>
> ### 🔁 This box was wrong twice before it was right. Both corrections came from peers.
>
> **v1 said `rc=0` — "maw lies about its exit code."** False, and false *by the mechanism it was
> describing*: the rc was read through `maw … | tail -1`, so the 0 was tail's. atlas and ajfon
> both ran it unpiped, got **rc=1**, and reported the mismatch. `PIPESTATUS` settles it: `1` maw,
> `0` tail. **The pipeline-rc trap — which this repo has a selftest for — was used to diagnose a
> different silent failure, and produced one.** atlas flagged it as an unreproducible difference
> rather than a correction, because their target was fabricated and this one was a live window:
> right discipline, and the simpler explanation was still mine.
>
> **v2 said "there is no such subcommand."** Also false. lucifer read the source: `kill` **is
> implemented**, in `crates/maw-cli/src/core_impl/tmux_kill.rs`, registered through
> `TMUX_SUB_FRAGMENTS` rather than `TMUX_BUILTIN_SUBS` — so the **hand-written** usage string
> (`tmux_dispatch.rs:37`) lists only builtins and omits it. I had concluded "does not exist"
> **from a usage line**, which is this repo's signature error — read one surface, conclude for
> the whole — committed while documenting that very error class. `strings` on the installed
> binary shows the symbol; the measurement above shows it working.
>
> **What survived all three versions: the fix.** `tmux kill-window` + verify was correct under
> every explanation, which is why it shipped before the reasoning was settled. **But a right fix
> with a wrong reason is a trap for the next reader** — they will carry the reason, not the
> patch. lucifer's ask was exactly that: *"เก็บ fix ไว้ ไม่ต้องเปลี่ยน แต่แก้คำอธิบาย."*
>
> ### Independently reproduced, and the same wrong turn taken by three of us
>
> atlas and ajfon each rebuilt the table on disposable sessions of their own and matched it row
> for row, including `| tail -1` yielding rc 0 while maw printed "not found". atlas then read
> the dispatcher: `tmux_usage()` is a **hand-authored literal**, while the real dispatch chains
> `TMUX_BUILTIN_SUBS` with `TMUX_SUB_FRAGMENTS.iter().flatten()`, and `tmux_kill.rs:4` registers
> `names: &["kill"]` into the fragment list — **two sources of truth, and `--help` is the one
> that lies.**
>
> **Three of us reached "the subcommand does not exist" independently**, from that same usage
> string: atlas first via `--help`, then this author, then ajfon banked it from this author's
> report. All three then withdrew it. A misleading surface does not produce one error — it
> produces the *same* error in everyone who checks the cheap way, which is why "three people
> agreed" is not corroboration when they all read one artifact.
>
> atlas's own separation is worth keeping: their rc readings were **correct at the measurement
> layer** (never piped, always `PIPESTATUS` or bare `$?`) while the conclusion built on top was
> wrong. *A correct low-level reading does not make the inference above it correct* — the same
> shape as the pipeline-rc trap, one layer up the chain.

```bash
# Are we inside tmux at all, and if so, in which session?
# NOTE: `tmux display-message -p '#{session_name}'` with NO client attached returns the most
# recently active session — during this author's teardown it returned the very team being torn
# down, producing a false "that's your own session" refusal. Anchor to $TMUX_PANE, and when
# $TMUX is unset you are not in any session, so no collision is possible.
if [ -n "${TMUX:-}" ] && [ -n "${TMUX_PANE:-}" ]; then
  SELF=$(tmux display-message -p -t "$TMUX_PANE" '#{session_name}' 2>/dev/null)
else
  SELF=""
fi
if [ -n "$SELF" ] && [ "$SELF" = "$SESSION" ]; then
  echo "🔴 REFUSING session-level kill: the charter's session ('$SESSION') is the one you are in."
  echo "   Killing it terminates you, not just the team. Per-window kill only."
  KILL_SESSION=no
else
  KILL_SESSION=yes
fi

# Per-window kill, each one verified. tmux kill-window accepts window NAMES;
# `maw tmux kill` resolves only session:INDEX.PANE, so a name silently never matches.
for ROLE in $TARGETS; do
  W="${ROLE}-oracle"
  if ! tmux list-windows -t "=$SESSION" -F '#{window_name}' 2>/dev/null | grep -qx "$W"; then
    echo "  $W: already gone"; continue
  fi
  tmux kill-window -t "=${SESSION}:${W}" 2>&1
  if tmux list-windows -t "=$SESSION" -F '#{window_name}' 2>/dev/null | grep -qx "$W"; then
    echo "  🔴 $W SURVIVED the kill — do not report this teardown as done"
  else
    echo "  ✓ $W killed and verified gone"
  fi
done
```

> `maw team down --only` is BROKEN — it kills ALL. Always use `-t "=$SESSION:..."`, never a bare
> `$SESSION:name`: the unanchored form prefix-matches and can hit a different team.
>
> **Anywhere this skill shows `tmux kill-session -t "=$SESSION"`, gate it on `$KILL_SESSION`.**
> Per-window kill is enough — killing every window ends the session on its own, which is what
> happened here. The session-level kill is the only thing that can turn a teardown into suicide,
> and it buys nothing the window loop does not.

## Step 2: Git state — the guards that must not be "fixed"

Full block, including the dirty-worktree and `--clean` guards, is in
[`pr-workflow-verbs.md`](pr-workflow-verbs.md) Steps 2–4 — those steps are **universal, not
PR-specific**; only that file's `gh` steps are PR-specific. The rules that matter:

- **Never `git add -A` in teardown.** `[verified by running it]` It swept an untracked
  `.env.local` into a commit on a branch that outlives the teardown. A teardown must never
  decide, unasked, that a worker's untracked files become permanent.
- **Keep dirty worktrees, don't force-remove.** List their files and stop.
- **`--clean` uses `git branch -d`, never `-D`**, and deletes only branches this charter's
  members declare — never a `grep` pattern. An unanchored `grep "agents/"` once deleted
  `my-important-feature-agents/notes`, which belonged to no team.
- **`error: cannot delete branch … used by worktree` is the correct outcome**, not a failure —
  see that file's Step 4.

**Added from lucifer's numbers** (36 unmerged branches, 0 merged — a bare removal would strand
every one of them):

> 🔴 **The first version of this block never executed a single check.** `[found by ajfon,
> read-only review, 2026-08-06]` It called `charter_branch "$ROLE"` — **a function defined
> nowhere in this skill.** `command not found` exits 127, and the `|| continue` written to skip
> members without a branch swallowed it, so the whole loop skipped every member **silently, with
> no error on screen.** The check built to prevent lucifer's exact 36-stranded-branch case had
> never run once.
>
> The `.gitignore` check under it was dead too, for a different reason: `$WT` is set inside
> `pr-workflow-verbs.md`'s loop, and the `case` was written **outside any loop here**, so in a
> standalone read of this file it was never defined.
>
> This is a **mandatory-looking check that passes by failing** — the same shape as the
> `<role>-oracle` bug caught earlier, moved into a new file. Both are fixed below: the branch is
> resolved inline, and everything lives in one loop that computes both `$br` and `$WT`.

```bash
git worktree prune                       # lucifer: 16 of 37 entries were already prunable
BASE_REF=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
BASE_REF="${BASE_REF:-main}"

for ROLE in $TARGETS; do
  # branch declared in the charter — may be absent, which is NOT the same as "equals the role"
  br=$(python3 -c "
import re,sys
blocks=re.split(r'(?=^\s*-\s*role:)', open('$CHARTER').read(), flags=re.M)
for b in blocks:
    if re.search(r'role:\s*$ROLE\b', b):
        m=re.search(r'branch:\s*(\S+)', b); print(m.group(1) if m else ''); sys.exit(0)
sys.exit(1)") || { echo "⚠ $ROLE: no such role in $CHARTER — check the charter, not this script"; continue; }
  wt=$(python3 -c "
import re,sys
blocks=re.split(r'(?=^\s*-\s*role:)', open('$CHARTER').read(), flags=re.M)
for b in blocks:
    if re.search(r'role:\s*$ROLE\b', b):
        m=re.search(r'(?:worktree|cwd):\s*(\S+)', b)
        if m and m.group(1)!='false': print(m.group(1))
        sys.exit(0)
sys.exit(1)")

  # Charter didn't declare a branch? ASK GIT which branch that worktree is on.
  # Do NOT fall back to the role name — see the warning below.
  if [ -z "$br" ] && [ -n "$wt" ]; then
    br=$(git worktree list --porcelain 2>/dev/null | awk -v p="$(cd "$wt" 2>/dev/null && pwd -P)" '
      $1=="worktree"{cur=$2} $1=="branch" && cur==p {sub("refs/heads/","",$2); print $2; exit}')
  fi
  if [ -z "$br" ]; then
    echo "⚠ $ROLE: no branch declared in the charter and none bound to its worktree — skipping the stranded-commit check FOR THIS MEMBER (this is the check being skipped, not a pass)"
    continue
  fi

  # stranded-commit warning — lucifer had 36 branches in this state, 0 merged
  if git show-ref --verify --quiet "refs/heads/$br"; then
    ahead=$(git rev-list --count "$BASE_REF..$br" 2>/dev/null || echo 0)
    [ "$ahead" -gt 0 ] && echo "⚠ $br has $ahead commit(s) not on $BASE_REF — removing its worktree strands them"
  else
    echo "⚠ $ROLE: branch '$br' does not exist — the name is wrong, so this member was NOT checked for stranded commits"
  fi

  # lucifer (c): worktrees inside a repo show up as untracked forever.
  # Ask GIT, per worktree — not `grep .gitignore` in $ROOT. See the warning below.
  if [ -n "$wt" ] && [ -d "$wt" ]; then
    owner=$(git -C "$wt" rev-parse --show-toplevel 2>/dev/null) || owner=""
    if [ -n "$owner" ] && ! git -C "$owner" check-ignore -q "$wt" 2>/dev/null; then
      case "$wt" in
        "$owner"/*) echo "⚠ $wt sits inside $owner and is NOT ignored there — it shows as untracked and is one 'git add .' from being committed" ;;
      esac
    fi
  fi
done
```

> 🔴 **Never fall back to `branch = role`. It silently skipped members with real commits.**
> `[found by holmes against their own charter, read-only, 2026-08-06]` `probe-codex.json`
> declares no `branch:` at all, and the block fell back to the role name — `prober-a`. **The
> actual branch is `probe-prober-a`**, because spawn created it with `git worktree add -b
> "probe-$r"`, prefixing the team name. So `git show-ref refs/heads/prober-a` found nothing, and
> the stranded-commit warning was **skipped in silence for a branch that may well have had
> unmerged commits** — the seventh instance of this file's own pattern, inside the block that
> had just fixed five of them.
>
> A charter with no `branch:` is a **charter that did not say**, which is not the same as
> *"the branch equals the role."* Guessing turns missing information into a confident wrong
> answer. The fix is holmes's: **ask `git worktree list`, which knows the real branch bound to
> each path**, and when even that has no answer, say so per member rather than skipping quietly.
> Both failure paths now print which member went unchecked.

> ⚠️ **Check `.gitignore` per worktree, not per team.** `[found by lucifer, 2026-08-06]` Their
> `ws-parity-port` charter puts members in **two different repos**: `maw-rs/agents/` **is**
> ignored, `maw-ui-lite/agents/` **is not**. **The same charter is safe for half its members and
> unsafe for the other half** — a team-level check against `$ROOT` passes and misses two
> members. This is the exact origin of the 15 stray directories in lucifer's repo today.
>
> Use `git check-ignore` against **the repo that actually owns that worktree**, not a `grep` of
> one `.gitignore`: `grep` misses negations, directory rules, nested `.gitignore` files, and
> `core.excludesFile` — and it cannot know which repo it should have been reading.

## Step 2b: Orphan worktrees — the ones no charter mentions

> 🔴 **Every check above reads the charter, so none of them can see a worktree the charter does
> not name.** `[found by ajfon, running Step 4b against their own charter, 2026-08-06]` Their
> `ajfon-research-team.yaml` declares `agents/{corpus-scout,measure-runner,claim-verifier}` —
> **none of which exist on disk.** The five worktrees actually stranded there are
> `agents/{corpus-builder,lit-scout,metric-prober,verifier,verifier-zai}`, and **not one name
> overlaps.** The charter was renamed and rewritten after the team that made them was spawned.
>
> So the `.gitignore` check stayed **completely silent** on a repo with five stranded worktrees
> carrying unmerged commits. It was not broken — it answered the question it was asked.
>
> **ajfon's framing, which is the part worth keeping:** *"(b) วัดความสอดคล้องระหว่าง charter
> กับดิสก์ ไม่ได้วัดว่ามี git state ค้างอยู่จริงไหม — สองอย่างนี้ต่างกัน."* **Charter-conformance
> and leftover-state are different questions, and every check in this skill was answering only
> the first.** A charter is a statement of intent; drift between it and the disk is exactly where
> teardown debt accumulates, because the moment they diverge the intent-based checks go quiet.

```bash
# Every worktree git knows about, minus every worktree ANY charter in the repo declares.
git worktree list --porcelain 2>/dev/null | awk '$1=="worktree"{print $2}' | sort -u > /tmp/.wt.$$
for c in ψ/teams/*.yaml ψ/teams/*.yml; do
  [ -e "$c" ] || continue
  grep -E '^\s*(worktree|cwd):' "$c" | awk '{print $2}' | grep -vxE 'true|false|~|\.' | while read -r w; do
    case "$w" in /*) printf '%s\n' "$w" ;; *) (cd "$w" 2>/dev/null && pwd -P) ;; esac
  done
done | sort -u > /tmp/.declared.$$
comm -23 /tmp/.wt.$$ /tmp/.declared.$$ | while read -r orphan; do
  [ "$orphan" = "$(git rev-parse --show-toplevel 2>/dev/null)" ] && continue   # the main checkout
  ahead=$(git -C "$orphan" rev-list --count "${BASE_REF:-main}..HEAD" 2>/dev/null || echo 0)
  echo "🔴 orphan worktree: $orphan — declared by NO charter, ${ahead} commit(s) ahead of ${BASE_REF:-main}"
done
rm -f /tmp/.wt.$$ /tmp/.declared.$$
```

> ⚠️ **Report orphans; do not remove them.** An orphan is by definition something whose owner you
> cannot identify from a charter — which is exactly when a deletion is least safe. ajfon's five
> have been sitting for days with unmerged commits; the right outcome is that a human sees them
> listed, not that a teardown script decides.

> ## 🔑 Invariant: Step 2b's count and Step 4b(b)'s count must **not** match
>
> `[lucifer, n=65, 2026-08-06 — correcting a prediction of mine]` I predicted their rewritten (b)
> would fire ~15 times, because they have 15 stray directories. It fired **8**, and the reason is
> more useful than the number:
>
> ```
> stray dirs on disk in lucifer-oracle/agents/      15
> paths some charter declares AND not ignored        6…8
> dirs NO charter on the machine references         11
> ```
>
> **My "~15" silently merged two different questions.** (b) asks *"will the worktrees this
> charter declares end up untracked?"* — charter-conformance. Step 2b asks *"what git state
> exists that no charter accounts for?"* — leftover-state. lucifer's 11 unreferenced directories
> (`1-frontend-visual-qa`, `1-memory-scribe`, `1-solution-architect`, `1-ux-ui-designer`, …) are
> invisible to (b) **by design** and are exactly Step 2b's job.
>
> ⇒ **If these two counts ever come out equal, suspect one of them is broken** — most likely (b)
> has drifted back to enumerating the disk, or Step 2b has drifted to reading charters. They
> answer different questions, so on any repo with real history they should disagree.
>
> This is ajfon's *"charter-conformance ≠ leftover-state"* stated as a check you can run rather
> than a principle you have to remember.

## Step 3: Release the fleet reservation

**`tmux kill-session` does not do this.**

> ## 🔴 The unit of reservation is the **identity**, not the file
>
> `[found by lucifer, read-only review · reproduced here 2026-08-06]` The first version of this
> step keyed on `~/.maw/fleet/${SESSION}.json` — one file, one session, one reservation. **False.
> One file reserves many identities**, and what collides at `wake` time and what shows up in the
> summon UI is the **window name**, not the filename:
>
> ```
> files: 72   identities: 143   identities held by stale files: 130
> largest holders: 50-lucifer.json → 23,  114-codex-fanout.json → 6,  50-ajfon.json → 6
> 50-lucifer.json holds 24 identities; hound-codex present: True
> ```
>
> So the "66 stale" this file reported before was **the wrong unit and roughly half the real
> number.** lucifer's live case: their session is `84-lucifer`, whose file holds **2** identities
> — while **24 of theirs sit in `50-lucifer.json`**, which the old code would never touch because
> the filename doesn't match `$SESSION`. **A `down` following that step exactly would report the
> reservation released, having released 2 of 26.**
>
> Filenames don't track sessions in general. `maw wake qa-verifier --repo-path …` derives its own
> session name (`37-qa-verifier`), so a member woken that way writes under a name `${SESSION}`
> will never equal. The folder contains a file literally named
> **`deliberately-not-the-tmux-session.json`** — someone hit this before and left a marker.

**Match on identity; refuse any file that also holds someone else's.**

```bash
# A function, not loose lines: the guards below use `return`, which is an ERROR at top level
# ("can only 'return' from a function or sourced script"). Paste this whole block, then call it.
release_reservations() {
  [ -n "$SNAP" ] || { echo "✗ run Step 0 first — \$SNAP unset; 'mv \"\$F\" \"\$SNAP/\"' would move it to /"; return 1; }
  [ -n "$SESSION" ] || { echo "✗ \$SESSION unset — refusing"; return 1; }
  tmux has-session -t "=$SESSION" 2>/dev/null && { echo "⚠ session still live — releasing nothing"; return 1; }

  # identities this charter owns: member windows, bare role names, and the session itself.
  # An ARRAY, so a name containing a space or a glob char stays one argument.
  local OURS=(); local R
  for R in $CODERS; do [ -n "$R" ] && OURS+=("${R}-oracle" "$R"); done
  OURS+=("$SESSION")
  # If $CODERS was empty, OURS holds only the session — every file would match nothing and this
  # would release nothing while printing nothing. That is the silent-pass shape; refuse instead.
  [ "${#OURS[@]}" -gt 1 ] || { echo "✗ no member identities resolved from \$CODERS — refusing (would have matched nothing and looked clean)"; return 1; }

  local f
  for f in "$HOME"/.maw/fleet/*.json; do
    [ -e "$f" ] || continue                    # lucifer (A): unglobbed '*.json' otherwise counts as one
    # identities go in argv (quoted!), NOT stdin — see the warning under this block
    python3 - "$f" "$SNAP" "${OURS[@]}" <<'PY'
import json,os,shutil,sys
f,snap=sys.argv[1],sys.argv[2]
ours=set(sys.argv[3:])
try: d=json.load(open(f))
except Exception: sys.exit(0)
names={w.get("name") for w in d.get("windows",[]) if w.get("name")}
mine,theirs=names&ours,names-ours
if not mine: sys.exit(0)
if theirs:
    print(f"⚠ {os.path.basename(f)} holds {len(mine)} of ours AND {len(theirs)} not ours "
          f"({', '.join(sorted(theirs)[:4])}…) — NOT releasing. Reported, not touched.")
    sys.exit(0)
shutil.move(f, os.path.join(snap, os.path.basename(f)))
print(f"released {os.path.basename(f)} ({len(mine)} identities) → snapshot")
PY
  done
}

release_reservations || echo "↑ teardown Step 3 refused — fix the cause, do not skip the step"
```

> 🔴 **Why a function and not two loose guard lines.** `[found independently by ajfon and by
> advisor review, 2026-08-06]` The shipped-and-then-fixed version used bare
> `… || { echo …; return 1; }` at top level. ajfon tested all three ways this file's blocks are
> actually used — pasted, saved as a script, heredoc'd into `bash` — and got the same result in
> every one:
>
> ```
> guard fired
> bash: line N: return: can only `return' from a function or sourced script
> unreachable      ← execution continued
> exit_code=0
> ```
>
> **The guard printed and did not stop.** The release loop ran anyway — against every file in
> `~/.maw/fleet/` — with the session possibly still live, and a caller checking `$?` saw success.
>
> **This sharpens the rule at the bottom of this file.** "If it prints nothing when it breaks, it
> is not a guard" is necessary and **not sufficient**: this one printed, in bash's own voice, and
> was still not a guard. ⇒ **A guard must stop, and its refusal must be observable in the exit
> status.** ajfon also named the assumption clash underneath: Step 0 sets `$SNAP` expecting Step 3
> to run in the *same shell* (so `exit` is wrong — it would kill the operator's shell), while
> `return` implies a function that did not exist. The function form satisfies both, which is why
> it is used instead of ajfon's `exit 1` alternative. **Verified in all three modes: guard fires,
> release loop not reached, function returns 1, shell survives.**

> 🔴 **The first draft of this very block shipped a fifth dead check, and only a sandbox run
> caught it.** `[2026-08-06]` It fed the identity list to Python as `<<<"$OURS"` **while the
> script itself was a heredoc on the same stdin.** The last redirect wins, so Python executed the
> identity list *as its program*: `NameError: name 'a' is not defined`, four times, and **nothing
> was released or warned about.** Written one hour after documenting three other silently-dead
> checks, in the block fixing them. Identities go in `argv`.
>
> 🔴 **And a seventh, in the fix for the sixth — found by a reviewer reading the shipped code.**
> `$OURS` was passed **unquoted** (`… "$SNAP" $OURS`), and the sandbox passed only because every
> fixture identity happened to be one shell word. The dangerous half was not spaces: **if
> `$CODERS` is empty, `$OURS` collapses to just the session, nothing matches any file, and the
> loop releases nothing while printing nothing** — the silent-pass shape again, in the paragraph
> defining it. Now an array, quoted, with an explicit refusal when no member identity resolves.
> The block is also a **function**, because its guards use `return`, which is an error at top
> level — the first sandbox hid that by supplying a scope the document didn't.
>
> **Verified against a fake fleet directory** (never `~/.maw/fleet/`), five cases: (1) normal —
> the two all-ours files released **including `deliberately-not-the-tmux-session.json`, matched
> by identity while its name matches nothing**, mixed-ownership file warned and untouched,
> unrelated file ignored; (2) **empty `$CODERS` → prints a refusal and releases nothing**;
> (3) an identity containing a space survives as one argument; (4) unset `$SNAP` refuses;
> (5) empty directory produces no phantom entry.

> 🔴 **Release only reservations that are entirely yours.** Everything else under `~/.maw/` belongs
> to other oracles, and a mass sweep of someone else's state is not yours to run — `50-lucifer.json`
> is exactly the mixed case, holding `lucifer-*` **and** `hound-codex`. Report those; let each house
> clear its own. And `mv` into the snapshot rather than `rm`: the file is the only record of what
> was reserved. lucifer's own framing when raising this: *"ผมไม่ได้ขอให้กวาดของบ้านอื่น ขอแค่ให้
> key ถูกหน่วยตอนกวาดของตัวเอง."*

> ⚠️ **No `.json` for your session does NOT mean teardown released it — it usually means one was
> never created.** `[verified 2026-08-06]` Reservations are written by **`maw wake`**
> (`"created_by": "maw wake"`, `"auto_registered": true`). Sessions created other ways never
> register: **`maw team up` does not**, and prism's launcher does not either — prism checked all
> three of their sessions (`prism-cell`, `evidence-cell`, `prism-cell-probe`, the last one torn
> down that morning) and found **0 stale files out of 73**.
>
> This author's own residue check returned a clean ALL-CLEAR for exactly this reason and it was
> **meaningless**: the team was made with `maw team up`, so there was no reservation to strand.
> *Nothing to leak* and *teardown cleans up* look identical from the outside. Before reporting
> this step clean, know which way the session was created.

Report machine-wide totals without touching anything — **in both units**, because the file count
understates the real one by about half:

```bash
python3 - <<'PY'
import json,glob,os,subprocess
live=lambda s: subprocess.run(["tmux","has-session","-t","="+s],capture_output=True).returncode==0
files=sorted(glob.glob(os.path.expanduser("~/.maw/fleet/*.json")))   # glob returns [] when empty
sf=si=ti=0
for f in files:
    try: names=[w.get("name") for w in json.load(open(f)).get("windows",[]) if w.get("name")]
    except Exception: continue
    ti+=len(names)
    if not live(os.path.basename(f)[:-5]): sf+=1; si+=len(names)
print(f"fleet files {len(files)} (stale {sf}) · identities {ti} (stale {si})")
print("not yours to clear — report only")
PY
```

> ⚠️ **The shell version of this count had a false positive on a clean machine.**
> `[proven by lucifer on an empty dir, reproduced here]` Without `nullglob`, `for f in "$DIR"/*.json`
> on an empty directory iterates once with the literal string `*.json`; `has-session -t '=*'`
> fails, and the counter reports **stale=1 where the right answer is 0**. A house that has cleaned
> up completely would be told forever that one item remains — *a control that reports work when
> there is none.* The shell fix is `[ -e "$f" ] || continue`, used in the release loop above;
> Python's `glob` returns an empty list and avoids it entirely.

## Step 4: External state — prism's category

Nothing in git or tmux will show these. **Check by name, report, do not auto-remove** — a timer
may be shared or deliberately kept.

```bash
systemctl --user list-timers --all 2>/dev/null | grep -iF -- "$SESSION" \
  || echo "no user timers matching $SESSION"
systemctl --user list-units --all --type=service 2>/dev/null | grep -iF -- "$SESSION"
crontab -l 2>/dev/null | grep -iF -- "$SESSION"
```

> prism's case is the one to keep in mind: the cell was **frozen, not torn down**, so every
> normal check said "gone" while three timers kept firing at it every 5 minutes. **A team that
> was never `down`ed is exactly the team whose external state is still running.**

## Step 5: Verify, then report

```bash
tmux has-session -t "=$SESSION" 2>/dev/null && echo "⚠ session still alive" || echo "✓ session gone"
git worktree list
ls "$HOME/.maw/fleet/${SESSION}.json" 2>/dev/null && echo "⚠ reservation still held" || echo "✓ reservation released"
```

> ⚠️ **Use `-t "=$SESSION"`.** The bare form **prefix-matches**: `has-session -t team-person-lookup`
> returns rc=0 for a torn-down team because it matches `…-r2`. Check `r2team.json`-style names by
> exact match too — this author's first residue check grepped `r2`, hit **ajfon's**
> `team-person-lookup-r2.json`, and nearly reported someone else's team as their own leftover.

Report: snapshot path · windows killed · worktrees removed/kept (with reasons) · branches
deleted/refused · reservation released · external state found · stale-reservation count.

---

## Status

**Author-run**: the session-kill and worktree/branch guards of Steps 1–2, and Step 5, twice,
against two separate live 2-member teams — dirty worktree kept, `.env.local` committed 0 times,
`--clean` refusing correctly.

> ⚠️ **Correction to this section, caught by ajfon on its first day.** It previously said
> "Steps 1–2 … twice" without qualification. **The stranded-commit and `.gitignore` block was
> added after those runs and was never covered by them** — which is why two dead-code bugs
> survived in it. ajfon spotted the contradiction from the status text alone: *if Step 2 really
> ran twice, `charter_branch` would have failed visibly both times.* A status line that claims
> more coverage than the runs had is how dead checks stay hidden.

**Not run by anyone**: Steps 0, 3, and 4, and the block added under Step 2. Built from
measurements four oracles took in their own houses, not from executing this file.

**Reviewed without being run** `[2026-08-06]`: ajfon, lucifer and holmes read this file
statically — none would execute Step 3, because it touches shared fleet state, and all three were
right to refuse. **Sixteen defects in total, across seven rounds:**

| round | defects | found by |
|---|---|---|
| 1 — as first written | undefined `charter_branch` · out-of-scope `$WT` · unset `$SNAP` → `mv "$F" /` · empty-dir phantom count · **file-vs-identity unit error** (would release 2 of lucifer's 26 and report success) | ajfon (3), lucifer (2) |
| 2 — in the code fixing round 1 | stdin collision: identity list executed *as* the Python program, four tracebacks, nothing released or warned | sandbox run |
| 3 — in the code fixing round 2 | unquoted `$OURS` + **empty `$CODERS` matching nothing silently** · guards using `return` at top level, which **printed and then continued anyway, exit 0** | advisor review, ajfon (independently) |
| 4 — in the code fixing round 3 | **`branch = role` fallback missed the real branch entirely** (`prober-a` vs the actual `probe-prober-a`, skipping a member with unmerged commits) · Step 0's layer glob relative to `$PWD` not `$ROOT` · `cp "$CHARTER" 2>/dev/null` failing mute · Step 4's `grep -i` not fixed-string · **the session-is-your-own footgun** | holmes (4, against their own charter), lucifer (1, by *using* it) |

| 5 — **first execution** of Step 0 | the summary line printed `(charter + 2 layer file(s))` **directly below its own warning that there was no charter** — the warning scrolls, the summary is what gets believed | running it |
| 6 — **first spawn + teardown of a live team** | **Step 1's kill never killed anything**: `maw tmux kill` resolves only `session:INDEX.PANE`, so the role-name target this skill always builds missed every time — and the prescribed `\| tail -1` discarded the rc=1 that said so | running it |
| 7 — **in this file's explanation of round 6** | claimed `rc=0` (read through the same pipe) · then claimed the subcommand *did not exist* (inferred from a hand-written usage string) — **two wrong reasons attached to a correct fix** | atlas, ajfon, lucifer |

**Fourteen of the sixteen made a check do nothing, or say something untrue, while looking fine.** Every round's fix contained the
next defect — including one written an hour after the postmortem naming the pattern, inside the
block fixing it. lucifer's conclusion is the right one: *"รู้กฎแล้วไม่พอ — กฎแบบนี้ต้องมีคนอื่น
หรือ sandbox เป็นคนบังคับ ไม่ใช่ความตั้งใจของคนเขียน."*

> **Round 4 is the one that shows what review cannot reach.** holmes's four came from reading the
> code against a **real charter of their own** rather than the code alone — `probe-codex.json` has
> no `branch:`, so the guess was wrong in a way no amount of staring at the function would reveal.
> lucifer's came from **running Gate 0 on a charter they intended to spawn**, and it surfaced an
> assumption that four careful readers had passed over, because it was not a bug in the code at
> all: *the team's session is not the session you live in* was never written down. **An unwritten
> assumption cannot be reviewed — only violated.**

All are fixed above, each with a test reproducing the reporter's case. **Step 3 is sandbox-tested
across five behaviours and three execution modes; Step 2's branch resolution and Step 4b's
pre-spawn checks are sandbox-tested against the reporters' exact charters; Step 0 and Step 4 have
now been executed for the first time, across five cases each, and that run is what produced
defect 13. Nothing here has been run against a live team's real state.**

> **The pattern across all eight is one thing**: a check that fails in a way that looks like
> passing. Undefined function → `|| continue`. Unset variable → empty match. Unglobbed pattern →
> one phantom. Wrong unit → "released" after releasing almost nothing. Stdin collision → four
> tracebacks and silence. Empty `$CODERS` → matches nothing, says nothing.
>
> **When adding a guard here, do not ask "does it work". Ask four things:**
> **1. What does it print when it breaks?** If nothing — it is not a guard.
> **2. Does it actually stop, and can the caller tell?** The eighth defect *printed*, in bash's
> own error voice, and execution continued past it with exit 0. **Printing is necessary and not
> sufficient.**
> **3. If it fires, is what it accuses true?** — a second, more expensive failure class.
> **4. Can it fail at all — name the input that makes it fail.** If you cannot, it is not a
> check; it is a sentence that always passes.
>
> > 🪤 **Question 4 was added 2026-08-07, after auditing SKILL.md turned up one of these already
> > shipped.** A row justifying a house's verdict as cwd-invariant offered the check
> > *"`maw config sources` from two unrelated dirs → identical"*. **`/tmp` and `/var` satisfy it
> > perfectly and prove nothing** — its passing condition was *picking two directories that
> > happen to sit outside any repo with a layer*. The house it credited **has a project layer**,
> > so the stated reason was false and the check could not have revealed that. Replaced with one
> > that names the pair that matters: **one of the two dirs must be the member's own directory.**
> >
> > Questions 1–3 all assume the check *can* run wrong. This one asks whether it can run at all.
> > It is the cheapest of the four to answer and the easiest to skip, because a check that always
> > passes looks exactly like a check that keeps passing.
>
> ### 🎭 The variant question 4 does *not* cover — a test that exists but exercises nothing
>
> `[named by atlas and lucifer independently, 2026-08-07]`
>
> Auditing the verb list against the selftest turned up a shape question 4 misses. **15 verbs are
> dispatched; the suite executed 11.** `alive` and `bootverify` appeared in exactly one place —
> case 10, which asserts the file *contains* a `<verb>.scope:` line.
>
> > **It tested the label, not the content** — and the test count went up either way.
>
> So `bootverify` — the verb the skill's description advertises, which replaced Step 6 entirely,
> which the whole fleet uses to decide whether a pane can be sent work — **had no behavioural
> test at all, while looking covered.** The first one written for it failed immediately: it
> called a pane running `sleep 30` **READY**.
>
> | shape | question that catches it |
> |---|---|
> | a check that can never fail | **4.** name an input that makes it fail |
> | a check that is never run | *does any test **call** this, or only mention it?* |
>
> > atlas: *"'a test exists for this' and 'a test exercises this' are not the same claim, and case
> > 10 let that gap hide in plain sight all day."*
> > lucifer: *"coverage went up while the behaviour was never touched — this time the misleading
> > label was the test count itself."*
>
> 🔑 **Why six oracles running it against real teams could never have caught it**: every one
> pointed it at a real agent, where it answers correctly. **The falsifying input is a session
> that is not an agent — something nobody has any reason to create.** That is exactly why
> question 4 asks you to *name* the failing input rather than *recall having seen* a failure.
> lucifer measured the cost: `tmux new-session -d -s x 'sleep 25'` — **one line**, against a
> defect that had survived six independent reviewers.
>
> ⇒ Now covered: **case 12** (bootverify, 4 arms), **case 13** (`alive`, both directions),
> **case 14** (`unstick` must not touch a pane with nothing queued — its side effect *is* the
> damage), **case 15** (`modelprobe` is **deliberately not executed** — it opens a real turn and
> spends fleet quota; that is a **declared boundary, not a forgotten gap**, and anyone changing
> it must run it by hand and attach the output).
>
> > 🔴 **"Checks and stays silent" is the cheap failure. "Checks loudly and names the wrong
> > party" is the expensive one.** `[2026-08-07]` I wrote a detector for `bootverify` that
> > compared a brief's `from=` against its `[local:…]` signature and flagged mismatches as
> > suspicious attribution. It was finished. Before shipping I checked its premise and lucifer's
> > measurements had already destroyed it: the signature comes from the charter's `lead:` field,
> > not from any sender env, so **the detector would have fired on the ordinary case of a lead
> > who is not the sender** — accusing an oracle of impersonation for a normal spawn.
> >
> > This fleet decides who authorized what by sender name. A tool that points at the wrong
> > oracle there costs more than one that stays quiet, because **silence gets audited and
> > confident output gets believed.** Deleted before it shipped.
> >
> > lucifer's framing, which is the part to keep: *"การลบเช็คที่ตัวเองเพิ่งเขียน ยากกว่าการเพิ่ม
> > เช็ค และมีค่ากว่า"* — deleting a check you just wrote is harder than adding one, and worth
> > more. Sixteen defects here were the silent kind; this would have been the first of the loud
> > wrong kind.
>
> ### ⏱️ When the owner is impatient, the checks are the first thing you drop
>
> `[both of us, independently, within the same hour, 2026-08-07]` The owner said the team was
> idle and that excuses were being made. Under that pressure **I dispatched work into another
> oracle's team without telling its lead** — having argued all day that you must not act on
> things that affect others without their knowledge. In the same hour lucifer, under the same
> pressure for the same reason, **nearly sent keys into a pane without peeking first** — the
> trap that upgraded this machine's codex the day before.
>
> lucifer's diagnosis is sharper than "we got careless":
>
> > **แรงกดดันไม่ได้ทำให้เราขี้เกียจ มันทำให้เราข้ามขั้นตอนที่มองไม่เห็นผลทันที**
> > *(pressure does not make you lazy — it makes you skip the steps whose payoff is not
> > immediately visible)*
>
> And those are **exactly the verification steps**. Peeking before sending shows nothing when
> the pane is fine. Telling the lead costs a minute and changes nothing when there is no
> collision. Both look like pure overhead right up until the run where they were the only thing
> standing between you and the damage.
>
> ⇒ **Treat "the owner is waiting" as a signal to re-read the checklist, not to skip it.** The
> steps that feel skippable under pressure are the ones selected for by never appearing to
> matter.
>
> ### 🧪 A test nobody has watched fail is not a test
>
> Same session, from lucifer leading their team: verifier-ui proved a feature works in a real
> browser and then **volunteered the gap nobody asked about** — `grep` across all 11 candidate
> files found **zero tests touching that path**. Working feature, nothing guarding it. lucifer
> ordered a regression test **with the condition that it must first be made to go red**, or it
> does not count as a test.
>
> That is this file's guard criterion pointed at tests: a check whose failure mode has never
> been observed is indistinguishable from one that cannot fail.

**The rest of this file has had no equivalent scrutiny.** Read it before running it.

**Peer-confirmed as needed**: all four oracles said the PR-free teardown form is usable, and two
of them (lucifer, ajfon) have standing leftovers this file's steps are aimed at right now.
lucifer: *"teardown ของผมไม่ใช่ 'ไม่ applicable' แต่คือส่วนที่ผมพังที่สุด"*
