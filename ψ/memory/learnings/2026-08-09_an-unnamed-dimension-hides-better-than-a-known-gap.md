---
pattern: A checker that prints the evidence and still passes has an unnamed dimension, not a bug — audit the out-of-scope list for absent nouns
date: 2026-08-09
source: "rrr: codex-fanout"
concepts: [agent-orchestration, verification, unnamed-dimension, out-of-scope-declaration, readiness-expires]
---

# An unnamed dimension hides better than a known gap

## What happened

`enginecheck` was the fleet's pre-spawn gate for agent teams. On 2026-08-09 a six-member
team froze — five panes including the team's own lead — on `Do you want to proceed?`. The
alias was correct in every dimension the tool had ever named: registered, right engine,
model pinned. It lacked `--dangerously-skip-permissions`.

The tool printed that exact flag-less command **on the line directly above `✅ PASS`**, and
its declared scope line read `out-of-scope=model-served,prompt-delivery,account-quota`.

**The word "permission" appears nowhere in it.** Not as a known-open gap. Not as a caveat.
The dimension had never been named, so nothing — not the checker, not the four days of
teaching material built on it — could point at its absence.

## The rule

**When a check prints the evidence of a failure and still passes, the defect is usually not
in the logic. It is a dimension nobody named.**

A known gap is comparatively safe: it has a name, so it is greppable, teachable, and shows
up in a scope declaration where a reader can weigh it. An unnamed dimension is invisible to
search *by construction* — nobody looks for what has no word.

So audit an out-of-scope list for **absent nouns**, not only for wrong entries. Ask: what
question could this check plausibly be asked, that is not on this list either as covered or
as excluded?

## How to apply

1. For any gate you own, write out the full set of properties the thing it guards actually
   carries. For a `maw` engine alias that turned out to be **four**: engine · model ·
   permission mode · trust registration — where the tool had only ever discussed two.
2. For each property, the gate must either check it or **name it in the scope line**.
   Silence is the failure mode; a declared limit is not.
3. Prefer WARN over FAIL for properties with legitimate alternatives (an ask-mode worker is
   correct for a read-only probe). The job is to make the consequence visible before the
   commit point — not to decide for the owner.
4. Emit a machine-greppable token per property so downstream gates can apply their own
   policy: `enginecheck.unverified: permission-not-bypassed`.

## The companion rule that fell out of the same incident

Every readiness check in that stack was measured at **t=0**, including its strongest rung
("the agent quotes your content back"). The frozen workers had *passed* it, then stalled at
their first write twenty minutes later.

⇒ **Ask what expires.** If the answer to *"why didn't the operator check again?"* is
*nothing said readiness expires*, that is a defect in the document, not in their diligence.
Detection for an expiring property must be a **loop**, not a gate — and it must be
read-only, because clearing someone's prompt grants a permission on their behalf.

## Cost of not having this

Four days of fleet-wide teaching about engine and model, built on a tool that silently
blessed the third dimension. Two houses stalled. One machine-wide binary upgrade triggered
by a related unnamed hazard on the same night.
