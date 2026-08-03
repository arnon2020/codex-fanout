---
pattern: "Relay ที่ default ไป system-correctness ก่อน user-standard จะถูกแก้ซ้ำ — human visibility คือ done-criteria + queue commands ต้อง supersede ชัดแจ้ง"
date: 2026-07-28
source: rrr: codex-fanout
concepts: ["relay-discipline", "human-visibility", "done-criteria", "queue-supersede", "orchestration", "lfs-001"]
---

# Relay defaults to system frame over user frame — และบทเรียน orchestration จาก LFS-001

## บริบท

Session สอน lucifer สร้างทีม → นำทีม 10 role ทำ LFS-001 จนได้ review packet
ผม (codex-fanout) ถูก user แก้ 2 ครั้งด้วย pattern เดียวกัน

## Pattern หลัก: system frame ≠ user frame

ครั้งที่ 1: coder-1 spawn นอก session ของ lead — ผมตอบ "แยก session เป็น pattern ปกติของ maw ไม่ผิด"
แต่ user มองผ่าน arra office UI ที่จัดกลุ่มตาม session → นอกห้อง = ผิดในโลกที่ user ใช้จริง
ครั้งที่ 2: identity spec ผมชี้ให้แก้ AGENTS.md (convention เดิมของ repo) — user ต้องแก้ว่า CLAUDE.md คือปัจจุบัน

**Rule**: ก่อนตัดสินว่าอะไร "ถูกแล้ว/ไม่ผิด" ถามก่อนว่า human มองเห็น/ใช้งานผ่านอะไร —
มาตรฐานการมองเห็นของ human คือส่วนหนึ่งของ done-criteria ไม่ใช่ความชอบส่วนตัว

## Lessons ประกอบ (จาก session เดียวกัน)

1. **Queue commands ต้อง supersede ชัดแจ้ง** — คำสั่ง 2 ฉบับที่ขัดกัน (kill+respawn vs bring)
   ถึงมือไม่เรียงลำดับ → pane ที่มีงานถูก kill ทั้งที่มีทางไม่เสียของ
   ทางแก้: ข้อความใหม่ระบุเสมอว่า "ยกเลิกฉบับก่อนเรื่อง X" และรวมคำสั่งเป็นฉบับเดียวเมื่อทำได้
2. **Consult ก่อน scale จับ failure mode ที่คนวางแผนมองไม่เห็น** — sage-codex ทำนาย
   orchestration collapse (lead context หมด) ล่วงหน้าไม่กี่นาทีก่อนเกิดจริง
3. **ทีมผลิตเร็วโดยไม่มี gate = งานที่ต้อง legitimize ย้อนหลัง** — แพงกว่าทำ gate เบาๆ แต่ไม่ข้าม
   (retrospective ADR, HOLD violation, verify ย้อนหลัง 18 นาที)
4. **Registry visibility มี 3 ระดับ**: [orphan] → fleet: → team: — team verbs เห็นเฉพาะระดับ team
   ก่อนสรุปว่า agent "มีตัวตน" ต้องรู้ว่าทะเบียนชั้นไหนเห็นมัน
