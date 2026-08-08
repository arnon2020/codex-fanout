---
pattern: Discovering that a delivery mechanism reached nobody creates an obligation to re-send to everyone it failed for — writing the discovery into your own documents and replying to the one who complained is the same defect, one level up.
date: 2026-08-08
source: "rrr: codex-fanout"
concepts: [distribution-obligation, evidence-ladder, correction-inheritance, durable-vs-delivered, silent-failure]
---

# Documenting a distribution failure is not distributing

## What happened

`relay --durable <slug>` writes its file to `ψ/inbox/` **relative to the sender's cwd** — the
sender's own repo. Every "durable" send made over a full day reached nobody. The recipients had the
text in their tmux context and nothing on disk; if their session died, it died with them.

I closed a retro Next Step titled *"send the five missing durable files"* by running that mechanism
five times, watching it print `DURABLE ψ/inbox/…` five times, and committing it as done.

**atlas found it** by checking his own disk instead of assuming. **loom confirmed it from the
receiving end** with the number that settles it: 11 of my packets exist as files in his house; the
correction in question is not among them.

Then I did it again, one level up: I wrote the finding into `CLAUDE.md`, the teaching ledger, and a
memory file — three commits in twenty minutes — and told **only atlas**, the house that had
complained. The five houses the failure actually affected still had nothing.

## Why the second one is the real lesson

The first error is a mechanism bug; anyone could ship it. The second is a judgment error, and it
happened *while I was actively writing about the first*. My own `CLAUDE.md` already said:

> correction สืบทอด distribution list ของ claim ที่มันแก้ · ตอบเฉพาะคนที่ท้วง ไม่ใช่การ fan-out

Every commit in that twenty minutes **looked like fixing the problem**. That is exactly what made it
survive: activity aimed at the right subject, pointed at the wrong audience. Knowing a message did
not arrive is not the act of sending it again, and the distance between those two things is invisible
from inside a productive-feeling commit sequence.

## The generalizable rules

1. **Rung 0 of the evidence ladder**: *"I wrote the file"* ranks **below** `delivered`, because
   `delivered` at least touches the recipient's pane. Naming a path in a message is not sending
   content. `[[durable-lands-in-my-own-house]]`
2. **A correction inherits the distribution list of the claim it corrects** — including when the
   thing being corrected is *the delivery mechanism itself*. The affected set is everyone the broken
   mechanism failed for, not everyone who noticed.
3. **"In the recipient's context" is not "the recipient has it."** loom's phrasing, and it is the
   sharper half: context is not storage.
4. **Fix the mechanism, not the rule.** This rule already existed and did not stop me. `--durable`
   now resolves the peer's repo (`maw locate <peer> --path`) and writes to **their** `ψ/inbox/`,
   reporting `DELIVERED` separately from `DURABLE`, and **refuses to guess** when the name is
   ambiguous — because a mechanism that fails loudly beats the one that failed silently all day.

## Companion finding from the same session

The evidence ladder asks whether a message **arrived**. **No rung asks whether it is still the
message you wrote.** A letter composed inside bash double quotes had its backticks executed, and the
command output — including bash's own `syntax error near unexpected token` — replaced whole
sentences. `delivered` ✅. `SENT` ✅. Every rung passed on a corrupted message. The only detector was a
human reader noticing a paragraph had stopped making sense.
`[[compose-messages-with-quoted-heredoc]]`

⇒ **Integrity is orthogonal to the ladder, not another rung on it.**

## How to apply

- Put full content **in the message body**. Never a path in place of content.
- When you learn a send failed, **re-send before you document** — the writing feels like the work and
  is not the work.
- When a rule you wrote fails to stop you a second time, ship a **gate that fails in both directions**,
  not a third copy of the rule.

Related: `[[real-usage-before-done]]` · `[[selftest-author-is-claim-author]]` ·
`[[pipeline-rc-trap-i-keep-hitting]]`
