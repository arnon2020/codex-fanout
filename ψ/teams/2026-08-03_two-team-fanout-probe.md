---
title: Two-team concurrent fanout probe — ลบแล้วทำใหม่พร้อมกันสองทีม
date: 2026-08-03
author: codex-fanout (AI oracle) [user-virtual-machine:codex-fanout]
binary: maw-rs v26.7.30-alpha.2017-17-g284ae4d (284ae4d) built 2026-08-03 17:09:46 +0700
scope: throwaway teams ของผมเอง · ไม่แตะ ai-design-look · ไม่แตะ symlink · ไม่แตะ repo ajfon
status: รันจบ ปิดครบ config คืนสภาพเดิม byte-identical
---

# สิ่งที่รัน

2 ทีมแยกกัน ทีมละ 1 worker (`drift-fanout-a` / `drift-fanout-b`) เข้า session `114-codex-fanout`
วงจรเต็ม: **สร้าง → ขึ้นพร้อมกัน → ลบ → ขึ้นใหม่พร้อมกัน → สั่งงานพร้อมกัน → เก็บผล → ปิด**
ทุกคำสั่ง `maw team *` นำหน้าด้วย `maw --version` ตามกติกา §0

---

# F1 🔴 `engine: codex` ตอนนี้ **spawn `claude` เงียบ ๆ** — และ `--dry-run` ไม่จับ

`[verified 2026-08-03 · 284ae4d · รันเอง 2 รอบ pane output แนบ]`

```
charter:  engine: codex
dry-run:  probe-a  probe-a  codex  missing  would fresh wake --wt agents/probe-a -e codex
pane จริง: MAW_SESSION_WINDOW=probe-a-oracle claude --model claude-opus-5 --continue
          No conversation found to continue      ← ตาย ทิ้ง pane เป็น bash
```

`claude --model claude-opus-5 --continue` = ค่าของคีย์ **`default`** ใน `~/.config/maw/maw.config.json`
แบบตรงตัวอักษร · `codex` **ไม่ใช่คีย์ใน `commands`** (มี 27 คีย์ ไม่มี `codex`)
config mtime = **2026-08-03 16:10:54** (วันนี้ ก่อน build 16:16 หกนาที)

ลูกโซ่การ resolve จาก source `[inferred: อ่าน source สอดคล้องกับที่รันได้]`
`crates/maw-cli/src/core_impl/wake_engine_command.rs:74-97`
`engine` → `window_name` → `<oracle>-oracle` → glob → `wake_engine` → **`default`** → builtin
ไม่มี warning สักบรรทัดเมื่อ fall through

**พิสูจน์ว่าเป็นเรื่องคีย์ ไม่ใช่ engine ถูกเมิน** — ทีม B เปลี่ยนเป็นคีย์ที่มีจริง
(`hound-codex-oracle`) แล้ว **boot เป็น codex จริงทันที** ตัวแปรเดียวที่ต่างคือชื่อคีย์

⇒ **`up --dry-run` ไม่ใช่หลักฐานว่า engine ผูกถูก** — มันสะท้อนค่าที่ขอ ไม่ใช่ค่าที่จะได้
ต้อง peek pane เสมอ

## ผลกระทบตรงต่อ Round 2 (ต้องแจ้ง ajfon ก่อน spawn)

charter `ai-design-look` เขียน `engine: codex` (lit-scout) และ `engine: codex-xhigh` (metric-prober)
**ทั้งสองไม่ใช่คีย์ใน commands ตอนนี้** ⇒ ถ้า `up` วันนี้จะได้ **claude** ทั้งคู่แบบเงียบ ๆ
= corpus-builder + metric-prober กลายเป็น family เดียวกับ lead **เสีย cross-family โดยไม่มีใครเห็น**
(Round 1 บูต codex ได้จริงเมื่อ 2026-08-02 — สิ่งที่เปลี่ยนคือ config ไม่ใช่ charter)

---

# F2 ✅ สองทีมพร้อมกันได้จริง — fanout > 1 ครั้งแรก

`[verified 2026-08-03 · 284ae4d]` รอบที่สอง: `up` สองคำสั่งขนานกัน จบใน **3 วินาที** ทั้งคู่

| ทีม | engine ใน charter | ที่บูตจริง (peek) | worktree |
|---|---|---|---|
| drift-fanout-a | `sage-codex-oracle` | OpenAI Codex v0.145.0 · **gpt-5.6-sol xhigh** · YOLO · ไม่มี trust prompt | `agents/probe-a` ✅ |
| drift-fanout-b | `hound-codex-oracle` | OpenAI Codex v0.145.0 · **gpt-5.5 high** · YOLO · ไม่มี trust prompt | `agents/probe-b` ✅ |

**engine ต่างกันคนละตัว ผูกถูกตาม charter ของใครของมัน ไม่ปนกัน** · ทั้งคู่รับงานและทำงานพร้อมกันจริง
(pwd/branch ถูกต้องทั้งคู่ในรายงานที่เขียนเอง)

---

# F3 ⚠️ `up` ขนานกันเข้า session เดียว — หน้าต่างหายไปเงียบ ๆ 1 ใน 2 รอบ

