---
read: true
---
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

---

## SCOPE UPDATE จาก Nat (2026-07-28 — หลัง dispatch แรก)

Nat ระบุมิติ "ปรับปรุง" แล้ว — Slice 1 ยังเป็น assess+proposal แต่ **focus 3 เป้านี้เท่านั้น**:

### เป้า 1: ปุ่ม Summon ใช้ง่ายขึ้น (UX)
ประเมิน flow ปัจจุบันทั้งเส้น (เลือก agent → พิมพ์ task → wake/ส่ง) แล้วเสนอการลดขั้นตอน/ความสับสน

### เป้า 2: เลือก agent ได้เร็วขึ้น
ปัจจุบัน `summonChoices = dormantAgents.slice(0, SUMMON_VISIBLE_LIMIT)` — จำกัดจำนวนที่โชว์
พิจารณา: search/filter box, keyboard navigation, จัดลำดับ (ล่าสุด/ใช้บ่อยก่อน), แสดงเกิน limit ยังไง
(registry มี oracle 60+ ตัว — รายการยาวคือปัญหาจริง)

### เป้า 3 (functional gap หลัก): รายชื่อ agent ต้อง sync กับ oracle registry อัตโนมัติ
**อาการที่ Nat เจอ**: รายชื่อใน Summon ไม่อัปเดตตาม registry — ต้องทำเอง/ไม่อัตโนมัติ
**Root cause ที่ codex-fanout ชี้เป้าจากโค้ด** (ให้ coder verify ต่อ):
- `OverviewGrid.tsx` fetch `/api/config` **ครั้งเดียวตอน mount** (`useEffect` deps `[]`) — ไม่มี refresh/poll/websocket → เพิ่ม oracle ใหม่ใน registry แล้วหน้าไม่เห็นจนกว่า reload
- ตรวจต่อว่า backend `/api/config` อ่านจากไหน (fleet configs? `~/.maw/oracles.json` มี 60+ oracles?) — ถ้า backend เองก็ cache/ไม่อ่าน registry สด ต้องแก้ทั้งสองชั้น
- Proposal ของเป้านี้ต้องระบุ: source of truth ของรายชื่อ, กลไก sync (poll interval / ws event / refetch on panel open), และ fallback เมื่อ backend ไม่ตอบ

**Done-criteria Slice 1 (อัปเดต)**: proposal ครอบ 3 เป้า แต่ละเป้ามี: current behavior (verified จากการใช้จริง+โค้ด) → ข้อเสนอ → effort S/M/L → ความเสี่ยง ส่งให้ lead review → relay ให้ Nat เลือกก่อนเริ่ม Slice 2 เช่นเดิม
