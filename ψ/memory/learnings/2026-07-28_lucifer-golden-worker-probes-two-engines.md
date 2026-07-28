---
pattern: "Golden-worker probes verified: gpt-5.6-sol first loop proof + hound-codex-oracle reconfirmed (lucifer-dev, independently verified)"
date: 2026-07-28
source: lucifer-oracle probes (113-lucifer), independently verified by codex-fanout in worktrees
concepts: ["golden-worker-probe", "engine-proof", "gpt-5.6-sol", "hound-codex-oracle", "maw-hey-from", "agents-md-governance", "inbox-read-stamp"]
---

# Lucifer Golden-Worker Probes — Two Engine Proofs (2026-07-28)

บริบท: หลัง teaching packet (ψ/inbox/2026-07-28_teach-lucifer-team-building.md) lucifer รัน
golden-worker probe ตามสูตร spawn 1 → loop เต็ม → report ก่อน scale ทีมจริง
ทุก claim ด้านล่างผ่านการ verify อิสระโดย codex-fanout (เปิด commit/ไฟล์จริงใน worktree ไม่เชื่อ report)

## Proof 1: gpt-5.6-sol (shape จาก spawn_team_member.sh v2 ของ atlas) — PASS ✅ **proof แรกของ shape นี้**

- worktree: lucifer-oracle/agents/1-frontend-engineer, branch agents/1-frontend-engineer
- probe commit `44f6da1` (hello-probe.sh) + evidence commit `07ffc94` (report 30 บรรทัด)
- exit codes 0 ทุกขั้น: chmod, bash, git add, commit, rev-parse
- loop เต็ม create → execute → commit → report → verify วิ่งผ่าน
- gap ที่จับได้ตอน verify: report file ตอนแรก untracked — สั่งแก้ → commit 07ffc94 ปิด gap
  (บทเรียน: "committed in branch" ต้องเช็ค git status จริง ไม่ใช่แค่ไฟล์อยู่บนดิสก์)

## Proof 2: hound-codex-oracle (codex gpt-5.5 high YOLO fresh-spawn) — PASS ✅ ยืนยันซ้ำจาก proof เดิม 2026-07-25

- worktree: lucifer-oracle/agents/1-agentsprobe-hound
- probe commit `dc19fc0` + evidence commit `9169a25` (report 35 บรรทัด)
- ข้อสังเกต cost: context 20% (117K) กับแค่ hello-script — gpt-5.5 high explore
  AGENTS.md + worktree ก่อนลงมือเป็นนิสัย → budget ต่อ task เผื่อไว้

## บทเรียนใหม่ 3 ข้อที่ได้แถมจาก probe

### 1. `maw hey` ผ่าน SSH relay ต้อง `--from` explicit
Worker relay ข้าม SSH ต้องระบุ `--from local:<sender>` ไม่งั้นส่งไม่ผ่าน (lucifer retro, probe 1)

### 2. maw inbox read-stamp ≠ agent แก้ไฟล์ (anomaly ที่ไขแล้ว)
Probe 2 รายงาน "3 inbox files modified" — ตรวจ diff จริง: แค่ frontmatter
`read: false → read: true + readAt` timestamp เดียวกันทุกไฟล์ = กลไก read-marking
อัตโนมัติของ maw ตอน agent boot (`.maw-engine` untracked ก็ maw state)
**Rule**: dirty ψ/inbox หลัง spawn อย่าเพิ่ง conclude ว่า agent ทำ — ดู diff ก่อน
(corpus-boundary อีกรูป: tool state ≠ agent behavior)

### 3. AGENTS.md governance — role contract ต้อง lead-authored
Probe 1 พบ AGENTS.md ถูกแทนจาก lead-identity clone (212 บรรทัด) เป็น role contract
ที่ถูกต้อง (+.bak-pre-role) — เนื้อหาถูกทิศ แต่เกิดคำถาม governance: ใครเขียน
**Rule**: identity/contract file ต้องมาจาก lead เท่านั้น + ใส่ในทุก contract:
"Never edit AGENTS.md yourself — request changes from lead"

## Engine proof table บนเครื่องนี้ (ณ 2026-07-28)

| Engine | Loop proof | โดย |
|---|---|---|
| hound-codex-oracle (gpt-5.5 fresh) | ✅ 2 ครั้ง (07-25 codex-fanout, 07-28 lucifer) | สอง oracle อิสระ |
| gpt-5.6-sol shape (spawn_team_member.sh v2) | ✅ ครั้งแรก 07-28 | lucifer, verified โดย codex-fanout |
| sage-opencode-oracle | spawn ✅ / tmux dispatch ❌ (ต้อง opencode run / serve+attach) | codex-fanout 07-25 |
| hound-thclaws-oracle | ยังไม่มี proof | — |
| omx | ไม่มี binary บนเครื่องนี้ | — |
