---
pattern: ฟิลด์ที่ระบบ "รับและ validate" แต่ไม่ทำตาม หลอกหนักกว่าฟิลด์ที่มันปฏิเสธ — และการตรวจที่สะท้อนค่าที่เราขอกลับมา ไม่ใช่การตรวจ
date: 2026-08-06
source: "fleet report: สมาชิกกำหนด harness/model ไม่ได้"
concepts: [maw, charter, engine, model, schema-vs-behavior, silent-fallthrough, verification, knowledge-distribution]
---

# คำขอ ไม่ใช่การตั้งค่า

`[verified 2026-08-06 · maw-rs 325db65 = binary ที่รันอยู่ · ทุกข้อจาก --dry-run ไม่ได้ spawn อะไร]`
`valid-if:` `maw --version` ยังขึ้นต้น `325db65` · `bash ψ/teams/scripts/verify-check.sh selftest` = OK

## เหตุ

fleet รายงานว่ากำหนด harness/model ให้สมาชิกทีมไม่ได้ — บางตัวได้ที่ขอ บางตัวไม่ได้
ไม่มีสัญญาณบอกว่าตัวไหนเป็นตัวไหน

รากไม่ใช่บั๊กเดียว มันคือ **สามชั้นที่ทุกชั้นบอกว่า "สำเร็จ"**:

1. **schema รับ** — `model:` `engines:` parse ผ่าน ไม่ error
> ❌ **CORRECTED 2026-08-06 (ภายหลังในวันเดียวกัน · atlas verify ซ้ำเป็นอิสระ)**
> ข้อ 2 ด้านล่างเขียนว่า `model:` ถูก "validate แล้วทิ้ง" — **ครึ่งเดียว**
> `team_up_helpers.rs:235` `engine = opts.engine.or(member.engine).or(member.model).unwrap_or("claude")`
> ⇒ **มี `engine:`** → `model:` ตายจริง (ข้อความเดิมถูกเฉพาะเคสนี้)
> ⇒ **ไม่มี `engine:`** → 🔴 **model string กลายเป็นชื่อ engine** → miss → fallthrough เงียบแน่นอน
> ⇒ กฎที่เดิมผมเขียนไว้ในไฟล์นี้เองว่า *"validate แล้วทิ้ง หลอกหนักกว่าปฏิเสธ"* ยังถูก
> **แต่ยังมีสถานะที่หลอกหนักกว่านั้นอีกชั้น: ถูกอ่านไปใช้ผิดฟิลด์**
> ⇒ และไฟล์นี้เป็น **ผิวที่ 5 จาก 6** ของ claim เดียวกัน — ดู §กฎข้อ 6 ท้ายไฟล์

2. **`team up` validate** — เอา `member.model` ไปตรวจว่าเป็น token ปลอดภัย แล้ว**ทิ้ง**
   (`team_up_apply.rs:186`) · argv ที่ส่งให้ wake ไม่มี `--model` (`:149`, unit test ยืนยันที่ `:251`)
   · `maw wake` **ไม่มีแฟลก `--model` ทั้งไบนารี**
3. **resolution ไหลลงเงียบ ๆ** — `commands.<engine>` ไม่มี ⇒ ตกไป **ชื่อ window → `<oracle>-oracle`
   → glob → `default`** ไม่มี error ไม่มี warning exit 0

```
wake coder-1 -e codex-xhigh → claude --model claude-opus-5 --continue   (ตกถึง default)
wake hermes  -e codex-xhigh → hermes --yolo                             (ชื่อ window ชนะ)
wake hermes  -e codex       → codex …                                   (ลงทะเบียนแล้วจึงชนะ)
```

⇒ charter เดียวกัน คนละเครื่อง คนละชื่อ window = **คนละ engine** และดูเหมือนสำเร็จทั้งหมด

## กฎที่เอาไปใช้ต่อได้

### 1. "รับและ validate แล้วทิ้ง" หลอกหนักกว่า "ปฏิเสธ"

ถ้า `model:` ถูกปฏิเสธตั้งแต่ preflight ทุกคนจะรู้ในวินาทีแรก · แต่มันตรวจว่า token ปลอดภัยไหม
— ซึ่งอ่านออกมาเหมือน *"ระบบเห็นฟิลด์นี้แล้ว"* — แล้วทิ้ง
⇒ ต่อยอดจาก [[charter-field-parsed-but-never-read]]: **grep หาจุดที่ *อ่านไปใช้*** ไม่ใช่จุดที่ประกาศ
**และไม่ใช่จุดที่ validate** — การ validate เป็นสัญญาณปลอมที่แรงกว่าการประกาศเฉย ๆ

