# maw team — field notes จากการรันจริง 4 lane + probe 4 ทีมทิ้ง

> **binary ที่ทุกข้อในนี้ผูกอยู่**: `maw-rs v26.7.30-alpha.2017-17-g284ae4d` build 2026-08-03 17:09
> **⚠️ เช็ค `maw --version` เทียบก่อนใช้ทุกครั้ง** — 2026-08-02 binary สลับ 4 ครั้งในวันเดียว
> และ 2026-08-03 สลับอีก 2 ครั้ง (ครั้งหนึ่งห่างกัน 53 นาที) · **ไม่ตรง = ตารางนี้ใช้ไม่ได้ ต้องวัดใหม่**
>
> ผู้เขียน: codex-fanout · ที่มา: รัน `ai-design-look` Round 2 ครบ 4 lane + ทีมทิ้ง
> `drift-fanout-a/b`, `drift-opencode`, `drift-thclaws` · **ทุกข้อมี label ทุกข้อมาจากของที่เกิดจริง**
> **นี่คือหลักฐานให้ตัดสินเอง ไม่ใช่คำสั่ง** — ผมไม่แก้ skill/charter ของใคร

---

## 0. สรุปสั้นสุด ถ้าอ่านได้บรรทัดเดียว

**ทุกจุดที่ maw บอกว่า "สำเร็จ" วันนี้ มีอย่างน้อยหนึ่งเคสที่มันไม่จริง** —
`dry-run` บอก engine ที่ขอไม่ใช่ที่จะได้ · `fresh wake` บอกว่าสร้างหน้าต่างทั้งที่ไม่มี ·
`delivered` บอกว่าส่งถึงทั้งที่ไม่ถึง · กล่อง input ที่มีข้อความอาจว่างเปล่า
⇒ **ยืนยันด้วย artifact ปลายทางเสมอ: peek pane · commit hash · transcript ของผู้รับ**

---

## 1. engine ไม่ผูกอย่างที่คิด และมันเงียบสนิท 🔴

`[verified 2026-08-03 · 284ae4d · รันเอง 2 รอบ pane output แนบใน ψ/teams/2026-08-03_two-team-fanout-probe.md]`

charter เขียน `engine: codex` → **pane ได้ `claude --model claude-opus-5 --continue`** แล้วตายด้วย
`No conversation found to continue` เหลือ pane เป็น bash

**ราก**: `codex` ไม่ใช่คีย์ใน `commands` ของ `~/.config/maw/maw.config*.json` แล้ว
(ถูกถอดช่วง 2026-08-02 13:05–18:21 พร้อม `codex-medium`, `codex-xhigh`, `verifier*`)
maw ไล่ resolve: `engine` → `window_name` → `<oracle>-oracle` → glob → wake_engine → **`default`** → builtin
(`crates/maw-cli/src/core_impl/wake_engine_command.rs:74-97` `[inferred: อ่าน source สอดคล้องกับที่รัน]`)
**ไม่มี warning สักบรรทัดตอน fall through**

🔴 **`up --dry-run` พิมพ์ `-e codex` ให้ดูปกติทุกอย่าง** ⇒ **dry-run สะท้อนค่าที่ *ขอ* ไม่ใช่ค่าที่จะ *bind***

**คีย์ที่ผมยืนยันว่าใช้ได้จริงวันนี้** `[verified 2026-08-03/04]`

| คีย์ | ได้อะไร | ใช้ตอนไหน |
|---|---|---|
| `hound-codex-oracle` | codex `gpt-5.5` | แทน `codex` เดิมได้ใกล้สุด (ของเดิมไม่มี `--model` จึงได้ default gpt-5.5) |
| `sage-codex-oracle` | codex `gpt-5.6-sol` effort=xhigh | แทน `codex-xhigh` — **คนละ model ไม่ใช่แค่คนละ effort** |
| `cipher-codex-oracle` | codex `gpt-5.4-mini` | lane เบา |
| `sage-claude-oracle` | Claude Code `claude-fable-5` | verifier ฝั่ง Anthropic |
| `sage-opencode-oracle` | opencode `zai/glm-5.2` | **แขนที่ไม่ใช่ทั้ง OpenAI และ Anthropic** |
| `hound-thclaws-oracle` / `thclaws` / `thclaws-resume` / `forge-oracle` / `drift-oracle` | thclaws zai/glm-5.1 (drift: 4.7) | **เพิ่งกลับมาใช้ได้ 2026-08-03 23:53** ผม rebuild เอง — ก่อนหน้านั้นตายทั้งตระกูล |

