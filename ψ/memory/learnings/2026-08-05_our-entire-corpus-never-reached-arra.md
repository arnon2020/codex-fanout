---
pattern: "ψ/memory/learnings/ ไม่ auto-index เข้า Arra — corpus ทั้งหมดตั้งแต่ 2026-07-24 ถือไว้ local 100% ขณะที่เราเขียนกฎว่า 'การถือไว้เป็น defect'"
date: 2026-08-05
source: awaken --reawaken step 3 (arra_search catch-up)
concepts: ["arra", "distribution", "knowledge-holding", "auto-memory-myth", "reawaken", "corpus"]
---

# corpus ของเราไม่เคยถึง Arra เลย

## เหตุ

`/awaken --reawaken` **step 3** สั่งว่า *"Read new learnings — `arra_search({query: 'recent learnings'})` to catch up"*
รอบก่อน (01:0x) ผมข้ามข้อนี้ ติดป้ายว่า `[unverified: ยังไม่ทดสอบว่า MCP arra-oracle ตอบไหม]`
รอบนี้รันจริง — **MCP ตอบปกติ** แต่สิ่งที่มันตอบคือปัญหา

## หลักฐาน `[verified 2026-08-05]`

`arra_stats` → `total: 6841` · `vector_status: connected` · `fts_status: healthy` ·
`last_indexed: 2026-08-04T12:04:58Z` · `version: 26.5.2-alpha.1704` ⇒ **ระบบไม่ได้พัง**

| query | filter | ผล |
|---|---|---|
| `absence claim scope … skill ไม่มีจริง` | `project: github.com/arnon2020/codex-fanout` | **0 doc ของ codex-fanout** — ที่คืนมาเป็น universal ของ tars/atlas ล้วน |
| `codex-fanout relay satellite … delivered` | เดียวกัน | เจอ 1 อันชื่อ codex-fanout แต่ `project:` เป็น **`nat-build-with-oracle/codex-fanout` (path ก่อน fork)** และเป็น**คนอื่น learn เรื่องเรา** |
| `teamclosed maw team status rc=0 …` | `mode: fts` | ไม่เจอของเรา |
| `TEACHING-LEDGER verify-check.sh บันไดชั้นของหลักฐาน` | — | ไม่เจอของเรา |

**ไม่มีเอกสารสักฉบับที่ `project: github.com/arnon2020/codex-fanout`**

ของเราที่อยู่ใน Arra **มีอันเดียว**:
`retro_2026-08-04_maw-team-up-wakes-the-engine-but-never-delivers-th`
→ `verified_by: codex-fanout` · `project:` **`github.com/arnon2020/ajfon-teams`**
⇒ **ajfon เป็นคนแบงก์ เราเป็นแค่ผู้ยืนยัน** — ความรู้เราเข้าระบบได้ก็ต่อเมื่อ**คนอื่นพามันเข้าไป**

## สิ่งที่หายไปทั้งหมด (local-only ตั้งแต่ 2026-07-24 · 12 วัน)

บันไดชั้นของหลักฐาน dispatch (ชั้น 0–4) · `teamclosed` + `maw team status` rc โกหก ·
`maw team up` ไม่ลงทะเบียนใน store · prefix-match `-t "="` + negative control ·
`relay()` กับเหตุผลที่เขียนกฎครั้งที่ 4 ไม่ใช่การแก้ · TEACHING-LEDGER 6 รอบ ·
VERIFY-THE-CHECK ตาราง 10 แถว · `unverified-confession-is-still-unverified` ·
`rule-indexed-by-topic-doesnt-fire` · `charter-field-parsed-but-never-read` ·
และ learning ของ reawaken วันนี้เอง

## ราก: เราเชื่อคำโฆษณาของ skill โดยไม่ตรวจ

`awaken/SKILL.md` step 5.2 เขียนว่า:

> *"The Oracle's auto-memory layer picks up new files in `ψ/memory/learnings/` **automatically —
> no separate API call needed**"*

`[verified 2026-08-05: false สำหรับ oracle นี้]` — เขียนไฟล์ลง `ψ/memory/learnings/` **ไม่ทำให้เข้า Arra**
ต้องเรียก `arra_learn` (ผ่าน skill `bank-to-arra`) เอง

⇒ นี่คือ **operational claim ที่ไม่มี label แล้วเราส่งต่อให้ตัวเอง** — คลาสเดียวกับกฎ teaching
discipline ของเราเองเป๊ะ: *"ทุก operational claim ต้องมี label · ไม่มี label = ห้ามส่งต่อ"*
เราบังคับกฎนี้กับสิ่งที่**เราสอนคนอื่น** แต่ไม่บังคับกับสิ่งที่**เครื่องมือบอกเรา**

## ทำไมมันเจ็บกว่าปกติ

golden rule ข้อที่ ajfon ตั้งชื่อให้เมื่อ 2026-08-04:

> 📮 **ความรู้มีพันธะเรื่องการกระจาย — การถือไว้เป็น defect แม้เนื้อหาจะถูก**
> *"None of those is a wrong fact. All three are a right fact failing to arrive."*

ตอนนั้นวัดที่ระดับ **ข้อความ 3 ฉบับ**. รอบนี้พบว่าอาการเดียวกันอยู่ที่ระดับ **corpus ทั้งก้อน** —
และมันอยู่ตรงนั้นมาตลอดช่วงที่เรากำลังเขียนกฎข้อนี้ ⇒ **การเขียนกฎเรื่องการกระจาย
ไม่ได้ทำให้ของถูกกระจาย** และ**เรานับ `git commit` เป็นการเผยแพร่มาตลอด**
ทั้งที่ git ของเราเป็น repo เดียว ไม่มี oracle อื่น `grep` เจอ

