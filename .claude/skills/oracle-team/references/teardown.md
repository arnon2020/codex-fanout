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
fleet json total : 73
  matching a live tmux session : 7
  stale (no such session)      : 66
live tmux sessions on machine  : 9
```

`72-hound-codex.json` still reserves the name of an oracle that does not exist. lucifer measured
73 / 66 / 9 in their house and arnon hit the user-visible form of the same bug the same day: a
deleted agent (`argus`) **still appearing in the summon UI**, because `~/.maw/fleet/28-argus.json`
outlived its removal from config.

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

```bash
git worktree prune                       # lucifer: 16 of 37 entries were already prunable
for ROLE in $TARGETS; do
  br=$(charter_branch "$ROLE") || continue
  git show-ref --verify --quiet "refs/heads/$br" || continue
  ahead=$(git rev-list --count "main..$br" 2>/dev/null || echo 0)
  [ "$ahead" -gt 0 ] && echo "⚠ $br has $ahead commit(s) not on main — removing its worktree strands them"
done
# lucifer (c): worktrees living inside the repo show up as untracked forever
case "$WT" in
  "$ROOT"/*) grep -qs "$(basename "$(dirname "$WT")")/" .gitignore \
      || echo "⚠ $WT is inside the repo and not in .gitignore — it will show as untracked and is one 'git add .' from being committed" ;;
esac
```

## Step 3: Release the fleet reservation

**`tmux kill-session` does not do this.** This is the step whose absence produced 66 stale files.

```bash
F="$HOME/.maw/fleet/${SESSION}.json"
if [ -e "$F" ]; then
  tmux has-session -t "=$SESSION" 2>/dev/null \
    && echo "⚠ session still live — not releasing $F" \
    || { mv "$F" "$SNAP/" && echo "released $F (moved into snapshot, not deleted)"; }
fi
```

> 🔴 **Release only your own session's file.** The other 65 belong to other oracles and other
> teams — this is shared state under `~/.maw/`, and this fleet's standing rule is that a mass
> sweep of someone else's state is not yours to run. Report the count, let each house clear its
> own. `mv` into the snapshot rather than `rm`: the file is the only record of what was reserved.

Report stale count without touching anything:

```bash
n=0; for f in "$HOME"/.maw/fleet/*.json; do
  s=$(basename "$f" .json); tmux has-session -t "=$s" 2>/dev/null || n=$((n+1))
done; echo "stale fleet reservations on this machine: $n (not yours to clear — report only)"
```

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

**Author-run**: Steps 1–2 and 5, twice, against two separate live 2-member teams — dirty
worktree kept, `.env.local` committed 0 times, `--clean` refusing correctly.

**Not yet run by anyone**: Steps 0, 3, and 4 as written. They are built from measurements four
oracles took in their own houses, not from executing this file. The measurements are solid; the
code that acts on them is new. **Read it before running it**, and expect Step 3 in particular to
be wrong in some way no one has hit yet.

**Peer-confirmed as needed**: all four oracles said the PR-free teardown form is usable, and two
of them (lucifer, ajfon) have standing leftovers this file's steps are aimed at right now.
lucifer: *"teardown ของผมไม่ใช่ 'ไม่ applicable' แต่คือส่วนที่ผมพังที่สุด"*
