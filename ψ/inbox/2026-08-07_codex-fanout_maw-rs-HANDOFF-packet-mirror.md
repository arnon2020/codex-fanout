---
from: codex-fanout (relayed on behalf of lucifer-oracle, who did the work)
to: เจ้าของ maw-rs
topic: /ws actions ค้าง async loop — แก้แล้ว พิสูจน์แล้ว **ยังไม่ merge และจะไม่ merge**
timestamp: 2026-08-07
status: branch pushed to arnon2020/maw-rs · NO PR opened · upstream untouched
---

# `agents/coder-a-ws-nonblocking-actions` — พร้อมให้ตัดสิน ไม่ได้พร้อมให้ merge

**branch อยู่ที่**: `arnon2020/maw-rs` → `agents/coder-a-ws-nonblocking-actions` @ `b1748a7`
`[verified 2026-08-07: ls-remote origin หลัง push]` · **`upstream` (Soul-Brews-Studio) ไม่ถูกแตะ**
`[verified: ls-remote upstream ว่างเปล่า]`

| sha | อะไร |
|---|---|
| `bab3727` | RED test — `SlowWsActionEngine` fixture, ไม่มี production hunk |
| `26ee8f5` | fix — `spawn_blocking` offload + five-action classifier |
| `b1748a7` | isolate test session fixtures |

## บั๊ก

`send` `sleep` `stop` `wake` `restart` รัน subprocess **synchronously ใน async frame loop**
⇒ ตัวใดตัวหนึ่งค้าง = captures/previews/heartbeat ของ connection นั้นค้างหมด
นับแยกกันโดยสองคนที่ไม่ได้คุยกัน **ได้ 5 เท่ากัน**

วัดบน shipped `325db65`: heartbeat ช้าไป **13.597s** หลัง restart reply 13.500s ·
spawn ช้า → timeout **32.636s** แล้ว socket close **1005**
⇒ **ผู้ใช้กด restart agent แล้ว socket ที่กำลังดูอยู่ตาย**

## การแก้ และสิ่งที่มัน**จงใจไม่ทำ**

offload ผ่าน `tokio::task::spawn_blocking` · heartbeat/refresh/capture/preview ยัง selectable ·
`socket.recv` **ถูก gate ระหว่าง action in-flight** เพื่อรักษาลำดับ reply ต่อ connection
แทนที่จะแลก stall กับ reply ที่สลับลำดับ

## หลักฐาน — เกณฑ์ถูก **freeze ด้วย sha256 ก่อนแพตช์มีอยู่**

```
RED control at bab3727   rc101 — woke arrived before heartbeat
same test at b1748a7     rc0
live wake     rc0 FIXED  max pending gap 2.114s (budget 3.5) · heartbeat 10.110s BEFORE reply 12.234s
live restart  rc0 FIXED  max pending gap 2.103s · heartbeat 10.095s BEFORE reply 14.619s
suite         rc0 136/136 รวม PTY test · clippy 0 · fmt 0
```

**"FIXED by the frozen definition"** — **มีขอบเขต ไม่ใช่ "fixed" เฉย ๆ**

## ⚠️ Coverage gap — verifier พูดเองเกี่ยวกับ PASS ของตัวเอง (ห้ามตัดออก)

- timing harness พิสูจน์ **dynamically แค่ `wake`/`restart`** · `send`/`sleep`/`stop`
  **static เท่านั้น** ⇒ regression เฉพาะ action ที่ทำให้ตัวใดตัวหนึ่งกลับไป synchronous **จับไม่ได้**
- **ยังไม่พิสูจน์**: timeout survival · disconnect cancellation / orphan blocking work ·
  cross-connection blocking-pool saturation · resource leak · real child command landing
  (harness child เป็น **delay stub**)
- ข้อสังเกต `servecore_ws_pty_attaches_and_bridges_binary_frames` ที่เคยตกทั้งสัปดาห์แล้วตอนนี้ผ่าน:
  lucifer เขียนเองว่า **"plausibly the same root cause — not verified, and not claimed"**
  ⇒ **ห้ามอัปเกรดเป็นข้ออ้าง**

## 🔴 Base topology — เรื่องที่ต้องตัดสินก่อน และ**เป็นของคุณ ไม่ใช่ของเรา**

build/test บน `c1e8797` · `[verified: merge-base --is-ancestor · fetch refs/heads/* เต็ม]`

| commit | fork `origin/main` | fork `origin/alpha` | upstream `main` | upstream `alpha` |
|---|---|---|---|---|
| `af250fe` | ✅ | ❌ | ❌ | ❌ |
| `66e50d0` | ✅ | ❌ | ❌ | ❌ |
| `325db65` | ❌ | ❌ | ❌ | ❌ |
| `cc0fc61` | ❌ | ❌ | ❌ | ❌ |
| `c1e8797` (base) | ❌ | ❌ | ❌ | ❌ |

⇒ **ฐานที่งานนี้ยืนอยู่ ไม่มีใน upstream เลยสักหัว** ⇒ PR ไป upstream จะลาก base
ที่ปลายทางไม่เคยเห็นไปด้วย **ไม่ว่าเลือก base ไหน**

**สองรีโปแตกกันคนละแบบ อย่าปน**: fork → `alpha` ตามหลัง `main` **61** ·
upstream → `main` นำ `alpha` **18** และ `alpha` นำ `main` **92**

`AGENTS.md` บังคับ base เป็น `alpha` ซึ่งเป็น default branch ด้วย — **PR ตาม base ที่บังคับ
จะแบก 61 commit ที่ไม่เกี่ยวและ diff ใหญ่กว่าการเปลี่ยนแปลงจริงสองเท่าตัวเลข**

## สิ่งที่เรา**ไม่ทำ** และเหตุผล

**ไม่เปิด PR · ไม่ rebase · ไม่ cherry-pick · ไม่ merge** — PR บังคับให้เลือก base
ซึ่งเป็นการตัดสินใจแทนคุณโดยปริยาย · เรา push branch อย่างเดียวเพราะ **3 commit นี้เคยอยู่
บนเครื่องเดียวในโลก** และนั่นเป็นความเสี่ยงที่แยกจากคำถาม base ได้

*— codex-fanout 🛰️ relay · งานเป็นของ lucifer-oracle 🕯️ (AI-generated; Rule 6)*
