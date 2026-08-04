---
pattern: ฟิลด์ใน config ที่ parse ผ่านโดยไม่ error ไม่ได้แปลว่ามีโค้ดอ่านมันไปใช้ — ก่อนพึ่งฟิลด์ไหน ให้ grep หา "จุดที่อ่านไปใช้" ไม่ใช่ "จุดที่ประกาศ"
date: 2026-08-04
source: "rrr: codex-fanout"
concepts: [maw, charter, agent-team, verification, schema-vs-behavior, dead-reference]
---

# ฟิลด์ที่ parse ผ่าน ≠ ฟิลด์ที่ถูกใช้

`[verified: source-read maw-rs 284ae4d (commit เดียวกับ binary ที่รัน) + ran เมื่อรอบก่อน]`
`valid-if:` `maw --version` ยังเป็น `284ae4d` และ
`python3 -c "import json,os;print(json.load(open(os.path.expanduser('~/.config/maw/maw.config.json'))).get('wake'))"` = `None`

## เหตุ

`ψ/teams/*.yaml` ทุกไฟล์ของเรามี `prompt:` ต่อ member — เขียนสัญญาการทำงานไว้ครบ
("WAIT for task", "own the loop", "never touch lead's checkout", "PR → alpha only")
ก๊อปต่อกันมาตั้งแต่ commit แรก `8879e4c` (2026-07-23) ผ่าน template ผ่าน charter เก่า
**ไม่มีใครเคยตรวจว่ามันเดินทางไปถึง agent ไหม**

มันไม่ถึง:

| กริยา | เกิดอะไร | citation |
|---|---|---|
| `team up` | argv = `wake <identity> --no-attach --session <s> -e <engine> [--repo-path <wt>]` — **ไม่มี `--prompt`** · `grep -n prompt` ในไฟล์นี้ + helpers = **0** | `team_up_apply.rs:146-155` |
| `team spawn --prompt` | เขียนไฟล์ `<vault>/<role>-spawn-prompt.md` (0600) แล้ว spawn ด้วย invocation ที่ไม่มี `--prompt` ⇒ **ไฟล์ถูกเขียน ไม่มีใครอ่าน** | `team_spawn.rs:93-95` |
| `team spawn-from` | เป็นที่เดียวที่ประกอบ `## Team goal` + `## Role prompt` แล้วส่งเข้าทางที่ตันเหมือนกัน | `team_spawn.rs:37,174-179` |
| `wake --prompt` | **ทางเดียวที่ส่งจริง** — ต่อท้ายเป็น positional arg ของ engine ⇒ เป็น **ข้อความ user แรก ไม่ใช่ system prompt** | `wake_engine_command.rs:158` |

schema รับฟิลด์ครบ (`TeamCharterMember122` = role/name/model/cwd/engine/target/**prompt**/
worktree/worktree_opt_out/branch · `team_core.rs:86-97`) ⇒ **parse สำเร็จ ไม่ error
preflight เขียว exit 0** — ทุกสัญญาณบอกว่าสำเร็จ

## แล้ว identity จริงมาจากไหน

`grep -rn "system-prompt\|system_prompt\|append_system" --include=*.rs crates/` = **0 hits**
· ไม่มี `commands.*` ตัวไหนใน `~/.config/maw/maw.config.json` ใส่ `--system-prompt-file`
· `"wake": null` ⇒ ไม่มี prompt กลางถูกยัดให้ทุก worker

⇒ **maw ไม่ตั้ง system prompt ให้ใครเลย** identity = อะไรก็ตามที่ engine โหลดเองที่ cwd:

- **claude** → `CLAUDE.md` ที่ราก worktree ซึ่ง **tracked ใน git** ⇒ worker ที่เราตั้งใจให้เป็น coder
  ตื่นมาเป็น *"Codex Fanout Oracle"* พร้อม Golden Rules + Escalation ครบ `[inferred: source + git ls-files]`