รอบแรก: log ของทั้ง A และ B พิมพ์ `fresh wake` เหมือนกัน **แต่ tmux มีหน้าต่างเดียว** (`probe-a-oracle`)
ของ B ไม่เกิดเลย ไม่มี error ไม่มี warning · รอบสอง: ครบทั้งสอง
`[verified — เกิด 1 ใน 2 รอบ n=2 ยังไม่รู้เงื่อนไขที่ทำให้เกิด]`

⇒ **output ของ `up` ไม่ใช่หลักฐานว่าหน้าต่างมีอยู่** ต้องยืนยันด้วย `tmux list-windows` / `maw ls -v`
⇒ ถ้าจะขึ้นหลาย lane ควรขึ้น**ทีละตัวแล้วเช็ค** (ตรงกับกฎเดิมของ charter Round 2 พอดี — ตอนนี้มีเหตุผลเชิงประจักษ์แล้ว)

---

# F4 🔴 worktree isolation **ไม่ถูกบังคับ** เมื่อ engine ใช้ `--sandbox danger-full-access`

probe-a รัน `cat ../probe-b/PROBE-REPORT.md` แล้ว **อ่านได้เต็มไฟล์** (แนบมาในรายงานตัวเอง)
probe-b รันคำสั่งคู่กันตอน 19:50:56 ได้ `No such file or directory` — นั่นคือ **ไฟล์ยังไม่ถูกเขียน**
(ENOENT) **ไม่ใช่การถูกปฏิเสธสิทธิ์** (probe-a เขียนเสร็จ 19:51:14 ทีหลัง 18 วินาที)

⇒ จำกัดขอบเขต claim เดิมในเลดเจอร์ (`worker sandbox อ่านนอก worktree ไม่ได้`, 2026-08-01):
**อันนั้นจริงกับ engine ที่จำกัดสิทธิ์ ไม่จริงกับ codex ที่รันด้วย `--sandbox danger-full-access`**
isolation ของ worktree เป็น **ข้อตกลง ไม่ใช่กำแพง** — worker เขียนทับกันได้ถ้า prompt ไม่ห้าม

---

# F5 warning `not an agent -- likely misaddressed` เกิดกับ codex ที่ live อยู่ด้วย

`maw hey` ไปยัง pane ที่รัน codex อยู่จริง ๆ (`cmd=node`, title `⠇ probe-a`) ยังขึ้น warning นี้
ทั้งที่ข้อความถึงและ worker ทำงานจริง `[verified 2026-08-03]`
⇒ เดิมบันทึกไว้ว่าเกิดกับ thclaws — **เกิดกับ codex ด้วย** · warning นี้บอกอะไรไม่ได้ทั้งสองทาง
(ไม่ได้แปลว่าไม่ถึง และ "delivered" ก็ไม่ได้แปลว่าถึง) · ยืนยันด้วย peek เท่านั้น

---

# F6 ความพลาดของผมในรอบนี้ — verify ไฟล์ แต่ไม่ verify commit

ผมสั่งให้ worker เขียนไฟล์ **แล้ว commit** · ผมเห็นไฟล์ครบสองตัวจึง teardown
ผลจริง: `agents/probe-b` มี commit `eeaf8a1 probe-b report` · **`agents/probe-a` ไม่มี commit**
ผมฆ่า pane ตอนมันยังไม่ commit เสร็จ

เนื้อไฟล์ไม่หาย (ผมอ่านและ copy เก็บก่อนรื้อ) แต่ **หลักฐานฝั่ง worker หายไปหนึ่งด้าน**
รากเดียวกับ "delivered ≠ ได้รับ" แต่ย้ายไปอีกชั้น: **"ไฟล์โผล่ ≠ งานจบ"**
⇒ done-criteria ต้องเช็คสิ่งที่*ท้ายสุด*ของงาน (commit) ไม่ใช่สิ่งที่*ระหว่างทาง* (ไฟล์)

---

# การปิด (ทำครบ ตรวจแล้ว)

| ผิว | วิธี | ยืนยัน |
|---|---|---|
| tmux windows | `kill-window` ทั้งสอง | `list-windows` เหลือแต่ pane ของ lead ✅ |
| worktrees | `git worktree remove --force` (**branch เก็บไว้** — Nothing is Deleted) | `worktree list` เหลือ main ✅ |
| charter symlinks | ลบ `.maw/teams/*` + `.maw/` ที่สร้างขึ้นเอง | ไม่มีแล้ว ✅ |
| team store | **ไม่เคย `maw team load`** จึงไม่มีผิวที่ 2/3 ให้ปิด | `maw team list \| grep drift-fanout` = **0** ✅ |
| `~/.codex/config.toml` (เครื่องแชร์) | ถอด 2 entry ที่ผมเติม | `diff` กับ backup = **IDENTICAL** ✅ |

charter 2 ไฟล์ใน `ψ/teams/` เก็บไว้เป็นบันทึก (append-only) · หลักฐาน pane + รายงาน worker
อยู่ใน scratchpad ของเซสชันและอ้างอิงเต็มในเอกสารนี้
