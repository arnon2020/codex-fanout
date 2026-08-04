---
pattern: "claim ว่า 'ไม่มี' ต้องระบุสโคปที่ค้น — ค้นสโคปเดียวแล้วสรุปว่าไม่มีทุกสโคป คือ scar เดิมชี้กลับทิศ"
date: 2026-08-05
source: awaken --reawaken (no-arg /awaken)
concepts: ["reawaken", "identity", "verify", "absence-claim", "scope", "negative-claim"]
---

# Re-awakening: Codex Fanout Oracle — และสิ่งที่มันจับได้

## เหตุการณ์

`/awaken` ไม่มี argument → ตีความเป็น `--reawaken` (path เกิดใหม่จะ **ทับ CLAUDE.md** ที่มี
golden rule ~40 ข้อ). ระหว่าง re-sync ตามขั้นตอน "refresh identity" ไปเจอว่า **CLAUDE.md
§Installed Skills ผิดมาตั้งแต่ 2026-08-01**

claim เดิม: *"Verified on disk 2026-08-01 (`ls ~/.claude/skills/`). **4 of 6 previously listed
here did not exist**"* — `codex-lead`, `oracle-team`, `oracle-write-complete-book`, `session-recap`

`[verified 2026-08-05]`:

| skill | claim 08-01 | ความจริง |
|---|---|---|
| `codex-lead` | ไม่มีจริง | **มี** — `.claude/skills/codex-lead/SKILL.md` 8.7K commit `8879e4c` |
| `oracle-team` | ไม่มีจริง | **มี** — `.claude/skills/oracle-team/SKILL.md` 12K commit `eca78eb` + `scripts/` 4 ไฟล์ |
| `oracle-team/scripts/codex-setup.ts` | missing, มี successor | **มี** 8.1K อยู่ใน git — และ **soul file บันทึกไว้เองตั้งแต่ 07-24** ว่าเอาเข้า git แล้ว |
| `session-recap` | ไม่มีจริง | **ไม่มีจริง** ✓ (`find /` ทั้งสองสโคป) |
| `oracle-write-complete-book` | "it isn't here" | **ไม่ได้ติดตั้ง** ✓ แต่ **มีอยู่** ใน `Soul-Brews-Studio/oracle-book-skills` + 2 repo พี่น้อง |

ทั้งสองตัวที่ "ไม่มีจริง" **อยู่ใน session skill list ตอนนี้** — คือมันโหลดอยู่ขณะที่ไฟล์บอกว่าไม่มี

## รากของความพลาด

การตรวจครั้งนั้นรัน **`ls ~/.claude/skills/`** — สโคปเดียว (global) — แล้วสรุปว่า
**ไม่มีทุกสโคป**. skill ของ Claude Code โหลดจากอย่างน้อย 2 ที่: `~/.claude/skills/` (global)
และ `.claude/skills/` (project-local ใน repo). ตรวจที่แรกแล้วเขียนคำว่า "did not exist" เฉย ๆ

นี่คือ **scar เดิมของฟลีต ชี้กลับทิศ**:

> *verify คุณสมบัติเดียว → เหมาว่าคำสั่งใช้ได้ทั้งหมด → ส่งต่อ* (prism ตั้งชื่อ 2026-08-01)

ทิศบวกคือ "ตรวจเจอ 1 อย่าง → เหมาว่าใช้ได้หมด". ทิศลบคือ **"ตรวจไม่เจอที่ 1 ที่ → เหมาว่าไม่มีที่ไหนเลย"**
คลาสเดียวกัน แต่เรามองไม่เห็นเพราะ**การบอกว่าตัวเองไม่มีของ มันดูถ่อมตัว ไม่ดูเหมือน overclaim**

และมันละเมิดกฎที่เราเขียนเองไว้แล้วใน CLAUDE.md เมื่อ 08-04:

> **`ยังไม่ได้ส่ง` ก็เป็น claim ที่ต้อง `grep` เหมือน `ส่งแล้ว` — ทิศลบไม่ได้ยกเว้นจากการตรวจ**

⇒ **กฎมีอยู่แล้ว claim ที่ละเมิดก็อยู่ในไฟล์เดียวกัน ห่างกัน 100 บรรทัด** — นี่คือคลาสเดียวกับ
`2026-08-04_rule-indexed-by-topic-doesnt-fire.md` อีกที: กฎอยู่ใต้หัวข้อ "dispatch" ไม่ยิงตอนตรวจ skill

## กฎที่ได้

**claim ว่า "ไม่มี" ต้องพก 2 อย่างเสมอ: (1) สโคปที่ค้น (2) คำสั่งที่ใช้ค้น**

- ❌ `ไม่มี codex-lead`
- ✅ `ไม่มี codex-lead ใน ~/.claude/skills/ [ls, 2026-08-01] — ยังไม่ได้ค้น project-local`
- ✅ `ไม่มี session-recap เลย [find / ทั้งสองสโคป, 2026-08-05]`

**ก่อนเขียนว่า skill ไม่มี**: `ls ~/.claude/skills/ .claude/skills/` — **สองที่เสมอ**

**"ไม่ได้ติดตั้ง" ≠ "ไม่มีอยู่"** — `oracle-write-complete-book` ถูกเขียนว่า *"it isn't here"*
ซึ่งถูก แต่ประโยคถัดมา *"don't promise it"* ทำให้อ่านเป็น "ของนี้ไม่มีในโลก" ทั้งที่ **ติดตั้งได้**
สองสถานะนี้พาไปคนละทางแก้: อันแรก = หาทางอื่น · อันหลัง = `git clone` แล้วจบ

## การกระจาย (ตามกฎ correction ต้องไหลลง teaching tree)

`grep -n -i "skill|codex-lead|oracle-team|ไม่มีจริง|4 ใน 6" ψ/teams/TEACHING-LEDGER.md`
→ hit 10 บรรทัด **ไม่มีอันไหนเป็น claim นี้** (เป็นเรื่อง `maw team oracle-invite` ไม่มีจริง,
`codex-team` SKILL.md pin version, และการ grep skill ฟลีตก่อนส่ง)

⇒ claim "4 ใน 6 ไม่มีจริง" **ไม่เคยถูกสอนออกไปให้ oracle ใด** — correction จบในไฟล์ตัวเอง
**ไม่ต้อง fan-out** และบันทึกไว้ตรงนี้ว่า*ทำไมถึงไม่ต้อง* เพราะ "ไม่ได้ส่ง" ก็เป็น claim ที่ต้องมีหลักฐาน

## ของค้างที่เจอพ่วง

`ψ/memory/resonance/codex-fanout-oracle.md` frontmatter ยังเขียน `human: Nat` ทั้งที่เปลี่ยนเป็น
"user" ตั้งแต่ **2026-07-28** — ค้าง **8 วัน** ในไฟล์ตัวตนของตัวเอง ขณะที่ CLAUDE.md และ MEMORY.md
แก้ไปแล้วทั้งคู่ ⇒ **การแก้ที่ไม่ได้ไล่ทุกที่ที่ claim อยู่ ก็คือ correction ที่ไม่ถึงปลายทาง** —
คลาสเดียวกับ `2026-08-01_corrections-must-flow-down-the-teaching-tree.md` แต่เป็นทรีภายในไฟล์ตัวเอง

เชื่อมกับ [[2026-08-04_rule-indexed-by-topic-doesnt-fire]] ·
[[2026-08-01_corrections-must-flow-down-the-teaching-tree]] ·
[[2026-08-04_unverified-confession-is-still-unverified]]
