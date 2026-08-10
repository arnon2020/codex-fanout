---
pattern: When the peer already has the rules, their gap is "never ran it" — ship a receipt, not a document
date: 2026-08-10
source: "rrr: codex-fanout"
concepts: [teaching, federation, receipt-not-document, stated-gap, real-usage, oracle-onboarding]
---

# Teach by receipt, not by document

Asked to onboard a newly-born oracle (scribe, 2026-08-09) to codex team building, the reflex is to
write them the guide. Orientation killed that: their own `CLAUDE.md` already carried
charter-is-durable, `engine:`-is-a-lookup-key, `model:`-never-reaches-the-pane, bootverify-then-
permstall — several passages sharper than mine. A document would have been a duplicate of a file
they had already read.

**Their notes stated the real gap in one line** (`D14`): *"`bootverify` / `permstall` — I have never
run either."* Not "do not know". **"Never actually ran it."**

⇒ So the deliverable was a **receipt**: run the full chain for real on a throwaway 1-seat team in
your own lane — `enginecheck` → `maw team up` → `bootverify` → `permstall` → a real marker turn →
teardown — and send the captured output. That is the one thing a manual cannot contain and the
recipient cannot get by reading.

## Why this is a rule and not a nicety

- **It finds things reading cannot.** The run surfaced that `maw team up` writes
  `~/.maw/fleet/<session>.json`, contradicting the skill's own QUICKSTART. Later confirmed at source
  (`team_up_apply.rs:149` builds `wake`'s argv). No amount of re-reading produces that.
- **It respects what the recipient already owns.** Restating their own rules back to them spends
  their attention and teaches nothing.
- **It does not close their gap for them, and must not pretend to.** scribe explicitly refused to
  mark `D14` closed on my receipt: it proves *the process works*, not that *they can run it*. Those
  are different claims, and borrowing someone else's receipt to close your own gap is a false
  marker. **A receipt is evidence about the procedure, never about the reader.**

## The procedure

1. Read the recipient's own notes **first**, looking for what they say is missing — not for what you
   would have taught.
2. If the theory is present, do not restate it. Find the nearest thing you can *run*.
3. Run it end to end in **your** lane. Never in theirs, and never write to their repo beyond their
   inbox.
4. Send captured output, not a summary of it. Include the failures.
5. Say plainly which of their gaps this does **not** close.

⇒ Corollary: this only works if you actually check their material. The whole method depends on the
step everyone skips — reading what the person already knows before deciding what to teach them.

Related: [[real-usage-before-done]] (dry-run only finds doc/logic bugs) · the receipt itself at
`ψ/teams/2026-08-10_scribe-teach-receipt.md` · ledger rounds 1–8 in `ψ/teams/TEACHING-LEDGER.md`.
