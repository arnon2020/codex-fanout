---
pattern: "opencode ≠ codex input model: tmux text injection bypasses AI, hits shell eval hook — ใช้ opencode run หรือ ACP แทน"
date: 2026-07-25
source: rrr: codex-fanout
concepts: ["opencode", "dispatch", "input-model", "maw-hey", "engine-difference", "tmux"]
---

# opencode Dispatch Discovery — 2026-07-25

## สถานการณ์

ทดสอบ opencode (sage-opencode-oracle / GLM 5.2) เป็น coder ใน maw team
พยายาม dispatch task ด้วย `maw hey` + `maw send-text` ที่ใช้กับ codex ได้ผล
ผล: `opencode: eval: line 5: syntax error` ทุกครั้ง, GLM 5.2 ไม่รับ task

## Root Cause

opencode มี eval hook ที่ intercept text ก่อนถึง AI input buffer:
- text ที่ส่งผ่าน tmux → shell eval → fail ถ้ามี shell special chars
- แม้ไม่มี special chars → `[local:codex-fanout]` prefix ของ maw เองก็ไม่ใช่ valid command
- codex TUI รับ raw keystrokes → AI prompt (mechanism ต่างกันสิ้นเชิง)

## Dispatch Options สำหรับ opencode

1. **`opencode run "<task>"`** — bundle task กับ contract ตอน spawn (น่าจะง่ายสุด)
2. **ACP server** (`opencode acp`) — Agent Client Protocol สำหรับ programmatic delivery
3. **Headless mode** (`opencode serve` + `opencode attach`) — server mode แล้ว attach
4. **Inbox file polling** — coder checks `ψ/inbox/` แทนรอ tmux input

## บทเรียน

1. **"New engine" = read manual first**: อย่า assume shared playbook — ทุก engine มี input model ของตัวเอง
2. **Error ครั้งที่ 1 บอก root cause**: `syntax error near unexpected token` = structural, ไม่ใช่ content — retry ไม่ใช่ solution
3. **Charter naming = team identity**: ถ้า session ชื่อ `codex-fanout` coder ชื่อ `codex-fanout-agentsopencode-1` → confusing เมื่อ engine เป็น opencode

## ยืนยัน

- opencode coder spawn: ✅ สำเร็จ
- opencode coder readiness report: ✅ ส่งกลับมาถูกต้อง ("online — agentsopencode-1 booted")
- task delivery via tmux: ❌ ล้มเหลวทุก mechanism
- task delivery via opencode run/ACP: 🔲 ยังไม่ทดสอบ — session ถัดไป