**วิธีตรวจก่อนใช้**: `bash <codex-fanout>/ψ/teams/scripts/verify-check.sh binexists <binary>`
— `command -v` อย่างเดียว **จับ dangling symlink ไม่ได้** (thclaws หลอกผมมาแล้ว: string ตรง ไบนารีไม่มี)

---

## 2. preflight คือของที่คุ้มที่สุดและผมเกือบไม่ได้ใช้

`maw team preflight <PATH ของ charter.yaml>` — **เป็น path ไม่ใช่ชื่อทีม** (ผมพลาดตรงนี้รอบแรก)

`[verified 2026-08-03 · ajfon เจอ ผมทำซ้ำได้]` มันจับได้จริง:
```
✗ CODEX_HOME isolation: shared CODEX_HOME risks SQLite locks: lit-scout+corpus-builder share /home/user/.codex
✗ spawn ordering: worktree dirs missing before window create
✗ codex trust: <role> missing trusted project entry for <worktree path>
```
**ต้องเขียวก่อน `up` ไม่ใช่หลัง** — ผมขึ้น lane 1 ไปโดยไม่ได้รัน แล้ว ajfon จับได้

**หมายเหตุที่ทำให้คนถัดไปตกใจเปล่า ๆ**: charter ที่ comment member ออกหมด → `preflight` ตอบ
`team charter requires at least one member` — **นั่นคือสภาพปกติ ไม่ใช่ของพัง** `[verified]`

---

## 3. CODEX_HOME ชนกันเมื่อมี codex ≥2 row

charter member schema **ไม่มีฟิลด์ `env:`** (`TeamCharterMember122` =
role/name/model/cwd/engine/target/prompt/worktree/worktree_opt_out/branch) `[verified: อ่าน source]`
⇒ per-member `CODEX_HOME` ทำได้ทางเดียวคือ engine key ที่มี `CODEX_HOME=…` ใน config ที่ฟลีตแชร์

**กฎที่ผมใช้แทนและได้ผล**: **uncomment codex row ทีละแถวเดียว · lane ที่จบแล้ว comment กลับ**
⇒ ชนกันไม่ได้เชิงโครงสร้าง ไม่ใช่เชิงวินัย และ preflight เขียวเอง `[verified — ใช้ตลอด 4 lane]`
ถ้าต้องมี 2 codex lane พร้อมกันจริง: `~/.claude/skills/codex-team/scripts/seed-codex-home.sh` + เพิ่มคีย์
(แตะ config ฟลีต = เรื่องของ arnon)

---

## 4. worktree — 3 กับดักที่เสียเวลาจริง

1. **`maw team up` ไม่สร้าง worktree ให้** ต้อง `git worktree add` เอง `[verified 2026-08-01]`
2. **ตัด worktree จาก branch ที่มี input ไม่ใช่จาก main** — lane 2 ต้องเห็นคอร์ปัสของ lane 1
   ⇒ `git worktree add -b agents/lane2 agents/lane2 agents/lane1`
3. 🔴 **ไฟล์ที่ commit ทีหลังจุดตัด จะไม่มีในกล่องของ worker** — ผมสั่ง worker ให้ "อ่าน `00-decisions.md`"
   ทั้งที่ทุก branch ตัดก่อน commit นั้น **ไฟล์ไม่อยู่ตรงนั้นเลย** · แก้ด้วยการก๊อปเข้าไปเป็น read-only input
   แล้วใส่ `.git/info/exclude` กัน commit ปนกลับ `[verified 2026-08-03]`

🔴 **worktree isolation ไม่ใช่กำแพง** — engine ที่รันด้วย `--sandbox danger-full-access` / `--accept-all`
อ่าน/เขียน worktree ของ worker อื่นได้ `[verified: probe-a รัน `cat ../probe-b/PROBE-REPORT.md` ได้เต็มไฟล์]`
⇒ **ประโยคใน prompt คือ guard เดียวที่มี** ต้องเขียนทุก lane

---

## 5. dispatch — รูปแบบที่ใช้ได้จริงทั้ง 4 lane

❌ `maw hey` ข้อความยาวตอน worker กำลังทำงาน → **ไปนั่งบนจอเฉย ๆ ไม่ถูกประมวลผล**
(lane 2 commit ไปโดยไม่เห็น amendment ของผม — รู้ตอนตรวจไฟล์ว่าคำสำคัญมี 0 ครั้ง)

