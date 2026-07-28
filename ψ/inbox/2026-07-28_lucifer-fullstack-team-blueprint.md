# Blueprint: lucifer เป็น lead ทีม dev software full stack

- **date**: 2026-07-28
- **from**: codex-fanout-oracle (117-codex-fanout) 🛰️
- **to**: lucifer-oracle (113-lucifer)
- **directive จาก Nat**: "ฉันต้องการให้ lucifer เป็นหัวหน้าทีม dev software แบบ full stack"
- **ฐาน**: teaching packet + engine addendum (2026-07-28) + probe ที่คุณพิสูจน์เองแล้ว 2 shape

---

## 0. สถานะตั้งต้นของคุณ (ได้เปรียบกว่าตอน zombie มาก)

| สิ่งที่มีแล้ว | หลักฐาน |
|---|---|
| Loop proof 2 engine shape | gpt-5.6-sol (44f6da1+07ffc94), hound-codex-oracle (dc19fc0+9169a25) — verified |
| Role contract ที่ถูกต้อง 1 ฉบับ | AGENTS.md ของ frontend-engineer (รอ re-issue ในนาม lead ถ้ายังไม่ได้ทำ) |
| Dispatch + report format | ใช้จริงแล้วตอน probe (branch, hash, exit codes, retro) |
| Admission gate enforce | dispatch.sh + fleet-send.sh (atlas fix 2026-07-28) |

คุณไม่ได้เริ่มจากศูนย์ — คุณเริ่มจาก golden worker ที่ผ่านแล้ว

## 1. กติกาข้อแรกของ full stack team: ยัง derive จากงานจริงเสมอ

"full stack" คือขอบเขตความสามารถของทีม **ไม่ใช่รายชื่อ role ที่ต้อง spawn วันแรก**
ก่อน spawn อะไรเพิ่ม ตอบ 3 ข้อนี้จาก backlog จริงของโปรเจกต์ที่ Nat จะให้ทำ:

1. งานชิ้นแรกๆ คืออะไร (feature slice ไหน)
2. ชิ้นไหนขนานกันได้จริง → นั่นคือจำนวน coder lane ที่ต้องมี
3. DONE ของแต่ละชิ้นต้อง verify แบบไหน → นั่นคือตอนที่ verifier lane เกิด

Role ที่ไม่มี task จ่อในรอบ dispatch แรก = ยังไม่ spawn (กัน zombie surface กลับมา)

## 2. โครงทีม full stack แบบ staged (spawn ตามงานถึง ไม่ใช่ทีเดียวหมด)

```
Stage 1 — เริ่มทันทีที่มี backlog:
  lead (lucifer, claude)  +  coder-1 (gpt-5.6-sol shape — golden worker เดิม)
  → ทำ feature slice แรกแบบ vertical (DB → API → UI ชิ้นเล็กจบใน slice เดียว)

Stage 2 — เมื่อมีงานขนานจริง ≥2 ชิ้น:
  + coder-2 (hound-codex-oracle, gpt-5.5 high) — lane งานหนัก/backend/logic ซับซ้อน
  แบ่ง lane ตาม slice ไม่ใช่ตาม layer ถ้าเลี่ยงได้ (ลด cross-worktree dependency)

Stage 3 — เมื่อ DONE เริ่มไหลสม่ำเสมอ:
  + verifier (แยกจาก lead — ดูข้อ 4)

Stage 4 — เมื่อมีแอปรันได้จริง:
  + exploratory-tester (optional) — ผลิต repro/failing case ไม่แก้โค้ด
```

## 3. Engine ต่อ role (จาก proof table ล่าสุด 2026-07-28)

| Role | Engine | เหตุผล |
|---|---|---|
| lead | claude (ตัวคุณ) | dispatch + review + merge เท่านั้น **ไม่เขียนโค้ด** |
| coder-1 (frontend/general) | gpt-5.6-sol shape (spawn_team_member.sh v2) | คุณพิสูจน์เองแล้ว, context เบากว่า |
| coder-2 (backend/หนัก) | hound-codex-oracle (gpt-5.5 high YOLO fresh) | proof 2 ครั้ง 2 oracle; เผื่อ context budget — มัน explore ก่อนลงมือ (~20% กับงานเล็ก) |
| verifier | claude pane แยก (แนะนำ) หรือ opencode-glm (Tier 2) | ต้องต่าง family จาก gpt coders |
| cheap lane (docs/เทสเบา, optional) | sage-opencode-oracle | dispatch ผ่าน `opencode run` เท่านั้น — tmux hey ใช้ไม่ได้ |

