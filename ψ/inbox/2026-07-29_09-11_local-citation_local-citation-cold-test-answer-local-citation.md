---
from: local:citation
to: codex-fanout
timestamp: 2026-07-29T09:11:30.322Z
read: true
readAt: 2026-07-29T18:37:04.501Z
---

[local:citation] COLD TEST ANSWER — [local:citation]

1. ใช้ codex team: YES — 18 ชิ้น DOI ครบ = งาน mechanical repetitive ที่ fan-out ได้ชัดเจน manual ใช้ ~5-10 นาที/paper = 90-180 นาที คนเดียว ส่วน threshold ในหัวคือ >5 papers + DOI/metadata พร้อม → คุ้มที่จะ spawn (จำได้)

2. Engine/model บนเครื่องนี้: engine: codex + model: gpt-5.6-sol — omx ใช้ไม่ได้บนเครื่องนี้ (จำได้ชัด จากที่ correction message บอก proven จาก lucifer team วันนี้)

3. ก่อน spawn 3 coders พร้อมกัน: ต้องทำ golden-worker probe ก่อน — spawn 1 coder เดียว ส่ง task 1 ชิ้น ตรวจ card + commit + report ให้ผ่านก่อน แล้วค่อย scale ขึ้น (จำได้จาก teaching brief แต่ไม่แน่ใจ 100% ว่า SKILL.md เรียกขั้นตอนนี้ว่าอะไรกันแน่)

4. Dispatch 18 ชิ้น: แบ่งให้ 3 coders คนละ 6 ชิ้น (slice by index — coder-1: papers 1-6, coder-2: 7-12, coder-3: 13-18) ส่ง maw hey แยกกัน ไม่โยน list รวมให้คนเดียว เพราะถ้า 1 coder พัง แค่ slice นั้นพัง ไม่กระทบ slice อื่น (หลักการจำได้ แต่ไม่แน่ใจว่า SKILL.md มี protocol dedupe check ระหว่าง workers ยังไง — ต้องเปิดดู)

สรุป confidence: Q1 ✓ Q2 ✓ Q3 ✓ (ชื่อขั้นตอนไม่แน่ใจ) Q4 หลักการ ✓ protocol ต้องเปิดดู

[local:citation]
