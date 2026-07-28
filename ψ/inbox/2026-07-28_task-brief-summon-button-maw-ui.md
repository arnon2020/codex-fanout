# TASK BRIEF — งานแรกของทีม lucifer-fullstack: ปรับปรุงปุ่ม Summon (maw-ui)

- **task-id**: LFS-001
- **date**: 2026-07-28
- **requested by**: Nat (ผ่าน codex-fanout relay)
- **assigned to**: lucifer-oracle (lead, 113-lucifer) → dispatch ต่อให้ coder ตาม blueprint Stage 1
- **โจทย์ดิบจาก Nat**: "งานแรกคือปรับปรุงปุ่ม Summon ในหน้า http://localhost:5173/#overview โปรเจค arra office"

---

## Grounding (scout โดย codex-fanout — verify แล้วทุกข้อ 2026-07-28)

| ข้อเท็จจริง | ค่า |
|---|---|
| โปรเจกต์จริง | `Soul-Brews-Studio/maw-ui` ("arra office" = ชื่อเรียก) |
| Path | `/home/user/ghq/github.com/Soul-Brews-Studio/maw-ui` |
| Dev server | รันอยู่แล้ว port 5173 (pid 1162, cwd = checkout หลัก) — หน้า `/#overview` ตอบ 200 |
| โค้ดปุ่ม Summon | `src/components/OverviewGrid.tsx` (37 matches — state ~บรรทัด 295-298, logic `runSummon` ~373-395, render ถัดลงไป) |
| Branch ปัจจุบัน | `main` |
| ⚠️ Hazard 1 | **main checkout dirty 20 ไฟล์** (รวม OverviewGrid.tsx เอง) — ห้าม coder แตะ checkout หลักเด็ดขาด ทำงานใน worktree แยกเท่านั้น |
| ⚠️ Hazard 2 | dev server ที่รันอยู่ serve จาก checkout หลัก — การทดสอบของ coder ต้องเปิด vite ของตัวเองใน worktree (พอร์ตอื่น เช่น `--port 5174`) ห้าม restart ตัวหลัก |

## พฤติกรรม Summon ปัจจุบัน (สรุปจากโค้ด)

Panel ในหน้า overview: ดึงรายชื่อ oracle จาก `/api/config` → คำนวณ dormant agents (ตัวที่ไม่ live) →
ผู้ใช้เลือก agent + พิมพ์ task (textarea) → ปุ่มสั่ง **wake เปล่า** หรือ **ส่ง task** (`runSummon(withTask)`) →
state machine 4 สถานะ: idle / waking / sent / error พร้อมข้อความ ("Task queued", "Wake failed" ฯลฯ)

## โครงงาน 2 slice (โจทย์ "ปรับปรุง" ยังไม่ระบุมิติ — อย่าเดา scope แทน Nat)

### Slice 1 — ASSESS + PROPOSE (dispatch ได้ทันที)

Coder (gpt-5.6-sol shape ตาม blueprint Stage 1) ใน worktree แยก:

1. รัน dev server ของตัวเอง เปิด `/#overview` ใช้ปุ่ม Summon จริงครบทุก path
   (เลือก agent, wake เปล่า, ส่ง task, กรณี error, กรณีไม่มี dormant agent)
2. อ่านโค้ด OverviewGrid.tsx ส่วน Summon ทั้งหมด
3. ผลิตไฟล์ proposal: ปัญหาที่พบจริง (UX / correctness / a11y / visual) + ข้อเสนอปรับปรุง
   เป็นรายการแยกชิ้น แต่ละชิ้นมี: อาการปัจจุบัน → สิ่งที่จะเปลี่ยน → effort (S/M/L)
4. **ห้ามแก้โค้ดใน slice นี้**

**Done-criteria slice 1**: ไฟล์ proposal อยู่ใน branch ของ coder + FINAL-REPORT END + lead review แล้ว relay ให้ Nat เลือกข้อที่จะทำ

### Slice 2 — IMPLEMENT (หลัง Nat เลือกแล้วเท่านั้น)

เฉพาะข้อที่ Nat อนุมัติ → vertical slice: แก้โค้ด + ทดสอบใน dev server ตัวเอง + commit เล็กๆ ต่อข้อ
**Done-criteria slice 2**: ทุกข้อที่อนุมัติ implement แล้ว, เทสโปรเจกต์ผ่าน (ถ้ามี), PR เปิดแล้ว (ห้าม commit ตรงเข้า main), report ตาม format

## กติกาที่ผูกกับงานนี้

- Repo นี้อยู่ org `Soul-Brews-Studio` ไม่ใช่ arnon2020 — **push เฉพาะ branch ของทีม, PR ต้องรอ Nat approve เสมอ**
- ห้ามยุ่งกับ 20 ไฟล์ dirty บน main — ไม่ commit แทน, ไม่ stash, ไม่ "ช่วยจัดระเบียบ" (Nothing is Deleted + ไม่ใช่งานของเรา)
- Report กลับ lead ตาม format: branch, commit hash, commands+exit codes, files changed, verification evidence, retro line, FINAL-REPORT END
- Lead peek loop 15-20 นาที + verify report อิสระก่อน relay ผล

— codex-fanout-oracle 🛰️ (AI, Claude Fable 5)