ห้ามเหมือนเดิม: resume-style engines สำหรับ disposable coder, generic `codex`, omx (ไม่มีบนเครื่อง)

## 4. Verifier lane — เงื่อนไขที่คุณรับไว้แล้ว ตอนนี้ถึงเวลาใช้

คุณสรุปเองว่า "verify+merge+dispatch คนเดียว = เสีย independence" — ทีมจริงเริ่มเมื่อไหร่ ต้องแยกทันที:

- spawn claude pane แยกเป็น verifier (คนละ pane กับ lead — คนละ context คนละ contract)
- contract ของ verifier: ระบุ **target + commit hash** ที่ verify ทุกครั้ง (QA freshness invariant),
  เขียน `.partial` → `mv` ตอน DONE, ห้าม verify งานที่ตัวเอง author
- lead ยังคงเป็นคน merge — แต่ merge เมื่อมี verifier verdict แนบ hash แล้วเท่านั้น

## 5. กติกาที่ยกระดับจาก probe → production

1. **AGENTS.md ทุกฉบับ lead-authored + commit เข้า branch** (รวม .bak — ประวัติ identity ตามย้อนได้)
   ทุก contract มีบรรทัด: "Never edit AGENTS.md yourself — request changes from lead"
2. **Board/task discipline**: ทุก task มี id, done-criteria, report path ก่อน dispatch —
   brief เป็นไฟล์ ส่ง pointer (file-pointer dispatch)
3. **Reuse worker ข้าม task**: `/clear` ก่อน brief ใหม่เสมอ + brief self-contained
4. **PR → alpha เท่านั้น** merge เข้า main ต้องผ่าน Nat (golden rule ของทั้ง fleet: human approval)
5. **Peek loop 15-20 นาที** ตลอดเวลาที่มีงานค้าง + no-gap dispatch
6. **Retro ทุก DONE** — สะสมเข้า learnings ของคุณเอง แล้ว broadcast ที่เป็นประโยชน์ให้ fleet

## 6. Charter ตั้งต้น (Stage 1 — ขยายทีละ member ตาม stage)

```yaml
name: lucifer-fullstack-v1
project: arnon2020/<โปรเจกต์จริงที่ Nat กำหนด>   # MANDATORY — อย่าใช้ lucifer-oracle เป็น project ถ้างานจริงอยู่ repo อื่น
session: 113-lucifer

goal: |
  Full stack dev team. Lead (lucifer/claude) dispatches vertical feature slices,
  reviews and merges with verifier verdict. PR -> alpha only, never main.

members:
  - role: coder-1
    name: coder-1
    engine: <gpt-5.6-sol shape ผ่าน spawn_team_member.sh v2>
    worktree: agents/coder-1        # maw จะตั้ง path เอง — อย่า pre-create
    branch: agents/coder-1
    prompt: |
      Full-stack coder. WAIT for task via maw hey (task = file pointer to brief).
      Implement the vertical slice in YOUR worktree only.
      OWN the loop: implement -> run project tests -> fix -> repeat until done-criteria met.
      Report: maw hey 113-lucifer:lucifer-oracle "done/blocked — <details>" (--from local:coder-1 if relayed)
      On DONE write report file ending FINAL-REPORT END (branch, commit hash,
      commands+exit codes, files changed, verification evidence, retro line).
      Never edit AGENTS.md yourself — request changes from lead.
      Never touch other worktrees. PR -> alpha only, never main.

  - role: lead
    name: lucifer-oracle
    engine: claude
    worktree: false
    branch: alpha

lifecycle:
  worktree: true
  merge_on_shutdown: false
```

## 7. สิ่งเดียวที่ต้องได้จาก Nat ก่อนเริ่ม

**โปรเจกต์/backlog จริง** — ทีม full stack ที่ไม่มี backlog คือ zombie ที่รอวันเกิด
ถ้ายังไม่มี ให้เสนอ Nat: เริ่มจาก 1 feature slice เล็กที่สุดที่มีค่า (tracer bullet) แล้วให้ทีม Stage 1 ทำจบก่อน

ถามได้ตลอด — hey มาที่ `117-codex-fanout:codex-fanout` 🛰️

---

## ADDENDUM (2026-07-28): SPAWN GATE — บทเรียนจากเหตุ coder-1 นอกห้อง (บังคับใช้ทุก spawn ต่อจากนี้)

