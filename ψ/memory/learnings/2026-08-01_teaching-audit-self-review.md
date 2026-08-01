---
title: Self-audit — คำสอนเรื่องสร้างทีมของ codex-fanout ผิดตรงไหน และปิดยังไง
date: 2026-08-01
author: codex-fanout (AI oracle) [user-virtual-machine:codex-fanout]
trigger: user — "ทบทวนว่าการสอนสร้างทีมถูกต้องหรือเปล่า เรื่องที่เคยพลาดจะเกิดอีกไหม หาช่องโหว่แล้วปิดมัน"
method: อ่าน artifact ที่สอนไปจริงทุกชิ้น → verify ทีละ claim ด้วย source + การรันจริง → แก้ + แจ้งผู้รับ
status: ปิดครบ 6 ช่องโหว่ · prevention เป็นกฎในไฟล์แล้ว ไม่ใช่ความตั้งใจ
---

# Self-audit: คำสอนสร้างทีม — ผิดตรงไหน จะเกิดซ้ำไหม

## รากเดียวของความพลาดทุกครั้ง

> **verify คุณสมบัติเดียว → เหมาว่าคำสั่งใช้ได้ทั้งหมด → ส่งต่อ**

prism ตั้งชื่อให้ และวันเดียวกันเกิดกับ **4 คน**: codex-fanout 1 ครั้ง, prism 2 ครั้ง, loom 1 ครั้ง
ไม่ใช่ความสะเพร่าของใครคนเดียว — เป็น failure mode ของวิธีทำงาน

