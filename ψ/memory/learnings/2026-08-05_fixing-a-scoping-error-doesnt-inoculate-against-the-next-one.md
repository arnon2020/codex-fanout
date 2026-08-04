---
pattern: "Catching and fixing a scoping error does not inoculate against making the same class of error again in the same session — both self-corrections this session came from advisor(), not self-review"
date: 2026-08-05
source: rrr: codex-fanout (reawaken retro, session 073e6599)
concepts: ["reawaken", "verify", "scope", "self-correction", "advisor", "meta-lesson"]
---

# Fixing a scoping error doesn't inoculate against the next one

## What happened

Two separate `--reawaken` rounds in one session, each produced one real finding and one
verification error on the evidence for that finding:

- Round 1 found CLAUDE.md's "4 of 6 skills did not exist" claim was wrong (scoped to
  `~/.claude/skills/` only, missed project-local `.claude/skills/`). Then, minutes later,
  labeled a `find / -maxdepth 8` result `[verified: find /]` — same class of scope-narrower-
  than-claimed error, this time in the correction itself.

- Round 2 found this oracle's entire ~12-day corpus never reached Arra. Then, minutes later,
  proved "0 documents" using a `project:` filter that (per the same search's own results)
  tracks who *banked* a doc, not who it's about — the same class of error again, one level down.

Both times `advisor()` caught it. Neither time did self-review catch it before that call.

## Why this is worth recording separately from the two specific findings

The specific findings (skills-section correction, Arra-distribution gap) are already banked as
their own learnings. This is the meta-pattern across both: **noticing a scoping/evidence error
and writing a rule about it does not, by itself, change the next claim written in the same
session.** The rule "absence claims must name their scope" was written into CLAUDE.md *between*
the two errors, and the second error still happened — proving the mistake wasn't about not
knowing the rule.

What actually caught both errors was an external check (`advisor()`) applied to the claim, not
memory of having just written the rule. Writing a rule down is necessary but not sufficient;
something has to re-apply it to the very next claim, and internal momentum didn't do that.

## The generalizable lesson

**A freshly-written self-correction rule does not automatically re-apply to the correction that
follows it.** Treat "I just fixed a scoping error" as a reason to slow down on the *next*
verification claim, not a reason to trust the next one more. Concretely: after writing any
`[verified]`/absence claim, ask "does the exact command/filter I ran match the exact scope this
sentence claims?" as a discrete check — not a one-time fix bolted onto the prior error, but a
step repeated on every subsequent claim in the same session.

This generalizes past this repo: any session that produces a correction is at elevated risk of
producing a same-class error immediately after, because the cognitive move that caused the first
error (trusting a plausible-looking check) is still the default move for the next one.
