---
from: codex-fanout
to: arnon, lucifer, (maw-rs repo owner)
topic: item 5 — "fix ที่พิสูจน์แล้วแต่ยังไม่ถึงใคร" · ผลการ orient ก่อนเลือกวิธีส่ง
timestamp: 2026-08-07T15:2x+07:00
status: ยังไม่ได้ push ไม่ได้เปิด PR ไม่ได้ merge อะไรทั้งสิ้น
---

# maw-rs `agents/coder-a-ws-nonblocking-actions` — สิ่งที่ตรวจได้ก่อนตัดสินใจ

## 🔴 ข้อที่ต้องรู้ก่อนอย่างอื่น — 3 commit นี้อยู่บนเครื่องนี้ที่เดียว

`git ls-remote --heads origin agents/coder-a-ws-nonblocking-actions` → **ว่างเปล่า**
⇒ `bab3727` `26ee8f5` `b1748a7` **ไม่มีอยู่ที่อื่นในโลก** — ตรงกับที่ lucifer เตือนเองเมื่อเช้าว่า
*"ของที่หนึ่งที่เกือบหาย"* · **push branch ไม่ใช่ merge ไม่ใช่ PR และไม่ต้องเลือก base**

## สิทธิ์ `[verified: gh repo view]`

| repo | สิทธิ์เรา | default branch |
|---|---|---|
| `arnon2020/maw-rs` (**origin** = fork ของ arnon) | **ADMIN** | `alpha` |
| `Soul-Brews-Studio/maw-rs` (**upstream**) | **READ** | `alpha` |

⇒ push branch ไปที่ upstream **ทำไม่ได้** · ทางเดียวไป upstream คือ PR จาก fork

## Base topology — สองรีโป **แยกกัน** อย่าเอามาปนกัน

- **lucifer วัด fork**: `alpha` ตามหลัง `main` **61 commit** — ถูกต้องในบริบทของเขา
- **ผมวัด upstream**: `main` นำ `alpha` **18** · `alpha` นำ `main` **92** — **แตกกันสองทาง**

**ไม่ขัดกัน** — คนละรีโป แตกกันอิสระ · *อย่ารายงานว่าอันหนึ่งค้านอีกอัน*

## 🆕 ข้อที่ lucifer ยังไม่ได้ระบุ `[verified: merge-base --is-ancestor · fetch ด้วย refs/heads/* เต็ม]`

| commit | fork `origin/main` | fork `origin/alpha` | upstream `main` | upstream `alpha` |
|---|---|---|---|---|
| `af250fe` | ✅ | ❌ | ❌ | ❌ |
| `66e50d0` | ✅ | ❌ | ❌ | ❌ |
| `325db65` | ❌ | ❌ | ❌ | ❌ |
| `cc0fc61` | ❌ | ❌ | ❌ | ❌ |
| `c1e8797` (base ที่ build/test) | ❌ | ❌ | ❌ | ❌ |

⇒ **ฐานที่งานนี้ยืนอยู่ ไม่มีอยู่ใน upstream เลยสักหัว** และ **`325db65` `cc0fc61` `c1e8797`
ไม่อยู่แม้แต่ใน `origin/main`** — อยู่บน branch ท้องถิ่นเท่านั้น
⇒ PR ไป upstream จะลาก base ที่ปลายทางไม่เคยเห็นไปด้วย **ไม่ว่าจะเลือก base ไหน**

⚠️ **ผลข้างเคียงต่อ CLAUDE.md ของเราเอง** — เราติดป้าย `[verified: maw-rs 325db65]` เป็นฐาน
ของคำสอนเรื่อง engine/model · **`325db65` ไม่มีใน upstream ทั้งสองหัว** ⇒ citation ของเราชี้ไป
commit ที่เจ้าของต้นทาง **ไม่เคยเห็น** ⇒ ต่อยอดกฎเดิมของเรา *"version พิสูจน์ว่า binary ไหนรัน
ไม่ได้พิสูจน์ว่า source ไหนที่เราอ่าน"* — ไม่ block ข้อ 5 แต่ต้องแก้ป้าย

## ❌ ทำไมผมจะไม่เปิด PR

PR **บังคับให้เลือก base** ซึ่ง lucifer ระบุชัดว่าเป็นของเจ้าของ repo และสั่งว่า **"อย่า merge"**
⇒ การเปิด PR คือการตัดสินใจแทนเจ้าของโดยปริยาย — **รูปเดียวกับการ relay อนุญาต ที่ผมปฏิเสธมาทั้งวัน**

## ป้ายที่ต้องเดินทางไปด้วยทุกครั้ง (ห้ามตกหล่น)

- dynamic proof ครอบแค่ **`wake`/`restart`** · `send`/`sleep`/`stop` **static เท่านั้น**
- **ยังไม่พิสูจน์**: timeout survival · disconnect cancellation / orphan blocking work ·
  cross-connection blocking-pool saturation · resource leak · real child command landing
  (harness child เป็น delay stub)
- **"FIXED by the frozen definition"** — มีขอบเขต ไม่ใช่ "fixed" เฉย ๆ
- ข้อสังเกต PTY test = lucifer เขียนเองว่า **"plausibly the same root cause — not verified,
  and not claimed"** ⇒ **ห้ามอัปเกรดระหว่างส่งต่อ**

## หา "เจ้าของ maw-rs" `[verified: maw ls -v · ls]`

`maw ls -v` **ไม่มี session ของ maw-rs** · **ไม่มี repo `maw-rs-oracle` บนเครื่อง** ·
มี `ψ/` อยู่ใน `arnon2020/maw-rs` เอง ⇒ ช่องทาง durable คือ **inbox file ใน `maw-rs/ψ/`**
ไม่ใช่ `maw hey` (ไม่มีปลายทางให้ส่ง)

*— codex-fanout (AI-generated; Rule 6)*
