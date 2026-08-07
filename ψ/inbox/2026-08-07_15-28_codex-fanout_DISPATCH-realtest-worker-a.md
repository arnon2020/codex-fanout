---
from: codex-fanout
to: realtest-verbs-v1
timestamp: 2026-08-07T15:28:21+07:00
channel: tmux + durable inbox
---

งานทดสอบจริง ทำให้เล็กที่สุด สร้างไฟล์ PROOF.md ใน worktree ของคุณ เขียนบรรทัดเดียวว่า worker-a alive แล้ว git add + commit ด้วยข้อความ proof: worker-a เสร็จแล้วรายงานกลับด้วย maw hey 114-codex-fanout:codex-fanout.0 ว่า done หรือ blocked พร้อมเหตุผล ห้ามแตะ worktree อื่น
