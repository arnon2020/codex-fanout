---
pattern: To prove a rule landed where it must, count it in the whole artifact AND in the required region, then assert equality — the region count alone proves presence, only equality proves absence elsewhere
date: 2026-08-10
source: "rrr: codex-fanout"
concepts: [verification, half-application, placement-invariant, delta-instrument-mismatch, gate-5.3]
---

# Count it whole and in-region, then assert equality

## The failure this detects

**HALF-APPLICATION** — a correct technique applied to one half of its domain. The reasoning is
right; its *scope of application* is short. Measured instances on 2026-08-09/10, mine and
others':

| where the rule lived | where it was needed | distance |
|---|---|---|
| `oracle-team/SKILL.md` prose half | the half an agent executes (`Verb: up`, Gate 0) | one file |
| `codex-lead` §3 (names the update dialog) | §2, where it spawns | one section |
| a paragraph saying *never hardcode the menu index* | the table two rows down doing exactly that | **eight lines** |
| atlas's END-TURN rule in `atlas-oracle/CLAUDE.md` | every other agent | one repo |
| Gate 5.3's own definition ("role brief / charter") | only the charter survives `maw team load` | inside itself |

**Proximity is not protection.** The closest instance was the hardest to see: adjacent text
reads as one already-understood context, so the eye stops checking.

## The invariant

```
whole   = count(token, entire artifact)
region  = count(token, required region)

region == 0        → ABSENT     it never landed
whole  >  region   → LEAKED     it also lives outside — and outside is the whole illness
whole  == region   → PLACED     present in the region and nowhere else
anchor not found   → UNVERIFIED cannot answer is not a pass
```

**Counting in the region alone proves presence. Only the equality proves absence elsewhere.**
That is the difference between "the rule is documented" and "the rule is where the reader walks".

Both counts must use the **same expression and the same unit**. `grep -c` counts matching
*lines*, not occurrences; mixing that against a `grep -o | wc -l` column silently manufactures a
bogus number that looks correct on each side.

## The companion rule, from the failure that produced this one

I sent three deltas to a peer; all three failed the same way. **Not one individual count was
wrong — every pairing was.** `perm 0→6` summed two different tokens under one label; `trust 0→4`
counted `trust=` before and `trust:` after; `bootverify 0→2` measured one line range before and a
different one after.

⇒ **A delta must come from the identical command run twice.** Pin the expression *and* the range,
and quote both alongside the number. Two commands that "measure the same thing" are not one
instrument.

The peer's own first measurement was wrong in the other direction — a case-insensitive substring
grep for `perm` returned 20 because it matches inside `permstall` and `permission`. Their prior
case: a run where a tool fired **zero** times while a bare-name grep reported **412 invocations**,
270 of them from that single non-firing run. **A substring count certifies what it cannot see.**
Both numbers are instrument artefacts until the expression is pinned.

## What this does not answer

It proves a token is in a named region and nowhere else. It does **not** prove that region is one
the consumer actually reads. That remains Gate 5.3 and it is a human question: *name the
consumer, then verify the file is on the path that consumer walks.* An oracle reads its own
`CLAUDE.md`; a maw-team worker seat reads **only its charter** — never an inherited `CLAUDE.md`,
and never a role brief, which is a render target destroyed by `maw team load` at exactly the
moment the seat starts reading it.

## Why it had to become a tool

The invariant existed for several hours as a bash one-liner two agents had each run by hand and
praised. **The only mechanical detector for HALF-APPLICATION was itself half-applied** — living
in memory, not in an instrument anyone could run. Implemented as
`verify-check.sh placement <file> <region-anchor-regex> <token>...`, with selftest arms that fail
in all three directions plus the missing-anchor case, because a check that cannot fail is not a
check.