ตัวเร่งที่ทำให้ลุกลาม: **การที่หลายคนอ่าน source แล้วตรงกัน ไม่ใช่การยืนยัน**
วันนี้ codex-fanout → prism → lucifer อ่านตรงกันทั้งสาย และ**ผิดเหมือนกันทั้งสาย**
เพราะไม่มีใครพิมพ์ `ls` สักครั้ง (prism's words)

---

## ช่องโหว่ที่พบและปิดแล้ว

### 1. ❌ กฎที่สอนผิด แล้วไม่มีใครตามแก้ — 3 วัน 4 oracle

`engine: codex → auto-resolve เป็น codex-resume → พัง` ส่งให้ atlas, tars, atlas-codex (2026-07-25)
และ lucifer (2026-07-28)

- citation-oracle **รันจริงและ disprove ตั้งแต่ 2026-07-29** (`engine: codex` ใช้ได้, commit `fc99a6b`)
- citation **ส่ง correction มาถึงผมแล้ว** (audit log 2026-07-29T09:20)
- ผมรับ แต่ **ไม่ได้ส่งต่อให้ 4 คนที่ถือของผิดอยู่**
- source ยืนยัน: `grep -rn "codex-resume" maw-rs/crates/` = **0 hits**;
  `wake_default_engine` คืน `"codex"` ไม่ใช่ `"codex-resume"`; ตัวจริงอยู่แค่ในไฟล์ `.bak` เก่า

**ปิดแล้ว**: retraction ส่งครบ 4 คน · lucifer ACK + แก้ memory 2 ไฟล์ · learnings แก้เป็น RETRACTED

**นี่คือช่องโหว่ที่แท้จริง**: correction ไหล**ขึ้น**มาหาผม แต่ไม่มีทางไหล**ลง**กลับไป
เพราะผมไม่มีบันทึกว่า "ใครถือ claim ไหนอยู่"

### 2. ❌ broadcast คำสั่งที่ไม่มีใครรัน ให้ 7 oracle

เช้านี้ส่ง "ใช้ `maw team up` แทน `maw team resume`" จาก **source อย่างเดียว** ไม่มีใครรัน exec

**ปิดแล้ว — และผลคือดี**: รัน throwaway probe (1 member, literal worktree, `engine: codex`)
บน maw-rs v26.7.30 → window ขึ้น → engine resolve ถูก → **Codex v0.145.0 UI live** (gpt-5.5, YOLO)
`maw team up` ใช้ได้จริง `[verified]`

**แต่เจอสิ่งที่ broadcast ขาดไป**: `maw team up` **ไม่ pre-seed codex directory-trust**
→ ทีมจะค้างที่ trust prompt ทั้งทีม ดูเหมือน "spawn สำเร็จแต่เงียบ" = zombie phase 2 พอดี
ส่ง follow-up ครบ 7 คนแล้ว (lucifer + ajfon ACK)

### 3. ❌ broadcast โดยไม่ตรวจว่า fleet มี artifact ที่ขัดกันอยู่

`codex-team/SKILL.md:128` (atlas's) เขียนว่า **"⛔ `maw team up` ≠ spawn — Do not use `up` to
materialize a worker"** — ผมไม่เคย grep เจอก่อนส่งของตัวเองให้ 7 คน

ผลตรวจ: บรรทัดนั้น pin ที่ v26.6.14 (`team_t3_up` hard-return read-only) และถูก shadow แล้วบน
pin ปัจจุบัน (`team_t5b_up` → `exec_up` → `wake_window`) — **ของ atlas ถูกในยุคนั้น**

**ปิดแล้ว**: ส่งหลักฐานให้ atlas ตัดสินใจเอง **ไม่แก้ skill ของคนอื่น** (ทำตามที่ prism ทำกับผม)

### 4. ❌ อ้าง skill/script ที่ไม่มีอยู่จริง — 4 ใน 6

`ls ~/.claude/skills/` พบว่า CLAUDE.md ของผมอ้าง skill ที่ไม่มี: `codex-lead`, `oracle-team`,
`oracle-write-complete-book`, `session-recap` (ตัวหลังเปลี่ยนชื่อเป็น `recap`)

หนักกว่านั้น: **`CODEX-TEAM-BOOTUP.md` เป็นเอกสาร public + release** และ charter ในนั้นชี้ไปที่
`~/.claude/skills/oracle-team/scripts/codex-setup.ts` — **path ที่ไม่มีอยู่** ใครทำตามจะตันที่บรรทัด 152

**ปิดแล้ว**: CLAUDE.md แก้ตามที่มีจริง + ระบุว่า `codex-team` เป็นของ atlas ไม่ใช่ของเรา ·
BOOTUP.md เพิ่ม staleness notice ตารางเทียบ 4 ข้อที่ตายแล้ว + ชี้ successor

### 5. ⚠️ n=1 ที่ถูกนำเสนอเป็นกฎ

BOOTUP.md เล่าเหตุการณ์วันเดียว (2026-07-23) แต่เขียนเหมือน runbook — bug #658, pool `~/.codex-team/N`,
symlink workaround ล้วน pin กับ build วันนั้น (`~/.codex-team/` ไม่มีจริงแล้ว — citation verified)

**ปิดแล้ว**: staleness notice บอกชัดว่านี่คือ **field report ของหนึ่งเซสชัน ไม่ใช่ runbook ปัจจุบัน**

### 6. ✅ สิ่งที่ตรวจแล้ว **ถูก** (ไม่แก้)

- Tier table engine ที่สอน lucifer — `hound-codex-oracle`, `sage-opencode-oracle`,
  `hound-thclaws-oracle` เป็น key จริงใน `commands` ทั้ง 3 ตัว ✅
- golden-worker probe ก่อน scale · hub-and-spoke + lead ต้อง drive · peek loop 15-20 นาที
- role prompt ต้องต่างกันจริง · verifier คนละ family กับ coder
- **charter role name ≠ tmux window name** — วันนี้ยืนยันซ้ำโดยโดนเอง:
  `maw hey atlas` fuzzy-match ไปโดน `54-atlas-codex` ผิดตัว

---

## Prevention — เป็นกฎในไฟล์ ไม่ใช่คำสัญญา

เขียนลง `CLAUDE.md` → **Golden Rules → Teaching discipline** แล้ว:

1. **ทุก operational claim ต้องมี label** — `[verified: ran on <binary> <version>, output แนบ]` /
   `[inferred: source only]` / `[unverified]` · ไม่มี label = ห้ามส่งต่อ
2. **ห้าม broadcast คำสั่งปฏิบัติการ** เว้นแต่มีคนรัน end-to-end บน version ที่ระบุ
   และข้อความต้องบอก version + ใครรัน
3. **ก่อน broadcast: `grep -rn "<verb>" ~/.claude/skills/`** — ถ้าขัดกับของใคร ให้แจ้งเจ้าของก่อน
4. **บันทึกทุกการสอนลง `ψ/teams/TEACHING-LEDGER.md` ในเซสชันนั้น** — claim ถูกล้มเมื่อไร
   `grep` ได้ทันทีว่าใครถืออยู่ แล้วส่ง retraction ให้ครบ
5. **ห้ามแก้ skill ของ oracle อื่น** — ส่งหลักฐานให้เจ้าของตัดสิน
6. **อย่าอ้าง skill/script โดยไม่ `ls`**

กฎข้อ 4 คือกลไกใหม่ที่ปิดรากของปัญหา: ledger ทำให้ **correction ไหลลงตาม teaching tree ได้**
ไม่ใช่จบที่ผมคนเดียวเหมือนกรณี citation → (ตัน) → lucifer

---

## จะเกิดซ้ำไหม — ตอบตรง

**ข้อ 1 (correction ไม่ไหลลง)**: เกิดยากขึ้นมาก — ledger ทำให้ตอบได้ว่า "ใครถือของผิดอยู่"
ซึ่งเมื่อวานตอบไม่ได้เลย นี่เป็นกลไก ไม่ใช่วินัย

**ข้อ 2-3 (broadcast ของดิบ)**: ขึ้นกับวินัยว่าจะ grep + รันก่อนส่งจริงไหม
กฎช่วยได้ระดับหนึ่ง แต่ **ไม่ใช่ hard gate** — ยอมรับตรง ๆ ว่ายังพลาดได้

**สิ่งที่ป้องกันไม่ได้ด้วยกฎ**: การที่ fleet เชื่อผมเพราะ**ชื่อ** — prism ยอมรับเองว่า
"ให้น้ำหนัก output ของคุณเพราะนึกว่า codex-fanout = ผู้เชี่ยวชาญ maw/codex"
ทางแก้เดียวคือ label ให้ผู้อ่านชั่งน้ำหนักจาก**หลักฐานในนั้น** ไม่ใช่จากชื่อคนส่ง

### หลักฐานว่ามันเกิดซ้ำได้จริง — เกิดในเซสชันนี้เอง

follow-up ที่ผมส่งไปประกาศกฎ "ต้อง label ทุก claim" **ตัวมันเองเขียนกว้างเกินหลักฐาน**:
probe พิสูจน์แค่ **1 member · worktree literal · engine คำสั่งเดี่ยว · pane `missing`**
แต่ผมเขียนว่า "`maw team up` materialize worker ได้จริง" ซึ่ง 7 คนจะอ่านว่าครอบคลุม charter ของตัวเอง

สิ่งที่ยังไม่ได้ทดสอบและ**ตรงกับเคสจริงของ loom พอดี**:
- branch `state == "dead"` → `team_t5b_resume_pane` (เติม `--resume`) — loom คือ pane ตายหลัง reboot
- engine ที่ค่าเป็น compound shell string (`env -u …`, `hook.sh; …`) — engine ของ loom เป็นแบบนี้
- หลาย member (loop `new-window` — collision/ordering)

advisor จับได้ → ส่ง **scope amendment** ครบ 7 คน + แก้ ledger แล้ว (lucifer ACK)

**บทเรียน**: รากนี้ลึกกว่าที่คิด — มันโผล่แม้ในข้อความที่กำลังประกาศกฎเพื่อกันมันเอง
กฎอย่างเดียวไม่พอ ต้องมี **ผู้ตรวจจากภายนอก** ก่อนส่งของสำคัญออก fleet

---

## Evidence trail

- probe: throwaway charter 1 member → Codex v0.145.0 UI live → session killed, `~/.codex/config.toml`
  restore กลับสภาพเดิม, ไม่เหลือ residue
- retraction: atlas, tars, atlas-codex, lucifer (inbox ครบ 4 · lucifer ACK + แก้ memory 2 ไฟล์)
- follow-up verified: 7 oracle (inbox ครบ · lucifer + ajfon ACK)
- atlas: หลักฐาน `:128`/`:251` version-pinned — ไม่แก้ skill เขา
- ไฟล์ที่แก้: `CLAUDE.md`, `CODEX-TEAM-BOOTUP.md`, `ψ/memory/learnings/2026-07-25_codex-team-spawn-lessons.md`
- ไฟล์ใหม่: `ψ/teams/TEACHING-LEDGER.md`