- **codex** → `AGENTS.md` ที่ cwd — **repo นี้ไม่มี tracked** ⇒ ได้ทั้ง role ทั้ง persona = ศูนย์
- **opencode / thclaws** → ⬜ ยังไม่ตรวจ
- 🔴 engine key ที่มี `--continue` / `resume --last` (`codex-fanout-oracle`, `ajfon-oracle`,
  `atlas-codex-oracle`) ⇒ ปลุกมา**ทับ conversation เดิม** — role ที่ถือคือของงานก่อนหน้า

## ผลที่ตามมาที่ต้องระวัง

`worktree isolation ไม่ใช่กำแพง` (verified 2026-08-03: probe-a อ่าน `../probe-b/` ได้เต็มไฟล์)
และเราสรุปกันไว้ว่า **"ประโยคใน prompt คือ guard เดียวที่มี"**
⇒ ถ้า prompt ไม่เคยถึง worker **ตอนนี้ไม่มี guard เลย** ต้องย้ายประโยคพวกนั้นไป `BRIEF.md`
ทุกครั้งที่ dispatch — และแม้แต่ตอนนั้นมันก็เป็น *user turn* ไม่ใช่ *system prompt*
agent เลือกเชื่อ `CLAUDE.md` ทับได้

## ที่มาของความรู้ที่ใช้เขียน charter — เน่าไปแล้ว 3 จุด

charter ทุกไฟล์ commit ใต้ชื่อมนุษย์ แต่ **110/116 commit ของ repo มี `Co-Authored-By: Claude`**
⇒ oracle เขียน มนุษย์ commit · ความรู้มาจาก 4 ทาง: template ใน skill · ก๊อป charter เก่า ·
ของที่รันเองแล้วเห็น · ถาม peer oracle — **สองทางแรกใช้บ่อยสุดและตายแล้ว**:

1. `codex-lead/SKILL.md` สั่ง *"Copy a known-good charter (e.g. `volt-codex2.yaml`)"* —
   `find ~ -name volt-codex2.yaml` **ไม่เจอทั้งเครื่อง**
2. template ชี้ engine command ไป `$HOME/.claude/skills/oracle-team/scripts/codex-setup.ts` —
   **ไม่มีไฟล์นั้น** (มีแต่สำเนา project-local) ⇒ ก๊อปไปใช้ตรง ๆ engine บูตไม่ขึ้น
3. **SKILL.md ขัดกันเองในไฟล์เดียว** — §1 ว่าต้องมี `defaults: {worktree: true}` ·
   §"v2 contract" ว่า *"NO defaults.worktree block"*

## กฎที่เอาไปใช้ต่อได้

1. **ก่อนพึ่งฟิลด์ไหนในสัญญา ให้ `grep` หาจุดที่ *อ่านมันไปใช้* ไม่ใช่จุดที่ *ประกาศ* มัน** —
   schema กับ behavior เป็นคนละที่ ไม่มีอะไรบังคับให้ตรงกัน
2. **จะอ้าง "ทั้ง repo ไม่มี X" ต้อง grep แบบกวาดที่สำเร็จจริง** — ถ้า grep ล้มเพราะ path ผิด
   (`--include=*.rs src/` บน repo ที่โค้ดอยู่ใต้ `crates/`) **ความล้มนั้นคือหลักฐานว่ายังไม่ได้ตรวจ
   ไม่ใช่หลักฐานว่าไม่มี** — เซสชันนี้ที่ปรึกษาเป็นคนจับ ไม่ใช่ผม
3. **เอกสารเครื่องมือต้องระบุว่าเป็นของ implementation ไหน** — `~/.claude/skills/maw/SKILL.md`
   อธิบาย prompt delivery ต่อ engine ไว้ละเอียด (system-prompt-file / AGENTS.md) แต่นั่นคือ
   **maw-js** ส่วนที่รันจริงคือ **maw-rs** ที่ไม่ทำสักอย่าง ⇒ เอกสารที่ถูกสำหรับของที่ไม่ได้รัน
   อันตรายกว่าไม่มีเอกสาร
4. **template ที่บอกให้ "ก๊อปตัวอย่างที่ใช้ได้" ต้องมี `valid-if:` ของตัวอย่างนั้นเอง**

เชื่อมกับ [[verify-the-check]] · [[teaching-ledger]] · กฎ ⏳ `valid-if:` ใน CLAUDE.md