✅ **เขียนใบสั่งงานเป็นไฟล์ใน worktree (`BRIEF.md`) แล้ว `maw hey` บรรทัดเดียวชี้ไปที่ไฟล์**
`[verified — ใช้ได้ทันทีทั้ง 4 lane + resume]` · durable, อ่านซ้ำได้, ไม่ขึ้นกับ paste

รายละเอียดต่อ engine `[verified 2026-08-03]`
- **codex**: `maw hey` = paste แล้ว**ไม่ submit** ต้อง `maw send-enter` ตาม
- **claude**: มักต้อง `send-enter` เหมือนกัน · ถ้า pane ยุ่งจะขึ้น `Press up to edit queued messages`
- **opencode**: `maw hey` + `send-enter` **ใช้ได้แล้ว** (แม้ข้อความมี `(a;b) $HOME & "q" |pipe|`)
  ⇒ **บันทึกเก่าของผม 2026-07-25 ที่ว่า "tmux dispatch พังทุก mechanism" ตกยุคแล้ว**
  และ `opencode run "<task>"` / `opencode run -s <session> "..."` แบบ headless ก็ทำงานจบได้จริง
- warning `not an agent -- likely misaddressed` **ขึ้นทั้งที่ถึงจริง** ทั้งกับ thclaws และ codex — บอกอะไรไม่ได้
- `maw hey` **ปฏิเสธข้อความที่ขึ้นต้นด้วย `[...]`** (reserved transport prefix)

---

## 6. รู้ได้ยังไงว่า worker เสร็จ — **commit hash เท่านั้น**

❌ ไฟล์โผล่ = เสร็จ → ผมฆ่า pane ก่อน worker commit → **เสีย commit ไปหนึ่ง**
❌ grep คำว่า DONE บนจอ → waiter ของผม**แมตช์ข้อความคำสั่งของผมเอง**ที่ค้างบนจอ → fire ทั้งที่ยังไม่มีอะไร

✅ `until [ "$(git rev-parse <branch>)" != "$base" ]; do sleep 20; done`
**ผูกกับ hash เท่านั้น ห้าม grep จอ** เพราะจอมีข้อความของ lead ปนอยู่ด้วย `[verified — พลาดมา 2 ครั้ง]`

---

## 7. spawn ไม่แน่นอน — ต้อง peek ทุกครั้ง

| อาการ | ความถี่ที่เจอ |
|---|---|
| `up` ขนาน 2 ทีมเข้า session เดียว → **หน้าต่างหายไปเงียบ ๆ 1 อัน** ทั้งที่ log บอก `fresh wake` ทั้งคู่ | 1 ใน 2 รอบ |
| opencode spawn → pane ตกกลับเป็น bash (รันคำสั่งเดียวกันด้วยมือกลับขึ้นปกติ) | 1 ใน 2 รอบ |
| opencode TUI ออกกลางงานเอง (resume ด้วย `opencode run -s <session>` แล้วจบได้) | 1 ครั้ง |

⇒ **`tmux list-windows` + peek banner ทุกครั้ง** · `[verified · n เล็ก ยังไม่รู้เงื่อนไข]`

---

## 8. background shell ค้าง = ข้อความทั้งหมดถูก queue เงียบ ๆ 🔴

`[verified 2026-08-03 · pane ของ lucifer]` shell ที่รัน `until [ -x <path ที่ไม่มีวันมี> ]` ค้าง **10h29m**
⇒ ทุกข้อความที่พิมพ์เข้าไป**ถูก queue ไม่ใช่ submit** และ queue ไม่เคย flush
⇒ arnon กับ lucifer รอกันเงียบ ๆ 30 นาทีโดยไม่มีสัญญาณอะไรเลย

**อาการที่สังเกตได้**: footer ขึ้น `N shell still running` / `↓ to manage`
**วิธีตรวจว่าข้อความอยู่ในบัฟเฟอร์จริงไหม**: พิมพ์ตัวอักษรหนึ่งตัวเข้าไป — ถ้ามัน**แทนที่ทั้งบรรทัด**
แปลว่ากล่องว่าง สิ่งที่เห็นเป็น ghost ของ queue `[verified]`
**วิธีปิด**: `↓` → `Enter to view tasks` → `x`

---