### 2. การตรวจที่สะท้อนค่าที่เราขอกลับมา ไม่ใช่การตรวจ

`maw team up --dry-run` พิมพ์ `engine=codex-xhigh` — อ่านจาก charter ที่เราเพิ่งเขียน
**มันไม่มีทางตกได้** ไม่ว่าระบบจะทำตามหรือไม่ · เราใช้มันเป็นหลักฐานมาตลอด (และ loom ก็ใช้)
⇒ ถามทุกครั้ง: **"การตรวจนี้ตกได้ด้วยเหตุอะไร"** ถ้าตอบไม่ได้ มันคือ echo ไม่ใช่ check
⇒ ชั้นหลักฐานของ engine: charter (เจตนา) → `--dry-run` ของ `team up` (**ยัง echo อยู่**) →
`maw wake --dry-run` (**คำสั่งจริงที่จะรัน**) → peek status bar (สิ่งที่ boot ขึ้นมาจริง)

### 3. ทางลัดที่ปลอดภัยกว่า global: repo-local config layer

`maw config set` ตั้งได้แค่ `node|port` ⇒ ต้องเขียนไฟล์เอง · แต่**ไม่ต้องแตะ global**
maw เดินขึ้นจาก cwd เก็บทุก `<ancestor>/.maw/maw.config.<N>.json` มา deep-merge เรียงตาม N
⇒ `<repo>/.maw/maw.config.60.json` ชนะ global (50) · เดินทางไปกับ repo · ไม่กระทบ oracle อื่น
(ตรงกับข้อบังคับ portability: ไม่ hardcode path, รอดการย้ายที่และเปลี่ยนเจ้าของ)

### 4. เครื่องมือที่เขียนมาจับ false-PASS ก็ติด false-PASS ได้ — และติดจริง 2 ครั้งในไฟล์เดียว

`enginecheck` เวอร์ชันแรก:
- แกะสมาชิกได้ **11 แถวจาก charter ที่มี 2 สมาชิก** เพราะ `maw team plan` พิมพ์
  `  - /path/...` ใต้ "would prepare artifacts" ด้วยรูปแบบเดียวกับบรรทัดสมาชิกเป๊ะ
  → **cross-check จำนวนที่ maw ประกาศเองจับได้** (นี่คือเหตุผลที่มันอยู่ตรงนั้น)
- อ่าน **ข้อความ error ของ `enginereg`** เป็น "คำสั่งที่จะรัน" เพราะดู *มีข้อความบรรทัดที่ 2 ไหม*
  แทนที่จะดู **exit code** → รายงาน ✅ PASS ให้ charter ที่ engine ไม่ได้ลงทะเบียน
  = **false-PASS ในเครื่องมือที่เขียนขึ้นเพื่อจับ false-PASS**
⇒ ต่อยอด `VERIFY-THE-CHECK.md`: **rc กับ output ต้องอ่านคู่กันเสมอ** — กฎนี้มีอยู่แล้วในไฟล์นั้น
สำหรับ `maw`/`tmux` และผมเพิ่งละเมิดมันกับ **ฟังก์ชันของตัวเองในไฟล์เดียวกัน**

### 5. 📮 ข้อที่แสบที่สุด — เรารู้เรื่องนี้มา 5 วันแล้ว

loom รายงานอาการนี้ **2026-08-01** เราเขียน §10 ของ research doc ในวันเดียวกัน
แล้ว**ถือไว้เฉย ๆ**: ไม่ทำเครื่องมือ ไม่แก้ skill (`codex-lead` ยังสอน `engines:` ซึ่งเป็น field ตาย)
ไม่ส่งกลับให้ loom จนสมาชิก fleet มาเจอเองอีกรอบ 2026-08-06
และ charter ของ repo นี้เอง (`codex-fanout-team.yaml`) ขอ `sage-opencode-oracle`
มาตั้งแต่ **2026-07-25** โดยที่ชื่อนั้นมีอยู่แค่ใน **YAML comment** ไม่เคยลงทะเบียน
⇒ *"ความรู้มีพันธะเรื่องการกระจาย — การถือไว้เป็น defect แม้เนื้อหาจะถูก"* อีกรอบ
และรอบนี้ **ของที่ถือไว้ชี้กลับมาที่ charter ของตัวเอง**

เชื่อมกับ [[charter-field-parsed-but-never-read]] · [[verify-the-check]] · [[teaching-ledger]] ·
`ψ/teams/ENGINE-AND-MODEL.md`
