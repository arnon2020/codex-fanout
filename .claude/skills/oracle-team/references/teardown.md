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
SNAP="${SNAP:-$HOME/.maw-teams/.snapshots/${SESSION}-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$SNAP"
cp "$CHARTER" "$SNAP/charter.yaml" 2>/dev/null
for L in .maw/maw.config.*.json; do [ -e "$L" ] && cp "$L" "$SNAP/"; done
cp ~/.maw/fleet/"${SESSION}".json "$SNAP/" 2>/dev/null
tmux list-windows -t "=$SESSION" -F '#{window_name}' > "$SNAP/windows.txt" 2>/dev/null
git worktree list > "$SNAP/worktrees.txt" 2>/dev/null
git branch -vv > "$SNAP/branches.txt" 2>/dev/null
echo "snapshot: $SNAP"
```

Cheap, and it is the only thing that makes any later step reversible.

## Step 1: Kill the session's windows

```bash
for ROLE in $TARGETS; do
  maw tmux kill "${SESSION}:${ROLE}-oracle" 2>&1 | tail -1
done
```

> `maw team down --only` is BROKEN — it kills ALL. Use per-window kill.
> Always quote `"${SESSION}:name"`, never bare `$SESSION:name`.

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
  # branch + worktree resolved from the charter, in the same loop that uses them
  br=$(python3 -c "
import re,sys
blocks=re.split(r'(?=^\s*-\s*role:)', open('$CHARTER').read(), flags=re.M)
for b in blocks:
    if re.search(r'role:\s*$ROLE\b', b):
        m=re.search(r'branch:\s*(\S+)', b); print(m.group(1) if m else '$ROLE'); sys.exit(0)
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

  # stranded-commit warning — lucifer had 36 branches in this state, 0 merged
  if git show-ref --verify --quiet "refs/heads/$br"; then
    ahead=$(git rev-list --count "$BASE_REF..$br" 2>/dev/null || echo 0)
    [ "$ahead" -gt 0 ] && echo "⚠ $br has $ahead commit(s) not on $BASE_REF — removing its worktree strands them"
  fi

  # lucifer (c): worktrees inside the repo show up as untracked forever
  case "$wt" in
    "$ROOT"/*) d=$(basename "$(dirname "$wt")")
      grep -qs "^${d}/" .gitignore \
        || echo "⚠ $wt is inside the repo and not in .gitignore — it shows as untracked and is one 'git add .' from being committed" ;;
  esac
done
```

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
[ -n "$SNAP" ] || { echo "run Step 0 first — \$SNAP is unset and 'mv \"\$F\" \"\$SNAP/\"' would move it to /"; return 1; }
tmux has-session -t "=$SESSION" 2>/dev/null && { echo "⚠ session still live — releasing nothing"; return 1; }

# identities this charter owns: the member windows, plus the session itself
OURS=$(for R in $CODERS; do echo "${R}-oracle"; echo "$R"; done; echo "$SESSION")

for f in "$HOME"/.maw/fleet/*.json; do
  [ -e "$f" ] || continue                      # lucifer (A): unglobbed '*.json' otherwise counts as one
  # identities go in argv, NOT stdin — see the warning under this block
  python3 - "$f" "$SNAP" $OURS <<'PY'
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
```

> 🔴 **The first draft of this very block shipped a fifth dead check, and only a sandbox run
> caught it.** `[2026-08-06]` It fed the identity list to Python as `<<<"$OURS"` **while the
> script itself was a heredoc on the same stdin.** The last redirect wins, so Python executed the
> identity list *as its program*: `NameError: name 'a' is not defined`, four times, and **nothing
> was released or warned about.** Written one hour after documenting three other silently-dead
> checks, in the block fixing them. Identities go in `argv`.
>
> **Verified against a fake fleet directory** (never `~/.maw/fleet/`) with four fixtures: a file
> matching `$SESSION`, a mixed-ownership file, an unrelated file, and one named
> `deliberately-not-the-tmux-session.json` holding one of ours. Result: the two all-ours files
> released **including the misnamed one**, the mixed file warned and untouched, the unrelated one
> ignored, empty directory produced no phantom entry, and unset `$SNAP` refused to run.

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
systemctl --user list-timers --all 2>/dev/null | grep -i "$SESSION" \
  || echo "no user timers matching $SESSION"
systemctl --user list-units --all --type=service 2>/dev/null | grep -i "$SESSION"
crontab -l 2>/dev/null | grep -i "$SESSION"
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

**Reviewed without being run** `[2026-08-06]`: ajfon and lucifer both read Steps 2–3 statically
and between them found **five defects, four of which made a check silently do nothing** —
undefined `charter_branch`, out-of-scope `$WT`, unset `$SNAP` turning `mv "$F" "$SNAP/"` into
`mv "$F" /`, the empty-directory phantom count, and the file-vs-identity unit error that would
have released 2 of lucifer's 26 identities while reporting success. A sixth, in the rewrite
itself, was caught by a sandbox run. All are fixed above; **Step 3's logic is now sandbox-tested,
Steps 0, 2's added block, and 4 are not.**

> **The pattern across all six is one thing**: a check that fails in a way that looks like
> passing. Undefined function → `|| continue`. Unset variable → empty match. Unglobbed pattern →
> one phantom. Wrong unit → "released" after releasing almost nothing. Stdin collision → four
> tracebacks and silence. **When adding a guard here, the question is not "does it work" but
> "what does it print when it breaks" — if the answer is nothing, it is not a guard.**

**The rest of this file has had no equivalent scrutiny.** Read it before running it.

**Peer-confirmed as needed**: all four oracles said the PR-free teardown form is usable, and two
of them (lucifer, ajfon) have standing leftovers this file's steps are aimed at right now.
lucifer: *"teardown ของผมไม่ใช่ 'ไม่ applicable' แต่คือส่วนที่ผมพังที่สุด"*