⇒ **`git commit` = durable · `arra_learn` = distributed · สองอย่างนี้คนละอย่าง**
บันไดชั้นหลักฐานของ dispatch มีคู่ขนานตรงนี้พอดี: เขียนลงดิสก์ ≠ ถึงปลายทาง

## สิ่งที่ยังไม่ได้ทำ (ไม่กลบ)

**ยังไม่ได้แบงก์อะไรเลยในรอบนี้** — backlog ~15 learning + 5 retro รอเจ้าของตัดสินใจว่า
จะแบงก์ทั้งหมด / เฉพาะที่ `[verified]` / หรือไม่แบงก์ (Principle 3: External Brain, Not Command)
`bank-to-arra` มี contract gate ของมันเอง ⇒ เป็นงานของมันเอง ไม่ใช่ของแถมท้าย reawaken

## 🔁 รอบตรวจซ้ำ (advisor ท้วง — และท้วงถูก 2 ข้อ)

**ข้อ 1: `project:` filter ไม่เคยเป็น probe ที่ตอบคำถามนี้ได้**

หลักฐานอยู่ในผลของผมเอง: doc เดียวที่เป็นเรื่องเรา ถูกแบงก์โดย ajfon และมี
`project: github.com/arnon2020/ajfon-teams` ⇒ **`project:` ติดตามผู้แบงก์ ไม่ใช่เจ้าของเรื่อง**
⇒ กรอง `project: .../codex-fanout` แล้วได้ 0 **ไม่ได้แปลว่าความรู้เราไม่อยู่ในระบบ** —
มันแปลแค่ว่าเราไม่เคยเป็นผู้แบงก์ (ซึ่งก็จริง แต่เป็นคนละ claim)
⇒ ซ้ำรอย 2 commit ก่อนหน้าเป๊ะ: **claim ทางลบที่หลักฐานไม่ครอบสโคปที่มันอ้าง**

**ข้อ 2: 4 probe แรกเป็น vector-similarity top-N ล้วน ไม่ใช่การ enumerate**

`ftsMatches: 0` ทุกอัน ⇒ ช่องทาง keyword-exact ไม่ได้ทำงานเลยใน 4 probe นั้น

### probe ที่ตัดสินได้จริง `[verified 2026-08-05]`

| probe | mode | ผล |
|---|---|---|
| `"shopee"` | fts | **`ftsMatches: 6`** · `source: "fts"` · **4ms** ⇒ **FTS ไม่ได้พัง** |
| `"codex-fanout"` | fts | **`ftsMatches: 16`** · 1ms — **ทุกอันเป็นของ oracle อื่นที่พูดถึงเรา** (tars/atlas/ajfon) ไม่มีอันไหนเราเขียน |
| **`"teamclosed"`** | fts | **`ftsMatches: 0`** ← คำที่เราประดิษฐ์เอง มีอยู่ที่เดียวในโลกคืองานเรา |

⇒ **`teamclosed` = 0 คือหลักฐานชี้ขาด** งาน 08-03/08-04 ของเราไม่อยู่ใน Arra จริง
⇒ **ข้อสรุปยืน แต่ probe ที่ทำให้ยืนคือ distinctive-token FTS ไม่ใช่ `project:` filter**

### FTS: ปิดป้าย `[unverified]` เดิม

`fts_status: healthy` เป็นความจริง — **FTS ทำงาน** ที่ทำให้ได้ 0 คือ **query ยาวหลายคำ**
(และ/หรือภาษาไทย) → ตกไปใช้ vector ทั้งหมด · single token → FTS ตอบใน 1–4ms

⇒ **ก่อน dedup ก่อนแบงก์ ต้อง probe ด้วย token เดี่ยวที่โดดที่สุด ไม่ใช่ประโยคยาว** —
query ยาวให้ความรู้สึกว่า "ค้นละเอียดกว่า" แต่**ปิดช่องทางที่แม่นที่สุดทิ้ง**
⇒ นี่คือ *"เครื่องมือตรวจที่ตัวมันเองพัง"* อีกแบบ: ไม่ได้พัง แต่**เราใช้ในโหมดที่มันไม่ตอบ**

## Family (step 2 ของ reawaken — ปิดด้วยรอบนี้)

`[verified 2026-08-05]` `gh` login แล้ว (`arnon2020`) · **เราลงทะเบียนแล้ว** —
issue **#2814** *"🌟 Codex Fanout Oracle Awakens — Relay Satellite"* (2026-07-24)
· registry = issue #60 *"Oracle — Start Here (**76+ Members**)"* updated 2026-07-31

⚠️ **ตัวเลขสมาชิกขัดกัน 3 ที่**: `awaken/SKILL.md:395` = **280+** · `oracle-family-scan` = **186+**
· registry จริง = **76+** ⇒ ตัวเลขใน skill เป็น claim ที่ไม่มีใครถอน คลาสเดียวกับ `valid-if:`
(ไม่ใช่ปัญหาของเรา ไม่แก้ skill คนอื่น — บันทึกไว้เฉย ๆ)

เชื่อมกับ [[2026-08-05_absence-claims-must-name-their-scope]] ·
[[2026-08-01_corrections-must-flow-down-the-teaching-tree]] ·
[[2026-08-04_rule-indexed-by-topic-doesnt-fire]]
