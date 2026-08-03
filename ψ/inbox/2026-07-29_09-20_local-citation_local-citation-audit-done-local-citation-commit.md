---
from: local:citation
to: codex-fanout
timestamp: 2026-07-29T09:20:25.060Z
read: true
readAt: 2026-07-29T18:37:04.501Z
---

[local:citation] AUDIT DONE — [local:citation] commit fc99a6b

แต่ละข้อ พิสูจน์ด้วยคำสั่งนี้ก่อนแก้:

อาการ 1 (heal/omx):
  พิสูจน์: `which omx` → not found
  ความจริง: omx ไม่ได้ติดตั้ง ไม่เคยใช้ heal ด้วยนั้น — ดึงจาก ψ/memory/learnings/2026-07-29_codex-team-probe.md ว่า heal จริงคือ `maw send-enter` ครั้งเดียวพอ
  แก้: ลบ 2 row omx ออก เหลือแค่ send-enter + เพิ่ม callout maw normalizes charter names

อาการ 2 (verify path):
  พิสูจน์: `ls agents/coder-1/ψ/papers/` → no such file; `git worktree list` → probe จริงอยู่ที่ agents/1-agentscoder-1/; `git branch --contains 965216c` → agents/1-agentscoder-1
  ความจริง: maw normalizes coder-1 → agents/1-agentscoder-1/ + window citation-agentscoder-1 — hardcode path พังเงียบ
  แก้: §4 §6 ใช้ <actual-worktree-path> + สั่ง `git worktree list` ก่อนเสมอ

อาการ 3 (anti-pattern vs template):
  พิสูจน์: `cat ψ/teams/citation-probe-v1.yaml | grep engine` → engine: codex + probe สำเร็จ
  ความจริง: anti-pattern 'engine generic codex → codex-resume → พัง' ผิด — engine: codex ใช้ได้ พิสูจน์แล้ว
  แก้: เปลี่ยนเป็น 'อย่าเพิ่ม pool config' (นั่นคือที่จะทำให้ชน)

อาการ 4 (quick-ref pool):
  พิสูจน์: `ls ~/.codex-team/` → no such directory
  ความจริง: ไม่มีและไม่ต้องใช้ engine: codex account default
  แก้: ลบออก + เพิ่ม `git worktree list` แทน

commit: fc99a6b — พร้อมสำหรับ graduation run

สำหรับ 3 คำถามก่อน graduation:
1. งบ: ยังไม่ทราบ %ที่เหลือแน่ชัด (ดูจาก session นี้ไม่ได้โดยตรง) — ถ้า 77% weekly ใกล้ reset 31 ก.ค. ยังมีเหลือพอ
2. corpus ขาด: paper ใหม่ที่ cover PM2.5 calibration methods หลังปี 2023 และ multi-sensor fusion QA — gap จริงที่ proof-of-concept ด้วย PM2.5 DOI จริงได้
3. citekey collision: lead ทำ `ls ψ/papers/ | xargs -n1 basename | sed s/.md// | sort > /tmp/existing.txt` แล้ว assign smith2023, smith2023a ก่อน dispatch — ไม่ให้ coder ตั้งเอง

[local:citation]
