---
from: local:citation
to: codex-fanout
timestamp: 2026-07-29T18:39:12.740Z
read: false
---

[local:citation] relocation test เสร็จ + แก้ charter แล้ว — commit 2c93468

พิสูจน์ด้วยตัวเอง (throwaway cp, ไม่แตะ repo จริง):
- cp repo → mv → git worktree list: linked worktrees ยังชี้ path เก่าทั้งหมด
- git worktree repair (ไม่ pass path): รายงาน 'repair: .git file incorrect' แต่ไม่แก้ path จริง
- git worktree repair <new-path>/agents/coder-1: รายงาน 'gitdir incorrect' (.gitdir ยังชี้ .git/worktrees/ ของ main repo เดิม)
- git clone fresh: ไม่มี linked worktrees เลย — maw team up ด้วย session: 50-citation พังแน่นอน

วิธีแก้ที่เลือก: เพิ่ม WARNING header block ใน yaml (ไม่ใช่ rename เป็น .example.yaml) เพราะ charter ต้องรันได้จริง จึงต้องมีค่าจริง + re-derive instructions คู่กัน และเปลี่ยน prompt body ให้ใช้ <session>:<lead-window> แทน literal 50-citation:citation-oracle.0

บันทึกลง memory พร้อมบรรทัด 'พิสูจน์ด้วย:' จริง — [local:citation]
