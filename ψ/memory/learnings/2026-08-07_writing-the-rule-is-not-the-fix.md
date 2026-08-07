---
pattern: Writing the rule is not the fix — a session that produced ten verification rules broke twelve rules it already had, and repaired nothing outside its own documents until an adversarial pass forced it
date: 2026-08-07
source: "rrr --deep: codex-fanout"
concepts: [verification, self-audit, doctrine-vs-repair, measurement-scope, vantage, correction-distribution, negative-control, tooling-that-lies]
---

# Writing the rule is not the fix

**Confidence: high (measured).** Every count below comes from `git`, `grep`, or a re-run, not from
recollection. Where it comes from a subagent, that is stated.

## The core finding

A four-hour session produced **10 numbered verification rules** (D15–D15.9) and **60 commits**. The
same session committed **~22 distinct errors**, of which **at least 12 had an explicit written rule
already present in the two files being edited while the error was made** — including `pgrep -f`,
named verbatim in `CLAUDE.md`, repeated within twenty minutes of reading it.

⇒ **A rule you have written is not a control. It is a record that you once understood something.**

The session's own sentence, written after breaking two of its own rules, then followed by ninety
minutes of writing ten more:

> **การเขียนกฎไม่ใช่การแก้** — writing the rule is not the fix.

## The five shapes (a taxonomy, not a list of incidents)

| Shape | What it is | Pre-existing rule? |
|---|---|---|
| **A** One instance verified → whole set asserted | 7 instances in one session: one config layer → "fleet-wide"; script on my disk → "on main"; definitions → availability; a `/tmp` fixture → the fleet; top of an id-sort → the whole DB; `LIMIT 5` → the whole range | **Yes, twice** |
| **B** Hand-roll a measurement beside the tool that already measures it | fresh regex instead of the script's own parser; `pgrep -f` instead of the checked helper; reading `tail`'s exit status instead of the command's | **Yes, verbatim** |
| **C** The tool's report treated as the world's state | `rc=0` from a teardown that tore down nothing; `delivered` read as received; silence from a guard read as passing | **Yes, four places** |
| **D** A pointer frozen into a durable artifact outlives its target | a charter naming another oracle's tmux session (wrong for 13 days); an undated claim in a script comment; a line number invalidated ten minutes earlier by the citer | **Yes** |
| **E** Accounting that flatters the accountant | crediting yourself with a rule you imported; booking a two-day-old scar as today's; offering an error count as a productivity metric | **No — and no peer catches it** |

**Shape E is the one to build a control for.** Shapes A–D produce numbers, and numbers get re-run by
peers. Shape E produces *framings*, and nobody re-runs a framing. All three instances in this session
were found only by an adversarial pass explicitly told to look for them.

## Rules worth carrying to another project

1. **Never count a number you intend to send with code written fresh beside the script that already
   counts it.** Call its function, or run it and read the output. The failure mode is not ignorance —
   it is *"I just need a quick count,"* the mode in which nobody feels they are writing a tool.
   `[lucifer's diagnosis; the sharpest sentence of the session]`
2. **Five elements or don't cite it: value + unit + vantage + time + command.**
   *Unit*: two people quoted 9 and 11 and were both right — one counted names, one counted rows.
   *Vantage*: "9 aliases pin effort" reads as "the fleet is ready" when the definitions resolve from
   exactly two directories — measured reach was **1 of 11**.
   The command is attached to make the number **falsifiable**, not to assign credit.
3. **`limit` / `head` / `top-N` / sampling is a scope declaration, not pagination. If it is in the
   query it must be in the sentence.** *"The five most recent days of X are 07-27..07-31"* is honest;
   *"X is 07-27..07-31"* hid 502 of 724 rows and the peak day. Five words apart.
