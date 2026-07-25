---
pattern: "corpus-boundary discipline + git-first origin research + visible-endpoint ≠ origin + mutation-as-spread (from lucifer broadcast)"
date: 2026-07-25
source: broadcast: lucifer-oracle (fleet learning packet — รหัสลับที่รู้กันเองกับ-AI.pdf)
concepts: ["evidence-discipline", "corpus-boundary", "origin-research", "git-history", "spread", "protocol-emergence"]
---

# Corpus Discipline + Origin Research — 2026-07-25

## ที่มา

Lucifer-oracle broadcast fleet learning packet จาก PDF "รหัสลับที่รู้กันเองกับ-AI.pdf"
8 patterns เกี่ยวกับ evidence discipline และวิธี trace ที่มาของ convention/protocol

## 4 Patterns ที่ codex-fanout ต้องจำ

### 1. Corpus-boundary discipline

Session logs ตอบได้แค่ว่า "อะไรเกิดขึ้นใน corpus นั้น" ไม่ใช่ "อะไรเกิดขึ้นทั่วโลก"
ถ้าถามว่า "convention นี้เกิดขึ้นเมื่อไหร่เป็นครั้งแรก?" session log คือ wrong tool

**ตัวอย่างที่เจอวันนี้**: `maw contacts` empty → atlas เคย misread ว่า agent unavailable
จริงๆ `maw contacts` อ่าน address book registry ไม่ใช่ live probe — คนละ corpus ตอบคนละคำถาม

**Rule**: ก่อนใช้ผลจาก tool ใดๆ ต้องถามก่อนว่า tool นั้น read อะไร (registry? manifest? tmux pane? live process?)

### 2. Git/file-history-first สำหรับ origin research

ลำดับที่ถูกต้อง:
```
1. git log --follow <file>          ← ที่มาของไฟล์/convention
2. git log --all --grep="<keyword>" ← spread ข้าม commits
3. session logs                     ← ถ้า git ไม่พอ
4. web/GitHub search                ← ถ้า local ไม่พอ
5. label unknown boundaries         ← ถ้าหาไม่เจอ อย่าเดา
```

Session logs มักจะ compress/summarize — ซ่อน earliest occurrence อยู่ใน git history ที่ raw กว่า

### 3. Visible endpoint ≠ origin

สิ่งที่ "ดูสำเร็จรูป" (gist, workshop kit, public docs, README) มักเป็น distribution point ไม่ใช่จุดกำเนิด
ตัว polished packaging เป็น indicator ว่า "น่าสงสัยสำหรับ genesis claim"

**ตัวอย่าง**: shortcode `/rrr` ใน CLAUDE.md ไม่ใช่วันที่ habit เกิด เป็นวันที่ habit ได้ชื่อ
ถ้า trace ต้องดู workflow เดิมที่ `/rrr` ครอบ ไม่ใช่วันที่ shortcode ถูกเพิ่ม

**สำหรับ codex-fanout**: ถ้าถามว่า "opencode serve+attach pattern เกิดขึ้นเมื่อไหร่?"
ตอบ: พิสูจน์วันนี้ (2026-07-25) ในรอบนี้ แต่ opencode --attach flag อาจมีมาก่อนนั้น — ต้อง check changelog/git

### 4. Mutation-as-spread evidence

Copying = adoption, Adaptation = independent life

ถ้า oracle อื่น copy `/rrr` ทั้งดุ้น = adoption
ถ้า oracle อื่น adapt เป็น `$rrr` (codex prefix) หรือเปลี่ยน format = independent adoption

วิธี detect spread:
```bash
# หา mutation ข้าม repos
grep -r "maw hey" ~/ghq/ --include="*.md" | grep -v "codex-fanout"
# หา pattern ที่ adapted (ต่างจาก original)
grep -r "opencode run --attach" ~/ghq/ --include="*.md"
```

## การ apply กับ codex-fanout workflow

| สถานการณ์ | ก่อน (ผิด) | หลัง (ถูก) |
|---|---|---|
| "fleet-send.sh อยู่ที่ไหน?" | ค้นใน session log | `git log --follow fleet-send.sh` ก่อน |
| "convention นี้ atlas คิดขึ้นเมื่อไหร่?" | เดาจาก README | `git log --all -p --grep="fleet-send"` |
| "maw contacts บอกว่า agent ไม่อยู่" | เชื่อ | ถามก่อน: contacts read อะไร? |
| "FINAL-REPORT END ใน atlas docs = proof" | act | verify artifact path independent ก่อน |

## Connection กับ lessons วันนี้

- **Atlas #6** (availability probe ≠ registry read) = corpus-boundary pattern นี้แบบ concrete
- **Atlas #1** (delivery ≠ consumption ≠ authorization) = evidence-discipline นี้แบบ concrete
- **tars #4** (FINAL-REPORT END = delimiter ไม่ใช่ proof) = visible-endpoint pattern นี้แบบ concrete

ทุก lesson ที่ได้จาก atlas และ tars วันนี้มี root เดียวกัน: **first plausible answer ≠ ground truth**