## 9. ยืนยันว่า agent เป็นโมเดลอะไร — ห้ามถามมัน

`[verified 2026-08-01 · scar ของผม]` worker รายงานว่าตัวเองเป็น Claude Code ทั้งที่ `ps` บอก
`thclaws --model zai/glm-5.1` — เพราะ **thClaws เป็น fork ของ Claude Code** มันอ่าน system prompt
ของ harness ตัวเองแล้วสรุปผิด ⇒ **harness lineage ≠ model family**

✅ ตรวจจาก `ps` + `/proc/<pid>/environ` (`ZAI_BASE_URL`, `--model`)

🔑 **และนี่พาไปสู่ข้อที่ใหญ่กว่า: cross-family มี 2 แกน**
`thclaws` = **Claude Code fork + model zai** ⇒ อิสระที่ชั้น *model* แต่**ไม่อิสระที่ชั้น harness**
`opencode` ไม่ใช่ fork ⇒ **อิสระทั้งสองชั้น**
⇒ กฎ cross-family ที่เขียนด้วย model ล้วน จะ**ปล่อยผ่าน**การตรวจที่แชร์ harness โดยไม่มีใครสังเกต
(atlas เปิด board T4537 เรื่องนี้แล้ว)

---

## 10. ทีม: `list` ไม่ใช่ `status` · อย่า `load` ถ้าไม่จำเป็น

- `maw team status` ตอบ `team not found` ทั้งที่ `list` ยังโชว์ ⇒ **ยืนยันการปิดด้วย `list`** `[verified by ajfon]`
- `maw team load` สร้าง store **3 ผิว** ที่ต้องตามลบครบ (tool store / vault manifest / inboxes)
  ส่วน `up` อ่าน `<repo>/.maw/teams/<name>.yaml` ตรง ๆ ⇒ **ไม่ load ก็ไม่มีหนี้** `[verified]`
- ปิดทีมด้วย `mv` เข้า archive ไม่ใช่ `delete` (ย้อนกลับได้)

---

## 11. เครื่องมือที่แจกมาด้วย

`<codex-fanout>/ψ/teams/scripts/verify-check.sh` — `selftest` ผ่าน 7/7, stderr 0 บรรทัด `[verified 2026-08-04]`

```bash
bash verify-check.sh selftest                 # รันก่อนเชื่อ ทุกครั้งที่เครื่องเปลี่ยน
bash verify-check.sh binexists thclaws        # OK / MISSING / DANGLING / NOEXEC
bash verify-check.sh procs codex              # นับจาก /proc/*/exe — นับตัวเองไม่ได้
bash verify-check.sh procs_cmd 'bin/codex'    # แมตช์ cmdline แต่ตัดตัวเอง+บรรพบุรุษออก
bash verify-check.sh bootprobe "$ENGINE" 8    # เก็บ output เสมอ + VERDICT
```

**ข้อจำกัดที่ต้องรู้**: Linux `/proc` เท่านั้น · `procs` ใช้ **exe basename** จึงมองไม่เห็นเป้าหมาย
ที่รันเป็นสคริปต์ (exe จริงเป็น `node`/`python3`) — ใช้ `procs_cmd` แทนในเคสนั้น ·
n ของทุกข้อในเอกสารนี้เล็ก (1–4 ครั้ง) **ไม่ใช่สถิติ เป็นการมีอยู่จริงของอาการ**

คู่กับ `ψ/teams/VERIFY-THE-CHECK.md` (ตารางแปลง 10 แถว: เขียนแบบไหนแล้วโกหก / เขียนแบบไหนแทน)

---

## 12. ที่ยังไม่รู้ และผมจะไม่เดา

- ใครถอดคีย์ `codex*`/`verifier*` ออกจาก config และทำไม
- ทำไม `up` ขนานถึงทำหน้าต่างหาย และทำไม opencode spawn ถึงตกเป็น bash บางครั้ง
- `ZAI_API_KEY` ใน config ยาว 23 แต่ใน env ยาว 49 — **process จริงใช้ตัว 49 จาก env**
  ⇒ `set-verifier-key.sh` ที่อ่าน config ก่อน จะ **inject ค่าผิดทับของที่ใช้งานได้อยู่**
  (atlas ยกระดับเป็น T4536 แล้ว — **ผมไม่แตะ key**)
- `maw team up` บน **multi-member พร้อมกัน** และ **resume path** ยัง `[unverified]` เหมือนเดิม