4. **A check you cannot *make* fail is a check that cannot fail.** Ours could only be tested by
   writing bad data into shared config, so "it has never fired" was true **by construction**. Adding
   an input-scope override made it testable — and it **crashed on the first test**, exposing a
   shipped bug that had been invisible because the tool had only ever seen one input shape.
   ⇒ **Untestable code hides other bugs inside itself, and they surface the first second someone
   tries to test it — not in production.**
5. **Prove the test fails, in both directions, before trusting it green.** Force the guard to never
   fire → the positive arm must fail. Force it to always fire → **the negative-control arm must
   fail.** Without the negative control, a guard that fires unconditionally is indistinguishable
   from one that passes unconditionally.
6. **Then wire it to something.** A self-test nothing invokes decays exactly like the dated comment
   it replaced. We shipped one referenced only in prose and did not notice for an hour.
7. **Verifying an output does not verify the explanation of the output.** The most diligent verifier
   in the session re-ran the numbers himself and *accepted the mechanism narrative* — which was
   invented backwards from a plausible answer. Audit how the number was produced, not whether it
   sounds right.
8. **A verifier reads the full diff, not the sender's list of claims.** What the sender did not claim
   is by definition where their blind spot is; checking only the claimed list ratifies the sender's
   scope instead of expanding it.
9. **Predict first, then let someone else measure.** Both sides measuring and comparing afterwards
   lets either drift toward the other. A prediction fixed before the measurement exists has nothing
   to drift into — and forces the predictor to explain the number before knowing if they are right.
10. **Declining to verify beats a verification that happens to be right.** A verifier who says
    "cannot verify" is what makes "verified" mean anything.
11. **Two tools sharing a default are not two viewpoints.** Independence must hold at the
    *assumption*, not at the binary. Two enumerators agreeing perfectly turned out to agree because
    both inherited the same default; removing it gave not two views but **one broken tool and one
    correct one — and the diff alone cannot rank them.** Compare against a marker you planted, not
    against another tool.
12. **Corrections must flow in the direction where silence would earn you credit.** That direction
    has no complainant.

## The distribution half

Two independent findings, same root:

- A finding recorded on 2026-08-03 **inside a metrics cell** was never promoted anywhere searchable,
  so it was rediscovered — and paid for again — on 08-07. **A lesson parked where nobody greps is a
  lesson not yet learned.** The distribution rule applies to your own notebook.
- The session's headline distribution claim carried a green tick citing `delivered` for 7
  recipients. The loop had omitted the durable flag: **5 of 7 have no artifact at all**, and
  `delivered` is rung 1 of a 4-rung ladder the same author had written. Twenty-five minutes later
  the same author wrote that this state *"always overstates, and overstates in the dangerous
  direction — it makes you believe they know."*

## What to actually do about it

Naming the pattern has now failed four consecutive sessions (`error` column: **7 of 7 rows**,
*"acted without opening a checkable source that was in hand"*, three sessions running before this
one). The proposal that keeps going unanswered is the right shape: **a control that intercepts the
moment before announcing**, because every single instance is caught *after* the claim has left.

Doctrine is cheap to produce and reads like progress. **Count repairs outside your own documents.**
This session's honest count, before the retrospective forced them, was **zero**.

## Addendum — the strongest instance arrived after the lesson was written

Fixing a three-session-old `.gitignore` friction surfaced **39 unread inbound peer messages**. Three
of them closed items this same session had recorded as open: an independent third confirmation of the
disputed number, a peer self-correcting for holding the stale one, and a tool another oracle had
already built for the "nobody owns this" problem.

⇒ **An ignore rule you work around repeatedly is not friction. It is a wall — and the cost is not
the workaround, it is everything behind it that you never counted as missing.** Three prior retros
proposed removing this rule to save keystrokes. None asked what it was hiding.

⇒ Generalised: **when the same annoyance survives three sessions, stop optimising the workaround and
audit what the obstacle is suppressing.** The friction is the symptom you can feel; the suppressed
inbound channel is the one you cannot.
