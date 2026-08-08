---
pattern: A sentence explaining what evidence MEANS is itself a claim and needs its own evidence
date: 2026-08-08
source: "rrr: codex-fanout (session ff1a7fa6)"
concepts: [category:oracle-meta, invented-connective-tissue, mechanism-claim-needs-command, invented-remedy, accidentally-right-is-worse, probe-must-not-name-its-answer]
---

# A sentence explaining what evidence MEANS is itself a claim

Five errors in one session, and they are **one shape**: observe something true, then write the
sentence saying what it *means*, and never check that sentence.

| observed (true) | invented (untested) | caught by |
|---|---|---|
| `include_skills_usage_instructions: False` in `models_cache.json` | "the model is never told its skills exist" | my own probe — a live worker listed **45 skills** |
| `find ~/.config/opencode -iname '*skill*'` → 0 | "opencode has no skill channel at all" | advisor — the binary has **327** skill strings |
| probe passed on a 90-line file | still passes at 160 lines | advisor — re-probe was 4/4, but that was luck |
| read 1 of 3 rule-source files | "the rule set is complete" | advisor — the other two held 3 real rules |
| `arra_search` → `ftsMatches: 0` | "the index is broken, needs a **reindex**" | arnon — the token was never in the document, and **no such verb exists** |

**Why it survives review:** the premise is verifiable and true, so the paragraph reads as reasoning
rather than as a guess. Twice the invented half happened to be **right**, which is worse than being
wrong — nothing forces a recheck, and it ships.

**Where it happens:** while writing the summary, not while running commands. Running things I am
careful; explaining them I reach for a tidy cause.

## Rules

1. **Any sentence stating a mechanism ("because…") or a remedy ("you need to…") must have a command
   behind it.** No command → write **"I don't know"**. An admitted gap costs less than a confident
   wrong cause.
2. **Never name a fix without confirming the verb exists.** Check the tool list first. "Needs a
   reindex" sounded like a diagnosis and was pure invention.
3. **A proof does not carry across a change to the thing proved.** A probe at 90 lines says nothing
   about 160. Re-probe on material growth, using content added *after* the earlier probe — that
   tests the new size and the new content's legibility in one shot.
4. **A probe that names the answer in its question proves nothing.** Asking "is there a file named
   X" sends the agent to read X. Name no file, and offer an explicit *"I'd have to look"* escape so
   the negative result is expressible.
5. **A negative claim must be searched with a token that is actually in the target.** I proved
   "not findable" with a string that `grep -c` says appears **0 times** in the document.

## Corollary — the same defect at the level of tools

Before any tool verb, **open the skill that documents it**. This session I spawned three workers by
trial and error (`charter not found` with rc=0, `team up` taking a name not a path, an update
dialog, a missing trust entry) while `oracle-team/SKILL.md` — 2,057 lines, in this repo, documenting
every one of them — sat unopened, **six commits after I declared it PRIMARY**.

⇒ *ความรู้มีพันธะเรื่องการกระจาย — การถือไว้เป็น defect แม้เนื้อหาจะถูก*, pointed at its author:
**a correct, installed, unopened skill is worth exactly what an unwritten one is worth.**