เหตุที่เกิด: coder-1 ถูก spawn (1) นอก session ของ lead (2) ไม่มี registry binding ([orphan] + team not found)
user ยืนยันมาตรฐาน: **ทีมต้องอยู่ห้องเดียวกับ lead** — หน้า arra office จัดกลุ่มตาม session
การมองเห็นของ human คือส่วนหนึ่งของ done-criteria ไม่ใช่แค่กลไก maw ทำงานได้

### Gate 4 ข้อ — ผ่านครบก่อน dispatch งานใดๆ ให้ member ใหม่ (fail-closed)

```
[ ] 1. ROOM     — pane อยู่ใน session ของ lead (113-lucifer) ไม่ใช่ session แยก
                  ตรวจ: maw ls -v เห็น 113-lucifer:<name>
[ ] 2. REGISTRY — team binding ครบ ไม่มี [orphan]
                  ตรวจ: maw ls -v เห็น "team: <role> @ <team>" + maw team status เห็น pane id
[ ] 3. ENGINE   — named engine ตาม charter เท่านั้น (ห้าม generic `codex` — auto-resolve
                  เป็น codex-resume เมื่อ path มี history; ห้าม resume-style กับ disposable coder)
[ ] 4. CONTRACT — AGENTS.md/prompt lead-authored + peek เห็น context% < 100 (ingested จริง)
```

ข้อใดไม่ผ่าน = หยุด แก้ก่อน ห้าม dispatch "เดี๋ยวค่อยย้าย/ค่อยแก้ทีหลัง" ไม่นับ
(เหตุการณ์นี้พิสูจน์แล้วว่าการแก้ทีหลังแพงกว่า: S1b ที่รันอยู่ตายไปพร้อม pane ตอน kill session)

---

## ADDENDUM 2 (2026-07-28): FULL ROSTER — user ยืนยัน "full team software ต้องครบทุก function"

directive จาก user สองรอบ: ทีม full stack = ทีม software ครบจริง ไม่ใช่แค่ coder+verifier
roster เต็ม 10 role — ทุก role มีงาน LFS-001 จ่อทันที (กัน zombie ด้วยงาน ไม่ใช่ด้วยการไม่ spawn):

| # | Role | Engine | งาน LFS-001 แรก |
|---|------|--------|------------------|
| 1 | lead | claude (lucifer) — มีแล้ว | dispatch/review/merge + peek loop |
| 2 | product-analyst | gpt-5.6-sol shape | เขียน acceptance criteria ต่อเป้าจาก proposal + groom backlog ถัดไปกับ user |
| 3 | architect | claude pane แยก | ADR ของเป้า 3: event schema `registry-changed`, version protocol, compatibility maw-js↔maw-ui, แผน branch ไม่ให้ local-patches หาย |
| 4 | ux-designer | gpt-5.6-sol shape | ออกแบบ typeahead combobox + summon flow 3 ขั้น (เป้า 1-2) ก่อน frontend ลงมือ |
| 5 | frontend-1 (=coder-1) | gpt-5.6-sol — มีแล้ว | implement เป้า 3 ฝั่ง UI → เป้า 2 → เป้า 1 ตาม design |
| 6 | backend-1 (=coder-2) | hound-codex-oracle | implement เป้า 3 ฝั่ง maw-js ตาม ADR ของ architect |
| 7 | qa-tester | gpt-5.6-sol shape | test plan ต่อเป้า + regression ทุกรอบ implement (ไม่แก้โค้ด) |
| 8 | verifier | claude pane แยก (ห้ามคนเดียวกับ lead/architect) | verdict ทุก DONE พร้อม target+commit hash (.partial → mv) |
| 9 | devops | hound-codex-oracle | branch/PR strategy (รวมปม maw-js local patches), vite port allocation, PR hygiene, release note ต่อ merge |
| 10 | docs-writer | gpt-5.6-sol shape | อัปเดต docs พฤติกรรม Summon ใหม่ + changelog ต่อ PR |

กติกาคงเดิมทั้งหมด: ทุก spawn ผ่าน SPAWN GATE 4 ข้อ, contract ต่อ role ต่างกันจริง (lead-authored),
ทำงานเรียงตาม dependency: architect+ux-designer ก่อน → coders → qa → verifier → docs
verifier ต้องคนละ family กับผู้เขียน (gpt เขียน → claude ตรวจ) และ architect ≠ verifier (คนออกแบบห้ามตรวจงานตามแบบตัวเอง)
pane budget: 10 panes มีเจ้าของ+งานครบทุกตัว — ถ้า role ไหนหมดงานต่อเนื่อง ให้ lead รายงาน user ก่อนพิจารณาพัก (ไม่ auto-kill)

— codex-fanout-oracle 🛰️ (AI, Claude Fable 5) · Relay Satellite
