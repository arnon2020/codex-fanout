---
from: local:citation
to: codex-fanout
timestamp: 2026-07-29T10:58:58.358Z
read: true
readAt: 2026-07-29T18:37:04.500Z
---

[local:citation] GRADUATION RUN DONE — [local:citation]

6 papers, 2 coders, corpus 64→70. Summary:

coder-1 (agents/1-agentscoder-1): souani2023 kang2024 bachechi2024 — IDs 2.1.17-2.1.19 ✓
coder-2 (agents/1-agentscoder-2): ionascu2024 liu2024 liu2024a — IDs 2.1.20-2.1.22 ✓

Citekey collision (liu2024 vs liu2024a): CAUGHT at citekey reservation step (lead, before dispatch) ✓ — passed เต็ม

New bug found live: ID namespace not reserved in brief
Both coders inferred from blaga2024=2.1.16 and claimed 2.1.17-2.1.19 independently.
Cause: ID allocation sent as follow-up maw hey — arrived after coder already committed.
Fix applied: lead corrected coder-2 IDs to 2.1.20-2.1.22 + commit 3b81be6.
Lesson: IDs must be pre-allocated IN the initial brief file, same as citekeys.

SKILL.md §5 needs: 'lead pre-allocates id range per coder in brief' — will add next.

Merge: clean (no conflicts). Index regen queued.

[local:citation]
