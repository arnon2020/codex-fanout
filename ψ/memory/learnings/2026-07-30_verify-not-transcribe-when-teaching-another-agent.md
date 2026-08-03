---
pattern: When teaching another agent a fix, applying the fix yourself and having them "pull" is not equivalent to them understanding it — give a required proof step every time, even for standards they couldn't have known before
date: 2026-07-30
source: "rrr: codex-fanout"
concepts: [teaching, verification, cross-oracle-dispatch, portability, git-worktree]
---

# Verify, don't transcribe — when teaching another agent

## What happened

Teaching Citation Oracle to spawn codex agents, the user twice caught the same failure mode
from two different angles in one session:

1. First correction ("ไม่ต้องการสอนแบบผิวๆ") — I'd handed Citation a skill file, ran a cold-test,
   it passed, and I declared the teaching done. Going back in, the skill still had 4 omx-era bugs
   (a heal instruction for a binary not installed on the machine, a verify path pointing at the
   wrong worktree, etc.) that would only surface the first time Citation ran it solo. Fixed this
   round correctly: gave Citation the *symptoms*, made them prove each one with a real command on
   their own machine, and fix it themselves. Their memory afterward had `พิสูจน์ด้วย:` lines for
   every fix — real evidence of understanding.

2. Second correction, two steps later — a brand-new requirement came in (teams must survive path
   relocation and owner handoff). I reasoned "this is new, Citation has no way to know it, so I'll
   just fix it and tell them to pull" — and did exactly that. When the user asked "why does
   Citation understand this, check whether I'm the one who's wrong," going into Citation's memory
   file showed zero verification lines — just a transcription of my explanation. I had repeated
   the *exact* mistake from correction #1, on myself, two steps after fixing it in someone else.

## The generalizable rule

**A fix you verify with a static check (grep, diff review, "I confirmed the string is gone") is
not the same claim as "the person I taught it to understands it."** These require different
evidence. Conflating them is what makes teaching shallow even when the underlying fix is correct.

The "this is new, they couldn't have known it" reasoning feels like a legitimate exception but
isn't one — a new standard is exactly the case where proof-of-understanding matters most, because
there's no prior exposure to fall back on if the recipient never internalizes it.

## How to apply

When teaching or correcting another agent (via dispatch, via a skill file, via any one-way
channel where you can't directly observe their reasoning):

- Every fix that changes what they should do needs a **required proof step** attached, not just
  delivery of the corrected artifact. "Here's the fix, pull it" without a follow-up execution/
  verification task from their side is not teaching — it's just distributing a patch.
- Check the artifact of understanding, not the artifact of compliance. A memory file that says
  "X told me Y and I fixed it" is compliance. A memory file with `พิสูจน์ด้วย: <command> → <result>`
  lines is understanding. Read the actual memory/report file before declaring a teaching task done
  — don't trust your own summary of what happened.
- This applies with *equal* force to new information you're certain the recipient couldn't have
  derived themselves. Time pressure or "obviously they didn't know this" is not a valid reason to
  skip the proof step — it's the reasoning that produces the exact failure this note describes.

## Related technical finding from the same session

Also empirically confirmed (not from recall): git worktrees store absolute paths on both sides
(`.git/worktrees/<name>/gitdir` in the main repo, and the worktree's own `.git` file) — moving a
repo with `mv` breaks every worktree with `fatal: not a git repository`, while the main repo keeps
working. Fix is `git worktree repair <new-worktree-paths...>` run from the **main repo only** —
running it from inside the broken worktree itself fails outright, since git can't locate the repo
to operate on. `~/.maw/oracles.json` also carries a stale absolute `local_path` after a move; fix
via `maw oracle scan` (it's a generated cache, not source of truth — never hand-edit it).
