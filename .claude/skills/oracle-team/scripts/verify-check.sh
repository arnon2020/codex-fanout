#!/usr/bin/env bash
# verify-check.sh — primitives ที่ "ตรวจแล้วไม่โกหก" สำหรับคำถาม 4 ข้อที่หลอกเราทั้งวัน 2026-08-03
#
# ทุกฟังก์ชันในนี้เกิดจากความพลาดจริง ไม่ใช่ทฤษฎี — ดู ψ/teams/VERIFY-THE-CHECK.md
#   binexists  ← `command -v` เพียว ๆ คืน rc=0 ชี้ path ที่ถูกลบแล้วได้ (bash HASH CACHE)
#                 [แก้เหตุผล 2026-08-04: atlas ทดสอบแล้วพิสูจน์ว่า dangling symlink
#                  `command -v` **จับได้** — เหตุผลเดิมของผมผิด ตัวเครื่องมือยังจำเป็น]
#   procs      ← pgrep -f นับคำสั่งตรวจของตัวเอง (ตอบ 2 ทั้งที่เหลือ 0)
#   bootprobe  ← ทิ้ง stderr แล้วสรุปว่า engine พัง ทั้งที่มัน boot สำเร็จ
#   (ไม่มี kill helper โดยตั้งใจ — `pkill -f` ฆ่า probe ของตัวเองมาแล้ว)
#
# ใช้:  source ψ/teams/scripts/verify-check.sh   หรือ   bash verify-check.sh <fn> <args>
set -uo pipefail

# ── binexists <name-or-path> ────────────────────────────────────────────────
# ตอบว่า "เรียกได้จริงไหม" ไม่ใช่แค่ "มีชื่ออยู่ใน PATH ไหม"
# เคสที่ `command -v` เพียว ๆ โกหก [verified 2026-08-04 · ทำซ้ำจากที่ atlas ชี้]:
#   bash HASH CACHE — รันไบนารีครั้งหนึ่ง ลบไฟล์ทิ้ง แล้วถามใหม่ → ยังคืน rc=0 พร้อม path เดิม
#   ปิดด้วย [ -x "$(command -v X)" ] ซึ่งเป็นสิ่งที่ฟังก์ชันนี้ทำ
# NB: dangling symlink ธรรมดา `command -v` / `type -P` / `which` **จับได้ทั้งหมด**
binexists() {
  local n="${1:?usage: binexists <name>}" p
  p=$(command -v -- "$n" 2>/dev/null) || { echo "MISSING   $n  (ไม่อยู่ใน PATH)"; return 1; }
  if [ ! -e "$p" ]; then
    echo "STALE     $n -> $p  (PATH/hash ชี้ไป target ที่ไม่มีอยู่แล้ว)"; return 1
  fi
  [ -x "$p" ] || { echo "NOEXEC    $n -> $p"; return 1; }
  echo "OK        $n -> $(readlink -f "$p")  ($(stat -c%s "$(readlink -f "$p")" 2>/dev/null) bytes)"
}

# ── procs <binary-basename> ─────────────────────────────────────────────────
# นับจาก /proc/*/exe ไม่ใช่ cmdline ⇒ **นับตัวเองไม่ได้** เพราะ shell ที่รันคำสั่งนี้
# มี pattern อยู่ใน cmdline แต่ exe ของมันคือ bash ไม่ใช่เป้าหมาย
procs() {
  local want="${1:?usage: procs <binary-basename>}" n=0 pid exe
  for pid in /proc/[0-9]*; do
    exe=$(readlink "$pid/exe" 2>/dev/null) || continue
    [ "$(basename -- "$exe")" = "$want" ] && n=$((n+1))
  done
  echo "$n"
}

# ── procs_cmd <pattern> ─────────────────────────────────────────────────────
# สำหรับเป้าหมายที่รันเป็นสคริปต์ (exe จริงคือ python3/node/bash) ⇒ `procs` จะมองไม่เห็น
# ตัวนี้แมตช์ cmdline **แต่ตัดตัวเองและบรรพบุรุษของตัวเองออก** จึงไม่นับคำสั่งตรวจเอง
# (นี่คือกับดักที่ทำให้ `pgrep -c -f` ตอบ 2 ทั้งที่เหลือ 0 เมื่อ 2026-08-03)
procs_cmd() {
  local pat="${1:?usage: procs_cmd <pattern>}" n=0 pid cl
  # สร้างเซ็ตของ pid ตัวเองและบรรพบุรุษ
  local self=$$ chain=" " p=$$
  while [ -n "$p" ] && [ "$p" != "0" ] && [ "$p" != "1" ]; do
    chain="$chain$p "; p=$(awk '{print $4}' "/proc/$p/stat" 2>/dev/null) || break
  done
  for pid in /proc/[0-9]*; do
    pid=${pid#/proc/}
    case "$chain" in *" $pid "*) continue ;; esac       # ข้ามตัวเอง/พ่อแม่
    # NB: process หายระหว่างวนลูปได้ (race) — ถ้าไม่ปิด stderr ตรงนี้ เครื่องมือจะพ่น noise
    #     แล้วคนใช้จะเติม 2>/dev/null ครอบทั้งคำสั่ง = กลับไปทิ้ง output ซึ่งคือนิสัยที่ไฟล์นี้ห้าม
    cl=$( { tr '\0' ' ' < "/proc/$pid/cmdline"; } 2>/dev/null ) || continue
    case "$cl" in *"$pat"*) n=$((n+1)) ;; esac
  done
  echo "$n"
}

# ── alive <binary-basename> ─────────────────────────────────────────────────
# 🔑 lucifer 2026-08-06: verb ที่ให้ verdict ต้องบอกขอบเขตของตัวเองเสมอ
#    `RUNNING` = มี process อยู่ **ไม่ได้แปลว่ารับงานได้** — 2026-08-06 codex process ถูกตัว
#    ถูก flag ครบ แต่จอเป็นหน้า installer ⇒ ส่งงานเข้าไปไม่ถึงไหน และ Enter ไปกด "Update now"
alive() {
  if [ "$(procs "$1")" -gt 0 ]; then echo "RUNNING  $1 ($(procs "$1"))"; else echo "NONE     $1"; fi
  echo "alive.scope: ตรวจ=มี process ตามชื่อ binary · **ไม่ตรวจ**=จอเป็นของ agent หรือ dialog, รับ turn ได้ไหม"
  echo "          ⇒ ถ้าถามว่า pane พร้อมรับงานหรือยัง ใช้ bootverify <session> ไม่ใช่ alive"
}

# ── bootprobe '<full command>' [seconds] [expect-binary] ───────────────────
# ตอบว่า "มันขึ้นไหม" โดย **เก็บ output ไว้เสมอ** — output คือคำตอบ ไม่ใช่ noise
# exit=124 (timeout) หรือ exit=0 พร้อม output ที่มีเนื้อ = ขึ้นได้ ไม่ใช่พัง
bootprobe() {
  local cmd="${1:?usage: bootprobe '<cmd>' [secs] [expect-bin]}" secs="${2:-8}" want="${3:-}"
  local out; out=$(mktemp)
  timeout "$secs" bash -c "$cmd" </dev/null >"$out" 2>&1; local rc=$?
  local lines; lines=$(grep -cv '^[[:space:]]*$' "$out" 2>/dev/null || echo 0)
  echo "exit=$rc  output_lines=$lines"
  if [ -n "$want" ]; then echo "seen_during_run=$(procs "$want")"; fi
  echo "--- output (3 บรรทัดแรก) ---"; head -3 "$out"
  echo "--- (เต็มที่ $out) ---"
  # เกณฑ์ตัดสิน: มี output = โปรเซสเริ่มจริง · rc=124 = ยังรันอยู่ตอนหมดเวลา (ปกติสำหรับ TUI)
  if [ "$lines" -gt 0 ] || [ "$rc" -eq 124 ]; then echo "VERDICT   BOOTED"; return 0
  else echo "VERDICT   NO-OUTPUT-NO-TIMEOUT (น่าสงสัย — อ่าน $out ก่อนสรุปว่าพัง)"; return 1; fi
}

# ── relay <session:window.pane> '<message>' [--durable <inbox-slug>] ────────
# **root-cause fix 2026-08-04** — กฎ "delivered ไม่ใช่ได้รับ" อยู่ใน CLAUDE.md ตั้งแต่ 2026-08-01
# และเป็นข้อ 12 ของ drift test ที่เราตอบถูกเมื่อวาน — แล้ววันนี้ยังพลาดทั้งสองท่า
# ⇒ เขียนกฎเป็นครั้งที่ 4 ไม่ใช่การแก้ · บังคับที่จุดใช้งานแทน
#
# บังคับ 4 ข้อที่ `maw hey` เปล่า ๆ ไม่บังคับ:
#   1. ต้องเป็น target เต็ม `session:window.pane` — ปฏิเสธชื่อสั้น (fuzzy-match ข้าม oracle ได้)
#   2. ตรวจว่า target มีอยู่จริงใน `maw ls -v` ก่อนส่ง  (เดาผิด 2 ตัวรวดเมื่อ 2026-08-04)
#   3. **ไม่ทิ้ง output** และตรวจ exit code — nonzero = ล้ม ไม่ใช่ "น่าจะถึง"
#   4. `--durable` เขียน inbox file ควบ สำหรับ correction/retraction
#
# ⚠️ ข้อจำกัดที่ต้องพูดตรง ๆ: ตัวนี้ยืนยันได้แค่ว่า **เขียนลง pane สำเร็จ** (ชั้น 1)
#    มันยัง **ยืนยันไม่ได้ว่า agent รับเข้า turn** — ยังต้องดูการตอบกลับที่มีเนื้อหา
#
# 🪜 บันไดชั้นของหลักฐาน [2026-08-04 · ajfon + ผม · ดู VERIFY-THE-CHECK.md §บันไดชั้น]:
#    1 `delivered` + exit 0      → เขียนลง pane สำเร็จ (ghost text ยังเป็นไปได้)
#    2 capture-pane เห็นข้อความ  → ตัวอักษรอยู่ในช่องพิมพ์ · **ยังไม่ถูก submit**
#      (codex ค้างเป็น `[Pasted Content NNN chars]` จนกว่าจะ send-enter)
#    3 busy marker               → engine คิดอะไรสักอย่าง — ไม่รู้ว่าเรื่องข้อความเรา
#    4 **agent อ้างถึงเนื้อความ** → 🔑 เข้า turn จริง (ชั้นสุดท้ายที่มี)
#    ⇒ `send-enter` ด้านล่าง: **ถูกเสมอ แต่จำเป็นบางเครื่องยนต์** — codex ต้องใช้,
#      claude เข้า turn เองได้ [ต่างคนต่าง n=1], opencode ยังไม่รู้
#
# 🔴 **2026-08-07 [lucifer · วัดสองรอบคนละทิศ] คำตอบของ `maw send` ไม่สัมพันธ์กับความจริง
#    ทั้งสองทิศ — เตือนก็ผิดได้ ไม่เตือนก็ผิดได้**
#      รอบ A: maw เตือน "may still have unsubmitted input" **แต่ข้อความเข้าไปแล้วจริง** → false alarm
#      รอบ B: maw ตอบ "delivered" เฉย ๆ ไม่เตือนอะไร **แต่ข้อความค้างในช่องพิมพ์ ไม่เคย submit**
#             → false negative · ทีม 4 คน idle อยู่เงียบ ๆ โดยไม่มีสัญญาณอะไรเลย
#    ⇒ นี่แรงกว่ากฎเดิม "delivered ไม่ใช่ได้รับ" เพราะเดิมเรายังเชื่อ **คำเตือน** อยู่
#      ตอนนี้รู้แล้วว่า **ความเงียบของ maw ก็ไม่ได้แปลว่าสำเร็จ**
#    ⇒ **ชั้น 1 ใช้ตัดสินอะไรไม่ได้เลยทั้งทางบวกและทางลบ** — ต้อง `peek` ดู pane เท่านั้น
#    ⇒ อาการที่ควรจำ: pane ที่ **idle พร้อมกันทั้งทีม** หลังสั่งงาน = สงสัยว่าไม่ได้ submit
#      ก่อนจะสรุปว่า "ทำเสร็จแล้ว" (lucifer มองไม่เห็นเพราะกำลังอ่านรายงานอยู่ ·
#      monitor จากข้างนอกเห็นก่อน)
#
# 🏷️ **Tier 3 แล้ว [verified 2026-08-04 02:43 · ส่งจริงถึง 40-ajfon:ajfon.0]**
#    Tier 1–2 (ปฏิเสธของปลอม) ผ่านตั้งแต่แรก — **และมันมองไม่เห็นบั๊กที่มีอยู่จริง**
#    การใช้จริงครั้งแรกล้มทันที: `exit 2` เงียบ เพราะ dispatcher ท้ายไฟล์ยิงตอนถูก `source`
#    ⇒ **fixture ที่ไม่แตะตัวประธานจริง มองไม่เห็น defect ที่ผูกกับตัวประธาน** — ของจริง
#      หนึ่งครั้ง เจอสิ่งที่เทสต์ปลอมสามอันมองข้าม (selftest 5d ปิดช่องนี้แล้ว)
relay() {
  local target="${1:?usage: relay <session:window.pane> '<msg>' [--durable <slug>]}"
  local msg="${2:?message required}"; shift 2
  local durable="" slug=""
  while [ $# -gt 0 ]; do
    case "$1" in --durable) durable=1; slug="${2:?--durable needs a slug}"; shift 2 ;; *) shift ;; esac
  done

  case "$target" in
    *:*.*) ;;
    *) echo "REFUSED   '$target' ไม่ใช่ target เต็ม — ต้องเป็น session:window.pane"
       echo "          (maw hey fuzzy-match ข้าม oracle ได้ · CLAUDE.md golden rule)"
       echo "          หาได้จาก: maw ls -v"; return 2 ;;
  esac

  # 🩹 2026-08-06 [verified: ยิงจริงแล้วโดน] ข้อความที่ **ขึ้นต้นด้วย `[`** ถูก maw ปฏิเสธ:
  #    "hey: bracket-prefixed hey text is reserved for signed transport prefixes"
  #    เพราะ maw เติม prefix ของมันเอง (`[local:<from>]`) ⇒ วงเล็บนำถูกจองไว้
  #    รูปนี้ล่อมาก: `[codex-fanout → ajfon] ...` เป็นหัวข้อความที่เขียนกันทั้ง fleet
  #    ดักที่นี่เพราะข้อความของ maw ไม่ได้บอกว่าต้องทำอะไรต่อ
  case "$msg" in
    \[*) echo "REFUSED   ข้อความขึ้นต้นด้วย '[' — maw จองไว้ให้ signed transport prefix"
         echo "          เปลี่ยนหัวเป็น 'codex-fanout → <ใคร> · ...' (ไม่มีวงเล็บนำ)"; return 2 ;;
  esac

  # 🔴 2026-08-07 `maw hey` เซ็นชื่อผู้ส่งจาก env `MAW_SENDER` ⇒ ถ้ามันผิด ข้อความจะเซ็นชื่อคนอื่น
  #    เช็คข้างล่างเป็น **self-check เท่านั้น** — ตรวจว่า *ของเราเอง* ตรงกับ window ของเราไหม
  #
  #    ⛔ **ห้ามใช้ MAW_SENDER ตามรอยว่าข้อความมาจาก pane ไหน — มันตามไม่ได้**
  #    `[วัดเอง 2026-08-07 หลัง lucifer ล้มสมมติฐานผม]`
  #      env ที่ process ของผมเห็น : MAW_SENDER=local:codex-fanout
  #      env ที่ pane ของผมถือ      : MAW_SENDER=local:tars-oracle
  #      pane ทั้งเครื่อง 36 อัน    : local:tars-oracle **ทุกอันเหมือนกันหมด**
  #      pane ที่ถือ codex-fanout   : 0
  #    ⇒ agent ตั้ง env นี้ **ที่ระดับ process ของตัวเอง** ไม่ได้รับจาก pane
  #    ⇒ ค่าใน pane เท่ากันหมดทั้งเครื่อง จึงไม่ได้บอกอะไรเลยว่าใครส่ง
  #    ⇒ **`from=` ใน log พิสูจน์ต้นทางไม่ได้** · ผมเคยตั้งสมมติฐานว่าตามรอยได้ **ผิด**
  #       และ lucifer ล้มมันด้วยการวัดครั้งเดียว ⇒ ถ้าต้องรู้ว่าใครสั่ง **ถามมนุษย์**
  if [ -n "${MAW_SENDER:-}" ]; then
    local mywin="${MAW_SESSION_WINDOW:-}"
    case "${MAW_SENDER}" in
      *"${mywin%-oracle}"*) ;;
      *) echo "⚠ MAW_SENDER='${MAW_SENDER}' ไม่ตรงกับ window '${mywin:-?}' — ข้อความจะถูกเซ็นชื่อคนอื่น"
         echo "  แก้: MAW_SENDER=local:<ชื่อคุณ> ก่อนคำสั่ง · ผู้รับตรวจไม่ได้ว่าลายเซ็นถูกหรือผิด" ;;
    esac
  fi
  local sess="${target%%:*}" win="${target#*:}"; win="${win%%.*}"
  if ! maw ls -v 2>&1 | grep -qF "$sess"; then
    echo "REFUSED   ไม่พบ session '$sess' ใน maw ls -v"; return 2
  fi
  if ! maw ls -v 2>&1 | grep -qF "$win"; then
    echo "REFUSED   ไม่พบ window '$win' ใน maw ls -v  (session '$sess' มีอยู่)"
    echo "          window name ของ charter role != tmux window name"; return 2
  fi

  # 🩹 2026-08-07 — ข้อความที่ **พังก่อนถึง relay** ผ่านทุกด่านของบันไดหลักฐาน
  #    ผมประกอบข้อความใน `"..."` ของ bash ⇒ ทุกอย่างใน backtick ถูกรันเป็นคำสั่ง แล้ว *ผลลัพธ์
  #    หรือ error* ไปแทนที่ข้อความ · holmes ได้รับใบที่มีรูและมี "syntax error near unexpected
  #    token" ปนอยู่ · `maw hey` คืน delivered · relay พิมพ์ SENT · **ถูกทุกด่าน**
  #    ⇒ 🪜 บันไดชั้น 1-4 ตอบว่า *ข้อความถึงไหมและเข้า turn ไหม* — **ไม่มีชั้นไหนถามว่า
  #      ข้อความยัง*เป็นสิ่งที่เราเขียน*อยู่ไหม** · จับได้ทางเดียวคือมีคนอ่านแล้วบอกว่าอ่านไม่รู้เรื่อง
  #    ⇒ ด่านนี้จับ **ร่องรอยของความพัง** ไม่ได้จับสาเหตุ (สาเหตุเกิดก่อนเราเห็น $msg แล้ว)
  #      แต่มันคือสิ่งเดียวที่จับได้อัตโนมัติ · **วิธีป้องกันจริงคือประกอบข้อความด้วย
  #      heredoc ที่ปิด expansion (`<<'EOF'`) ไม่ใช่ `"..."`** — กฎนี้อยู่ใน CLAUDE.md ตั้งแต่ 07-30
  #      และผมยังเหยียบเมื่อ 2026-08-07 ⇒ เขียนกฎครั้งที่ 2 ไม่ใช่การแก้ ด่านนี้คือการแก้
  local _leak
  for _leak in 'syntax error near unexpected token' 'unexpected end of file' \
               'command not found' 'command substitution:' 'No such file or directory' \
               'missing file operand'; do
    case "$msg" in
      *"$_leak"*)
        echo "REFUSED   ข้อความมีร่องรอย shell error: \"$_leak\""
        echo "          น่าจะเกิดจากประกอบข้อความใน \"...\" แล้ว backtick/\$(...) ถูกรัน"
        echo "          แก้: MSG=\$(cat <<'EOF' ... EOF) แล้วส่ง \"\$MSG\""
        echo "          (ถ้าตั้งใจส่งข้อความที่มีคำนี้จริง ๆ ให้ส่งผ่านไฟล์แทน)"
        return 2 ;;
    esac
  done

  local out; out=$(maw hey "$target" "$msg" 2>&1); local rc=$?
  echo "$out" | head -1 | cut -c1-100
  if [ $rc -ne 0 ]; then echo "FAILED    maw hey exit=$rc — ยังไม่ถึง อย่าอ้างว่าส่งแล้ว"; return 1; fi
  case "$out" in *delivered*) ;; *) echo "SUSPECT   ไม่เห็นคำว่า delivered ใน output — อ่าน output เต็มก่อนสรุป"; return 1 ;; esac

  # 🩹 2026-08-09 [lucifer จับ · เขา audit กว้างกว่าที่ผมสั่งแล้วเจอในไฟล์ของผมเอง]
  #    เดิมบรรทัดล่างยิง `send-enter` ทันทีหลัง `delivered` **โดยไม่ดูจอก่อน**
  #    ⚠️ lucifer แยกคลาสให้เอง และผมเห็นด้วย — **นี่ไม่ใช่ `fleet-send.sh:495-505`**:
  #      · `fleet-send` ส่ง Enter **3 ครั้งทุก send ไม่มีเงื่อนไข** `capture-pane` 0 จุด
  #      · `relay` ส่ง **ครั้งเดียวหลังยืนยัน delivered** และ Enter นั้น **จำเป็นจริง** —
  #        codex ค้างเป็น `[Pasted Content NNN chars]` จนกว่าจะมี Enter มา submit (:109-112)
  #    ⇒ ช่องจริง**แคบกว่า** และ lucifer ระบุได้ตรง: **`delivered` ไม่ได้พิสูจน์ว่า pane
  #      บริโภคข้อความ** — ถ้า pane นั่งบน trust/update dialog อยู่ก่อน `delivered` ก็ยังขึ้นได้
  #      แล้ว **Enter ของเราไปลงที่ dialog นั้นแทน**
  #    ⇒ ทางแก้ที่เขาเสนอและผมทำตาม: **เช็คจอก่อน ไม่ใช่ถอด send-enter ออก**
  #    ⇒ บน codex 0.147.0 ตัวไฮไลต์คือ `1. Yes, continue` (trust) · บน 0.146.1 คือ `Update now`
  #      ⇒ **Enter เปล่าตรงนั้นตอบคำถามเรื่องของกลางโดยไม่ได้อ่าน**
  #    ⚠️ **ด่านนี้เกือบทำลายช่องทางที่ผมใช้อยู่** — ผมส่งข้อความที่*อธิบาย*ไดอะล็อกพวกนี้
  #       ไปทุกบ้านคืนนี้ ⇒ scrollback ของเขามีคำเหล่านั้นเต็มไปหมด ⇒ ถ้าจับแค่ "มีคำ"
  #       relay จะปฏิเสธการส่งหา oracle ทุกตัวที่ผมเพิ่งคุยด้วย
  #       🔑 **เครื่องมือที่จับ "การพูดถึงปัญหา" ว่าเป็น "ปัญหา" คือ false positive ที่
  #          ฆ่าตัวเอง** — และผมเจอมันเพราะ *ทดสอบ* ไม่ใช่เพราะคิดออก
  #    ⇒ รัดสองชั้น: ดูเฉพาะ **ท้ายจอ** (บริเวณที่ยัง live) + ต้องมี **แถวตัวเลือกเลข**
  #       ติดกับ banner ไม่ใช่แค่ประโยคคำถามลอย ๆ
  local pre; pre=$(maw peek "$target" 2>/dev/null | tail -12)
  local banner="" opt=""
  banner=$(printf '%s' "$pre" | grep -m1 -E \
    'Update available!|Do you trust the contents of this directory|Is this a project you created or one you trust|Do you want to (proceed|create|make|edit|run)|requires approval' 2>/dev/null)
  opt=$(printf '%s' "$pre" | grep -m1 -E '^[[:space:]]*[›>❯[:space:]]*[0-9]\.[[:space:]]' 2>/dev/null)
  [ -n "$opt" ] || banner=""      # มีคำถามแต่ไม่มีเมนู = กำลังพูดถึง ไม่ใช่กำลังถาม
  if [ -n "$banner" ]; then
    echo "REFUSED   ไม่กด Enter — pane กำลังแสดง dialog ของ CLI ไม่ใช่ช่องพิมพ์ของ agent"
    echo "          เห็น: $(printf '%s' "$banner" | sed 's/^[[:space:]]*//' | cut -c1-72)"
    echo "          ⇒ ข้อความ **ส่งถึง pane แล้ว** แต่ยังไม่ถูก submit และจะไม่ถูก submit"
    echo "             จนกว่าจะเคลียร์ dialog — **อ่านเลขจากจอจริง อย่ากด Enter เปล่า**"
    echo "             (0.147.0 ไฮไลต์ '1. Yes, continue' · 0.146.1 ไฮไลต์ 'Update now')"
    echo "          ⇒ เคลียร์เองแล้วค่อยส่งซ้ำ · หรือถ้าเป็น pane ของบ้านอื่น ให้เจ้าของเคลียร์"
    return 3
  fi
  local eout; eout=$(maw send-enter "$target" 2>&1); local erc=$?
  [ $erc -ne 0 ] && { echo "FAILED    send-enter exit=$erc"; return 1; }

  if [ -n "$durable" ]; then
    local f="ψ/inbox/$(date +%Y-%m-%d_%H-%M)_codex-fanout_${slug}.md"
    { printf -- '---\nfrom: codex-fanout\nto: %s\ntimestamp: %s\nchannel: tmux + durable inbox\n---\n\n' \
        "$sess" "$(date -Iseconds)"; printf '%s\n' "$msg"; } > "$f"
    echo "DURABLE   $f  (สำเนาของ **ผู้ส่ง** — ยังไม่ถึงเขา)"

    # 🩹 2026-08-07 — **`--durable` เดิมเขียนลง inbox ของผู้ส่งเท่านั้น ⇒ ผู้รับไม่ได้อะไรเลย**
    #    atlas จับได้ด้วยการเช็คดิสก์ตัวเอง · **loom ยืนยันซ้ำจากฝั่งผู้รับ**: packet ของผม
    #    ที่เป็นไฟล์ในบ้าน loom มี 11 ใบ · correction 16:35 **ไม่มี** — เขามีแต่ใน context
    #    ⇒ session เขาตาย ของหายไปด้วย · ผมปิด Next Step ว่า "ส่ง durable ครบ" บนกลไกนี้
    #    ⇒ 🪜 "ผมเขียนไฟล์แล้ว" = **ชั้น 0** ต่ำกว่า `delivered` เพราะ delivered ยังแตะ pane เขา
    #    วิธีที่ถูกคือของ **loom**: เขียนลง `ψ/inbox/` ของ *ผู้รับ* ตรง ๆ (เขาทำกับผมแบบนี้มาตลอด)
    #    ⚠️ `maw locate` fuzzy — ชื่อกำกวมคืน "matches multiple targets" (เช่น `ajfon`)
    #       ⇒ **ไม่เดา** · ถ้าไม่ชัด ให้ตกลงมาเป็นสำเนาผู้ส่งพร้อมบอกตรง ๆ ว่ายังไม่ถึง
    local peer="${sess##*-}" peerpath="" pf=""
    peerpath=$(maw locate "$peer" --path 2>/dev/null | head -1)
    case "$peerpath" in
      /*) if [ -d "$peerpath/ψ/inbox" ]; then
            pf="$peerpath/ψ/inbox/$(date +%Y-%m-%d_%H-%M)_codex-fanout_${slug}.md"
            if cp -- "$f" "$pf" 2>/dev/null; then
              echo "DELIVERED $pf  ← เขียนลงดิสก์ **ของผู้รับ**"
            else
              echo "WARN      เขียน $pf ไม่ได้ — ผู้รับยังไม่มีไฟล์ อย่านับว่าส่งถึง"
            fi
          else
            echo "WARN      $peerpath ไม่มี ψ/inbox — ผู้รับยังไม่มีไฟล์"
          fi ;;
      *)  echo "WARN      maw locate '$peer' ไม่ให้ path ที่ชัดเจน — **ผู้รับยังไม่มีไฟล์**"
          echo "          (ชื่อกำกวม/ไม่พบ) ⇒ ใส่เนื้อหาเต็มในตัวข้อความ อย่าให้ path แทนเนื้อหา" ;;
    esac
    # 🩹 2026-08-04: `.gitignore` มี `ψ/*` ⇒ ไฟล์นี้ **ไม่เข้า git** ถ้าไม่ `-f`
    #    วันที่ผมเลิกใช้ `git add -f ψ/` ไฟล์ durable ตัวแรกหลังกฎใหม่ตกทันที **เงียบสนิท**
    #    `git commit` exit 0 · ledger เขียนว่า durable ครบ · ไม่มีอะไรเตือน
    #    ⇒ ไฟล์บนดิสก์อย่างเดียว = durable ต่อ session **ไม่ใช่ต่อประวัติ**
    if git rev-parse --git-dir >/dev/null 2>&1 && git check-ignore -q -- "$f" 2>/dev/null; then
      echo "WARN      $f ถูก .gitignore — ต้อง 'git add -f' ไม่งั้น durable แค่ต่อ session"
    fi
  fi
  echo "SENT      $target  [delivered · ยังไม่ยืนยันว่า agent รับเข้า turn]"
  # 🔴 2026-08-06: ก่อนจะเขียนว่าใคร "เงียบ/ไม่ตอบ" ให้ `maw peek <target>` ก่อนเสมอ
  #    ผม broadcast ว่า "holmes ไม่มีเสียง 2 รอบ" ให้ 6 oracle อ่าน — **เท็จ**
  #    holmes รอคำตอบ yes/no จากผมอยู่ใน pane ตัวเอง `peek` ใช้เวลา 3 วินาที ผมไม่ได้ทำสักครั้ง
  #    สโคปที่ผมค้นคือ "ข้อความที่เข้ามาหาผม" แต่ประโยคที่เขียนคือ "เขาไม่มีเสียง" — คนละอย่าง
  #    ⇒ **ความว่างเปล่าไม่ใช่หลักฐาน จนกว่าจะไปดูปลายทาง** · ทิศลบไม่ได้ยกเว้นจากการตรวจ
  echo "          ⚠ ถ้าไม่ได้รับคำตอบ: 'maw peek $target' ก่อนสรุปว่าเขาเงียบ — เขาอาจรอคุณอยู่"
}

# ── teamclosed <team> ───────────────────────────────────────────────────────
# ตอบว่า "ทีมนี้ปิดจริงไหม" ไม่ใช่ "คำสั่งไหนพูดว่าอะไร"
#
# 🏷️ ที่มา 1 — ajfon 2026-08-02: `maw team status` ตอบ "team not found" ทั้งที่ `list`
#    ยังโชว์ ⇒ "อย่าใช้ status ยืนยันว่าปิด ใช้ list"
#    **repro บนเครื่องนี้ ได้คนละอาการ แต่เจอของที่แรงกว่า**
#    [verified 2026-08-04 · maw-rs v26.7.30-alpha.2017-17-g284ae4d · ajfon ทำซ้ำยืนยันแล้ว]
#      · status vs list **ตรงกัน** ทั้ง 3 ทีม ⇒ อาการของ ajfon ผูกกับ binary ของเขา
#      · **`maw team status <ทีมที่ไม่มีอยู่>` คืน rc=0** พิมพ์ "⚠ team not found" ลง
#        **stdout** ⇒ `status X >/dev/null 2>&1 && echo CLOSED` **พิมพ์ CLOSED จริง**
#        (ajfon ยืนยันด้วยการแยกสตรีมสองทาง) — รูปเดียวกับ `maw hey` warning-ไม่ใช่-error
#    ⇒ ข้อห้ามของเขาถูก **ด้วยเหตุผลที่ไม่พึ่ง binary**: `status` ไม่มีช่องบอกความล้มเหลวเลย
#
# 🏷️ ที่มา 2 — ajfon 2026-08-04 (ล้มเวอร์ชันแรกของฟังก์ชันนี้ ภายในไม่กี่นาทีหลังผมส่งไป):
#    **`maw team up` เป็น charter-driven reconciliation — ไม่ลงทะเบียนใน tool store**
#    ⇒ ทีมที่ `up` สร้าง **ไม่โผล่ใน `list` เลยขณะมีชีวิต** ⇒ เวอร์ชันที่ดูแต่ `list`
#    ตอบ **false-CLOSED บนทีมที่กำลังรัน** — แย่กว่าเคส rc โกหก เพราะ list ไม่รู้จักทีม*ทั้งประเภท*
#    [verified 2026-08-04 · ผมทำซ้ำเอง ไม่ได้รับป้ายเขามาใช้ต่อ]
#      `maw team list | grep -c person-lookup` → **0**
#      `tmux list-windows -t team-person-lookup-r2` → **4 windows** (anchor + 3 worker)
#      `teamclosed person-lookup-r2` (เวอร์ชันแรก) → **CLOSED** ← false-CLOSED ของจริง
#    ⇒ เพิ่มผิว tmux · **ajfon บอกตรงว่าเขายังไม่ได้ทดสอบ rc ของ `has-session` ให้**
#      ผมทดสอบเอง: มีจริง **rc=0** · ไม่มี **rc=1** `[verified 2026-08-04]`
#
# 🏷️ ที่มา 3 — ที่ปรึกษาจับได้ว่า selftest 5e เดิมเลือกตัวประธานเป็น **header row `TEAM`**
#    (`awk NR>1` ข้ามแค่บรรทัดว่างบรรทัดแรก) ⇒ กับดัก substring ที่โฆษณาไว้ว่าทดสอบ
#    `atlas` vs `atlas-codex` จริง ๆ ทดสอบ `TEAM` vs `TEA` = **fixture Tier 1 ในไฟล์ที่
#    ทั้งเล่มพูดว่า Tier 1 มองไม่เห็น defect ที่ผูกกับตัวประธาน** — แก้ให้ข้าม header ตรง ๆ แล้ว
#
# ⚠️ ขอบเขตที่ตอบไม่ได้ (พิมพ์ออกมาเองเมื่อตรวจไม่ถึง ไม่เงียบ):
#    · vault + charter เป็น path **เทียบ CWD** ⇒ ถามถึงทีมของ oracle อื่น ผิวนี้ไม่ถึง
#    · ตอบเรื่อง "มีอยู่/มีชีวิตไหม" ไม่ได้ตอบว่า worker มีงานทำไหม (ajfon ข้อ 4: `up`
#      ปลุก pane ได้โดยไม่ส่ง prompt — exit 0, preflight 11/11, และ worker นั่งว่าง)
# ── _vc_row_verdict <แถวจาก maw team list> ─────────────────────────────────
# แยก **บันทึก** ออกจาก **ของค้าง** ในแถวเดียวกันของ `maw team list`
#   `vault N prep-only`     → charter-only : ไม่เคยมี pane · maw สร้างแถวจากไฟล์ charter
#   `tool  N no live panes` → open         : เคยมี pane แล้วตาย = ของค้างจริง
# แยกออกมาเป็นฟังก์ชันเพราะ **เทสต์แถวสังเคราะห์ได้** — ผมสร้างแถว vault/prep-only จริง
# ในเทสต์ไม่ได้ (`maw team list` ไม่ลิสต์ charter ที่วางเปล่า ๆ ใน cwd — ลองแล้ว ทั้งมี/ไม่มี
# `git init` ก็ไม่โผล่ ⇒ มันมาจาก vault store ที่ `maw team prep` ลงทะเบียน ไม่ใช่จากไฟล์ล้วน)
# ⇒ เทสต์ตัวนี้ตรวจ **ตรรกะการจัดประเภทของผม** ไม่ได้ตรวจ **พฤติกรรมการลิสต์ของ maw**
# ── _vc_sweep_scan ─────────────────────────────────────────────────────────
# กวาด candidate ทั้งหมด **จากระบบไฟล์** (ไม่ parse ตารางที่ render ให้คนอ่าน) แล้ว assert
# invariant: **ทีมที่มี store dir ค้าง ต้องไม่มีวันได้ `CHARTER-ONLY` และต้องไม่ rc=0**
# พิมพ์บรรทัดสรุปเครื่องอ่านได้: `SWEEP swept=N nostore=N union=N`
# ⚠️ **ทุก element ของ union ต้องออกทางถังใดถังหนึ่งพอดี** (swept | nostore) — ห้ามมี `continue`
#    เส้นทางไหนที่ไม่เพิ่มถังใดเลย ไม่งั้น conservation ในแขน ง จะจับไม่ได้ว่าของหาย
_vc_sweep_scan() {
  local cand seen=" " swept=0 nostore=0 union=0 out rc
  for cand in .maw/teams/*.yaml "$HOME/.claude/teams/"*/ "ψ/memory/mailbox/teams/"*/; do
    [ -e "$cand" ] || continue                      # glob ไม่แมตช์ = ไม่ใช่ element ของ union
    cand=$(basename -- "${cand%/}"); cand=${cand%.yaml}
    case "$seen" in *" $cand "*) continue ;; esac   # นับ union แบบ unique
    seen="$seen$cand "
    union=$((union+1))
    if [ -d "$HOME/.claude/teams/$cand" ] || [ -d "ψ/memory/mailbox/teams/$cand" ]; then
      swept=$((swept+1))
      out=$(teamclosed "$cand" 2>&1); rc=$?
      case "$out" in
        *CHARTER-ONLY*) echo "   ✗ '$cand' มี store dir ค้างแต่ได้ CHARTER-ONLY — บันทึกบัง residue" ;;
        *) [ $rc -eq 0 ] && echo "   ✗ '$cand' มี store dir ค้างแต่ rc=0" ;;
      esac
    else
      nostore=$((nostore+1))                        # charter อย่างเดียว ไม่มี residue = ไม่ใช่เคสของแขนนี้
    fi
  done
  echo "SWEEP swept=$swept nostore=$nostore union=$union"
}

# ── _vc_team_list_plain ────────────────────────────────────────────────────
# seam เดียวที่ selftest แทนได้ — คืนตาราง `maw team list` ดิบ ๆ พร้อม rc ของมัน
_vc_team_list_plain() { maw team list 2>&1; }

_vc_row_verdict() {
  local row="${1:?usage: _vc_row_verdict <row>}" store status
  store=$(printf '%s\n' "$row" | awk '{print $2}')
  # STATUS มีช่องว่างในตัว ("no live panes") ⇒ ตัด 3 คอลัมน์หน้า + ZOMBIES ท้าย แล้ว trim
  status=$(printf '%s\n' "$row" | awk '{$1="";$2="";$3="";$NF="";sub(/^ +/,"");sub(/ +$/,"");print}')
  if [ "$store" = "vault" ] && [ "$status" = "prep-only" ]; then echo "charter-only"; else echo "open"; fi
}

teamclosed() {
  local t="${1:?usage: teamclosed <team-name>}"
  local unreachable="" found="" rc_open=0 vaultrow=""

  # ── ผิว 1: tmux (ทีมจาก `up` โผล่ที่นี่ที่เดียว) ─────────────────────────
  # 🧭 **ตัดสินใจโดยตั้งใจ**: session ที่ยังอยู่ = ยังไม่ปิด **แม้เหลือแต่ `_anchor`**
  #    `maw team up` ทิ้ง window `_anchor` ไว้ซึ่งอยู่ทนกว่า worker ⇒ ทีมที่ worker ตายหมด
  #    แต่ session ยังอยู่ จะได้ `LIVE` · **นี่คือคำตอบที่ต้องการ** เพราะคำถามคือ "ปิดหรือยัง"
  #    และ session ที่ค้างคือเหตุผลที่แท้จริงที่จะยังไม่เรียกว่าปิด (ต้อง kill-session ก่อน)
  #    ⚠️ แต่ **LIVE ไม่ได้แปลว่า worker มีงานทำ** — ajfon ข้อ 4: `up` ปลุก pane ได้โดย
  #      ไม่ส่ง prompt เลย exit 0 preflight เขียว และ worker นั่งว่าง ⇒ ฟังก์ชันนี้ตอบไม่ได้
  if binexists tmux >/dev/null 2>&1; then
    # 🔑 `-t "=..."` บังคับ exact — **ไม่ใช่การกันเคสสมมติ** [ajfon แจ้ง + ผมทำซ้ำ 2026-08-04]
    #    `has-session -t team-person-lookup` คืน **rc=0** ทั้งที่ทีมนั้นยุบไปแล้ว
    #    เพราะ prefix-match กับ `team-person-lookup-r2` ⇒ **false-ALIVE ของจริงบนเครื่องนี้**
    #    ⚠️ และคู่ rc/stream ที่นี่ **ตรงข้ามกับ `maw team status`**:
    #       tmux: rc พูดความจริง · ข้อความอยู่ **stderr**
    #       maw : rc **โกหก** (0 เสมอ) · ข้อความอยู่ **stdout**
    #    ⇒ **อ่านทั้ง rc และ output ต่อคำสั่ง อย่าเดารูปแบบจากคำสั่งอื่น** (ajfon ตั้งข้อสังเกต)
    local sess
    for sess in "$t" "team-$t"; do
      if tmux has-session -t "=$sess" 2>/dev/null; then
        local nw; nw=$(tmux list-windows -t "=$sess" 2>/dev/null | wc -l)
        echo "LIVE      $t  tmux session '$sess' มีอยู่จริง ($nw windows)"
        tmux list-windows -t "=$sess" -F '          #{window_index}: #{window_name}' 2>/dev/null
        echo "          ⇒ ทีมจาก \`maw team up\` ไม่ลงทะเบียนใน store — list/status มองไม่เห็น"
        echo "          [LIVE = 'session ยังอยู่' ไม่ใช่ 'worker ยังทำงาน' — ดูรายชื่อ window เอง]"
        return 1
      fi
    done
  else
    unreachable="$unreachable tmux(ไม่มีไบนารี)"
  fi

  # ── ผิว 2: maw team list (store-registered) ──────────────────────────────
  if binexists maw >/dev/null 2>&1; then
    local lout lrc
    # แยกการ *เรียก* ออกจากการ *ตีความ* เพื่อให้ selftest แทนตารางสังเคราะห์เข้ามาได้
    # (จำเป็น: ผมสร้างแถว `vault/prep-only` จริงในเทสต์ไม่ได้ — ดู _vc_row_verdict)
    lout=$(_vc_team_list_plain 2>&1); lrc=$?
    if [ $lrc -ne 0 ] || [ -z "$lout" ]; then
      echo "UNKNOWN   maw team list exit=$lrc / output ว่าง — ยังตอบไม่ได้ว่าปิด"; return 2
    fi
    local plain; plain=$(printf '%s\n' "$lout" | sed 's/\x1b\[[0-9;]*m//g')
    # ต้องเห็น header จริงก่อน ไม่งั้นถือว่าอ่านฟอร์แมตไม่ออก → UNKNOWN ไม่ใช่ CLOSED
    printf '%s\n' "$plain" | awk '$1=="TEAM" && $2=="STORE"{f=1} END{exit !f}' || {
      echo "UNKNOWN   อ่าน header ของ maw team list ไม่ออก — ฟอร์แมตเปลี่ยน ยังตอบไม่ได้"; return 2; }
    local row
    row=$(printf '%s\n' "$plain" | awk -v n="$t" '$1=="TEAM" && $2=="STORE"{h=1;next} h && $1==n {print; exit}')
    if [ -n "$row" ]; then
      # 🩹 2026-08-08 [prism จับ · ผมทำซ้ำจาก cwd ของเขาแล้วได้แถวเดียวกันเป๊ะ] —
      #    เดิมผมนับ **ทุกแถว** ใน `maw team list` เป็น OPEN โดยไม่อ่านคอลัมน์ STATUS
      #    แต่แถวสองแบบนี้คนละความหมาย และ **ทางแก้คนละอัน**:
      #      `tool  N  no live panes`  = เคยมี pane แล้วตาย ⇒ ของค้างจริง ต้อง `maw team delete`
      #      `vault N  prep-only`      = **ไม่เคยมี pane** · maw ลิสต์ออกมาจาก *ไฟล์ charter*
      #                                   ที่ยังอยู่ใน `.maw/teams/*.yaml` ของ **cwd ปัจจุบัน**
      #    ⇒ oracle ที่เก็บ charter ไว้เป็นบันทึกถาวร (Nothing is Deleted) จะได้ OPEN **ตลอดกาล**
      #      ทางเดียวที่จะพลิกเป็น CLOSED คือ **ลบไฟล์บันทึกทิ้ง** — เครื่องมือที่บังคับให้ละเมิด
      #      หลักการเพื่อให้ตัวเองเขียว คือเครื่องมือที่ผิด ไม่ใช่หลักการที่ผิด
      #    `[verified 2026-08-08: cd prism-oracle → teamclosed prism-cell ได้ 'vault 11 prep-only'
      #      · cwd ผม → CLOSED · แถวเดียวกันปรากฏ/หายตาม cwd เพราะ maw อ่าน charter แบบ dir-aware]`
      #    ⚠️ **ที่ prism สรุปว่าเป็นผิว 3 (charter ของสคริปต์นี้) — ไม่ใช่** · ผิว 3 คืน `GHOST`
      #      ไม่ใช่ `OPEN` · แถวที่เขาเห็นมาจาก **maw เอง** ที่ผิว 2 ⇒ ข้อสรุปเขาถูก ที่อยู่ผิด
      # 🔴 2026-08-08 รอบสอง [prism จับ · `bash -x` แล้วชี้บรรทัดมาเลย] — แพตช์แรกของผม
      #    `return 0` **ตรงนี้** ⇒ ทีมที่มีทั้งแถว vault/prep-only **และ** store dir ค้าง
      #    จะได้ `CHARTER-ONLY` โดย **ไม่เคยรันเช็ค GHOST เลย** ⇒ residue จริงถูกบัง
      #    หลักฐานของเขา: `evidence-cell` มี `~/.claude/teams/evidence-cell/` residue **8 ไฟล์**
      #    (spawn-prompt ทุก role · mtime 2026-08-01) แต่แถว list เป็น `vault 0 prep-only`
      #    ⇒ **ผมย้าย false-green จากที่หนึ่งไปอีกที่** ซึ่งเป็นสิ่งที่ lucifer เตือนไว้พอดี
      #    และ fixture ของ lucifer ตอบ GHOST ถูก **เพราะทีมสมมติของเขาไม่มีแถวใน maw list**
      #    ⇒ เทสต์สองคนไม่ชนกันเลยทั้งที่ทดสอบเรื่องเดียวกัน — ต้องมี**ทั้งสองเงื่อนไขพร้อมกัน**
      #    ⚠️ ผมเองก็รัน `teamclosed evidence-cell` แล้วได้ GHOST **จาก cwd ผม** แล้วนับว่าผ่าน —
      #      แถว vault ไม่โผล่จาก cwd ผม ⇒ **ผมตรวจเคสที่ไม่มีบั๊กแล้วสรุปว่าไม่มีบั๊ก**
      #  ⇒ ห้าม `return` ที่ผิวนี้ · เก็บใส่ตัวแปรแล้ว **ตกลงไปให้ผิว store dir ตัดสินก่อน**
      if [ "$(_vc_row_verdict "$row")" = "charter-only" ]; then
        vaultrow="$row"
      else
        echo "OPEN      $t  ยังอยู่ใน maw team list"
        printf '          %s\n' "$row"; return 1
      fi
    fi
  else
    unreachable="$unreachable maw(ไม่มีไบนารี)"
  fi

  # ── ผิว 3+4: ไดเรกทอรีค้าง 2 สโตร์ + charter (ทั้งคู่เทียบ CWD ยกเว้น tool store) ──
  # ⚠️ ไดเรกทอรี "ไม่มี" ≠ "ตรวจไม่ได้" — ไม่มี = ตรวจแล้วไม่เจอ ต้องไม่ดันไปเป็น UNKNOWN
  #    ไม่งั้นฟังก์ชันนี้จะตอบ UNKNOWN ตลอดกาลจาก repo ที่ไม่มี .maw/teams/ =
  #    **ตัวตรวจที่ไม่มีวันตอบ CLOSED ก็คือตัวตรวจที่ไม่มีใครเรียก** (รูปเดียวกับกฎที่ไม่มีใครอ่าน)
  #    ที่ "ตรวจไม่ได้" จริงมีอย่างเดียวคือ **ไบนารีหาย** — ผิวนั้นเงียบโดยไม่รู้ผล
  # 🩹 2026-08-08 [lucifer จับ] — เดิมผมกอง **ไฟล์ charter** ไว้กับ **ไดเรกทอรี store**
  #    แล้วเรียกทั้งก้อนว่า GHOST rc=1 · lucifer ชี้ว่า *"ยังไม่มีการยุบครั้งไหน archive charter
  #    เลย · .maw/teams มี charter 65 ใบ"* ⇒ ทุกทีมที่ปิดถูกต้องจะติด GHOST **ถาวร**
  #    และทางเดียวที่จะพลิกคือ **ปลดนิยามทีมทิ้ง** ซึ่งเขาบอกตรง ๆ ว่านั่นเป็นสิทธิ์ของ arnon
  #    ไม่ใช่สิ่งที่คำว่า "ยุบทีม" ครอบถึง — **เขาถูก** และเป็น defect เดียวกับที่ prism เจอ
  #    ที่ผิว 2 พอดี (เครื่องมือบังคับให้ลบบันทึกเพื่อให้ตัวเองเขียว) แค่คนละผิว
  #  ⇒ แยกตามสิ่งที่ของนั้น *เป็น*:  store dir = **runtime residue** · charter = **นิยาม/บันทึก**
  local ghosts="" charteronly=""
  [ -d "$HOME/.claude/teams/$t" ]    && ghosts="$ghosts ~/.claude/teams/$t"
  [ -d "ψ/memory/mailbox/teams/$t" ] && ghosts="$ghosts ψ/memory/mailbox/teams/$t"
  [ -f ".maw/teams/$t.yaml" ]        && charteronly=".maw/teams/$t.yaml"

  if [ -n "$ghosts" ]; then
    echo "GHOST     $t  ไม่มี session แต่ยังมี **state ของ runtime** ค้าง:$ghosts"
    [ -n "$charteronly" ] && echo "          (+ ไฟล์ charter $charteronly — อันนั้นเป็นบันทึก ไม่ใช่ของค้าง)"
    [ -n "$vaultrow" ] && printf '          (+ แถวใน maw team list ที่มาจาก charter นั้น: %s)\n' "$(printf '%s' "$vaultrow" | sed 's/^ *//')"
    echo "          (ย้ายเข้า archive ด้วย mv — ย้อนกลับได้ ต่างจาก delete)"
    return 1
  fi

  if [ -n "$vaultrow" ]; then
    echo "CHARTER-ONLY $t  ไม่มี tmux session · ไม่เคยมี pane · ไม่มี state ของ runtime ค้าง"
    printf '             %s\n' "$vaultrow"
    echo "             ⇒ ตอบคำถาม 'ปิดยัง' ว่า **ปิดแล้ว** — แถวนี้คือบันทึกที่ maw อ่านจากไฟล์ charter"
    echo "             ⇒ ถ้าอยากให้แถวหายด้วย ต้องย้าย/ลบ charter ซึ่ง**ไม่จำเป็น**"
    echo "          [ผิว charter ดูที่เดียว: .maw/teams/<ชื่อ>.yaml — charter ที่เก็บชื่ออื่น/ที่อื่น (เช่น lab/*/charter.json) **มองไม่เห็น**]"
    echo "teamclosed.scope: ตรวจ=tmux,list,store/vault · **ไม่ตรวจ**=git worktree/branch, ~/.maw/fleet, systemd/cron"
    return 0
  fi

  if [ -n "$charteronly" ]; then
    echo "CHARTER-ONLY $t  ไม่มี session · ไม่อยู่ใน list · ไม่มี state ของ runtime — เหลือแต่ $charteronly"
    echo "             ⇒ ตอบคำถาม 'ปิดยัง' ว่า **ปิดแล้ว** · charter คือนิยามทีม เก็บไว้ได้ตาม Nothing is Deleted"
    # 🩹 2026-08-08 [lucifer จับ รอบสอง] — เขาได้ `CLOSED` กับ restart-verify-v1 แล้ว **ท้วงเอง**
  #    ว่ามันไม่ได้สะอาดกว่า `GHOST`: charter ของทีมนั้นอยู่ที่ `ψ/lab/…/charter.json`
  #    ซึ่ง **ผิวนี้ไม่เคยมองไปตรงนั้น** ⇒ CLOSED แปลว่า *ผมไม่ได้ดูที่ที่ charter เขาอยู่*
  #    ไม่ใช่ *ไม่มี charter เหลือ* — scar เดิมของ repo นี้เป๊ะ ๆ (claim ทางลบต้องพกสโคปที่ค้น)
  echo "          [ผิว charter ดูที่เดียว: .maw/teams/<ชื่อ>.yaml — charter ที่เก็บชื่ออื่น/ที่อื่น (เช่น lab/*/charter.json) **มองไม่เห็น**]"
  echo "teamclosed.scope: ตรวจ=tmux,list,store/vault · **ไม่ตรวจ**=git worktree/branch, ~/.maw/fleet, systemd/cron"
    return 0
  fi

  # ── ไม่เจอที่ไหนเลย — แต่ต้องบอกด้วยว่าผิวไหนตรวจไม่ถึง ───────────────────
  if [ -n "$unreachable" ]; then
    echo "UNKNOWN   $t  ไม่เจอในผิวที่ตรวจได้ แต่ตรวจไม่ครบ:$unreachable"
    echo "          ⇒ **ไม่ใช่ CLOSED** — ผิวที่ตรวจไม่ถึงอาจถือทีมนี้อยู่"
    return 2
  fi
  echo "CLOSED    $t  ไม่มี tmux session · ไม่อยู่ใน list · ไม่มี state ค้างใน store/vault (ไฟล์ charter ไม่ถูกแตะ)"
  echo "          [ขอบเขต: vault + charter อ่านจาก CWD ปัจจุบัน — ทีมของ oracle อื่นอยู่ใน repo เขา]"
  # 🔑 lucifer 2026-08-06: *"ความพลาดทุกเคสวันนี้มาจากเครื่องมือที่รายงานผลโดยไม่บอกขอบเขต"*
  #    `CLOSED` ตอบแค่ "session/list/store ไม่มีแล้ว" — **ไม่ได้แปลว่าเก็บกวาดครบ**
  #    วันนี้พิสูจน์แล้วว่ามีของค้างอีก 3 ชนิดที่คำสั่งนี้มองไม่เห็นเลยสักชนิด:
  #      git worktree/branch ค้าง (lucifer 36 unmerged · ajfon 5 อยู่ 3-4 วัน)
  #      fleet reservation (130 identity ค้างจาก 143 บนเครื่องนี้)
  #      external state (prism: systemd timer 3 ตัวยิงใส่ cell ที่ตายแล้วทุก 5 นาที)
  # 🩹 2026-08-08 [lucifer จับ รอบสอง] — เขาได้ `CLOSED` กับ restart-verify-v1 แล้ว **ท้วงเอง**
  #    ว่ามันไม่ได้สะอาดกว่า `GHOST`: charter ของทีมนั้นอยู่ที่ `ψ/lab/…/charter.json`
  #    ซึ่ง **ผิวนี้ไม่เคยมองไปตรงนั้น** ⇒ CLOSED แปลว่า *ผมไม่ได้ดูที่ที่ charter เขาอยู่*
  #    ไม่ใช่ *ไม่มี charter เหลือ* — scar เดิมของ repo นี้เป๊ะ ๆ (claim ทางลบต้องพกสโคปที่ค้น)
  echo "          [ผิว charter ดูที่เดียว: .maw/teams/<ชื่อ>.yaml — charter ที่เก็บชื่ออื่น/ที่อื่น (เช่น lab/*/charter.json) **มองไม่เห็น**]"
  echo "teamclosed.scope: ตรวจ=tmux,list,store/vault · **ไม่ตรวจ**=git worktree/branch, ~/.maw/fleet, systemd/cron"
  echo "          ⇒ CLOSED = 'session ไม่อยู่แล้ว' **ไม่ใช่** 'เก็บกวาดครบ' — ดู references/teardown.md"
  return 0
}

# ── teamresidue <team> ──────────────────────────────────────────────────────
# ตอบคำถามที่ `teamclosed` **ประกาศเองว่าไม่ตอบ**: ทีมลงแล้ว เหลืออะไรทิ้งไว้
#
# 🏷️ ที่มา (2026-08-10 · prism รายงาน · ผมยืนยันเองด้วย systemctl --user):
#    บรรทัด `teamclosed.scope: … **ไม่ตรวจ**=git worktree/branch, ~/.maw/fleet, systemd/cron`
#    มีมาตั้งแต่วันที่เขียน `teamclosed` และคอมเมนต์ในไฟล์นี้เอง (บรรทัด ~526) ก็เขียนไว้ว่า
#    *"external state (prism: systemd timer ยิงใส่ cell ที่ตายแล้วทุก 5 นาที)"*
#    ⇒ **ช่องนี้ถูกตั้งชื่อไว้ตลอด แต่ไม่เคยมีโค้ดเดินไปถึง** — HALF-APPLICATION ในเครื่องมือ
#    ของผมเอง: เหตุผลอยู่ในครึ่งคอมเมนต์ ไม่อยู่ในครึ่งที่รัน (รูปเดียวกับ perm=/trust= ใน
#    oracle-team ที่ผมไปจับของคนอื่นเมื่อเช้า)
#
# 🔑 สิ่งที่ prism สอนและเป็นหัวใจของเวิร์บนี้ — **อ่านคอลัมน์ SUB ไม่ใช่ ACTIVE**
#    `[verified 2026-08-10: prism-cell-rq001-watchdog.service = failed 1,093 ครั้ง ตั้งแต่ 08-06
#     · timer ของมัน ACTIVE=active SUB=waiting · เป็น unit เดียวที่ failed ทั้งเครื่อง]`
#    timer ที่ `active/waiting` กับ service ที่ `failed` **จากภายนอกดูเหมือน "ระบบทำงานอยู่" เท่ากัน**
#    ⇒ `failed` ของ service **ไม่ดังที่ไหนเลย** ถ้าไม่มีใครถาม
#
# ⚠️ ตกได้ด้วยอะไร (ถามทุกครั้ง ไม่งั้นมันคือ echo ไม่ใช่ check):
#    rc=1 เมื่อเจอ residue จริง · rc=0 เมื่อสะอาด ⇒ ทีมที่เพิ่งยุบแล้วยังมี timer ค้าง **ต้องได้ rc=1**
#    selftest ข้อ 5g ยิงทั้งสองทิศด้วยชื่อทีมที่ไม่มีจริง (ต้องสะอาด) และด้วย pattern ที่แมตช์ยูนิตจริง
# ⛔ อ่านอย่างเดียว — ไม่ stop ไม่ disable ไม่ลบ · ของแบบนี้เป็นของบ้านเจ้าของทีม
teamresidue() {
  local t="${1:?usage: teamresidue <team-name>}" found=0 unreachable=""

  # 1) systemd --user — ผิวที่ teamclosed ประกาศว่าไม่ตรวจ
  if command -v systemctl >/dev/null 2>&1; then
    local units
    units=$(systemctl --user list-units --all --no-legend --plain 2>/dev/null \
            | grep -E -- "(^|[^a-zA-Z0-9_-])${t}([^a-zA-Z0-9_-]|$)|maw-gate-tick-${t}" || true)
    if [ -n "$units" ]; then
      # อ่าน SUB (คอลัมน์ 4) ไม่ใช่ ACTIVE (คอลัมน์ 3) — บทเรียนของ prism
      printf '%s\n' "$units" | while read -r unit load active sub _rest; do
        case "$sub" in
          failed)  printf 'teamresidue.systemd: 🔴 %s SUB=%s (ACTIVE=%s) — service ล้มเงียบ ไม่ดังที่ไหน\n' "$unit" "$sub" "$active" ;;
          waiting|running) printf 'teamresidue.systemd: ⚠️  %s SUB=%s (ACTIVE=%s) — ยังยิงอยู่\n' "$unit" "$sub" "$active" ;;
          *)       printf 'teamresidue.systemd: •  %s SUB=%s (ACTIVE=%s)\n' "$unit" "$sub" "$active" ;;
        esac
      done
      found=1
    fi
  else
    unreachable="$unreachable systemd(ไม่มี systemctl)"
  fi

  # 2) ~/.maw/fleet — entry ค้างยึดชื่อ member ไว้ ⇒ spawn ครั้งหน้าล้มด้วย ambiguity
  local fleet
  fleet=$(ls ~/.maw/fleet/ 2>/dev/null | grep -i -- "$t" || true)
  if [ -n "$fleet" ]; then
    printf 'teamresidue.fleet: 🔴 %s\n' "$fleet"
    echo   'teamresidue.fleet: ⇒ tmux kill-session ไม่ลบไฟล์นี้ · entry ค้างยังตอบชื่อ member เดิม'
    found=1
  fi

  # 3) git worktree/branch — ผิวที่สามที่ teamclosed ประกาศว่าไม่ตรวจ
  if git rev-parse --git-dir >/dev/null 2>&1; then
    local wt
    wt=$(git worktree list 2>/dev/null | grep -i -- "$t" || true)
    [ -n "$wt" ] && { printf 'teamresidue.worktree: 🔴 %s\n' "$wt"; found=1; }
  else
    unreachable="$unreachable git(cwd ไม่ใช่ repo)"
  fi

  echo "teamresidue.scope: ตรวจ=systemd --user,~/.maw/fleet,git worktree · **ไม่ตรวจ**=cron, timer ของ user อื่น, state นอกเครื่อง"
  [ -n "$unreachable" ] && echo "teamresidue.unreachable:$unreachable ⇒ ผลนี้ไม่ใช่ 'สะอาด' มันคือ 'ไม่ได้ดู'"
  if [ "$found" = 1 ]; then
    echo "RESIDUE   $t  ⇒ teardown ยังไม่จบ — **teamclosed CLOSED ตอบคนละคำถาม** (session หาย ≠ เก็บกวาดครบ)"
    echo "          ⛔ เวิร์บนี้ไม่แตะอะไรเลย — ถ้าเป็นทีมบ้านอื่น ส่งหลักฐานให้เจ้าของตัดสิน"
    return 1
  fi
  echo "NO-RESIDUE $t  ในสามผิวที่ระบุข้างบน"
  return 0
}

# ── siblings <file> [root...] ───────────────────────────────────────────────
# ถามก่อน commit: **ไฟล์ที่ผมเพิ่งแก้ มีฝาแฝดบนดิสก์ที่ผมไม่ได้แก้ไหม**
#
# 🏷️ ที่มา (2026-08-10 · prism ตั้งชื่อรูปนี้ · สามอินสแตนซ์อิสระในวันเดียว):
#    prism  — patch `9de4fd9` แก้ watchdog **ไฟล์เดียวจากสองไฟล์ที่เหมือนกัน**
#             evidence-cell ได้ · prism-cell ไม่ได้ ⇒ **failed 1,093 ครั้ง 4 วัน โดยไม่มีใครรู้**
#    ผมเอง  — `verify-check.sh` มี **5 ก๊อป** · `oracle-team/SKILL.md` มี **5 ก๊อป** และ finding
#             ของผมเองไปอยู่ก๊อปที่ deploy แล้วไม่กลับบ้าน (portia จับ)
#    atlas  — เขียนกฎ end-turn ลง `atlas-oracle/CLAUDE.md` ซึ่งไม่มี agent อื่นอ่าน
#    ⇒ **สามคน สามเครื่องมือ วันเดียว** — prism: *"ไม่ใช่เรื่องบังเอิญแล้ว"*
#
# 🔑 ต่างจาก `copy-drift-check.sh` (holmes) ตรงที่ **อันนั้นเทียบก๊อปที่คุณรู้ว่ามี**
#    อันนี้ **ไปหาก๊อปที่คุณไม่รู้ว่ามี** — ซึ่งคือทั้งหมดของ defect นี้: ถ้าคุณรู้ว่ามันมี
#    คุณคงแก้ไปแล้ว · `placement` ถามว่ากฎอยู่ในภูมิภาคที่บังคับไหม · อันนี้ถามว่า
#    **ภูมิภาคที่บังคับมีกี่ที่**
#
# ⚠️ ตกได้ด้วยอะไร: rc=1 เมื่อมีฝาแฝดที่ **เนื้อหาต่าง** (= อาจแก้ไปแค่ตัวเดียว)
#    rc=0 เมื่อไม่มีฝาแฝด หรือฝาแฝดตรงกันหมด ⇒ ทดสอบสองทิศได้จริงด้วยไฟล์จริงบนเครื่อง
# ⛔ อ่านอย่างเดียว — บอกว่ามีอะไรต่าง ไม่ตัดสินว่าอันไหนถูก และไม่ copy ให้
siblings() {
  local f="${1:?usage: siblings <file> [root...]}"; shift
  [ -r "$f" ] || { echo "siblings: อ่าน $f ไม่ได้"; return 2; }
  local base me roots
  base=$(basename "$f"); me=$(md5sum < "$f" | cut -d' ' -f1)
  if [ "$#" -gt 0 ]; then roots="$*"; else
    local reporoot; reporoot=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
    roots="$reporoot $HOME/.claude $HOME/.codex $HOME/.config"
  fi
  echo "siblings.subject: $f  md5=${me:0:10}  lines=$(wc -l < "$f")"
  echo "siblings.roots: $roots"

  local hits same=0 diff=0 out=""
  hits=$(find $roots -type f -name "$base" \
           -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | sort -u)
  local h hm
  while IFS= read -r h; do
    [ -z "$h" ] && continue
    [ "$(readlink -f "$h")" = "$(readlink -f "$f")" ] && continue
    hm=$(md5sum < "$h" | cut -d' ' -f1)
    if [ "$hm" = "$me" ]; then
      same=$((same+1)); out="$out$(printf 'siblings.same: ✓ %s\n' "$h")"$'\n'
    else
      diff=$((diff+1))
      out="$out$(printf 'siblings.DIFF: 🔴 %s  md5=%s lines=%s\n' "$h" "${hm:0:10}" "$(wc -l < "$h")")"$'\n'
    fi
  done <<EOF_SIB
$hits
EOF_SIB
  [ -n "$out" ] && printf '%s' "$out"
  echo "siblings.count: same=$same differ=$diff"
  echo "siblings.scope: ค้นตาม **ชื่อไฟล์เท่านั้น** ใน root ที่ลิสต์ · **ไม่เจอ**=ฝาแฝดที่ถูกเปลี่ยนชื่อ, อยู่นอก root, เนื้อหาซ้ำแต่คนละชื่อ"
  echo "siblings.blindspot: 🔴 ฝาแฝดที่ **ถูก rename ตอน port** (เช่น <teamA>-x.py / <teamB>-x.py) ผ่านฉลุย"
  echo "                    ⇒ นั่นคือ **เคสที่สร้างเวิร์บนี้ขึ้นมา** (prism 2026-08-10) — ใช้ \`twinfix A B\` แทน"
  if [ "$diff" -gt 0 ]; then
    echo "SIBLING-DRIFT $base  ⇒ มีฝาแฝด $diff ตัวที่เนื้อหาต่าง — **แก้ตัวเดียวจากหลายตัวหรือเปล่า**"
    echo "              ⇒ ไม่ได้แปลว่าต้องซิงก์ทุกตัว — บางตัวตั้งใจให้ต่าง (worktree เก่า, appendix)"
    echo "              ⇒ แปลว่า **ต้องตัดสินใจอย่างรู้ตัว** ไม่ใช่ไม่รู้ว่ามันมีอยู่"
    return 1
  fi
  echo "NO-SIBLING-DRIFT $base"
  return 0
}

# ── twinfix <fileA> <fileB> ─────────────────────────────────────────────────
# ถามคำถามที่ `diff` ตอบไม่ได้: **มี fix ที่ลงข้างเดียวไหม**
#
# 🏷️ ที่มา (2026-08-10 · prism · หลังจาก `siblings` ของผม **จับเคสของเขาไม่ได้**):
#    ฝาแฝดของผม = ชื่อเดียวกัน คนละ path ⇒ `siblings` เจอ
#    ฝาแฝดของเขา = **คนละชื่อ เนื้อเดียวกัน** (`evidence-cell-rq001-watchdog.py` /
#    `prism-cell-rq001-watchdog.py`) ⇒ `siblings` **ผ่านฉลุยกับไฟล์ที่ล้ม 1,093 ครั้ง**
#    ⇒ 🪞 **half-application ของเวิร์บที่ผมเพิ่งสร้างเพื่อแก้ half-application** — และ
#      เคสที่มันไม่ครอบ **คือหนึ่งในสามเคสที่ผมยกมาเป็นเหตุผลสร้างมัน**
#      (การประกาศ scope ไว้ **ไม่ได้ช่วย** เมื่อสิ่งที่ถูกกันออกคือโจทย์ตั้งต้น)
#
# 🔑 prism พิสูจน์ว่า **`diff` เป็นเครื่องมือผิด**: เขา diff ฝาแฝด 5 คู่ → ต่างกัน 4 คู่
#    (4/28/100/186 บรรทัด) **แต่ส่วนใหญ่คือ PORT-DELTA ที่ตั้งใจ** ⇒ ถ้าเชื่อ diff ต้องไล่ซ่อม 4 คู่
#    ⇒ `diff` ตอบ *"ต่างไหม"* · คำถามจริงคือ *"มี fix ที่ลงข้างเดียวไหม"*
#    ⇒ เกณฑ์ที่แยกได้จริงคือ **commit ที่แตะฝาแฝดข้างเดียว** — เขาใช้แล้วเจอตัวที่สอง
#      (`b8f90fa` scope caveat ลง prism-cell ข้างเดียว · evidence-cell ไม่เคยได้ ⇒ ledger
#      ของ cell นั้นอ่านแข็งกว่าที่มันรองรับมาตลอด)
#
# ⚠️ ตกได้ด้วยอะไร: rc=1 เมื่อมี commit ฝั่งเดียว · rc=0 เมื่อทุก commit แตะทั้งคู่
# ⛔ อ่านอย่างเดียว · และ **ไม่ได้แปลว่าต้อง port ทุกอัน** — ดู `twinfix.caveat` ท้ายผล
twinfix() {
  local a="${1:?usage: twinfix <fileA> <fileB>}" b="${2:?usage: twinfix <fileA> <fileB>}"
  local repo; repo=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "twinfix: cwd ไม่ใช่ git repo"; return 2; }
  local la lb
  la=$(git log --format=%h -- "$a" 2>/dev/null); lb=$(git log --format=%h -- "$b" 2>/dev/null)
  [ -n "$la$lb" ] || { echo "twinfix: ไม่มีประวัติ git ของทั้งสองไฟล์ (ยัง untracked?)"; return 2; }
  local onlyA onlyB
  onlyA=$(comm -23 <(printf '%s\n' "$la" | sort -u) <(printf '%s\n' "$lb" | sort -u) | tr '\n' ' ')
  onlyB=$(comm -13 <(printf '%s\n' "$la" | sort -u) <(printf '%s\n' "$lb" | sort -u) | tr '\n' ' ')
  echo "twinfix.a: $a  commits=$(printf '%s\n' "$la" | grep -c .)"
  echo "twinfix.b: $b  commits=$(printf '%s\n' "$lb" | grep -c .)"
  echo "twinfix.onlyA: ${onlyA:-<none>}"
  echo "twinfix.onlyB: ${onlyB:-<none>}"
  echo "twinfix.scope: ตรวจ **ประวัติ git ของสอง path ที่คุณระบุเอง** · **ไม่ตรวจ**=เนื้อหา, ไฟล์ที่ยังไม่ commit, ฝาแฝดตัวที่สามที่ไม่ได้ระบุ"
  if [ -n "$onlyA$onlyB" ]; then
    echo "LOPSIDED  ⇒ มี commit ที่แตะฝาแฝดข้างเดียว — **อ่านมันทีละอัน** ก่อนสรุปว่าต้อง port"
    echo "          ⇒ 🔑 prism 2026-08-10: **port หลักการ ไม่ port การวัด** — การวัดผูกกับ engine"
    echo "             ที่วัดมัน · ฝาแฝดคนละ engine รับหลักการได้ **รับตัวเลขไม่ได้**"
    echo "twinfix.caveat: commit ฝั่งเดียว ≠ defect เสมอ — PORT-DELTA ที่ตั้งใจก็โผล่ที่นี่"
    return 1
  fi
  echo "BALANCED  ทุก commit แตะทั้งคู่"
  return 0
}

# ── enginereg <engine-name> ─────────────────────────────────────────────────
# "engine name นี้ลงทะเบียนไว้จริงไหม" — คำถามเดียวที่ตัดสินว่า charter จะได้ engine ที่ขอ
#
# 🏷️ ที่มา (2026-08-06 · loom รายงาน 2026-08-01 แล้วเราถือไว้ 5 วัน):
#    `maw team up` ส่งต่อ **เฉพาะชื่อ** engine → `maw wake -e <name>`
#    `wake_resolve_command_from_config` (wake_engine_command.rs:67) ไล่ตามลำดับ:
#      1) commands.<engine>          ← ที่เดียวที่ engine ของ charter มีผล
#      2) commands.<window-name>     ← ชื่อ window ชนะ engine ที่ขอ ถ้าข้อ 1 ไม่เจอ
#      3) commands.<oracle>-oracle
#      4) glob บนชื่อ window (`banker*`, `verifier*`, `researcher*` …)
#      5) commands.<engine-จาก-defaults> หรือชื่อ engine ดิบ ๆ
#      6) commands.default
#    ⇒ ถ้าข้อ 1 ไม่เจอ **ไม่มี error ไม่มี warning exit 0** แต่ pane ได้ engine คนละตัว
#    `[verified 2026-08-06 · maw-rs 325db65]`
#      maw wake coder-1 --dry-run -e codex-xhigh → claude --model claude-opus-5 --continue
#      maw wake hermes  --dry-run -e codex-xhigh → hermes --yolo        ← ชื่อ window ชนะ
#      maw wake hermes  --dry-run -e codex       → codex …              ← ข้อ 1 เจอ จึงชนะ
# valid-if: bash ψ/teams/scripts/verify-check.sh enginereg codex   → REGISTERED
# 🔴 `[dir]` **ไม่ใช่ของประดับ**: maw resolve `commands` แบบ dir-aware **เทียบ path ของ
#    สมาชิกคนนั้น** ไม่ใช่ cwd ของคนสั่ง (`wake_engine_command.rs:17,135-137` · #600)
#    ⇒ alias ที่อยู่ใน `<repo>/.maw/` **มองไม่เห็นจาก worktree นอก repo**
#    `[verified 2026-08-06]`  wake … -e codex-sol                → codex --model gpt-5.6-sol
#                             wake … -e codex-sol --repo-path /tmp → claude --model claude-opus-5
#    ⇒ ถามจาก cwd ของ lead แล้วตอบว่า REGISTERED = **false-PASS** สำหรับสมาชิกที่ worktree อยู่นอก repo
# ── _vc_dead_key <engine-name> <dir> ────────────────────────────────────────
# ตอบคำถามที่ `enginereg` เดิม **แยกไม่ออก**: UNREGISTERED เพราะ *ไม่เคยมี* หรือเพราะ
# *มีแต่ในไฟล์ที่ maw ไม่อ่าน*  — สองอย่างนี้ FAIL หน้าตาเหมือนกัน แต่ทางแก้คนละอัน
#
# 🏷️ ที่มา: lucifer 2026-08-07 วัดเองหลัง RETRACT ไฟล์ตาย — **9 คีย์อยู่เฉพาะใน
#    `~/.config/maw/maw.config.json`** รวม `codex-xhigh` ที่ charter ของเขาขอ **57 ไฟล์**
#    เขา (และผม) อ่าน 64/65 FAIL ว่า "engine ไม่ได้ลงทะเบียน" ⇒ ทางแก้ที่ได้คือ
#    "เพิ่มคีย์ให้ 57 charter" ทั้งที่ของจริงคือ "ย้าย 9 บรรทัด"
#    ⇒ **ข้อสรุปถูก แต่เหตุผลผิด ⇒ ทางแก้ผิด** และเครื่องมือมองไม่เห็นเพราะมันดูแค่ merged config
#
# 🔎 วิธีตัดสินว่าไฟล์ไหน "ตาย": **ถาม `maw config sources` ว่ามันลิสต์ไฟล์ไหนบ้าง**
#    ไม่ใช่ reimplement กฎตั้งชื่อ (`maw.config.<เลข>.json`) เอง — ถ้ากฎเปลี่ยนวันหน้า
#    การถาม maw จะตามเปลี่ยนเอง ส่วนสำเนากฎจะ drift เงียบ ๆ (บทเรียนจาก atlas T4543)
#
# 🚨 เงื่อนไขที่ต้องจริงพร้อมกันถึงจะยิง (ไม่งั้นมันกล่าวหาผิด):
#    (1) `enginereg` บอก UNREGISTERED อยู่แล้ว = merged config **ไม่มีคีย์นี้จริง**
#    (2) ไฟล์นั้น **ไม่อยู่ใน `maw config sources`** ⇒ maw ไม่อ่าน
#    (3) ไฟล์นั้น **มี `commands.<e>` เป็น string ไม่ว่าง** ⇒ คีย์มีอยู่จริงในนั้น
#    ⇒ ถ้า `maw config sources` อ่านไม่ได้ **คืนค่าว่าง (เงียบ)** ไม่ใช่เดาว่าตาย —
#      การกล่าวหาผิดแพงกว่าการไม่พูด
# valid-if: bash ψ/teams/scripts/verify-check.sh selftest   → case 11 ต้องผ่าน
_vc_dead_key() {
  local e="$1" dir="${2:-.}"
  while [ -n "$dir" ] && [ ! -d "$dir" ]; do
    local up; up=$(dirname -- "$dir"); [ "$up" = "$dir" ] && break; dir="$up"
  done
  [ -d "$dir" ] || dir="."
  local live; live=$( cd "$dir" 2>/dev/null && maw config sources 2>/dev/null ) || return 0
  [ -n "$live" ] || return 0
  local abs; abs=$( cd "$dir" 2>/dev/null && pwd -P ) || return 0
  MAW_LIVE_SOURCES="$live" python3 -c '
import json,os,sys
e=sys.argv[1]; start=sys.argv[2]
live=set()
for ln in os.environ.get("MAW_LIVE_SOURCES","").splitlines():
    for tok in ln.split():
        if tok.startswith("/"): live.add(os.path.realpath(tok))
cands=[]
d=start
while True:
    cands.append(os.path.join(d,".maw"))
    nd=os.path.dirname(d)
    if nd==d: break
    d=nd
cands.append(os.path.expanduser("~/.config/maw"))
seen=set()
for cd in cands:
    if not os.path.isdir(cd): continue
    for fn in sorted(os.listdir(cd)):
        if not (fn.startswith("maw.config") and fn.endswith(".json")): continue
        p=os.path.realpath(os.path.join(cd,fn))
        if p in live or p in seen: continue
        seen.add(p)
        try: cmds=json.load(open(p)).get("commands")
        except Exception: continue
        if not isinstance(cmds,dict): continue
        v=cmds.get(e)
        if isinstance(v,str) and v.strip():
            print("%s\n  commands.%s = %s" % (p,e,v.strip()))
' "$e" "$abs" 2>/dev/null
}

enginereg() {
  local e="${1:?usage: enginereg <engine-name> [dir]}" dir="${2:-.}" cmd
  # ถ้า dir ยังไม่มีจริง (worktree ที่ยังไม่ได้สร้าง) ใช้บรรพบุรุษที่ใกล้ที่สุดที่มีอยู่ —
  # ผลเท่ากัน เพราะ layer chain สร้างจากการไล่ขึ้นบรรพบุรุษอยู่แล้ว
  while [ -n "$dir" ] && [ ! -d "$dir" ]; do
    local up; up=$(dirname -- "$dir"); [ "$up" = "$dir" ] && break; dir="$up"
  done
  [ -d "$dir" ] || dir="."
  cmd=$( cd "$dir" 2>/dev/null && maw config 2>/dev/null | python3 -c '
import json,sys
try: cfg=json.load(sys.stdin)
except Exception: sys.exit(3)
c=cfg.get("commands")
if not isinstance(c,dict): sys.exit(3)
v=c.get(sys.argv[1])
if not isinstance(v,str) or not v.strip(): sys.exit(1)
print(v.strip())
' "$e" )
  case $? in
    0) echo "REGISTERED   $e   [scope: $dir]"; echo "             $cmd"; return 0 ;;
    1) echo "UNREGISTERED $e   [scope: $dir]  ⚠ charter ที่ขอ engine นี้จะได้ engine อื่นเงียบ ๆ (ชื่อ window → glob → default)"
       local _dead; _dead=$(_vc_dead_key "$e" "$dir")
       if [ -n "$_dead" ]; then
         echo "             🔴 DEAD-LAYER — คีย์นี้ **มีอยู่** ในไฟล์ที่ maw ไม่อ่าน:"
         printf '%s\n' "$_dead" | sed 's/^/               /'
         # 🏷️ lucifer 2026-08-07 (20 นาทีหลังผม ship): ป้ายนี้ **จริง** แต่คำสั่งแก้ที่ผมพ่วงมา
         #    ("ย้ายบรรทัดนั้น") **ผิดสำหรับเคส (B)** — codex-medium จาก /tmp ติดป้ายนี้
         #    ทั้งที่ตัวจริงอยู่ใน live layer ของ lucifer อยู่แล้ว ⇒ ใครทำตามจะไปย้ายบรรทัด
         #    ในไฟล์ตาย แล้ว **ปัญหาจริง (layer scope แคบเกิน) ยังอยู่ครบ**
         #    ⇒ *"DEAD-LAYER กำลังจะเป็นพาหะตัวใหม่แทน UNREGISTERED — ป้ายที่ถูกกว่าเดิม
         #       แต่ยังกว้างกว่าความจริง ก็ยังพาคนไปแก้ผิดที่ได้"*
         #    🔑 สิ่งที่เครื่องมือนี้ **รู้จริง** คือ "คีย์อยู่ในไฟล์ที่ไม่ถูกอ่าน" เท่านั้น ·
         #       มัน **ไม่รู้** ว่าคีย์นี้อยู่ใน live layer ที่อื่นบนเครื่องไหม (มองไม่เห็นจาก path นี้
         #       ตามนิยาม) ⇒ **จึงห้ามสั่งการแก้ · ให้แยกสองเคสแล้วส่งคืนคนอ่าน**
         echo "             ⚠️ **ยังบอกไม่ได้ว่าแก้ทางไหน — สองเคสนี้หน้าตาเหมือนกันจากตรงนี้**:"
         echo "               (A) อยู่ **เฉพาะ** ในไฟล์ตาย    ⇒ แก้ = **ย้าย** บรรทัดข้างบนไป layer ที่ maw อ่าน"
         echo "               (B) อยู่ใน **live layer ที่อื่นด้วย** ⇒ ไฟล์ตายเป็น **ตัวหลอก** ·"
         echo "                   ปัญหาจริงคือ **layer นั้นแคบเกินกว่าจะครอบ path นี้** ⇒ ขยาย scope"
         echo "                   หรือย้าย path ของสมาชิก **ไม่ใช่ไปยุ่งกับไฟล์ตาย**"
         echo "               แยกก่อนลงมือ — รันจากที่ที่คุณคิดว่าคีย์นี้เคยใช้ได้:"
         echo "                   maw config explain commands.$e"
         echo "               resolve ได้ที่ไหนสักที่ = (B) · FINAL null ทุกที่ = (A)"
       else
         echo "             แก้: เพิ่มคีย์ใน .maw/maw.config.<N>.json ที่เป็น **บรรพบุรุษของ path สมาชิกคนนี้**"
       fi
       return 1 ;;
    *) echo "UNKNOWN      $e  อ่าน merged config ไม่ได้ (maw config / python3) — **ตอบไม่ได้ ไม่ใช่ผ่าน**"
       return 2 ;;
  esac
}

# ── enginecheck <charter.yaml|team-name> ────────────────────────────────────
# ตอบว่า "สมาชิกแต่ละคนจะได้ harness+model ที่ charter ขอจริงไหม" **ก่อน** spawn
#
# ⚠️ เหตุผลที่ต้องมีตัวนี้แทนการดู `maw team up --dry-run`:
#    dry-run พิมพ์ engine ที่มันจะ **ขอ** ไม่ใช่ engine ที่จะ **ได้** — มันสะท้อน charter กลับมา
#    เฉย ๆ `[verified 2026-08-06]` charter เขียน `engine: codex-xhigh, model: gpt-5.6-sol`
#      maw team up … --dry-run  → engine=codex-xhigh              ← รายงาน
#      maw wake     … --dry-run → claude --model claude-opus-5 …  ← ของจริง
#    **การตรวจที่ยืนยัน claim ที่ตัวมันเองไม่ได้ทดสอบ** = คลาสเดียวกับ VERIFY-THE-CHECK ทั้งเล่ม
#
# ⚠️ `model:` ใน charter **ไม่เคยถึง pane** — แต่กฎมีสองครึ่ง ไม่ใช่ครึ่งเดียว
#    `[verified 2026-08-06 · team_up_helpers.rs:235 · atlas verify ซ้ำเป็นอิสระ]`
#      engine = opts.engine.or_else(member.engine).or_else(member.model).unwrap_or("claude")
#    · **มี `engine:`** ⇒ `model:` ตายจริง (validate แล้วทิ้ง `team_up_apply.rs:186`)
#    · **ไม่มี `engine:`** ⇒ 🔴 **model string กลายเป็น *ชื่อ engine*** ⇒ `wake -e <model>`
#      ⇒ ไม่มีใน `commands` ⇒ fallthrough เงียบ **แน่นอน 100%** — แย่กว่าถูกทิ้ง
#    · argv ที่ส่งให้ wake ไม่มี `--model` (`team_up_apply.rs:149` + unit test `:251`)
#      · `maw wake` ไม่มีแฟลก `--model` ทั้งไบนารี
#    ⇒ **model แสดงออกได้ที่เดียวคือในสตริงคำสั่งของ engine alias**
#    🩹 บล็อกนี้เคยเขียนแค่ครึ่งแรก ("validate แล้วทิ้ง · ไม่มีผลเลย") จนถึง 2026-08-06 —
#       **atlas จับได้ว่าเป็นผิวที่ 4 ของ claim เดียวกันที่เราแก้ไปแล้ว 3 ผิว**
#       (เนื้อ skill · description ของ skill · packet ที่ส่งไป 6 คน) ⇒ แก้ claim ต้องไล่ทุกผิว
#
# ⚠️ ขอบเขตที่ตอบไม่ได้ (พิมพ์เอง ไม่เงียบ):
#    · ตอบไม่ได้ว่า "บัญชีเสิร์ฟ model นี้ไหม" — ชื่อ model ผิดจะพังข้างใน engine หลัง pane ขึ้น
#    · ตอบไม่ได้ว่า worker ได้ prompt ไหม (ดู learning 2026-08-04 charter-field-parsed)
# ── ขอบเขตถาวรของเครื่องมือนี้ — คงที่ทุกรอบโดยธรรมชาติ ไม่ใช่ผลการวัด ───────
# 🏷️ ajfon 2026-08-06 (รอบ 4): สามข้อนี้เครื่องมือนี้วัดไม่ได้ไม่ว่ารันกี่ครั้ง ⇒ มันคือ
#    **คำประกาศขอบเขต** ไม่ใช่ **ผลการวัดรอบนี้** ⇒ ต้องอยู่คนละ namespace กับสิ่งที่ผันแปร
#    ไม่งั้นกฎที่ผูกกับ "มี UNVERIFIED ไหม" จะเป็นจริงตลอดกาลและแยกแยะอะไรไม่ได้
VC_SCOPE_LINE='enginecheck.scope: out-of-scope=model-served,prompt-delivery,account-quota'

# ── enginelist [dir] ────────────────────────────────────────────────────────
# "มี alias อะไรให้ใช้บ้างจากตรงนี้" — คำถามแรกของคนที่เข้ามาใน fleet ที่มีอยู่แล้ว
# 🏷️ atlas 2026-08-06 (finding #2, จุดที่เขาต้องเดามากที่สุดในการรีวิวทั้งรอบ):
#    เอกสารบอกวิธีหา *model* name แต่ **ไม่มีที่ไหนบอกวิธีดู *alias* ที่ลงทะเบียนแล้ว**
#    · `maw config sources` = บอกไฟล์ ไม่ใช่ชื่อ · `maw config` = ทิ้งทุกอย่างออกมา
#    · `engineone` = ทดสอบ **ชื่อเดียวที่ต้องรู้อยู่ก่อนแล้ว**
#    ⇒ เขาต้องไปเปิด ~/.config/maw/maw.config.50.json ดิบ ๆ เพื่อรู้ว่า codex ลงทะเบียนแล้ว
#      และ `commands.claude` ไม่ได้ลงทะเบียน
# ตัดคีย์ที่ไม่ใช่ engine ออก: glob (`verifier*`) และ `_`-prefixed helper
enginelist() {
  local dir="${1:-.}"
  while [ -n "$dir" ] && [ ! -d "$dir" ]; do
    local up; up=$(dirname -- "$dir"); [ "$up" = "$dir" ] && break; dir="$up"
  done
  [ -d "$dir" ] || dir="."
  # 🏷️ tars 2026-08-06 (v3): `enginelist.count` เดิมไม่บอกว่านับจากที่ไหน ⇒ ผมส่งเลข "27"
  #    ให้เขาโดยบอกว่า "เลขของเครื่องนี้" **ผิด — มันคือเลขของ repo ผม** บ้านอื่นเห็น 19/14
  #    ส่วนต่าง 8 คือ alias ใน .maw/maw.config.60.json ของผมเอง
  #    ⇒ **คลาสเดียวกับที่ thread นี้เกิดมาเพื่อฆ่า**: เลขที่อ้างโดยไม่มีสโคป คนอื่นรันแล้วไม่ตรง
  #      แล้วสรุปว่า "alias หาย" หรือ "เครื่องมือพัง" ทั้งที่ทั้งสองเลขถูก
  #    ⇒ และมันเกิดกับ *ผู้เขียนเครื่องมือ ในข้อความที่อธิบายเครื่องมือ* ⇒ แก้ที่ output ไม่ใช่ที่วินัย
  local abs; abs=$(cd "$dir" 2>/dev/null && pwd) || abs="$dir"
  printf 'enginelist.scope: dir=%s layers=%s\n' "$abs" \
    "$( ( cd "$dir" 2>/dev/null && maw config sources 2>/dev/null ) \
        | awk '{printf "%s%s:%s", (NR>1?",":""), $1, $NF}' )"
  ( cd "$dir" 2>/dev/null && maw config 2>/dev/null ) | python3 -c '
import json,sys
try: cfg=json.load(sys.stdin)
except Exception:
    print("UNKNOWN  อ่าน merged config ไม่ได้ — **ตอบไม่ได้ ไม่ใช่ว่าไม่มี**"); sys.exit(2)
c=cfg.get("commands")
if not isinstance(c,dict):
    print("UNKNOWN  ไม่มี commands ใน merged config"); sys.exit(2)
def model_of(v):
    p=v.split()
    for i,t in enumerate(p):
        if t in ("--model","-m") and i+1<len(p): return p[i+1]
        if t.startswith("--model="): return t.split("=",1)[1]
    return ""
usable=[(k,v) for k,v in sorted(c.items())
        if isinstance(v,str) and v.strip() and not k.startswith("_") and "*" not in k]
globs=[(k,v) for k,v in sorted(c.items())
       if isinstance(v,str) and v.strip() and "*" in k and k!="default"]
print("enginelist.count: %d usable=%d glob=%d" % (len(usable)+len(globs), len(usable), len(globs)))
# 🔴 lucifer 2026-08-07: คำเตือน glob เคยอยู่ **ท้ายลิสต์ 27 บรรทัด** — คนที่กำลังตั้งชื่อ role
#    ต้องเห็นก่อนลิสต์ ไม่ใช่หลัง ⇒ ยกขึ้นมาไว้ใต้ count
if globs:
    print("enginelist.HIJACK-RISK: %d glob key ด้านล่างแมตช์ **ชื่อ role/window** ที่ขั้น 4 ของ chain" % len(globs))
    print("  ⇒ ชิงไปก่อน commands.default **ไม่ว่า charter จะขอ engine อะไร**")
    print("  ⇒ เคสจริง 2026-08-07: role ชื่อ `verifier` + charter สั่ง claude/sonnet-5")
    print("     โดน `verifier*` ⇒ บูตเป็น thclaws zai/glm-5.1 — คนละ vendor คนละ CLI")
    print("  ⇒ ตั้งชื่อ role ให้ **ไม่ขึ้นต้น** ด้วย pattern เหล่านี้ หรือ pin ด้วย alias ที่ลงทะเบียนจริง")
    for k,_ in globs:
        print("     ⚠ %s" % k)
for k,v in usable:
    print("enginelist.engine: %s model=%s cmd=%s" % (k, model_of(v) or "-", v))
for k,v in globs:
    print("enginelist.glob: %s model=%s cmd=%s" % (k, model_of(v) or "-", v))
' || return $?
  # 🏷️ tars 2026-08-06: เวอร์ชันแรกของฟังก์ชันนี้ **ตัด glob ทิ้ง** ด้วยเหตุผลที่ถูกทางเทคนิค
  #    (มันแมตช์ *ชื่อ window* ไม่ใช่ชื่อ engine) — **แต่ผลคือเครื่องมือที่มีไว้ทำให้ resolution
  #    มองเห็นได้ กลับซ่อนขั้นที่ 4 ของ chain ทิ้ง ซึ่งเป็นคำอธิบายทั้งหมดของการบูตผิด**
  #    หลักฐานของเขา: banker ขอ `claude` ได้ **codex** (glob `banker*`) · verifier ขอ
  #    `forge-oracle` ได้ **thclaws** (glob `verifier*`) · researcher ขอ `codex-full` ได้ codex
  #    ⇒ คนที่บูตผิดแล้วเปิด enginelist หาสาเหตุ จะไม่เห็นสาเหตุ และจะสรุปตามเอกสารว่า
  #      "ตกไปเป็น claude" ซึ่งผิดทั้งสามแถว ⇒ แสดงแยกหัวข้อ ไม่ตัดทิ้ง
  echo "[ขอบเขต: การมีชื่ออยู่ในลิสต์ ไม่ได้แปลว่าบัญชีเสิร์ฟ model นั้นได้ — ต้อง boot ถึงจะรู้]"
}

# ── bootverify <session> ────────────────────────────────────────────────────
# ตอบข้อที่ทั้งฟลีตยังไม่มีใครพิสูจน์: **pane boot เป็น engine ที่ขอไปจริงไหม**
# และแยกให้ชัดว่า **process ถูก ≠ agent พร้อมรับงาน** (2026-08-06: /proc บอกว่า codex ถูกตัว
# แต่จอเป็นหน้า "Update available!" ⇒ Enter เปล่าไปกด "Update now" อัปทั้งเครื่อง)
# ⚠️ read-only ล้วน — ไม่ส่ง key ไม่กด Enter ไม่แตะอะไรใน pane
# ── _vc_argv_basename <cmdline> <n> ─────────────────────────────────────────
# คืน basename ของ **อาร์กิวเมนต์ที่ n ที่ไม่ใช่แฟลกและไม่ใช่ VAR=VAL** จาก cmdline หนึ่งก้อน
#
# 🔴 2026-08-07 · แทนที่ท่าเดิม `… | awk '{print $1}' | xargs -r basename` ซึ่ง **พังเงียบ**
#    กับ pane ของ codex ทุกตัวบนเครื่องนี้ — และพังมาก่อนเทสต์นี้จะมีอยู่:
#    cmdline ของ codex **มีขึ้นบรรทัดใหม่** (brief ถูกส่งเป็น argv) ⇒ `awk '{print $1}'`
#    พิมพ์ `$1` ของ **ทุกบรรทัด** ⇒ `xargs` ยัดให้ `basename` หลายตัว ⇒ `extra operand`
#    ⇒ **stderr ถูก `2>/dev/null` กลืน · ผลลัพธ์ว่าง** ⇒ `proc=?` มาตลอดโดยไม่มีใครสังเกต
#    ⇒ `xargs` ยัง **แกะเครื่องหมายคำพูด** ด้วย ⇒ brief ที่มี `'` เดี่ยว ๆ ทำให้มันตายอีกทาง
#    🔑 นี่คือ pipeline-rc trap เวอร์ชันที่เงียบกว่า: **ไม่ใช่ rc ที่โกหก แต่เป็น output ที่หายไป**
#    ⇒ ใช้ bash ล้วน ไม่มี subprocess ที่ตีความ quote/บรรทัดแทนเรา
# 🩹 2026-08-07 (ที่ปรึกษาจับ · ผมยืนยันแล้ว) — เวอร์ชันแรกตัดเหลือ **บรรทัดแรก** (`${1%%$'\n'*}`)
#    ⇒ **เปลี่ยนความหมายของ `probe_bin` ใน `enginecheck` เงียบ ๆ** ท่าเดิมสแกน **ทั้งสตริง**
#    `[verified]` input `"MAW_SESSION_WINDOW=x\nclaude --model y"` → ท่าเดิม `claude` · ของผม **ว่าง**
#    ⇒ `probe_bin` ว่างไหลเข้าเงื่อนไข WARN-vs-FAIL ที่อยู่ใต้มันพอดี ⇒ **คำตอบของ verb ที่ 5 บ้านใช้**
#    ⇒ ผมยืนยัน regression ด้วย charter **เดียว** ที่ PASS — ซึ่ง probe ของมัน resolve ที่บรรทัดแรก
#       **การทดสอบที่ไม่มีเคสที่ทำให้ต่าง ไม่ได้ทดสอบความต่าง** (guard ข้อ 4 กับตัวเอง อีกครั้ง)
#    ⇒ สแกนทั้งสตริง (IFS ปกติแยกที่ newline อยู่แล้ว) · ปัญหาเดิมของ bootverify คือ
#       **ส่งหลาย token ให้ `basename`** ไม่ใช่การสแกนหลายบรรทัด ⇒ คืน token เดียวเสมอก็พอ
_vc_argv_basename() {
  local line="$1" n="${2:-1}" tok i=0
  for tok in $line; do
    case "$tok" in
      -*) continue ;;      # แฟลก
      *=*) continue ;;     # VAR=VAL นำหน้าคำสั่ง
    esac
    i=$((i+1))
    [ "$i" = "$n" ] && { printf '%s' "${tok##*/}"; return 0; }
  done
  return 1
}

# ── mawverb <subcommand...> ─────────────────────────────────────────────────
# "คำสั่ง `maw team <x>` ที่ฉันกำลังจะรัน มีอยู่จริงไหม" — ถามก่อนรัน ไม่ใช่หลังพัง
#
# 🔴 2026-08-07 · เจอจากการไล่ inventory คำสั่งทุกตัวที่ skill สั่งให้ผู้อ่านรัน
#    **`maw` กับ `maw team` ใช้ธรรมเนียมตรงข้ามกันสำหรับคำสั่งที่ไม่มีอยู่** `[verified]`
#
#      maw zzz-not-a-verb    → rc=2 · "unknown command" · **stderr**
#      maw team zzz-nope     → **rc=0** · usage ทั้งก้อน · **stdout** · stderr **ว่าง**
#
#    ⇒ 🔑 **`maw team <พิมพ์ผิด> && echo OK` พิมพ์ OK** · และ guard ที่เขียนว่า
#       `maw team up … || fail` **ไม่มีวันยิง** ถ้า verb พิมพ์ผิด — มันจะ "สำเร็จ" เงียบ ๆ
#       โดยไม่ได้ทำอะไรเลย ⇒ ทีมไม่ถูกสร้าง แต่สคริปต์เดินต่อเหมือนสร้างแล้ว
#    ⇒ นี่คือรูปเดียวกับ `maw team status <ทีมที่ไม่มี> → rc=0` ที่บันทึกไว้แล้ว
#       **แต่กว้างกว่า**: อันนั้นคือ verb เดียว อันนี้คือ **ทุก verb ที่พิมพ์ผิด**
#    ⇒ และเป็นตัวอย่างที่สองของกฎในบ้านนี้: **อ่าน rc *และ* output ทุกคำสั่ง
#       อย่าเดารูปแบบจากคำสั่งที่เพิ่งเจอ — แม้แต่ binary เดียวกันก็ไม่เหมือนกันข้ามระดับ**
# valid-if: bash ψ/teams/scripts/verify-check.sh selftest → case 16 ต้องผ่าน
mawverb() {
  local sub="${1:?usage: mawverb <team-subcommand>}"
  local usage
  usage=$(maw team zz-vc-probe-not-a-verb 2>&1 | grep -m1 '^usage: maw team')
  if [ -z "$usage" ]; then
    echo "UNKNOWN   อ่านลิสต์ subcommand จาก maw ไม่ได้ — **ตอบไม่ได้ ไม่ใช่ผ่าน**"
    return 2
  fi
  # ดึงเฉพาะในวงเล็บ <a|b|c> แล้วเทียบแบบตรงตัว
  local list="${usage#*<}"; list="${list%%>*}"
  case "|$list|" in
    *"|$sub|"*) echo "OK        maw team $sub"; return 0 ;;
  esac
  echo "✗ NOSUCH  'maw team $sub' ไม่มีอยู่ใน subcommand list ของ binary นี้"
  # 🩹 บรรทัดนี้เคยเขียน `|| fail` ไว้ใน backtick ในสตริง double-quote ⇒ **shell รันมันเป็นคำสั่ง**
  #    ⇒ ผู้อ่านเห็น "⇒  ของคุณจะไม่ยิง" (คำหาย) + syntax error แปะหน้า — **scar เดียวกับที่ทำ
  #    ข้อความหา peer เพี้ยนเมื่อเช้านี้ ครั้งที่ 3 ของวัน และคราวนี้อยู่ใน guard เอง**
  echo '          ⚠️ maw team จะ **คืน rc=0 และพิมพ์ usage ลง stdout** ⇒ `|| fail` ของคุณจะไม่ยิง'
  echo "          มีจริง: $list"
  return 1
}

bootverify() {
  local sess="${1:?usage: bootverify <session>}"
  binexists tmux >/dev/null 2>&1 || { echo "UNKNOWN   ไม่มี tmux"; return 2; }
  tmux has-session -t "=$sess" 2>/dev/null || { echo "FAIL      ไม่มี session '$sess'"; return 1; }

  local wins w pid child cmd screen model rc=0 n=0 unpinned=0 queued=0
  wins=$(tmux list-windows -t "=$sess" -F '#{window_name}' 2>/dev/null)
  [ -n "$wins" ] || { echo "FAIL      session '$sess' ไม่มี window"; return 1; }

  while IFS= read -r w; do
    [ -n "$w" ] || continue
    n=$((n+1))
    pid=$(tmux list-panes -t "=${sess}:${w}" -F '#{pane_pid}' 2>/dev/null | head -1)
    cmd=""
    # 🩹 pane process อาจ **เป็นตัว engine เอง** (tmux รันคำสั่งตรง ๆ ไม่ผ่าน shell)
    #    หรือเป็น shell ที่มี engine เป็นลูก (maw wake ผ่าน bash) — ต้องดูทั้งสองแบบ
    #    [เจอตอนเทสต์: เวอร์ชันแรกเดินแต่ลูก ⇒ รายงาน PROCESS-GONE ให้ pane ที่รัน engine อยู่จริง]
    if [ -r "/proc/${pid:-0}/cmdline" ]; then
      cmd=$(tr '\0' ' ' < "/proc/${pid}/cmdline")
    fi
    case "$(_vc_argv_basename "$cmd" 1)" in
      bash|sh|zsh|-bash|""|login)
        cmd=""   # pane เป็นเชลล์เปล่า → หา engine จากลูกแทน
        for child in $(pgrep -P "${pid:-0}" 2>/dev/null); do
          [ -r "/proc/$child/cmdline" ] || continue
          cmd=$(tr '\0' ' ' < "/proc/$child/cmdline")
          [ -n "$cmd" ] && break
        done ;;
    esac
    screen=$(tmux capture-pane -p -t "=${sess}:${w}" 2>/dev/null | grep -v '^\s*$' | tail -25)

    if [ -z "$cmd" ]; then
      # 🔑 lucifer 2026-08-06: PROCESS-GONE กับ NOT-READY **ต้องแยกจากกันเสมอ** เพราะทางแก้คนละทาง
      #    NOT-READY = engine รันอยู่ รอ/เคลียร์จอ  ·  PROCESS-GONE = ไม่มี engine ต้อง spawn ใหม่
      #    ⇒ **false ทิศ PROCESS-GONE แพงกว่าทิศ READY**: คนอ่านจะไป restart engine ที่รันอยู่ดี ๆ
      #    (บั๊กแรกของ verb นี้เป็นทิศนั้นพอดี — เดินแต่ process ลูก)
      echo "bootverify.pane: $w PROCESS-GONE — ไม่มี engine ใน pane นี้ · แก้: spawn ใหม่ (ไม่ใช่รอ)"
      rc=1; continue
    fi
    # 🔴 จอเป็นของ installer/dialog ไม่ใช่ของ agent → ยังรับงานไม่ได้ และ Enter จะไปโดนเมนู
    case "$screen" in
      *"Update available!"*|*"Press enter to continue"*|*"1. Update now"*)
        # 🔴 2026-08-07 · เดิมบรรทัดนี้เขียน `(3=Skip)` — **ผิด และผิดในบรรทัดที่สอนว่าห้ามกดมั่ว**
        #    เมนูของ codex **ต่างกันตามเวอร์ชัน**: 0.146.0 = `1 Update now / 2 Skip` ·
        #    0.146.1 = `1 Update now / 2 Skip / 3 Skip until next version`
        #    ⇒ บน 0.146.1 เลข **3 ไม่ใช่ Skip** แต่คือ *"Skip until next version"* ซึ่ง
        #      **เขียน preference ถาวรลง state ของ codex ที่ทุก oracle ใช้ร่วมกัน**
        #    ⇒ การ hardcode เลขใด ๆ คือตัวบั๊กเอง — เครื่องมือไม่รู้ว่าเครื่องนั้นเป็นเมนูแบบไหน
        #    [clean-room tester 2026-08-07 อ่านเมนูจริงแล้วส่ง `2` — และเขาถูก ผมผิด]
        # 🌐 2026-08-07 [clean-room tester #2] บรรทัดนี้เป็น **คำสั่งที่เสี่ยงที่สุดในทั้ง skill**
        #    (กดผิด = `npm install -g` ทับ binary ของทั้งเครื่อง) **แต่เดิมเป็นภาษาไทยล้วน**
        #    ⇒ สำหรับ skill ที่ทดสอบกับ "คนที่ไม่รู้คำตอบ" นี่เป็น defect ไม่ขึ้นกับว่าใครอ่านไทยได้
        #    ⇒ คำเตือนความปลอดภัย = อังกฤษก่อน ไทยตาม · ที่เหลือคงเดิม
        echo "bootverify.pane: $w NOT-READY screen=cli-update-dialog · engine is running"
        echo "          ⇒ FIX: READ THE MENU ON SCREEN, then send the number next to 'Skip'."
        echo "             NEVER send a bare Enter — the highlighted default is 'Update now',"
        echo "             which runs 'npm install -g' against the whole machine."
        echo "          ⚠️ The numbering is NOT stable across codex versions:"
        echo "               0.146.0 → 2=Skip     0.146.1 → 2=Skip, 3='Skip until next version'"
        echo "               '3' writes a PERSISTENT preference into shared codex state. Prefer the"
        echo "               option that leaves no trace. Newer versions may differ again — read it."
        echo "          ⇒ ไทย: **อ่านเลขจากจอก่อนกด** ส่งเลขที่คู่กับ 'Skip' · **ห้าม Enter เปล่า**"
        echo "             (ค่า default คือ 'Update now' = อัปเกรด binary ของทั้งเครื่อง)"
        echo "             เลขไม่คงที่ข้ามเวอร์ชัน · เลือกตัวที่ไม่ทิ้งร่องรอยเสมอ"
        echo "          ⇒ maw peek \"$sess:$w\"   # look before you press"
        rc=1; continue ;;
      *"trust this folder"*|*"you trust"*)
        echo "bootverify.pane: $w NOT-READY screen=trust-prompt · engine รันอยู่ · แก้: ตอบ '1' เฉพาะเจาะจง ไม่ใช่ Enter เปล่า"
        rc=1; continue ;;
    esac
    # 🔴 2026-08-07 [lucifer] ข้อความที่ **ค้างในช่องพิมพ์แต่ไม่เคย submit** ไม่มีสัญญาณอะไรเลย:
    #    maw ตอบ "delivered" เฉย ๆ · ไม่มีคำเตือน · ทีม 4 คน idle เงียบ ๆ เหมือนทำงานเสร็จ
    #    ⇒ อาการที่มองเห็นได้จริงคือ **composer มีเนื้อหาแต่ pane ไม่ busy**
    #    (codex ค้างเป็น `[Pasted Content NNN chars]` · จำนวน `#N` = มีหลายฉบับซ้อน)
    if ! printf '%s' "$screen" | grep -qE 'esc to interrupt'; then
      q=$(printf '%s' "$screen" | grep -oE '\[Pasted Content [0-9]+ chars\]' | grep -c .)
      if [ "${q:-0}" -gt 0 ]; then
        echo "bootverify.pane: $w QUEUED-NOT-SUBMITTED — มี $q ข้อความค้างในช่องพิมพ์ pane ไม่ busy"
        echo "          ⇒ `maw send` ตอบ delivered ได้ทั้งที่ยังไม่ถูก submit — **ความเงียบไม่ใช่ความสำเร็จ**"
        echo "          ⇒ แก้: peek ยืนยันว่าจอเป็นของ agent แล้ว `maw send-enter <target>`"
        rc=1; queued=$((queued+1)); continue
      fi
    fi
    # 🔴 2026-08-07 · **false-READY ที่ selftest 12 จับได้ในการรันครั้งแรก**
    #    เดิม: `cmd` ไม่ว่าง ⇒ ไหลลงไป READY ⇒ **pane ที่รัน `sleep 30` ได้ `overall: READY`**
    #    ⇒ verb นี้ถามแค่ *"มี process ไหม"* ไม่เคยถาม *"มันเป็น agent ไหม"*
    #    ⇒ **นี่คือแถว `RUNNING` ในตาราง signal-substitution ของ skill นี้เอง**
    #       ("a process exists — not that the agent can take a turn") **อยู่ใน verb ที่สร้างมาแก้มัน**
    #    ⇒ ไม่มีใครใน 6 บ้านจับได้ เพราะทุกคนรันมันกับ **ทีมจริงที่เป็น agent อยู่แล้ว**
    #       — เคสที่หักล้างมันได้ต้องเป็น session ที่ *ไม่ใช่* agent ซึ่งไม่มีใครมีเหตุให้ลอง
    # 🚨 ทิศของความระมัดระวัง: lucifer บอกว่า **false PROCESS-GONE แพงกว่า false READY**
    #    ⇒ ตรงนี้จึง **ไม่** ประกาศ PROCESS-GONE (process มีอยู่จริง) แต่ประกาศว่า
    #    **ยืนยันไม่ได้ว่าเป็น agent** พร้อมพ่น cmd ที่เห็นออกมาให้คนอ่านตัดสิน
    #    ⇒ "ยืนยันไม่ได้" ≠ "ไม่มี" — สองสถานะนี้พาไปคนละทางแก้ (ดู scar เรื่อง absence claim)
    # 🩹 `pbin` เคยถูกคำนวณหลังจุดนี้ ⇒ เช็คลายเซ็นอ้างตัวแปรที่ยังไม่มี ⇒ `unbound variable`
    #    (`set -u` จับให้ตอนรัน selftest 12 แขน (ข) — เป็นเหตุผลที่แขนนั้นต้องรันของจริง
    #     ไม่ใช่แค่ grep หาสตริงในไฟล์) ⇒ ย้ายการคำนวณขึ้นมาก่อนผู้ใช้รายแรก ไม่ใช่ทำสำเนาที่สอง
    local pbin
    pbin=$(_vc_argv_basename "$cmd" 1)
    case "$pbin" in
      node|python|python3|bun|deno|ruby|perl|sh|env)
        local real
        real=$(_vc_argv_basename "$cmd" 2)
        [ -n "$real" ] && pbin="${real} (via ${pbin})" ;;
    esac
    local agentsig=""
    case "$pbin" in
      claude*|codex*|opencode*|thclaws*|*"(via node)"|*"(via python3)"|*"(via bun)"|*"(via deno)")
        agentsig="proc" ;;
    esac
    if [ -z "$agentsig" ]; then
      printf '%s' "$screen" | grep -qE 'esc to interrupt|Enter to select|⏵⏵|Claude Code|for shortcuts|\[Pasted Content' \
        && agentsig="screen"
    fi
    if [ -z "$agentsig" ]; then
      echo "bootverify.pane: $w NOT-READY screen=no-agent-signature proc=${pbin:-?} cmd=${cmd}"
      echo "          ⇒ process มีอยู่ **แต่ยืนยันไม่ได้ว่าเป็น agent** (ไม่ใช่ PROCESS-GONE — อย่า spawn ทับ)"
      echo "          ⇒ ถ้านี่คือ engine ที่เครื่องมือยังไม่รู้จัก: peek ดูจอเอง แล้วบอกผมให้เพิ่มลายเซ็น"
      rc=1; continue
    fi
    model=$(printf '%s' "$cmd" | sed -n 's/.*--model \([^ ]*\).*/\1/p')
    # 🩹 2026-08-07 [lucifer · ทีมจริง 3 pane] alias ที่ **ไม่ pin --model** ทำให้ตรงนี้ว่าง
    #    แล้วรายงาน `model=-` **ทั้งที่คำตอบอยู่บนจอที่ capture มาแล้ว** (status bar โชว์
    #    `gpt-5.6-sol medium` ชัด ๆ) ⇒ อ่านจาก /proc ก่อน ถ้าไม่มีค่อย fallback ที่ status bar
    #    ซึ่ง doc เองบอกว่าเป็นหลักฐานชั้นที่ครอบเรื่อง model ที่บัญชีเสิร์ฟจริง
    # 🔑 lucifer 2026-08-07: แหล่งของ model มีความเสถียร **คนละชั้น** ต้องแยกให้เห็น
    #    `--model` ใน cmdline = pin จริง เปลี่ยนไม่ได้จากข้างนอก
    #    status bar อย่างเดียว = engine อ่านมาจาก **config ของตัวเอง** (~/.codex/config.toml)
    #    ⇒ ทีมรันบน ambient default · ใครแก้ config.toml ทีมเปลี่ยน model เงียบ ๆ ทั้งทีม
    #    เคสจริง: ws-parity-port 4 pane — cmdline ไม่มี --model เลย แต่ status bar โชว์ gpt-5.6-sol
    # 🔴 2026-08-07 [lucifer วัดด้วย tmux ล้วน ไม่แตะ maw] **`flag-pinned` เคยอ่านว่า "ดีกว่า"**
    #    pane ที่ pin `--model zzz-not-a-model` (ชื่อที่ไม่มีอยู่จริง):
    #      · boot สำเร็จ · banner พิมพ์ "zzz-not-a-model with high effort · Claude Max" **เหมือนของจริง**
    #      · `bootverify` → **READY · model=zzz-not-a-model (flag-pinned) · unpinned=0**
    #      · turn แรก → engine **ปฏิเสธชัดเจน** ("may not exist or you may not have access")
    #    ⇒ 🔑 **ทีมที่ pin ผิด ได้ป้ายที่ดูน่าเชื่อถือกว่าทีมที่ไม่ pin** — ตรงข้ามกับเจตนาของเครื่องมือ
    #    ⇒ **ความเสียหายอยู่ในช่วงระหว่าง boot กับ turn แรก ซึ่งทุกเครื่องมือของเราอ่านว่าปกติ**
    #      ตั้งทีม 10 คน เช็คด้วย bootverify อย่างเดียว → READY ครบ → พังตอนสั่งงานจริงทีละคน
    #    ⇒ `flag-pinned` แปลว่า **"ขอไว้"** ไม่ใช่ **"ใช้ได้"** — ป้ายต้องพูดแบบนั้น
    local msrc="flag-pinned-UNVALIDATED"
    if [ -z "$model" ]; then
      model=$(printf '%s' "$screen" | grep -oE '(gpt|claude|o[0-9]|sonnet|opus|haiku|glm|zai)[A-Za-z0-9./_-]*' | tail -1)
      if [ -n "$model" ]; then
        msrc="AMBIENT-not-pinned"
        unpinned=$((unpinned+1))
      fi
    fi
    # 🩹 codex ติดตั้งผ่าน npm ⇒ pane process คือ `node .../codex` ⇒ basename = "node"
    #    ตัวอย่างใน doc เขียน proc=codex ⇒ ใครเขียน gate `grep proc=codex` จะพลาดทั้งเครื่อง
    #    ⇒ ถ้าตัวแรกเป็น interpreter ให้เอา **สคริปต์ที่มันรัน** มาเป็นชื่อแทน
    # (pbin คำนวณไปแล้วก่อนเช็คลายเซ็น agent ด้านบน — อย่าคำนวณซ้ำที่นี่)
    # 🩹 2026-08-06 [prism รัน bootverify กับ prism-cell ที่ live อยู่จริง 8 pane]
    #    `cut -c1-90` ตัดท้ายคำสั่งทิ้งเงียบ ๆ ⇒ `--model gpt-5.5` ที่อยู่ท้ายหายไปจากจอ
    #    ⇒ คนอ่านเข้าใจผิดได้ว่า model หาย ทั้งที่มันอยู่ตรงนั้น
    #    ⇒ ใส่ `…` ให้เห็นว่าโดนตัด · และ `model=` อ่านจากคำสั่ง**เต็ม** เสมอ ไม่ใช่จากตัวที่ตัดแล้ว
    # 🔴 2026-08-07 [prism] **config resolve ถูก ≠ pane ที่รันอยู่สะท้อน config นั้น**
    #    เคสจริงของเขา: charter แก้ให้ pin --model gpt-5.5 ตอน 14:46 แต่ pane เริ่ม 12:05
    #    ⇒ ยังรัน ambient เดิม ขณะที่ dry-resolve ตอบ PASS ทุกครั้ง เพราะอ่าน config ไม่เคยอ่าน pane
    #    ⇒ ชื่อที่เขาตั้ง: **proof-of-resolve ไม่ใช่ proof-of-applied**
    #
    # ⛔ **เช็คนี้ถูกถอดออก ไม่ใช่เพราะไม่สำคัญ แต่เพราะ `bootverify` ตอบมันเองไม่ได้**
    #    ผมลองสองเวอร์ชัน **ทั้งสองเป็นเครื่อง false-positive** และ prism จับเวอร์ชันแรก:
    #      v1 เทียบ **mtime ของไฟล์ layer** → prism: การแก้ตอน 14:46 แค่ *เติม* key `codex-gpt55`
    #         ไม่ได้แตะ `opencode-verify` ที่ verify-b ใช้ (`git log -p` ยืนยัน string ไม่เคยเปลี่ยน)
    #         ⇒ **stale-by-mtime จริง · stale-by-content ไม่จริง** ⇒ ยิงผิดทุกครั้งที่มีคน
    #         append key ที่ไม่เกี่ยวกับ role นั้น
    #      v2 เทียบ **`maw wake <role> --dry-run` กับ cmdline จริง** → ผมวัดเอง:
    #         wake ที่ไม่มี `-e` คืน **default** (`claude --model claude-opus-5`) ไม่ใช่ engine
    #         ของ role (`opencode --model zai/glm-5.2`) ⇒ ต่างกันเสมอสำหรับ **ทุก** member
    #         ที่ตั้ง engine ไว้ ⇒ ยิง 8/8 รวมตัวที่ prism พิสูจน์แล้วว่าไม่ drift
    #    ⇒ รากเดียวกันทั้งสองครั้ง: **`bootverify` ไม่รู้จัก charter** จึงไม่รู้ว่า role ไหนควรได้ engine ไหน
    #       และคำถาม "pane สะท้อน config ปัจจุบันไหม" ตอบไม่ได้ถ้าไม่รู้ว่า "ควรเป็นอะไร"
    #
    # ✅ **วิธีที่ถูกต้อง จนกว่าจะมีคนทำ**: `enginecheck <charter>` รู้ engine ต่อ role อยู่แล้ว
    #    ⇒ ที่ที่ควรอยู่คือตรงนั้น ไม่ใช่ที่นี่ · เทียบ `enginecheck` resolved กับ `/proc` cmdline
    #    ของ pane ที่ชื่อตรงกัน ⇒ ต่างกัน = drift จริง · ยังไม่ได้ทำ **และห้ามนับว่าตรวจแล้ว**
    #    (บันทึกเป็นของ prism · ผมลบเช็คที่เขียนเองสองรอบแทนที่จะ ship ของที่ชี้ผิด)
    local shown="$cmd" mark=""
    if [ "${#cmd}" -gt 90 ]; then shown=$(printf '%s' "$cmd" | cut -c1-90); mark="…(ตัด ${#cmd} อักษร)"; fi
    echo "bootverify.pane: $w READY proc=${pbin:-?} model=${model:--}${model:+ (${msrc})} cmd=${shown}${mark}"
  done <<< "$wins"

  echo "bootverify.scope: อ่านอย่างเดียว · ยืนยัน process+จอ · **ไม่ยืนยันว่าบัญชีเสิร์ฟ model ได้** (ใช้ modelprobe)"
  if [ "$unpinned" -gt 0 ]; then
    echo "bootverify.unpinned: $unpinned/$n pane อ่าน model จาก **config ของ engine เอง ไม่ใช่ --model**"
    echo "          ⇒ ทีมรันบน ambient default · แก้ ~/.codex/config.toml เมื่อไหร่ ทีมเปลี่ยน model เงียบ ๆ"
    echo "          ⇒ ถ้าต้องการให้เสถียร: pin --model ใน alias ของ engine"
    echo "          💸 ambient default บนเครื่องนี้คือ **tier บนสุด** ⇒ unpinned = จ่ายเรตท็อปโดยอุบัติเหตุ"
  fi
  # 🔴 2026-08-07 [lucifer] `unpinned=0` เคยอ่านว่า "ครบถ้วน ไม่มีอะไรต้องห่วง"
  #    **แต่ pane ที่ pin ชื่อ model ที่ไม่มีอยู่จริง ก็ให้ unpinned=0 เหมือนกัน** และได้ READY
  #    ⇒ ต้องพูดออกมาว่า **pinned = ขอไว้ ไม่ใช่ ใช้ได้** ทุกครั้งที่มี pane ที่ pin
  if [ "$unpinned" -lt "$n" ]; then
    echo "bootverify.pinned-unvalidated: $((n-unpinned))/$n pane pin --model ไว้ — **นั่นคือสิ่งที่ *ขอ* ไม่ใช่สิ่งที่ *ใช้ได้*"
    echo "          🔴 [verified 2026-08-07] pane ที่ pin ชื่อ model ที่ **ไม่มีอยู่จริง** ก็ boot ผ่าน · banner"
    echo "             พิมพ์ชื่อมั่วนั้นเหมือนของจริง · verb นี้ตอบ READY · และปฏิเสธจริงตอน **turn แรก** เท่านั้น"
    echo "          ⇒ ยืนยันว่าใช้ได้จริงได้ทางเดียว: codex → 'modelprobe <alias> <dir>' · claude/opencode → **ส่ง turn จริง**"
  fi
  [ "${queued:-0}" -gt 0 ] && echo "bootverify.queued: $queued pane มีคำสั่งค้างที่ไม่เคยถูก submit — ทีมดูเหมือนว่างแต่ยังไม่ได้เริ่ม"
  [ "$rc" = "0" ] && echo "overall: READY panes=$n${unpinned:+ unpinned=$unpinned}" || echo "overall: NOT-READY — อย่าเพิ่งส่งอะไรเข้า pane ที่ยังไม่ READY · NOT-READY=รอ/เคลียร์จอ · PROCESS-GONE=spawn ใหม่ (คนละทางแก้)"
  return $rc
}

# ── unstick <session> [max-attempts] ───────────────────────────────────────
# เคลียร์ข้อความที่ค้างในช่องพิมพ์ (ที่ `bootverify` รายงานเป็น QUEUED-NOT-SUBMITTED)
# 🔑 **หนึ่ง send-enter ไม่พอ** [lucifer วัดเอง 2026-08-07: ทั้งสาม pane ต้องใช้ **2 attempt
#    เท่ากันหมด**] ⇒ ยิง enter ครั้งเดียวแล้วคิดว่าจบ = อาการกลับมา และคนอ่านจะสรุปว่า detector ผิด
# ⇒ ขั้นตอนที่ถูก: **enter → วัดซ้ำ → วนจนกว่า Pasted Content เหลือศูนย์**
# ⚠️ ตัวนี้ **ส่ง key เข้า pane** — ต่างจาก verb อื่นในไฟล์นี้ทั้งหมด
#    ⇒ peek ก่อนทุก pane · ถ้าจอเป็น dialog ของ CLI (update/trust) **ข้าม ไม่กด**
#    เพราะ Enter ตรงนั้นไปกดเมนู ไม่ใช่ submit (เคส 2026-08-06 อัป codex ทั้งเครื่อง)
unstick() {
  local sess="${1:?usage: unstick <session> [max-attempts]}" maxn="${2:-4}"
  binexists tmux >/dev/null 2>&1 || { echo "UNKNOWN   ไม่มี tmux"; return 2; }
  tmux has-session -t "=$sess" 2>/dev/null || { echo "FAIL      ไม่มี session '$sess'"; return 1; }
  local w n try left total_fixed=0 skipped=0
  while IFS= read -r w; do
    [ -n "$w" ] || continue
    local sc; sc=$(tmux capture-pane -p -t "=${sess}:${w}" 2>/dev/null)
    case "$sc" in
      # 🩹 2026-08-09 [lucifer เทียบ list ทีละแถวกับจอ 0.147.0 ที่เขาจับเอง — และเขาถูก]
      #    list เดิม 4 แถว: 2 แถวเจาะจง codex (`Update available!` · `1. Update now`)
      #    **เป็นของ dialog ที่ 0.147.0 เอาออกไปแล้ว** · `trust this folder` เป็น
      #    **ถ้อยคำของ claude ไม่ใช่ codex** ⇒ trust dialog จริงของ codex 0.147.0
      #    (`Do you trust the contents of this directory?` / `1. Yes, continue`)
      #    **ไม่มีแถวไหนตรงเลย** — รอดมาได้ด้วย footer ทั่วไป `Press enter to continue` เท่านั้น
      #    ⇒ 🔑 **guard ที่กันได้เฉพาะไดอะล็อกรุ่นก่อน แล้วบังเอิญกันรุ่นปัจจุบันด้วย footer
      #      ที่ไม่เกี่ยวกับเรื่อง** — footer เปลี่ยนเมื่อไหร่ ด่านหายเงียบ
      #    ⇒ ต่อยอดกฎคืนนี้: **ไดอะล็อกเป็นคุณสมบัติของ (เวอร์ชัน × เครื่องยนต์)**
      #      pattern list จึงต้องมี `valid-if:` เหมือน claim อื่น — ทบทวนเมื่อ engine อัป
      *"Update available!"*|*"Press enter to continue"*|*"1. Update now"*|*"trust this folder"*\
      |*"Do you trust the contents of this directory"*|*"1. Yes, continue"*\
      |*"Is this a project you created or one you trust"*)
        echo "unstick.pane: $w SKIP — จอเป็น dialog ของ CLI ไม่ใช่ของ agent · Enter จะไปกดเมนู"
        skipped=$((skipped+1)); continue ;;
    esac
    n=$(printf '%s' "$sc" | grep -c 'Pasted Content')
    [ "${n:-0}" -gt 0 ] || { echo "unstick.pane: $w ok — ไม่มีของค้าง"; continue; }
    for try in $(seq 1 "$maxn"); do
      maw send-enter "${sess}:${w}.0" >/dev/null 2>&1
      sleep 2
      left=$(tmux capture-pane -p -t "=${sess}:${w}" 2>/dev/null | grep -c 'Pasted Content')
      if [ "${left:-0}" -eq 0 ]; then
        echo "unstick.pane: $w cleared after $try attempt(s)  (ค้างตอนแรก $n)"
        total_fixed=$((total_fixed+1)); break
      fi
      [ "$try" = "$maxn" ] && echo "unstick.pane: $w 🔴 ยังเหลือ $left หลัง $maxn ครั้ง — อย่ายิงต่อ ไปดู pane เอง"
    done
  done < <(tmux list-windows -t "=$sess" -F '#{window_name}' 2>/dev/null)
  echo "unstick.scope: ส่ง Enter เท่านั้น · ไม่ส่งเนื้อหา · ข้าม pane ที่จอเป็น dialog"
  echo "overall: cleared=$total_fixed skipped=$skipped  ⇒ ยืนยันซ้ำด้วย: bootverify $sess"
  return 0
}

# ── modelprobe <engine-alias> <dir> ─────────────────────────────────────────
# ตอบคำถามเดียวที่ `enginecheck` ประกาศมาตลอดว่าตอบไม่ได้: **บัญชีเสิร์ฟ model นี้ได้จริงไหม**
# 🏷️ 2026-08-06: `gpt-5.6-mini` บูตขึ้นปกติ · banner พิมพ์ `model: gpt-5.6-mini xhigh` ·
#    แล้ว turn แรกคืน `400 The 'gpt-5.6-mini' model is not supported ... ChatGPT account`
#    ⇒ **banner บอกแค่ว่าแฟลกไปถึง engine** · มีแต่ turn จริงที่บอกว่ามันใช้ได้
#    ⇒ ผมเองใส่ model ตัวนั้นเป็นตัวอย่างในเอกสารและใช้ทดสอบ up ทุกรอบ โดยไม่เคยส่ง turn
# ⚠️ ตัวนี้ **เสียโควตาจริง** (turn เล็กที่สุดที่ทำได้) ⇒ ไม่ถูกเรียกจาก selftest และไม่ควร
#    รันในลูป · รันหนึ่งครั้งต่อ engine ใหม่หนึ่งตัว ก่อนไว้ใจทั้งทีม
modelprobe() {
  local e="${1:?usage: modelprobe <engine-alias> <dir>}" dir="${2:?usage: modelprobe <engine-alias> <dir>}"
  local reg_out reg_rc cmd
  reg_out=$(enginereg "$e" "$dir" 2>/dev/null); reg_rc=$?
  if [ "$reg_rc" -ne 0 ]; then
    printf 'modelprobe.engine: %s UNVERIFIED reason=alias-not-registered\n' "$e"
    printf 'overall: UNVERIFIED\n'; return 2
  fi
  cmd=$(printf '%s\n' "$reg_out" | sed -n '2s/^ *//p')
  case "$cmd" in
    *codex*) ;;
    *) printf 'modelprobe.engine: %s UNVERIFIED reason=only-codex-supported-by-this-probe\n' "$e"
       printf 'overall: UNVERIFIED\n'; return 2 ;;
  esac
  local model; model=$(printf '%s' "$cmd" | sed -n 's/.*--model[= ]\([^ ]*\).*/\1/p')
  [ -n "$model" ] || model="(engine default from config.toml)"
  local tmp out rc
  tmp=$(mktemp -d)
  out=$( cd "$tmp" && timeout 240 codex exec --dangerously-bypass-approvals-and-sandbox \
           ${model:+-m "$model"} -c model_reasoning_effort=low \
           "Create a file named probe.txt containing exactly OK. Then stop." 2>&1 ); rc=$?
  local served="no"
  [ -f "$tmp/probe.txt" ] && served="yes"
  rm -rf "$tmp"
  # 🔴 2026-08-07 · **verb นี้ทิ้งขยะลงไฟล์กลางทุกครั้งที่รัน และผมเพิ่งรู้วันนี้**
  #    `codex exec` เขียน `[projects."<tmp>"] trust_level=...` ลง `~/.codex/config.toml`
  #    ซึ่ง **ใช้ร่วมกันทั้งเครื่อง** · เราลบ `$tmp` แต่ **ไม่เคยลบ entry**
  #    `[verified 2026-08-07]` ในบรรดา entry ที่ path ตายแล้ว 146 ตัว **24 ตัวเป็นรูปของ verb นี้**
  #    (`/tmp/tmp.*` 8 · `*modelprobe/scratchpad*` 16) ⇒ สะสมจากการรัน probe ล้วน ๆ
  #    ⇒ เครื่องมือที่เราสร้างมาเพื่อ "ตรวจก่อนทำ" **เป็นตัวที่สกปรกที่สุดในชุด**
  #    ⇒ ลบเฉพาะบล็อกที่ชี้ path ของเราเอง · แมตช์ path เต็ม ห้าม pattern กว้าง
  #      (ไฟล์นี้มี path ของ oracle บ้านอื่นอยู่ด้วย) · กิน `\n` นำหน้าด้วย ไม่งั้นเหลือบรรทัดว่าง
  # 🔴 2026-08-07 [clean-room tester #3] เก็บ trust entry แล้ว **แต่ยังทิ้ง rollout ไว้**
  #    `codex exec` เขียน `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` โดยบันทึก
  #    `"cwd":"/tmp/tmp.XXXX"` และ `"originator":"codex_exec"` ⇒ **ไม่มี token ของทีมอยู่ในไฟล์เลย**
  #    ⇒ **การตรวจ residue ที่ teardown สอน (`grep -rl "$TEAM" ~/.codex/sessions/`) หาไม่เจอ
  #      โดยโครงสร้าง** ⇒ สะสมไฟล์ละหนึ่งต่อการ probe หนึ่งครั้ง ทั่วทั้งเครื่อง
  #    ⇒ *"verb ที่สะอาดที่สุดของ skill คือ verb ที่ตามรอยยากที่สุด"* — เก็บด้วย **cwd ของเราเอง**
  #      ซึ่งเป็น path ที่ไม่ซ้ำใครและเราสร้างเอง (ไม่ใช่ pattern กว้าง ไม่แตะของบ้านอื่น)
  if [ -d "$HOME/.codex/sessions" ]; then
    MP_TMP="$tmp" python3 - <<'PY' 2>/dev/null
import os, pathlib
tmp = os.environ["MP_TMP"]
root = pathlib.Path.home()/".codex/sessions"
needle = ('"cwd":"%s"' % tmp).encode()
alt    = ('"cwd": "%s"' % tmp).encode()
for p in root.rglob("rollout-*.jsonl"):
    try: blob = p.read_bytes()
    except Exception: continue
    if needle in blob or alt in blob:
        try: p.unlink()
        except Exception: pass
PY
  fi
  if [ -f "$HOME/.codex/config.toml" ]; then
    MP_TMP="$tmp" python3 - <<'PY' 2>/dev/null
import os, re, pathlib
tmp = os.environ["MP_TMP"]
p = pathlib.Path.home()/".codex/config.toml"
try: src = p.read_text()
except Exception: raise SystemExit(0)
pat = re.compile(r'(?m)^\n?\[projects\."' + re.escape(tmp) + r'"\]\n(?:(?!^\[).*\n?)*')
out, n = pat.subn('', src)
if n: p.write_text(out)
PY
  fi
  if [ "$served" = "yes" ]; then
    printf 'modelprobe.engine: %s PASS model=%s served=yes\n' "$e" "$model"
    printf 'overall: PASS model-served=yes\n'; return 0
  fi
  local why; why=$(printf '%s\n' "$out" | grep -oE '"message":"[^"]*"' | head -1)
  printf 'modelprobe.engine: %s FAIL model=%s served=no rc=%s %s\n' "$e" "$model" "$rc" "${why:-no-file-produced}"
  printf 'overall: FAIL model-served=no\n'; return 1
}

# ── engineone <engine-name> <dir> ───────────────────────────────────────────
# โหมดสมาชิกเดี่ยว — สำหรับ gate ที่รับงานทีละ worker ไม่มี charter ไม่มี roster
# 🏷️ ที่มา: atlas 2026-08-06 ตรวจ interface กับ T4543 แล้วพบว่า `enginecheck` เป็น
#    charter/roster-shaped แต่ `preflight.sh` ของเขาเป็น single-worker
#    (`--job-file <path> --repo <path> --engine <one>`) ⇒ **structural mismatch**
#    ไม่ใช่เรื่องรูปแบบข้อความ · โหมดนี้เป็น subset ของสิ่งที่ enginecheck คำนวณต่อสมาชิกอยู่แล้ว
#    ⇒ เพิ่มโหมด **ไม่เปลี่ยน default** — team-shaped ยังถูกสำหรับ skill
#
# stdout เป็น **machine keys ยึดคอลัมน์ 0** ตามที่ gate ของ atlas grep ได้:
#   enginecheck.engine: <name> <PASS|FAIL|UNVERIFIED> resolved=<cmd>
#   overall: PASS|FAIL|UNVERIFIED
# rc: 0=PASS 1=FAIL 2=UNVERIFIED (ตอบไม่ได้ ≠ ผ่าน)
engineone() {
  local e="${1:?usage: engineone <engine-name> <dir>}" dir="${2:?usage: engineone <engine-name> <dir>}"
  local reg_out reg_rc cmd="" scope actual

  # 🏷️ atlas 2026-08-06 ข้อ (i): `enginereg` เดินขึ้นหาบรรพบุรุษที่ *มีอยู่จริง* เมื่อ dir ที่ขอ
  #    ยังไม่ถูกสร้าง (เคสปกติของ gate ที่รัน **ก่อน spawn**) — แล้วเดิมมันไม่บอกว่าทำ
  #    ⇒ ผู้เรียกแยกไม่ออกระหว่าง "dir มีจริงและ engine resolve ได้ที่นั่น" กับ
  #      "dir ยังไม่มี เลยไปตอบจากสโคปอื่น" · **สโคปที่ตอบ ≠ สโคปที่ถาม แต่ผลดูเหมือนกัน**
  #    ⇒ พ่น `scope=resolved|dir-absent` และเมื่อ dir-absent บอก path ที่ใช้ตอบจริงด้วย
  #    (นี่ไม่ใช่ false-green — atlas ถอนข้อกล่าวหานั้นเอง เพราะ control พิสูจน์ว่า
  #     alias ที่อยู่แค่ layer เฉพาะที่ ยัง FAIL ถูกต้องจากทั้ง /tmp และ dir ที่ไม่มี —
  #     แต่ความ *แม่น* ของคำตอบยังขาดไป และ gate ต้องรู้ว่าครึ่ง dir-scoped ทำงานหรือเปล่า)
  if [ -d "$dir" ]; then
    scope="resolved"; actual="$dir"
  else
    scope="dir-absent"
    actual="$dir"
    while [ -n "$actual" ] && [ ! -d "$actual" ]; do
      local up; up=$(dirname -- "$actual"); [ "$up" = "$actual" ] && break; actual="$up"
    done
    [ -d "$actual" ] || actual="."
  fi

  reg_out=$(enginereg "$e" "$dir" 2>/dev/null); reg_rc=$?
  local tail_field="scope=$scope"
  [ "$scope" = "dir-absent" ] && tail_field="scope=dir-absent answered-from=$actual"

  if [ "$reg_rc" -eq 2 ]; then
    printf 'enginecheck.engine: %s UNVERIFIED resolved= %s\n' "$e" "$tail_field"
    printf 'overall: UNVERIFIED\n'; return 2
  fi
  if [ "$reg_rc" -eq 0 ]; then cmd=$(printf '%s\n' "$reg_out" | sed -n '2s/^ *//p'); fi
  if [ -n "$cmd" ]; then
    printf 'enginecheck.engine: %s PASS resolved=%s %s\n' "$e" "$cmd" "$tail_field"
    printf '%s\n' "$VC_SCOPE_LINE"
    # 🏷️ ajfon 2026-08-06 (รอบ 4): เดิมบรรทัด scope hardcode UNVERIFIED ทั้งสามค่าทุก code path
    #    ⇒ กฎของ atlas ("PASS + UNVERIFIED ใด ๆ ⇒ UNVERIFIED") **เป็นเท็จไม่ได้เลย**
    #    ⇒ contract 3 ค่ายุบเหลือ 2 (FAIL / ไม่-FAIL) และ `overall: PASS` กลายเป็นค่าที่
    #      พิมพ์ออกมาแต่ห้ามใช้ — **echo กลับทิศ** ซึ่งคือ defect ที่ Gate 0b ตั้งขึ้นมาแก้
    #    ⇒ แยกสอง namespace: `scope` = ขอบเขตถาวรที่เครื่องมือนี้วัดไม่ได้โดยธรรมชาติ (คงที่)
    #      · `unverified` = สิ่งที่ **ผันแปรจริงต่อรอบ** ⇒ กฎไปผูกกับตัวหลัง แล้วมันเป็นเท็จได้
    if [ "$scope" = "dir-absent" ]; then
      printf 'enginecheck.unverified: answered-from-ancestor=%s\n' "$actual"
    else
      printf 'enginecheck.unverified:\n'
    fi
    printf 'overall: PASS requires-post-boot-verification=true\n'; return 0
  fi
  # 🏷️ ajfon 2026-08-06: **`dir-absent` + ไม่เจอ = "ตอบไม่ได้" ไม่ใช่ "ตอบว่าไม่ผ่าน"**
  #    เราไปตอบจากบรรพบุรุษที่มีอยู่ ไม่ใช่จาก dir ที่ถูกถาม ⇒ แยกไม่ออกระหว่าง
  #    "alias ไม่มีจริง" กับ "เรามองผิดที่" ⇒ gate ที่รัน engineone **ก่อน mkdir** จะได้ FAIL
  #    แล้วสรุปว่า alias ผิด ทั้งที่ alias ถูก
  #    NB: `dir-absent` + **เจอ** ยังเป็น PASS ถูกต้อง — บรรพบุรุษที่เจอมันครอบ path จริงอยู่แล้ว
  #        เมื่อ dir ถูกสร้าง ⇒ อสมมาตรนี้ตั้งใจ ไม่ใช่ความพลาด
  if [ "$scope" = "dir-absent" ]; then
    printf 'enginecheck.engine: %s UNVERIFIED resolved= %s\n' "$e" "$tail_field"
    printf '%s\n' "$VC_SCOPE_LINE"
    printf 'enginecheck.unverified: asked-dir-does-not-exist\n'
    printf 'overall: UNVERIFIED requires-post-boot-verification=true\n'; return 2
  fi
  printf 'enginecheck.engine: %s FAIL resolved= %s\n' "$e" "$tail_field"
  printf '%s\n' "$VC_SCOPE_LINE"
  printf 'enginecheck.unverified:\n'
  printf 'overall: FAIL requires-post-boot-verification=true\n'; return 1
}

# ── _vc_permmode <resolved-cmd> ─────────────────────────────────────────────
# มิติที่ **สาม** ของ alias ที่เราไม่เคยตั้งชื่อ: engine · model · **permission mode**
#
# 🔴 เกิดจากของจริง 2026-08-08 ~22:1x +07 — ทีม `pivot-registry-expand` ของ holmes
#    ค้าง **3 pane พร้อมกัน** โดยที่ทุกด่านของเราขึ้นเขียว
#    `[verified: tmux capture-pane + ps --ppid <pane_pid>]`
#      :1 prober-thai-gov  "Do you want to create prober-thai-gov.md?"
#      :2 prober-intl-corp "Do you want to proceed?"
#      :5 reviewer         "This command requires approval"
#      process จริง (pid ลูก ไม่ใช่ pane pid): `claude --model claude-opus-5`
#      alias: holmes-oracle/.maw/maw.config.60.json:30
#             "holmes-fresh-claude": "claude --model claude-opus-5"   ← ไม่มี bypass
#
# 🕳️ **ทำไม enginecheck เดิมถึงไม่จับ — และมันแย่กว่า "ไม่จับ"**
#    `[verified: รัน enginecheck กับ charter ที่ engine=default]`
#      จะรันจริง  : claude --model claude-opus-5 --continue
#      ✅ PASS · overall: PASS · ENGINECHECK OK
#    มัน **พิมพ์คำสั่งที่ขาดแฟลกออกมาให้เห็นเต็ม ๆ แล้วตัดสินว่าผ่าน** — และ
#    `out-of-scope=model-served,prompt-delivery,account-quota` **ไม่มีคำว่า permission**
#    ⇒ นี่ไม่ใช่ช่องที่เรารู้ตัวว่าเปิดอยู่ด้วยซ้ำ · alias ที่ลงทะเบียนถูกต้อง 100%
#      และจะค้างทุกครั้งที่ worker เขียนไฟล์แรก **ได้ PASS เท่ากับ alias ที่ใช้งานได้**
#
# ⚖️ ทำไม WARN ไม่ใช่ FAIL: ask-mode เป็นทางเลือกที่ **ถูกต้องได้** (probe ที่ห้ามเขียน,
#    ทีมที่มีคนนั่งเฝ้า) ⇒ เครื่องมือนี้ไม่มีสิทธิ์ตัดสินแทนเจ้าของทีม · หน้าที่มันคือ
#    ทำให้ "จะค้าง" **มองเห็นก่อน spawn** ไม่ใช่ค้นพบตอนนาทีที่ 40
#    ⇒ machine block พ่น `perm=<mode>` ให้ gate ตัดสินเองตามนโยบายบ้านตัวเอง
#
# 🏷️ ทุกแถวมาจาก `--help` ของไบนารีบนเครื่องนี้ `[verified 2026-08-08]` ไม่ใช่ความจำ:
#   codex    `--dangerously-bypass-approvals-and-sandbox` = "Skip all confirmation prompts"
#            `-a|--ask-for-approval never` = "Never ask for user approval"
#   claude   `--dangerously-skip-permissions` = "Bypass all permission checks"
#            `--permission-mode bypassPermissions`
#   opencode `--auto` = "auto-approve permissions that are not explicitly denied (dangerous!)"
#            ⚠️ **"that are not explicitly denied"** — deny-list ยังค้างได้ ⇒ อ่อนกว่าอีกสามตัว
#   thclaws  `--accept-all` = "Never ask for tool-call approval (alias: --dangerously-skip-permissions)"
#            `--permission-mode auto`
#            ⚠️ `--allowed-tools` **ไม่ใช่ bypass** — มันคือ allowlist คนละกลไก
#               จะยังค้าง/ปฏิเสธเมื่อโมเดลเรียก tool นอกลิสต์
#   engine อื่น ⇒ `unknown` **ไม่ใช่ ok** (ตอบไม่ได้ ≠ ผ่าน — กฎเดิมของไฟล์นี้)
# ── _vc_strip_env_prefix <cmd> ──────────────────────────────────────────────
# 🩹 2026-08-08 [loom จับ · ยืนยันด้วย output ของเครื่องมือเอง] `_vc_argv_basename`
#    ข้าม **assignment** (`BASH_ENV=/x codex …`) ได้ แต่ **`env` เป็นไบนารีจริง** ไม่ใช่ assignment
#      `BASH_ENV=/path codex --ask-for-approval never`  → engine=codex  ✅
#      `env -u ANTHROPIC_API_KEY claude --dangerously…` → engine=env    ❌ → perm=unknown
#    ⇒ ทั้งที่ `--dangerously-skip-permissions` **อยู่ในบรรทัดเดียวกับที่มันพิมพ์ออกมาเอง**
#    ⇒ กิน `env` + แฟลกของมัน (`-u NAME` `-i` `-0` `--unset=NAME` `VAR=v`) แล้วอ่าน token ถัดไป
#    🟢 loom ชมส่วนที่ถูก และผมเห็นด้วยว่ามันคือส่วนที่ต้องไม่แก้: `unknown` **ไม่เท่ากับ pass**
#       ถ้ามันเดาว่า pass เขาจะเชื่อแล้วเดินต่อ — การปฏิเสธที่จะตอบคือพฤติกรรมที่ถูก
#       บั๊กนี้จึงทำให้เครื่องมือ **เงียบเกินจริง ไม่ใช่ปลอดภัยเกินจริง** ซึ่งเป็นทิศที่ยอมรับได้กว่า
_vc_strip_env_prefix() {
  local cmd="$1"
  # ตัด assignment นำหน้าออกก่อน (รูปเดิมที่ _vc_argv_basename รองรับอยู่แล้ว)
  while [[ "$cmd" =~ ^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+(.*)$ ]]; do
    cmd="${BASH_REMATCH[1]}"
  done
  # ถ้าเหลือ `env` หรือ `/usr/bin/env` เป็นตัวแรก ⇒ กินมันและแฟลกของมัน
  if [[ "$cmd" =~ ^[[:space:]]*(/[^[:space:]]*/)?env[[:space:]]+(.*)$ ]]; then
    cmd="${BASH_REMATCH[2]}"
    while :; do
      case "$cmd" in
        -u[[:space:]]*)      cmd="${cmd#-u}"; cmd="${cmd#"${cmd%%[![:space:]]*}"}"
                             cmd="${cmd#* }" ;;                       # กิน NAME ที่ตามมา
        --unset=*[[:space:]]*|-i[[:space:]]*|-0[[:space:]]*|--ignore-environment[[:space:]]*)
                             cmd="${cmd#* }" ;;
        [A-Za-z_]*=*[[:space:]]*) cmd="${cmd#* }" ;;                  # VAR=v หลัง env
        *) break ;;
      esac
    done
  fi
  printf '%s' "$cmd"
}

# ── _vc_engine_pid <pane_pid> ───────────────────────────────────────────────
# "process ไหนคือ engine จริงของ pane นี้" — คำถามที่ผมสั่งฟลีตไปแล้ว **สามครั้ง สามคำตอบผิด**
#
#   ครั้งที่ 1  `codex --version`            → อ่าน **ไฟล์บนดิสก์** ตอบเรื่อง boot ครั้งหน้า
#   ครั้งที่ 2  `readlink /proc/<child>/exe` → **lucifer หักล้าง**: `/home/user/.npm-global/bin/codex`
#               เป็น `#!/usr/bin/env node` script ไม่ใช่ ELF ⇒ ลูกชั้นที่ 1 คือ **`/usr/bin/node`**
#               และ `comm` ที่ชั้นนั้นคือ **`MainThread`** ⇒ **ไม่มีฟิลด์ไหนมีคำว่า codex เลย**
#   ครั้งที่ 3  `pgrep -x codex -P $PANE`    → **ผมทดสอบข้อเสนอนี้แล้วมันก็ตก**: บน 3 pane จริง
#               คืน**ค่าว่างทั้งสาม** เพราะ codex เป็น **หลาน (depth 2)** ไม่ใช่ลูก
#               และ atlas วัดไว้ว่า `comm` ก็ไม่น่าเชื่อ (`codex-code-mode` 8 ตัวบนเครื่องนี้)
#
# 🔑 **สองข้อเสนอจาก peer สองคน ขัดกันเองที่ขอบ**: lucifer ให้ key ที่ `comm==codex` ·
#    atlas ให้เลิกใช้ `comm` แล้วใช้ `exe` ⇒ **ทางที่ทนทั้งสองรูปคือไม่ยึดทั้งชื่อและความลึก**:
#    **เดินลูกหลานทุกชั้น แล้วเลือกตัวแรกที่ `exe` ชี้ไปที่ไบนารีของ engine ที่รู้จัก**
#    `[verified 2026-08-09 · 3 pane จริง: codex อยู่ depth 2 · claude อยู่ depth 1]`
#
# ⇒ 🪜 บทเรียนที่ใหญ่กว่าตัวคำสั่ง: **คำสั่งเดียวกัน ถูกในเคสที่ผมวัด และผิดในรูปที่ผมไม่ได้วัด**
#    ผมอ่าน pane ของ holmes ถูกตัวจริง ๆ — แต่ **generalize คำสั่งจากเคสเดียวไปให้ทั้งฟลีต**
#    ซึ่งคือ scar ประจำรีโปนี้ (*"ตรวจคุณสมบัติเดียว → เหมาว่าทั้งหมด"*) **ผิวที่ ๕ ของคืนเดียว**
_vc_engine_pid() {
  # 🩹 กับดัก bash + `set -u`: `local a="$1" b="$a"` **บรรทัดเดียว** ตาย เพราะ bash
  #    ขยายทุก word ก่อนแล้วค่อยกำหนดค่า ⇒ `$a` ยังไม่มีตอนขยาย ⇒ unbound variable
  local root="${1:?usage: _vc_engine_pid <pane_pid>}"
  local queue="$root" cur kids e
  local depth=0
  while [ -n "$queue" ] && [ "$depth" -lt 6 ]; do
    local next=""
    for cur in $queue; do
      e=$(readlink "/proc/$cur/exe" 2>/dev/null) || e=""
      case "$e" in
        */codex*|*/claude*|*/opencode*|*/thclaws*)
          # ข้าม shim ของ node/bun ที่บังเอิญมีคำว่า codex ใน path ไม่ได้ — ตรวจว่ามันไม่ใช่ interpreter
          case "$e" in
            */bin/node|*/bin/bun|*/bin/deno|/usr/bin/node) ;;
            *) printf '%s	%s' "$cur" "$e"; return 0 ;;
          esac ;;
      esac
      kids=$(pgrep -P "$cur" 2>/dev/null | tr '
' ' ')
      next="$next $kids"
    done
    queue="$next"; depth=$((depth+1))
  done
  return 1
}

# ── _vc_engine_basename <cmd> ───────────────────────────────────────────────
# 🩹 2026-08-09 — `/proc` ของ worker จริงคืน `node /home/user/.npm-global/bin/codex --model …`
#    ⇒ `_vc_argv_basename … 1` ได้ **`node`** ⇒ `perm=unknown` กับ **codex worker ทุกตัว**
#    เจอตอนกวาดฟลีตจริง ไม่ใช่ตอนอ่านโค้ด — fixture ผมป้อน `codex …` ตรง ๆ เสมอ จึงไม่เคยโผล่
#    ⇒ 🔑 **สตริงที่ alias เขียนไว้ กับสตริงที่ `/proc` คืนมา ไม่ใช่อันเดียวกัน**
#      และ `_vc_permmode` ถูกใช้กับทั้งสองทาง (ก่อน spawn จาก alias · หลัง spawn จาก /proc)
_vc_engine_basename() {
  local b; b=$(_vc_argv_basename "$1" 1)
  case "$b" in
    node|nodejs|python|python3|bun|deno|ruby|perl|sh|bash|npx) _vc_argv_basename "$1" 2 ;;
    *) printf '%s' "$b" ;;
  esac
}

# 🏷️ arg 2 (ทางเลือก) = **ชื่อ engine ที่ยืนยันมาจากภายนอก** — ใช้เมื่อมี process จริง
#    atlas 2026-08-09: `comm` ก็ไม่ใช่ `codex` เสมอ — เครื่องนี้มี `comm=codex-code-mode` 8 ตัว
#    ⇒ `pgrep -x codex` = 12 · ของจริง = 20 `[ผมยืนยันเอง: ไล่ /proc/*/exe · 5 เก่า 15 ใหม่]`
#    🔑 **ชื่อ process เป็นสิ่งที่โปรแกรมตั้งเองได้ · `exe` เป็นสิ่งที่ kernel ตอบ**
#    ⚠️ แต่รับข้อเสนอของ atlas ได้แค่ **ครึ่งเดียว และครึ่งที่รับไม่ได้สำคัญ**:
#      `exe` บอกว่า **engine ไหน** — บอก **ธง** ไม่ได้ · `--ask-for-approval never` อยู่ใน argv
#      ที่เดียว ⇒ **สองแหล่ง แหล่งละคำถาม** ไม่ใช่เลือกข้างใดข้างหนึ่ง
#      และ `enginecheck` รัน **ก่อน spawn** ⇒ **ไม่มี process ให้ readlink เลย** ⇒ ข้อเสนอนี้
#      ใช้กับ enginecheck ไม่ได้โดยโครงสร้าง ไม่ใช่เพราะไม่อยากทำ
_vc_permmode() {
  # 🩹 2026-08-08 selftest จับ regression ที่ผมเพิ่งสร้างเองตอนแก้เคส `env` ของ loom:
  #    `_vc_strip_env_prefix` ตัด **assignment นำหน้า** ทิ้ง ⇒ `CODEX_HOME=…` หายไปด้วย
  #    ⇒ สาย codex อ่าน CODEX_HOME ไม่เจอ ⇒ fallback ไป `~/.codex` ⇒ **ตอบ bypass ผิด**
  #    ⇒ เก็บสตริงเดิมไว้ต่างหาก: `$cmd` ใช้หา *ไบนารี* · `$orig` ใช้หา *env ที่ผูกมากับ alias*
  #    🔑 บทเรียน: การ normalize ที่ทำเพื่อคำถามหนึ่ง **ทำลายข้อมูลของอีกคำถามในฟังก์ชันเดียวกัน**
  local orig="$1" cmd="$1" bin
  cmd=$(_vc_strip_env_prefix "$cmd")
  bin="${2:-$(_vc_engine_basename "$cmd")}"
  case "$bin" in
    codex)
      case "$cmd" in
        *--dangerously-bypass-approvals-and-sandbox*) echo "bypass|--dangerously-bypass-approvals-and-sandbox" ;;
        *"--ask-for-approval never"*|*"--ask-for-approval=never"*|*"-a never"*) echo "bypass|--ask-for-approval never" ;;
        *)
          # 🩹 2026-08-08 — **ผมเกือบส่ง false alarm ทิศตรงข้าม** และเจอตอน probe ของจริง:
          #    boot codex เปล่า ๆ (ไม่มีแฟลกเลย) แล้วสั่งให้ `curl` + เขียนไฟล์นอก cwd
          #    ⇒ **มันทำทั้งสองอย่างโดยไม่ถามสักครั้ง** เพราะ `~/.codex/config.toml`
          #      มี `approval_policy = "never"` อยู่แล้วทั้งเครื่อง
          #    ⇒ สำหรับ codex **แฟลกไม่ใช่ชั้นเดียวที่ตอบมิตินี้** — config ที่ persist ตอบได้เอง
          #    ⇒ ถ้าอ่านแต่สตริงคำสั่ง จะตะโกน `ask` ใส่ alias ที่ไม่มีปัญหา
          #      แล้วคนจะเลิกอ่านคำเตือน ซึ่งฆ่าเครื่องมือนี้ทั้งตัว
          #    🕳️ นี่คือ scar เดิมของรีโปนี้ชี้กลับมาที่ผม: **ตรวจคุณสมบัติเดียว → เหมาว่าทั้งหมด**
          #       ผมพิสูจน์ claude แล้วเขียนกฎให้ 4 engine · ทิศที่ผมพลาดคือทิศ "กล่าวหา"
          #    ⇒ `CODEX_HOME` มาก่อน `~/.codex` เพราะ alias มักตั้งของตัวเอง (worktree-local)
          local ch cfgfile pol
          ch=$(printf '%s' "$orig" | sed -n 's/.*CODEX_HOME=\([^ ]*\).*/\1/p')
          ch="${ch/#\$HOME/$HOME}"; ch="${ch/#\~/$HOME}"
          cfgfile="${ch:-$HOME/.codex}/config.toml"
          pol=$(grep -m1 -E '^[[:space:]]*approval_policy[[:space:]]*=' "$cfgfile" 2>/dev/null \
                | sed 's/.*=[[:space:]]*//; s/"//g; s/[[:space:]]*$//')
          case "$pol" in
            never|on-failure)
              echo "bypass|ไม่มีแฟลก แต่ approval_policy=\"$pol\" ใน $cfgfile ⇒ ไม่ถาม [ผูกกับไฟล์ ไม่เดินทางไปกับ charter]" ;;
            "") echo "ask|codex ไม่มีแฟลก และอ่าน approval_policy จาก $cfgfile ไม่ได้ (ไม่มีไฟล์/ไม่มีคีย์)" ;;
            *)  echo "ask|codex ไม่มีแฟลก และ approval_policy=\"$pol\" ⇒ จะถาม" ;;
          esac ;;
      esac ;;
    claude)
      case "$cmd" in
        *--dangerously-skip-permissions*) echo "bypass|--dangerously-skip-permissions" ;;
        *"--permission-mode bypassPermissions"*|*"--permission-mode=bypassPermissions"*) echo "bypass|--permission-mode bypassPermissions" ;;
        *) echo "ask|claude ไม่มี --dangerously-skip-permissions ⇒ ถามทุก write/bash" ;;
      esac ;;
    opencode)
      case "$cmd" in
        *--auto*) echo "bypass-weak|--auto (auto-approve เฉพาะที่ไม่ได้ถูก deny ไว้)" ;;
        *) echo "ask|opencode ไม่มี --auto" ;;
      esac ;;
    thclaws)
      case "$cmd" in
        *--accept-all*) echo "bypass|--accept-all" ;;
        *"--permission-mode auto"*|*"--permission-mode=auto"*) echo "bypass|--permission-mode auto" ;;
        *--allowed-tools*) echo "allowlist|มีแต่ --allowed-tools ซึ่งเป็น allowlist ไม่ใช่ bypass" ;;
        *) echo "ask|thclaws ไม่มี --accept-all" ;;
      esac ;;
    "") echo "unknown|แยกชื่อไบนารีจากคำสั่งไม่ได้" ;;
    *)  echo "unknown|ไม่รู้จักธงของ engine \"$bin\" — ตอบไม่ได้ ≠ ผ่าน · ดู \`$bin --help\`" ;;
  esac
}

# ── _vc_perm_report <role> <engine> <resolved-cmd> ──────────────────────────
# พิมพ์บรรทัดคนอ่าน + ต่อ machine block  (อาศัย dynamic scope ของ bash เพื่อเขียน `machine`
# ของ enginecheck — ตั้งใจ ไม่ใช่อุบัติเหตุ · จึง **ห้าม** ประกาศ `local machine` ที่นี่)
#
# 🔴 ต้องเรียกจาก **ทั้งสองสาย** ของ enginecheck:
#    · สาย alias ลงทะเบียนแล้ว
#    · สาย fallthrough (engine ไม่ลงทะเบียน ⇒ ตกไป `default`)  ← **สายที่ holmes เดินมา**
#      `default` บนเครื่องนี้ = `claude --model claude-opus-5 --continue` = **ask**
#      ⇒ สายที่อันตรายที่สุดคือสายที่เกือบไม่ได้ตรวจ (แพตช์แรกของผมตกสายนี้ไปจริง ๆ)
_vc_perm_report() {
  local role="$1" engine="$2" cmd="$3" pm pmode pwhy
  [ -n "$cmd" ] || { printf '    ❓ perm     unknown — ไม่มีคำสั่งให้ตรวจ\n'
                     machine="${machine}enginecheck.perm: $role unknown engine=$engine
"; return 0; }
  pm=$(_vc_permmode "$cmd"); pmode="${pm%%|*}"; pwhy="${pm#*|}"
  case "$pmode" in
    bypass)      printf '    🔓 perm     bypass — %s\n' "$pwhy" ;;
    bypass-weak) printf '    🔓 perm     bypass-weak — %s\n' "$pwhy"
                 printf '               deny-list ยังทำให้ค้างได้ ⇒ อ่อนกว่า bypass ของ codex/claude\n' ;;
    allowlist)   printf '    ⚠️ perm     allowlist — %s\n' "$pwhy"
                 printf '               จะค้าง/ถูกปฏิเสธเมื่อโมเดลเรียก tool นอกลิสต์\n' ;;
    ask)         printf '    🔴 perm     ASK — %s\n' "$pwhy"
                 printf '               ⇒ worker จะค้างที่ **การเขียนไฟล์/คำสั่งแรก** ไม่ใช่ตอน boot\n'
                 printf '               ⇒ bootverify จับไม่ได้ (มันตรวจจอตอน boot) · หลัง spawn ใช้ `permstall <session>`\n'
                 printf '               ถ้าตั้งใจให้ถาม (probe/มีคนเฝ้า) = ถูกต้อง · ถ้าไม่ ต้องฝัง bypass ใน alias\n' ;;
    *)           printf '    ❓ perm     unknown — %s\n' "$pwhy" ;;
  esac
  machine="${machine}enginecheck.perm: $role $pmode engine=$engine
"
}

# ── _vc_tier_report <role> <resolved-cmd> ───────────────────────────────────
# 🎚️ **มิติที่สี่ — และมันไม่ใช่ความถูกต้อง มันคือ *ความเหมาะสมกับงาน***
#    engine/model/permission/trust ตอบว่า *worker จะทำงานได้ไหม*
#    **tier ตอบว่า จ่ายแพงเกินไปไหม และแรงพอไหม** — คนละคำถาม และไม่มีด่านไหนถามมันเลย
#
# `[verified 2026-08-09 · model-tier-census.py บน 10 layer file · 61 alias]`
#    effort ที่ถูก pin 19 ตัว: **xhigh 9 · medium 8 · high 1 · low 1**
#    และ **9 alias ไม่ pin ทั้ง model และ effort** ⇒ ขี่ ambient default ของ `config.toml`
#    ⇒ **ทีมที่ทุก role ได้ tier เดียวกัน ไม่ใช่การตัดสินใจ มันคือ default ที่รั่วผ่านมา**
#
# ⚖️ **สิ่งที่เครื่องมือนี้จะไม่ทำ**: ไม่จัดอันดับว่า model ไหน "ดีกว่า" — ผมวัดไม่ได้
#    และ claim แบบนั้นไม่มีหลักฐานรองรับในรีโปนี้ ⇒ **รายงานชื่อ model เฉย ๆ**
#    ส่วน `model_reasoning_effort` **จัดอันดับได้** เพราะ codex นิยามลำดับไว้เอง
#    (low < medium < high < xhigh) ⇒ อันนี้เทียบได้โดยไม่ต้องเดา
#
# 🔑 รูปที่มันจับ: **ทีม 7 role ที่ทุกคนได้ xhigh** อ่านแล้วเหมือนความรอบคอบ
#    แต่มันแปลว่า **ไม่มีใครเลือกอะไรเลย** — role ที่แค่อ่านไฟล์แล้วรายงาน จ่ายเท่ากับ
#    role ที่ออกแบบสถาปัตยกรรม · และ role ที่ยากจริงอาจได้ `low` โดยไม่มีใครเห็น
_vc_tier_report() {
  local role="$1" cmd="$2" model="" effort=""
  model=$(printf '%s' "$cmd" | sed -n 's/.*--model[= ]\([^ ]*\).*/\1/p')
  effort=$(printf '%s' "$cmd" | sed -n 's/.*model_reasoning_effort=\{0,1\}["=]\{0,2\}\([a-z]*\).*/\1/p')
  [ -n "$effort" ] || effort=$(printf '%s' "$cmd" | sed -n 's/.*--effort[= ]\([a-z]*\).*/\1/p')
  printf '    🎚️ tier     model=%s effort=%s\n' "${model:-ambient}" "${effort:-ambient}"

  # 🩹 2026-08-10 [atlas เสนอเป็น "แกนที่ 3" หลัง portia ตั้ง codex seat แรก · ผมไม่รับกรอบ
  #    "placement" แต่รับของ] Step 7 คือ *เนื้อหาถูก อยู่ผิดครึ่ง* · อันนี้ **ไม่มี carrier เลย**:
  #    engine กับ permission อยู่ในสตริง alias และไฟล์บอกไว้ · **model ของ alias ที่ไม่มี
  #    `--model` มาจาก `$CODEX_HOME/config.toml` ซึ่ง machine-global · agent ไหนก็แก้ได้ ·
  #    ไม่มีอะไรระหว่าง charter กับ pane เอ่ยถึงมัน** และ `enginecheck` PASS + `bootverify`
  #    READY **ยืนอยู่ได้พร้อมกันขณะที่มันเป็นจริง**
  #    ⇒ `bootverify` มี `AMBIENT-not-pinned` อยู่แล้ว แต่นั่นคือ **หลัง** boot
  #      ⇒ ที่ขาดคือสัญญาณ **ก่อน commit point** — รูปเดียวกับที่การแก้ permission ทำเมื่อ 08-09
  #    ⇒ พิมพ์ **ไฟล์+บรรทัด+ค่า** ที่จะเป็นคนตัดสิน ไม่ใช่แค่คำว่า "ambient"
  local msrc="alias" mfile="" mline="" mval=""
  if [ -z "$model" ]; then
    msrc="ambient"
    local ch; ch=$(printf '%s' "$cmd" | sed -n 's/.*CODEX_HOME=\([^ ]*\).*/\1/p')
    ch="${ch/#\$HOME/$HOME}"; ch="${ch/#\~/$HOME}"
    case "$cmd" in
      *codex*)
        mfile="${ch:-$HOME/.codex}/config.toml"
        if [ -r "$mfile" ]; then
          mline=$(grep -n -m1 -E '^[[:space:]]*model[[:space:]]*=' "$mfile" 2>/dev/null | cut -d: -f1)
          mval=$(grep -m1 -E '^[[:space:]]*model[[:space:]]*=' "$mfile" 2>/dev/null \
                 | sed 's/.*=[[:space:]]*//; s/^"//; s/"$//')
        else mval="<อ่านไฟล์ไม่ได้>"; fi ;;
      *) mfile=""; mval="<engine นี้ยังไม่รู้ว่าอ่าน ambient จากไหน>" ;;
    esac
    if [ -n "$mfile" ]; then
      printf '               📍 model-source=ambient ⇒ %s:%s = %s\n' "$mfile" "${mline:-?}" "${mval:-<ไม่มีบรรทัด model>}"
      printf '                  ⇒ ไฟล์นี้ **machine-global · agent ไหนก็แก้ได้** และไม่มีอะไรใน charter เอ่ยถึงมัน\n'
      printf '                  ⇒ แก้บรรทัดเดียว = **ทุก seat ที่เคยบูตจาก alias นี้เปลี่ยน model** โดย PASS ไม่ขยับ\n'
    else
      printf '               📍 model-source=ambient ⇒ %s\n' "$mval"
    fi
  fi
  if [ -z "$model" ] && [ -z "$effort" ]; then
    printf '               ⚠️ ไม่ pin ทั้งสองอย่าง ⇒ ขี่ค่าใน config.toml ของ home นั้น\n'
    printf '                  ⇒ ใครแก้ config เมื่อไหร่ **ทีมเปลี่ยน tier เงียบ ๆ ทั้งทีม**\n'
  fi
  machine="${machine}enginecheck.tier: $role model=${model:-ambient} effort=${effort:-ambient} model-source=$msrc${mfile:+ ambient-from=$mfile:${mline:-?}}
"
}

# ── _vc_tier_summary — ระดับ *ทีม* ไม่ใช่ระดับสมาชิก ────────────────────────
# ข้อนี้ต้องดูทั้งทีมพร้อมกันถึงจะเห็น — สมาชิกทีละคนดูปกติหมด
_vc_tier_summary() {
  local m="$1" n_mem n_model n_effort n_ambient
  n_mem=$(printf '%s\n' "$m" | grep -c '^enginecheck.tier: ')
  [ "$n_mem" -ge 2 ] || return 0
  n_model=$(printf '%s\n' "$m" | sed -n 's/^enginecheck.tier: [^ ]* model=\([^ ]*\).*/\1/p' | sort -u | grep -c .)
  n_effort=$(printf '%s\n' "$m" | sed -n 's/^enginecheck.tier: .* effort=\(.*\)$/\1/p' | sort -u | grep -c .)
  n_ambient=$(printf '%s\n' "$m" | grep -c 'model=ambient effort=ambient')
  printf 'enginecheck.tiers: members=%s distinct-model=%s distinct-effort=%s all-ambient=%s\n' \
    "$n_mem" "$n_model" "$n_effort" "$n_ambient"
  if [ "$n_model" = "1" ] && [ "$n_effort" = "1" ]; then
    printf '  🎚️ ทุก role ในทีมนี้ได้ **tier เดียวกันหมด** (%s สมาชิก)\n' "$n_mem"
    printf '     นี่อาจถูกต้องถ้าตั้งใจ — แต่ถ้าไม่ได้ตั้งใจ มันคือ default ที่รั่วผ่านมา\n'
    printf '     role ที่อ่านไฟล์แล้วรายงาน จ่ายเท่ากับ role ที่ออกแบบสถาปัตยกรรม\n'
    printf '     ⇒ ตั้ง alias แยกต่อ tier แล้วให้ charter เลือกต่อ role (model อยู่ในสตริงคำสั่งเท่านั้น)\n'
  fi
  if [ "$n_ambient" -gt 0 ]; then
    printf '  ⚠️ %s สมาชิกไม่ pin ทั้ง model และ effort ⇒ tier ของทีมขึ้นกับไฟล์ที่คนอื่นแก้ได้\n' "$n_ambient"
  fi
}

# ── _vc_trust_report <role> <resolved-cmd> <member-dir> ─────────────────────
# 🔴 คลาสเดียวกับ permission เป๊ะ — **ค้างตอน boot โดยที่ทุกด่านเขียว** แค่คนละนาที
#    codex ถาม `Do you trust the contents of this directory?` เมื่อ **path ของสมาชิก**
#    ไม่มี entry ใน `$CODEX_HOME/config.toml` ⇒ pane นั่งรอ ไม่รับ turn
#
# 🧪 **trust เทียบ path แบบเป๊ะ ไม่สืบทอดจาก ancestor** `[verified 2026-08-09 · 0.147.0 · 2 แขน]`
#    lucifer วัดแขนบวกได้แขนเดียวแล้วประกาศขอบเขตตัวเองไว้ตรง ๆ · ผมยิงแขนที่ขาดให้ครบ
#    ใช้ throwaway `CODEX_HOME` (ไม่แตะ home จริงของใคร) แล้วลบทิ้งพร้อม auth:
#      ARM A  trust เฉพาะ `[projects."/home/user"]` · cwd `/home/user/.tmp-trustprobe/armA`
#             ⇒ **ขึ้น trust dialog เต็มจอ** ทั้งที่ ancestor ถูก trust แล้ว
#      ARM B  เพิ่ม `[projects."/home/user/.tmp-trustprobe/armB"]` · cwd อันเดียวกัน
#             ⇒ **บูตเข้า prompt ตรง ไม่มี dialog**
#    ⇒ **ตกได้ทั้งสองทิศ** ⇒ `/home/user` ถูก trust ไม่ได้ช่วย worktree ลูกแม้แต่ระดับเดียว
#    ⇒ นี่คือเหตุผลที่ home ของ lucifer มี entry ราย worktree 38 อัน ทั้งที่ ancestor trusted แล้ว
#
# ⚠️ **เครื่องนี้มี codex home อย่างน้อย 6 แห่ง** (lucifer ตั้ง `CODEX_HOME` แยกต่อ role)
#    ⇒ ด่านที่อ่าน `~/.codex` ที่เดียว **ตอบแทนทั้งเครื่องไม่ได้** ⇒ อ่าน home ที่ *alias นี้* ชี้ไป
_vc_trust_report() {
  local role="$1" cmd="$2" mdir="$3" ch cfg n
  case "$(_vc_engine_basename "$(_vc_strip_env_prefix "$cmd")")" in
    codex) ;;
    *) return 0 ;;                      # engine อื่นไม่มีกลไกนี้ — เงียบ ดีกว่าเดา
  esac
  ch=$(printf '%s' "$cmd" | sed -n 's/.*CODEX_HOME=\([^ ]*\).*/\1/p')
  ch="${ch/#\$HOME/$HOME}"; ch="${ch/#\~/$HOME}"
  cfg="${ch:-$HOME/.codex}/config.toml"
  if [ ! -r "$cfg" ]; then
    printf '    ❓ trust    อ่าน %s ไม่ได้ ⇒ ตอบไม่ได้ว่าจะเจอ trust dialog ไหม\n' "$cfg"
    machine="${machine}enginecheck.trust: $role unknown home=${ch:-$HOME/.codex}
"; return 0
  fi
  n=$(grep -cF "[projects.\"$mdir\"]" "$cfg" 2>/dev/null || true)
  if [ "${n:-0}" -ge 1 ]; then
    printf '    🤝 trust    exact-path entry มีอยู่แล้วใน %s ⇒ ไม่เจอ dialog ตอนบูต\n' "$cfg"
    machine="${machine}enginecheck.trust: $role trusted home=${ch:-$HOME/.codex}
"
  else
    printf '    🟠 trust    **ไม่มี entry สำหรับ path นี้** ⇒ pane จะขึ้น `Do you trust…` แล้วนั่งรอ\n'
    printf '               ตรวจที่: %s\n' "$cfg"
    printf '               ⚠️ trust เทียบ path **เป๊ะ** ไม่สืบทอดจาก ancestor — `/home/user` trusted ไม่ช่วย\n'
    printf '                  `[verified 2026-08-09 · codex 0.147.0 · ตกได้สองทิศ]`\n'
    printf '               ⛔ **อย่าเคลียร์ด้วย Enter เปล่า** — 0.147.0 ไฮไลต์ `1. Yes, continue`\n'
    printf '                  (บน 0.146.1 เลข 1 คือ `Update now` ที่อัปเกรด binary ทั้งเครื่อง)\n'
    machine="${machine}enginecheck.trust: $role untrusted home=${ch:-$HOME/.codex}
"
  fi
}

# ── placement <file> <region-anchor-regex> <token>... ───────────────────────
# 🎯 **ตัวตรวจเชิงกลของ HALF-APPLICATION** — จนถึง 2026-08-10 คลาสนี้หาเจอได้ทางเดียวคือ
#    **มีคนบังเอิญสังเกต** (perm=/trust= อธิบายครบในครึ่งบน หายเกลี้ยงจากครึ่งที่ agent เดิน ·
#    เลข `3` hardcode ห่างจากย่อหน้าที่ห้าม hardcode แปดบรรทัด)
#
# 🔑 **หลักการ (atlas generalize จาก self-check ที่ผมยิงมือ แล้วขอเอาไปใช้เอง)**:
#    นับ token **ทั้ง artifact** และ **ในภูมิภาคที่บังคับ** แล้ว **บังคับให้เท่ากัน**
#    ⇒ นับในภูมิภาคอย่างเดียว พิสูจน์แค่ว่า **มีอยู่**
#    ⇒ **ความเท่ากันเท่านั้นที่พิสูจน์ว่า *ไม่มีที่อื่น*** — และ "อยู่ที่อื่น" คือทั้งหมดของโรคนี้
#
# ⚠️ ตัวนี้เกิดเพราะ **ตัวตรวจของโรคนี้ ก็เป็น half-application เหมือนกัน**: ผมยิงเป็น
#    bash one-liner สดในเทิร์นเดียว atlas ชมว่าเป็น invariant แล้วบอกว่าจะเอาไปใช้ —
#    ซึ่งแปลว่ามันอยู่ในความจำของสองคน ไม่ได้อยู่ในเครื่องมือที่ใครก็รันได้
#
# ⚠️ `grep -cF` นับ **บรรทัดที่มี** ไม่ใช่จำนวนครั้ง — ทั้ง whole และ region ใช้หน่วยเดียวกัน
#    จึงเทียบกันได้ · **ห้ามเทียบข้ามหน่วย** (บทเรียน delta ที่ถอนไป 2026-08-10)
placement() {
  local file="${1:?usage: placement <file> <region-anchor-regex> <token>...}"
  local anchor="${2:?ต้องระบุ regex ของบรรทัดที่เริ่มภูมิภาคบังคับ}"
  shift 2
  [ $# -ge 1 ] || { echo "ต้องระบุอย่างน้อย 1 token"; return 2; }
  [ -f "$file" ] || { echo "placement: ไม่มีไฟล์ $file"; return 2; }
  local ln total
  ln=$(grep -nE -- "$anchor" "$file" 2>/dev/null | head -1 | cut -d: -f1)
  total=$(wc -l < "$file")
  if [ -z "$ln" ]; then
    echo "placement: หา anchor ไม่เจอ — /$anchor/ ⇒ **ตอบไม่ได้ ไม่ใช่ผ่าน**"
    echo "overall: UNVERIFIED"; return 2
  fi
  printf 'placement.file: %s lines=%s
' "$file" "$total"
  printf 'placement.region: from=%s (/%s/) to=EOF  ⇒ %s บรรทัด · นอกภูมิภาค %s บรรทัด
'     "$ln" "$anchor" "$((total-ln+1))" "$((ln-1))"
  local bad=0 t whole region
  for t in "$@"; do
    whole=$(grep -cF -- "$t" "$file")
    region=$(sed -n "${ln},\$p" "$file" | grep -cF -- "$t")
    if [ "$region" -eq 0 ]; then
      printf '  ❌ ABSENT      %-46s whole=%s region=0 ⇒ ไม่อยู่ในภูมิภาคที่บังคับเลย
' "$t" "$whole"
      bad=1
    elif [ "$whole" -ne "$region" ]; then
      printf '  ⚠️ LEAKED      %-46s whole=%s region=%s ⇒ **%s บรรทัดอยู่นอกภูมิภาค**
'         "$t" "$whole" "$region" "$((whole-region))"
      printf '                 นอกภูมิภาคที่บรรทัด: %s
'         "$(head -n $((ln-1)) "$file" | grep -nF -- "$t" | cut -d: -f1 | tr '
' ',' | sed 's/,$//')"
      bad=1
    else
      printf '  ✅ PLACED      %-46s whole=%s region=%s (เท่ากัน)
' "$t" "$whole" "$region"
    fi
  done
  echo 'placement.scope: out-of-scope=ความหมาย,ลำดับ,ว่าผู้บริโภคอ่านจริงไหม'
  echo '  ⚠️ ตัวนี้ตอบแค่ว่า *ข้อความอยู่ในภูมิภาคที่บังคับและไม่มีที่อื่น*'
  echo '     มันไม่ได้ตอบว่าภูมิภาคนั้นคือที่ที่ผู้บริโภคเดินผ่านจริง — นั่นคือ Gate 5.3 ที่คนต้องตอบเอง'
  [ "$bad" -eq 0 ] && { echo 'overall: PLACED'; return 0; }
  echo 'overall: MISPLACED'; return 1
}

# ── permstall <session> ─────────────────────────────────────────────────────
# 🔑 **ชั้นที่บันไดหลักฐานของเราไม่มี: ความพร้อมมันหมดอายุ**
#
#    บันไดเดิมทั้งบันได (delivered → capture-pane เห็นข้อความ → busy marker →
#    /proc cmdline ถูก → จอเป็นของ agent → agent อ้างเนื้อความกลับมา)
#    **วัดที่ t=0 ทั้งหมด** · `bootverify` ก็ตรวจจอตอน boot (update/trust dialog)
#    ซึ่งตอนนั้นยัง **ไม่มี** permission prompt เพราะ worker ยังไม่ได้เขียนอะไร
#
#    worker ของ holmes **ผ่านชั้นสูงสุด** (รับ turn · ตอบ · ลงมือทำงาน) แล้วค่อยไปค้าง
#    ตอนเขียนไฟล์แรก ⇒ `READY` ตอน boot **ไม่ใช่หลักฐานว่า READY ตอน write แรก**
#
# ⇒ และนี่คือคำตอบว่าทำไม lead ไม่เดินดู: **ไม่ใช่เพราะ lead ขี้เกียจ** — lead ตรวจครบ
#   ตามที่ skill สั่ง เห็น READY แล้วไปทำอย่างอื่น เพราะ **ไม่มีที่ไหนบอกว่าความพร้อม
#   หมดอายุได้** ⇒ แก้ที่เครื่องมือ+เอกสาร ไม่ใช่ที่วินัยของ lead
#
# อ่านอย่างเดียว: capture-pane · **ไม่ส่ง ไม่กด ไม่เลือกตัวเลืกใด ๆ**
# การกด "Yes" คือการให้สิทธิ์แทนมนุษย์ของทีมนั้น — ไม่ใช่งานของเครื่องมือตรวจ
# (golden rule: ห้ามเป็นคนถือ "อนุญาต" ของมนุษย์ไปส่งต่อ)
permstall() {
  local sess="${1:?usage: permstall <session> [--watch [sec]]   # อ่านอย่างเดียว ไม่ส่งอะไรเข้า pane}"
  # ── --watch: ตอบข้อที่เจ้าของงานชี้ตรง ๆ ว่า "lead ไม่ได้เดินดู worker" ────────
  # เราแก้เรื่อง *มองไม่เห็น* ไปแล้ว (ตัวตรวจมีแล้ว) แต่ยังเหลือเรื่อง **ต้องจำว่าต้องตรวจ**
  # ⇒ กฎที่พึ่งความจำของคนคือกฎที่จะพลาด — **ทำให้มันเป็นสิ่งที่เปิดทิ้งไว้ ไม่ใช่สิ่งที่ต้องนึกได้**
  # ⇒ พิมพ์เฉพาะตอน **สถานะเปลี่ยน** ไม่งั้นมันกลายเป็นเสียงรบกวนแล้วคนจะปิดมัน
  if [ "${2:-}" = "--watch" ]; then
    local iv="${3:-60}" prev="" now
    echo "permstall.watch: $sess ทุก ${iv}s — พิมพ์เฉพาะตอนสถานะเปลี่ยน · Ctrl-C เพื่อหยุด"
    echo "  (อ่านอย่างเดียวทุกรอบ ไม่ส่ง ไม่กด — ปลอดภัยที่จะเปิดค้างไว้ข้ามคืน)"
    while :; do
      now=$(permstall "$sess" 2>&1)
      local sig; sig=$(printf '%s' "$now" | grep -E '^permstall.pane:|^permstall.count:')
      if [ "$sig" != "$prev" ]; then
        printf '\n──── %s ────\n' "$(date '+%H:%M:%S')"
        printf '%s\n' "$now"
        prev="$sig"
      fi
      sleep "$iv"
    done
  fi
  local wins n_block=0 n_pane=0 n_stale=0
  wins=$(tmux list-windows -t "=$sess" -F '#{window_index}:#{window_name}' 2>/dev/null) || {
    echo "permstall.session: $sess NOT-FOUND (tmux list-windows)"; echo "overall: UNVERIFIED"; return 2; }
  [ -n "$wins" ] || { echo "permstall.session: $sess NO-WINDOWS"; echo "overall: UNVERIFIED"; return 2; }
  echo "permstall $sess   [อ่านอย่างเดียว · ไม่ส่ง Enter · ไม่เลือกตัวเลือก]"
  while IFS= read -r w; do
    [ -n "$w" ] || continue
    local idx="${w%%:*}" name="${w#*:}" pane cap q
    pane="${sess}:${idx}"
    n_pane=$((n_pane+1))
    cap=$(tmux capture-pane -p -t "=$pane" 2>/dev/null | tail -40)
    # 🔴 2026-08-09 [lucifer เสนอ · ผมยืนยันบน pane ตัวเอง] `(deleted)` ต้องเป็น **สัญญาณของตัวเอง**
    #    ไม่ใช่รายละเอียดที่ซ่อนใน `exe=` ของ pane ที่ค้าง — เพราะ pane ที่รัน binary ซึ่ง
    #    **ไม่มีอยู่บนดิสก์แล้ว คือ pane ที่ไม่มีใครรู้ว่ามันรันอะไรอยู่**
    #    และมันเกิดกับ **pane ที่ทำงานปกติ** ด้วย ⇒ ต้องตรวจทุก pane ไม่ใช่เฉพาะที่ BLOCKED
    #    `[verified 2026-08-09: ทั้ง 8 oracle pane ของฟลีต รวม pane ของผมเอง รัน
    #      @anthropic-ai/.claude-code-DycUbYqO/bin/claude.exe (deleted) · staging dir หายแล้ว ·
    #      package บนดิสก์ mtime 09:17 วันนี้ = **หลัง** ทุก pane เกิด ⇒ `claude --version`
    #      ตอบ 2.1.226 แต่ไม่มี pane ไหนบนเครื่องนี้เป็น 2.1.226]`
    #    🎯 scar ที่เราสอนกันทั้งคืน (*version บนดิสก์ ≠ version ใน pane*) **เป็นจริงกับตัวเราเอง
    #      พร้อมกันทั้ง 8 คน ในเวลาที่เรากำลังคุยเรื่องนี้** — เราเล็งมันไปที่ worker เท่านั้น
    #    ⚖️ ขอบเขต (lucifer ระบุเอง ผมไม่ขยาย): `(deleted)` + staging dir หาย + mtime หลัง start
    #      พิสูจน์ว่า **ไฟล์ที่ pane รัน ไม่ใช่ไฟล์ที่อยู่บนดิสก์ตอนนี้** — **ไม่ได้**พิสูจน์ว่า
    #      *เลขเวอร์ชัน*ต่างกัน · อ่าน inode ที่ถูกลบกลับไม่ได้
    local _sp _sexe
    _sp=$(tmux display-message -p -t "=$pane" '#{pane_pid}' 2>/dev/null)
    local _sres=""
    [ -n "${_sp:-}" ] && _sres=$(_vc_engine_pid "$_sp" 2>/dev/null)
    _sexe=$(printf '%s' "$_sres" | cut -f2)
    case "${_sexe:-}" in
      *"(deleted)"*)
        n_stale=$((n_stale+1))
        # 🩹 2026-08-09 [lucifer จับ · **คลาสเดียวกับ WARN ของ engine claude ที่เขาจับเมื่อคืน
        #    คนเดิม ครั้งที่สอง**] ป้ายเดิมชื่อ `STALE-BIN` ⇒ **ยืนยันความล้าสมัยที่มันไม่ได้วัด**
        #    `[verified 2026-08-09]` pane ของ lucifer (`2341711`) exe เป็น `(deleted)` **จริง**
        #    แต่ build ที่มันประกาศคือ `2.1.226` = **เท่ากับเลขบนดิสก์เป๊ะ** (same-version replace)
        #    ⇒ **`(deleted)` กับ "ล้าสมัย" เป็นคนละคำถาม** — pane รัน binary ที่ถูกลบได้
        #      โดยเวอร์ชันไม่ล้าเลย · prism ก็เหมือนกัน
        #    ⇒ ถ้าเหลือช่องเดียวชื่อ STALE ตัวที่ current จะถูกรายงานว่าเก่า **แล้วคนจะเลิกเชื่อสัญญาณ**
        #      ซึ่งเป็นความล้มเหลวแบบเดียวกับ false alarm ที่เราไล่กันมาทั้งคืน
        printf '  ⏳ REPLACED-BIN %-31s ไฟล์ที่รันอยู่ **ไม่ใช่ไฟล์ที่อยู่บนดิสก์ตอนนี้**\n' "$name"
        printf '      exe=%s\n' "$(printf '%s' "$_sexe" | sed 's|/home/user/.npm-global/lib/node_modules/||' | cut -c1-84)"
        # ช่องที่สาม [lucifer 2026-08-09] — **pid คือสิ่งที่ทำให้คำตอบเรื่อง version ยังไม่หมดอายุ**
        # process เปลี่ยน image ตัวเองไม่ได้ ⇒ ตราบใดที่ pid นี้ยังมีชีวิต build ก็เปลี่ยนไม่ได้
        # ⇒ พิมพ์ pid ออกมาเพื่อให้คนเอาไปผูกกับ transcript ได้ ไม่ต้องเดาว่า entry ไหนของใคร
        # 🩹 หยิบ pid จาก **ผลเรียกเดียวกัน** — รอบแรกผมอ้าง `$_ep` ซึ่งเป็นตัวแปรของบล็อก
        #    ข้างล่างที่ยังไม่ถูกกำหนดตรงนี้ ⇒ พิมพ์ `engine-pid=? alive=NO` ให้ pane ที่มีชีวิตอยู่
        #    ⇒ **สัญญาณที่โกหกทิศ "ตาย" บน pane ที่ยังรัน** — เจอเพราะรันดู ไม่ใช่เพราะอ่านโค้ด
        local _epid_s; _epid_s=$(printf '%s' "$_sres" | cut -f1)
        printf '      engine-pid=%s alive=%s started=%s\n' "${_epid_s:-?}" \
          "$([ -d "/proc/${_epid_s:-0}" ] && echo yes || echo NO)" \
          "$(ps -o lstart= -p "${_epid_s:-0}" 2>/dev/null | cut -c5-16 | tr -s ' ')"
        printf '      ⚠️ นี่ **ไม่ได้แปลว่าเวอร์ชันล้าสมัย** — same-version replace เกิดขึ้นจริงบนเครื่องนี้\n'
        printf '         วัดเวอร์ชันที่รันอยู่แยกต่างหาก (claude): grep -o \x27"version":"[^"]*"\x27 <transcript.jsonl> | tail -1\n'
        printf '         ⇒ กฎที่แม่น: อ่าน entry ที่เขียน **หลัง engine pid ปัจจุบันเกิด** —\n'
        printf '            "entry สุดท้าย" เป็นแค่ heuristic ที่ใช้ได้เพราะมันมาจาก pid ที่ยังมีชีวิต\n'
        printf '         ⇒ version เปลี่ยนกลางไฟล์ได้ — ไม่ใช่ process เดียวเปลี่ยน build แต่เป็น\n'
        printf '            **คนละ process จาก resume เขียนลง session file เดียวกัน**\n'
        printf '         ⇒ 🔑 process เปลี่ยน build ตัวเองไม่ได้ ⇒ ถ้า pid ยังมีชีวิต เลขนั้นคือ\n'
        printf '            **build ที่รันเดี๋ยวนี้** และเปลี่ยนไม่ได้จนกว่าจะ restart\n'
        printf '      permstall.pane: %s REPLACED-BINARY\n' "$name" ;;
    esac
    # ธงของ prompt ต่อ engine — จับ **ตัวคำถาม** ไม่ใช่ตัวเลือก เพราะตัวเลือก/ตัวเลข
    # เปลี่ยนตามเวอร์ชัน (บทเรียน update-dialog: ห้าม hardcode เลข)
    #
    # 🔴 2026-08-09 [arnon ชี้ · ผมทดสอบแล้วมันจริง] เดิมด่านนี้จับ **เฉพาะ permission**
    #    ⇒ pane ที่ค้างบน `✨ Update available!` ได้ `blocked=0` **เขียวสนิท**
    #    ⇒ **false green ในเครื่องมือที่สร้างมาเพื่อฆ่า false green** — และเป็นเคสที่
    #      เจ้าของงานบอกว่าเจอบ่อยที่สุด: *"worker เปิดขึ้นมาถามว่าจะ update ไหม
    #      แล้ว lead ไม่ได้ตามดูว่ามันค้างอยู่หน้านั้นหรือเปล่า"*
    #    ⇒ `bootverify` จับได้ แต่มันเป็น **ด่านครั้งเดียวที่ t=0** · เวอร์ชันใหม่ของ codex
    #      **โผล่เมื่อไหร่ก็ได้** ⇒ worker ที่ spawn ตอนบ่ายเจอ dialog ที่ worker ตอนเช้าไม่เจอ
    #      ⇒ ต้องอยู่ใน **ลูป** ไม่ใช่ในด่านบูต
    #    ⇒ แยก `kind=` เพราะ **ทางแก้คนละทาง**:
    #        permission  → ให้สิทธิ์ หรือ restart ด้วย alias ที่มี bypass token
    #        cli-dialog  → อ่านเลขจากจอ · **ห้าม Enter เปล่าเด็ดขาด** — บน update dialog
    #                      ตัวไฮไลต์คือ `Update now` ที่รัน `npm install -g` ทั้งเครื่อง
    local kind="" q=""
    # 🩹 2026-08-09 — เดิมจับคำเดี่ยว ⇒ **`อนุญาต` ลอย ๆ ในผลงานของ worker ทำให้เตือนมั่ว**
    #    เจอตอนกวาดฟลีตจริง: `prober-academic-alt` ที่**กำลังทำงานอยู่** ถูกรายงานว่า BLOCKED
    #    เพราะเนื้อความที่มันเขียนเองมีคำนั้น ⇒ ใช้กฎสองเงื่อนไขเดียวกับ cli-dialog:
    #    **คำถาม + แถวตัวเลือกเลข ต้องอยู่ท้ายจอด้วยกัน** (prompt ของ claude มี `1. Yes` เสมอ)
    local tail15; tail15=$(printf '%s' "$cap" | tail -15)
    local qb qo
    # 🩹 2026-08-10 [verified: live codex 0.147.0 approval prompt · atlas routed the gap · portia found it]
    #    เดิมคำในนี้เป็น **คำศัพท์ของ claude ล้วน** ⇒ codex ถาม `Would you like to run the following
    #    command?` ⇒ `qb` ว่าง ⇒ **AND ไม่ครบ ⇒ blocked=0 บนจอที่มี prompt เต็ม ๆ** (false negative)
    #    ยืนยันด้วยการรัน `permstall` ใส่เพนที่กำลังถามจริง ไม่ใช่ด้วยการอ่าน regex:
    #      ก่อนแก้ → `permstall.pane: codex no-prompt-visible` · blocked=0
    #    ⚠️ **คง AND ไว้** (banner + แถวตัวเลือก) — มันคือกันชน false-positive จาก 2026-08-09
    #      (worker ที่เขียนคำว่า `อนุญาต` ในผลงานตัวเอง ถูกรายงาน BLOCKED) · แก้เฉพาะ**คลังคำ**
    qb=$(printf '%s' "$tail15" | grep -m1 -E \
      'Do you want to (proceed|create|make|edit|run)|Would you like to run the following command|Permission required|requires approval|Allow .* to |Grant .* permission|auto-approve\?|Approve this|ขออนุญาต' 2>/dev/null)
    # 🩹 2026-08-10 [prism วัด opencode 1.18.15 · zai/glm-5.2 · ผมยืนยันซ้ำบนเพนจริงของตัวเอง]
    #    **opencode ไม่มีแถวตัวเลือกเป็นตัวเลขเลย** — มันเป็น `Allow once / Allow always / Reject`
    #    ⇒ ต่อให้เติม banner อย่างเดียว AND ก็ไม่มีวันครบ ⇒ **ต้องเติมทั้งสองฝั่ง**
    #    ⇒ สามตระกูลไม่แชร์ token กันสักตัว: claude `Do you want to…`+Yes/No ·
    #      codex `Would you like to run…`+`1. Yes, continue` · opencode `△ Permission required`+`Allow once`
    qo=$(printf '%s' "$tail15" | grep -m1 -E \
      '^[[:space:]]*[›>❯[:space:]]*[0-9]\.[[:space:]]|Allow once|Allow always' 2>/dev/null)
    if [ -n "$qb" ] && [ -n "$qo" ]; then q="$qb"; kind="permission"; fi
    if [ -z "$q" ]; then
      # 🔒 สองเงื่อนไข ไม่ใช่เงื่อนไขเดียว — บทเรียนจากด่าน `relay` เมื่อชั่วโมงก่อน:
      #    ถ้าจับแค่ "มีคำ" มันจะเตือนใส่ pane ที่กำลัง**พูดถึง**ไดอะล็อก (เช่น oracle ที่
      #    กำลังคุยเรื่องนี้อยู่) ⇒ **เตือนมั่วบ่อย ๆ = lead ปิดมันทิ้ง = กลับไปที่ปัญหาเดิม**
      #    ⇒ ต้องมี **banner** + **แถวตัวเลือกเลข** อยู่ใน **ท้ายจอ** ด้วยกัน
      local tailcap; tailcap=$(printf '%s' "$cap" | tail -15)
      local b o
      b=$(printf '%s' "$tailcap" | grep -m1 -E \
        'Update available!|Do you trust the contents of this directory|Is this a project you created or one you trust|trust this folder' 2>/dev/null)
      o=$(printf '%s' "$tailcap" | grep -m1 -E '^[[:space:]]*[›>❯[:space:]]*[0-9]\.[[:space:]]' 2>/dev/null)
      if [ -n "$b" ] && [ -n "$o" ]; then q="$b"; kind="cli-dialog"; fi
    fi
    if [ -n "$q" ]; then
      n_block=$((n_block+1))
      printf '  🔴 BLOCKED  %-34s [%s] %s\n' "$name" "$kind" "$(printf '%s' "$q" | sed 's/^[[:space:]]*//' | cut -c1-60)"
      printf '      pane=%s\n' "$pane"
      # ของจริงที่รันอยู่ — ต้องอ่าน **pid ลูก** เพราะ pane เป็น bash เปล่าในรูป `maw wake`
      local ppid child
      ppid=$(tmux display-message -p -t "=$pane" '#{pane_pid}' 2>/dev/null)
      child=$(ps --ppid "$ppid" -o args= 2>/dev/null | head -1)
      [ -n "$child" ] && printf '      proc=%s\n' "$(printf '%s' "$child" | cut -c1-96)"
      if [ -n "$child" ]; then
        # ตัวตนของ engine ถามจาก kernel ไม่ใช่จากชื่อที่โปรแกรมตั้งเอง (atlas) และ
        # **ไม่ยึดความลึก** เพราะ codex อยู่ depth 2 (node shim คั่น) ส่วน claude อยู่ depth 1
        # (lucifer หักล้างรูป depth-1 ของผม · ข้อเสนอ `pgrep -x codex -P` ของเขาก็ตกด้วย
        #  เพราะ `-P` ดูแค่ลูกตรง — ผมทดสอบแล้วคืนค่าว่างทั้ง 3 pane)
        local cpid cexe cbin="" _ep
        _ep=$(_vc_engine_pid "$ppid" 2>/dev/null) || _ep=""
        cpid=$(printf '%s' "$_ep" | cut -f1)
        cexe=$(printf '%s' "$_ep" | cut -f2)
        case "$cexe" in
          *codex*) cbin=codex ;; *claude*) cbin=claude ;;
          *opencode*) cbin=opencode ;; *thclaws*) cbin=thclaws ;;
        esac
        if [ -n "$cexe" ]; then
          printf '      exe=%s\n' "$(printf '%s' "$cexe" | cut -c1-92)"
          case "$cexe" in *"(deleted)"*)
            printf '      ⏳ binary ที่ pane นี้รันอยู่ **ถูกแทนที่ไปแล้วบนดิสก์** — pane เก่ากว่าเครื่อง\n' ;;
          esac
        fi
        # 🩹 2026-08-10 [verified: live codex probe — เอาต์พุตขัดแย้งกันเองในบล็อกเดียว]
        #    `_vc_permmode` ดึง CODEX_HOME จาก **สตริงคำสั่ง** ⇒ ครอบเฉพาะ alias ที่เขียน
        #    `CODEX_HOME=… codex …` ไว้เอง · ถ้า CODEX_HOME มาจาก **env ของ pane**
        #    (`tmux -e`, `maw wake`) cmdline ไม่มีคำนั้น ⇒ fallback ไป `~/.codex`
        #    ⇒ ผมได้ `perm=bypass … ⇒ ไม่ถาม` **พิมพ์ติดกับ `🔴 BLOCKED [permission]`
        #      ของเพนที่กำลังถามอยู่จริง ๆ** — เอาต์พุตเถียงตัวเองห่างกัน 2 บรรทัด
        #    ⇒ หลัง spawn แหล่งที่เชื่อได้คือ **environ ของโปรเซสจริง** ไม่ใช่สตริงที่เราเดา
        local penv=""
        [ -n "$cpid" ] && penv=$(tr '\0' '\n' < "/proc/$cpid/environ" 2>/dev/null | sed -n 's/^CODEX_HOME=//p' | head -1)
        local pm; pm=$(_vc_permmode "${penv:+CODEX_HOME=$penv }$child" ${cbin:+"$cbin"})
        printf '      perm=%s  (%s)\n' "${pm%%|*}" "${pm#*|}"
        [ -n "$penv" ] && printf '      perm.src=CODEX_HOME จาก /proc/%s/environ (ไม่ใช่จาก cmdline)\n' "$cpid"
      fi
      if [ "$kind" = "cli-dialog" ]; then
        printf '      ⛔ นี่คือจอของ **CLI เอง ไม่ใช่ของ agent** — ข้อความที่ส่งไปจะไม่ถูก submit\n'
        printf '         **ห้ามส่ง Enter เปล่า**: บน update dialog ตัวไฮไลต์คือ `Update now`\n'
        printf '         ซึ่งรัน `npm install -g` **แทนที่ binary ของทุก oracle บนเครื่องนี้**\n'
        printf '         (เกิดจริง 2026-08-08 · pane ของทีมหนึ่งอัป codex ทั้งเครื่องจาก 0.146.1)\n'
        printf '         ⇒ อ่านเลขจากจอนี้เอง เมนูเปลี่ยนตามเวอร์ชัน · เลือกตัวที่ไม่ทิ้งร่องรอย\n'
      fi
      printf '      permstall.pane: %s BLOCKED kind=%s\n' "$name" "$kind"
    else
      printf '      permstall.pane: %s no-prompt-visible\n' "$name"
    fi
  done <<< "$wins"
  echo
  printf 'permstall.count: panes=%s blocked=%s replaced-binary=%s\n' "$n_pane" "$n_block" "$n_stale"
  if [ "$n_stale" -gt 0 ]; then
    printf '  ⏳ %s pane รัน binary ที่ไม่มีอยู่บนดิสก์แล้ว ⇒ `<engine> --version` **ตอบแทน pane เหล่านี้ไม่ได้**\n' "$n_stale"
    printf '     สิ่งที่วัดได้: *ไฟล์ที่รันอยู่ ≠ ไฟล์บนดิสก์* · **สิ่งที่วัดไม่ได้จากช่องนี้: เลขเวอร์ชัน**\n'
    printf '     ⚠️ same-version replace มีจริง — pane ที่ REPLACED อาจเป็นเวอร์ชันเดียวกับดิสก์เป๊ะ\n'
    printf '     ⇒ "ไม่รู้ว่ารันอะไร" กับ "รันของเก่า" เป็นคนละช่อง อย่าบีบเป็นช่องเดียว\n'
  fi
  echo 'permstall.scope: out-of-scope=agent-actually-working,prompt-older-than-scrollback,prompt-vocabulary-non-claude'
  echo '  ⚠️ "no-prompt-visible" ไม่ได้แปลว่า worker กำลังทำงาน — แปลว่า *ตอนนี้* ไม่มีคำถามบนจอ'
  echo '     prompt ที่เลื่อนพ้น scrollback ไปแล้ว มันมองไม่เห็น ⇒ วนตรวจ ไม่ใช่ตรวจครั้งเดียว'
  # 🔴 2026-08-08 [advisor จับ · แล้วผมไปทดสอบจริงแล้วเจอของที่ไม่คาด] ธงที่ใช้ grep จอ
  #    **พิสูจน์กับ claude เท่านั้น** — ทุก BLOCKED ที่ผมวัดได้เป็น claude ทั้งหมด
  #    · `selftest 21` ทดสอบ `_vc_permmode` ซึ่งอ่าน **สตริงคำสั่ง** ไม่ได้แตะ regex ตัวนี้เลย
  #    · ผมพยายามสร้าง prompt ของ codex เพื่อทดสอบ **แล้วสร้างไม่ได้**: boot codex เปล่า ๆ
  #      สั่ง `curl` + เขียนไฟล์นอก cwd ⇒ **ทำให้โดยไม่ถาม** เพราะ `~/.codex/config.toml`
  #      ตั้ง `approval_policy = "never"` ไว้ทั้งเครื่อง ⇒ จะทดสอบต้องแก้ของกลาง **ซึ่งไม่ทำ**
  #    ⇒ **ประกาศขอบเขตไว้ ดีกว่าปล่อยให้เข้าใจว่าครอบ** — ทีมที่ worker เป็น codex/opencode/
  #      thclaws ยังต้องอ่านจอเองจนกว่าจะมีคนเจอ prompt จริงของเครื่องยนต์นั้นแล้วส่งข้อความมา
  echo '  🟡 ธงที่ใช้จับ prompt: claude [verified] · codex [verified 2026-08-10 · v0.147.0 · 2 arm]'
  echo '     · **opencode / thclaws ยัง [unverified]** — อย่าอ่าน blocked=0 บนสองตัวนั้นเป็นหลักฐาน'
  echo '     codex ปิดได้เพราะ `-a untrusted` บน command line **ชนะ** approval_policy=never ใน config'
  echo '     ⇒ ที่เคยเขียนว่า "สร้าง prompt ไม่ได้" ผิด — ผมติดที่ config เพราะไปแก้ config ไม่ใช่ใช้แฟลก'
  if [ "$n_block" -gt 0 ]; then
    echo "overall: BLOCKED panes=$n_block"
    echo '  แก้ไม่ได้ด้วยเครื่องมือนี้โดยเจตนา — การกด Yes คือการให้สิทธิ์แทนมนุษย์ของทีมนั้น'
    echo '  ถ้าเป็นทีมของคุณเอง: อ่านตัวเลขจากจอจริง (อย่า hardcode) หรือ restart ด้วย alias ที่มี bypass'
    return 1
  fi
  echo 'overall: NO-VISIBLE-PROMPT'
}

enginecheck() {
  local arg="${1:?usage: enginecheck <charter.yaml|team-name>}" charter=""
  if [ -f "$arg" ]; then charter="$arg"
  else
    local c
    for c in ".maw/teams/$arg.yaml" "ψ/teams/$arg.yaml" ".maw/teams/$arg.json" "ψ/teams/$arg.json"; do
      [ -f "$c" ] && { charter="$c"; break; }
    done
  fi
  [ -n "$charter" ] || { echo "UNKNOWN   ไม่พบ charter '$arg' (มองที่ .maw/teams/ และ ψ/teams/ เทียบ CWD) — **ตอบไม่ได้**"; return 2; }

  # ใช้ `maw team plan` เป็นตัว parse YAML แทนการ parse เอง — เป็น parser ตัวเดียวกับที่
  # `team up` ใช้จริง ⇒ ไม่มี drift · และมันเป็น read-only (phase-0: no files written)
  local plan
  plan=$(maw team plan "$charter" 2>&1) || { echo "UNKNOWN   maw team plan ล้ม:"; echo "$plan"; return 2; }

  local declared parsed
  declared=$(printf '%s\n' "$plan" | sed -n 's/^members (\([0-9]*\)).*/\1/p' | head -1)
  # บรรทัดสมาชิกหน้าตา:  "  - role (target=auto, name=x, model=y, engine=z)"
  # ⚠️ ต้องตัดเฉพาะบล็อกใต้ "members (N):" — `plan` พิมพ์ "  - /path/..." ใต้หัวข้อ
  #    "would prepare artifacts:" ด้วยรูปแบบเดียวกันเป๊ะ ⇒ `sed -n 's/^  - //p'` เพียว ๆ
  #    แกะได้ 11 แถวจาก charter ที่มี 2 สมาชิก [เจอจริงตอนรันกับ charter ของ repo นี้เอง
  #    2026-08-06 — เคสนี้คือเหตุผลที่ cross-check จำนวนอยู่ข้างล่าง ไม่ใช่ของประดับ]
  parsed=$(printf '%s\n' "$plan" | awk '
    /^members \(/ { inblock=1; next }
    inblock && /^  - / { sub(/^  - /,""); print; next }
    inblock && !/^  - / && NF { inblock=0 }
  ')
  local n_parsed; n_parsed=$(printf '%s' "$parsed" | grep -c . || true)
  if [ -n "$declared" ] && [ "$declared" != "$n_parsed" ]; then
    echo "UNKNOWN   maw บอกว่ามี $declared สมาชิก แต่แกะได้ $n_parsed — **ตอบไม่ได้ ไม่ใช่ผ่าน**"
    return 2
  fi
  [ "$n_parsed" -gt 0 ] || { echo "UNKNOWN   charter '$charter' ไม่มีสมาชิก — **ตอบไม่ได้**"; return 2; }

  # 🩹 2026-08-06 [clean-room tester · ผมทำซ้ำได้: charter path เต็มเดิม 4 cwd → PASS/PASS/FAIL/FAIL]
  #    เดิม: root = git root ของ **ผู้เรียก** ⇒ ยืนคนละที่ = คำตอบคนละอย่าง สำหรับ charter เดียวกัน
  #    charter ประกาศ path เทียบ **repo ของตัวมันเอง** ไม่ใช่ที่ที่คนรันบังเอิญยืนอยู่
  #    ⇒ anchor ที่ไดเรกทอรีของ charter เสมอ · caller ยืนที่ไหนก็ได้ ผลต้องเหมือนเดิม
  #    (นี่คือ FAIL ปลอมที่พ่นคำสั่ง "อย่า spawn จนกว่าจะแก้" ใส่ charter ที่ถูกอยู่แล้ว)
  local cdir root
  cdir=$(cd "$(dirname "$charter")" 2>/dev/null && pwd -P) || cdir=$PWD
  root=$(git -C "$cdir" rev-parse --show-toplevel 2>/dev/null) || root=""
  if [ -z "$root" ]; then
    # charter ไม่ได้อยู่ใน git repo — ใช้ไดเรกทอรีของ charter ขึ้นไปหนึ่งชั้นจาก ψ/teams|.maw/teams
    case "$cdir" in
      */ψ/teams|*/.maw/teams) root=$(cd "$cdir/../.." && pwd -P) ;;
      *) root="$cdir" ;;
    esac
  fi
  echo "enginecheck $charter  ($n_parsed สมาชิก)  [repo root: $root]"
  echo "enginecheck.anchor: charter-dir  (verdict ไม่ขึ้นกับ cwd ของผู้เรียก)"

  # 🏷️ lucifer 2026-08-06 (EXTRA B, verified A/B): `defaults: {engine: X}` **ไม่เคยถูกอ่าน**
  #    `team_t3_classify` = opts.engine → member.engine → member.model → "claude"
  #    **ไม่มี defaults ใน chain** และ parser เก็บมันไว้เฉย ๆ (`team_core.rs:455`)
  #    ⇒ dead field ตัวที่ 3 ต่อจาก `model:` และ `engines:`
  #    🔴 และฟังก์ชันนี้ **มองไม่เห็นด้วยตัวเอง** เพราะใช้ `maw team plan` เป็น parser ซึ่ง
  #      แทนค่าเป็น claude ไปแล้ว ⇒ เดิมรายงานว่า "charter ขอ engine=claude" ซึ่ง**เท็จ**
  #      คนอ่านจะไปลงทะเบียน claude แล้ว FAIL หาย ทั้งที่ยังไม่มีวันได้ engine ที่ขอ
  #    ⇒ ต้องอ่าน defaults: จากไฟล์ตรง ๆ ก่อน แล้วเตือนดัง ๆ
  local dflt
  dflt=$(awk '/^defaults:/{f=1;next} f&&/^[^[:space:]]/{f=0} f&&/engine:/{sub(/.*engine:[[:space:]]*/,"");print;exit}' "$charter" 2>/dev/null)
  if [ -n "$dflt" ]; then
    # เตือนเฉพาะเมื่อมี member ที่ **พึ่ง** defaults จริง — ถ้าทุกคนมี engine: ของตัวเอง
    # คีย์นี้ไม่มีพิษ และการเตือนก็เป็นแค่ noise (control ของ lucifer เป็นแบบนั้น)
    local naked
    naked=$(awk '/^[[:space:]]*-[[:space:]]*role:/{if(n&&!e)c++; n=1; e=0}
                 n&&/^[[:space:]]+engine:/{e=1}
                 END{if(n&&!e)c++; print c+0}' "$charter" 2>/dev/null)
    if [ "${naked:-0}" -gt 0 ]; then
      echo
      echo "🔴 charter นี้มี  defaults: engine: $dflt  — **maw ไม่เคยอ่านคีย์นี้**"
      echo "   และมี $naked member ที่ไม่มี engine: ของตัวเอง ⇒ **จะได้ 'claude' ไม่ใช่ '$dflt' และ exit 0**"
      echo "   ⇒ ย้าย engine ไปไว้ที่ member ทุกคน · บรรทัดด้านล่างแสดงค่า **หลัง** maw แทนแล้ว"
      echo "   ⇒ ยืนยันเอง: maw team up <team> --dry-run แล้วอ่านคอลัมน์ engine"
    fi
  fi
  echo
  local fail=0 line role rest engine model ident cmd machine=""
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    role=${line%% (*}
    rest=${line#*(}; rest=${rest%)}
    engine=$(printf '%s' "$rest" | sed -n 's/.*engine=\([^,)]*\).*/\1/p')
    model=$(printf '%s'  "$rest" | sed -n 's/.*model=\([^,)]*\).*/\1/p')
    ident=$(printf '%s'  "$rest" | sed -n 's/.*name=\([^,)]*\).*/\1/p')
    [ -n "$ident" ] || ident="$role"
    [ -n "$engine" ] || engine="claude"

    # 🔴 path ของสมาชิก = สโคปที่ maw ใช้ resolve `commands` ของคนนั้น (ไม่ใช่ cwd ของ lead)
    local wt cwdf mdir
    cwdf=$(printf '%s' "$rest" | sed -n 's/.*[ (]cwd=\([^,)]*\).*/\1/p')
    wt=$(printf '%s'   "$rest" | sed -n 's/.*worktree=\([^,)]*\).*/\1/p')
    if   [ -n "$cwdf" ]; then mdir="$cwdf"
    elif [ -n "$wt" ] && [ "$wt" != "false" ]; then
      case "$wt" in /*) mdir="$wt" ;; *) mdir="$root/$wt" ;; esac
    else mdir="$root"
    fi

    printf '  %s\n' "$role"
    printf '    charter ขอ : engine=%s model=%s\n' "$engine" "${model:--}"
    printf '    สโคป path  : %s\n' "$mdir"

    # ⚠️ ต้องดู **exit code** ของ enginereg ไม่ใช่ "มีข้อความบรรทัดที่ 2 ไหม" — ตอนล้มมัน
    #    ก็พิมพ์ 2 บรรทัดเหมือนกัน ⇒ เวอร์ชันแรกของฟังก์ชันนี้อ่านข้อความ "แก้: เพิ่มคีย์…"
    #    เป็นคำสั่งที่จะรัน แล้วรายงาน ✅ PASS ให้ charter ที่ engine ไม่ได้ลงทะเบียน
    #    **false-PASS ในเครื่องมือที่เขียนมาเพื่อจับ false-PASS** (เจอจริง 2026-08-06)
    local reg_out reg_rc
    reg_out=$(enginereg "$engine" "$mdir" 2>/dev/null); reg_rc=$?
    if [ $reg_rc -eq 0 ]; then cmd=$(printf '%s\n' "$reg_out" | sed -n '2s/^ *//p'); else cmd=""; fi
    if [ $reg_rc -eq 2 ]; then
      printf '    ⚠️ UNKNOWN อ่าน merged config ไม่ได้ ⇒ **ตอบไม่ได้ ไม่ใช่ผ่าน**\n'
      machine="${machine}enginecheck.member: $role UNVERIFIED engine=$engine resolved=
"
      fail=1
    elif [ -z "$cmd" ]; then
      # ไม่ได้ลงทะเบียน → ข้อ 1 ไม่เจอ → ตกไปตามชื่อ window ยิงหา wake เพื่อดูของจริง
      # 🩹 2026-08-07 [lucifer · spawn ทีมจริง] เดิมไม่ส่ง `--repo-path` ⇒ สมาชิกที่ path อยู่
      #    **นอก repo** (เช่น `~/.maw-teams/<team>/<role>`) probe ตอบไม่ได้ → ตกไปพิมพ์บรรทัด
      #    ทั่วไป "ตกไปตามชื่อ window → glob → default" ซึ่ง **บอก consequence ผิด**
      #    ของจริงในเคสเขา: member ชื่อ `verifier` ที่ charter สั่ง claude/sonnet-5
      #    โดน glob `verifier*` → บูตเป็น **thclaws --model zai/glm-5.1 คนละ vendor**
      #    lucifer ได้คำตอบจริงด้วยการเติม `--repo-path` เอง ⇒ เติมให้ที่นี่
      local probe
      probe=$(maw wake "$ident" --no-attach --dry-run -e "$engine" --repo-path "$mdir" 2>&1 \
              | sed 's/\x1b\[[0-9;]*m//g' | sed -n 's/^ *command: *//p' | head -1)
      # ถ้ายังว่าง ลองแบบไม่ระบุ path (สมาชิกที่อยู่ใน repo)
      [ -n "$probe" ] || probe=$(maw wake "$ident" --no-attach --dry-run -e "$engine" 2>&1 \
              | sed 's/\x1b\[[0-9;]*m//g' | sed -n 's/^ *command: *//p' | head -1)
      # ชื่อนี้โดน glob ตัวไหน "จับ" ไหม — glob แมตช์ **ชื่อ window** จึง hijack ตาม role name
      local hijack
      hijack=$(maw config explain 2>/dev/null | grep -oE '"[A-Za-z0-9_-]+\*"' | tr -d '"' | while read -r g; do
                 case "${ident}" in "${g%\*}"*) echo "$g" ;; esac
               done | head -1)
      [ -n "$hijack" ] || hijack=$(python3 - "$mdir" "$ident" <<'PY' 2>/dev/null
import json,os,sys,glob as _g
d,ident=sys.argv[1],sys.argv[2]
keys=[]
p=os.path.abspath(d)
seen=set()
while True:
    for f in sorted(_g.glob(os.path.join(p,'.maw','maw.config.*.json'))):
        if f in seen: continue
        seen.add(f)
        try: keys += [k for k in json.load(open(f)).get('commands',{}) if '*' in k]
        except Exception: pass
    if p=='/': break
    p=os.path.dirname(p)
for f in sorted(_g.glob(os.path.expanduser('~/.config/maw/maw.config.*.json'))):
    try: keys += [k for k in json.load(open(f)).get('commands',{}) if '*' in k]
    except Exception: pass
for k in keys:
    if ident.startswith(k[:-1]): print(k); break
PY
)
      # แยกสองกรณีที่ไม่เท่ากัน:
      #   · probe ชี้ไปที่ binary ชื่อเดียวกับที่ขอ → **ได้ของถูกโดยบังเอิญ** (ผ่าน default)
      #     ยังอันตรายเพราะขึ้นกับชื่อ window: `wake hermes -e claude` → `hermes --yolo`
      #     `[verified 2026-08-06]` ⇒ WARN ไม่ใช่ FAIL แต่ต้องพิมพ์ให้เห็น
      #   · probe ชี้ไปที่อย่างอื่น หรือ probe ตอบไม่ได้ → FAIL (ตอบไม่ได้ ≠ ผ่าน)
      # 🩹 2026-08-07 [atlas อ่านเจอตอนตรวจแพตช์ `_vc_argv_basename`] จุดนี้ **ไม่ติดกับดัก
      #    extra-operand** เพราะมี `head -1` คั่นอยู่ — แต่ยังผ่าน `xargs` ซึ่ง **แกะเครื่องหมาย
      #    คำพูดเอง** ⇒ token ที่มี `'` เดี่ยวยังทำให้มันตายเงียบได้ ⇒ ใช้ตัวเดียวกับ bootverify
      #    ⇒ **แหล่งเดียว ไม่ใช่สองท่าที่พังคนละแบบ** (บทเรียน "แก้ที่เดียว ≠ แก้ claim")
      local probe_bin=""
      [ -n "$probe" ] && probe_bin=$(_vc_argv_basename "$probe" 1)
      # 🩹 2026-08-07: WARN ("ได้ของถูกโดยบังเอิญ") ใช้ได้เฉพาะตอน **ไม่มี model ที่ถูกขอ**
      #    ถ้า charter ขอ model ไว้ แล้วคำสั่งที่จะรันจริง **ไม่มี model นั้น** ⇒ ของที่ได้ผิด
      #    ไม่ใช่ "ถูกโดยบังเอิญ" ⇒ FAIL · เจอตอนที่ probe เริ่ม resolve ได้หลังเติม --repo-path
      #    (เคส `model:` ที่ไม่มี `engine:` — engine ตกเป็น "claude" แล้วเทียบ claude กับ claude
      #     ซึ่งเป็นการเทียบ fallback กับตัวมันเอง จึงผ่านเสมอ = false pass)
      local model_ok=1
      if [ -n "$model" ]; then
        case "$probe" in *"$model"*) ;; *) model_ok=0 ;; esac
      fi
      if [ -n "$probe_bin" ] && [ "$probe_bin" = "$engine" ] && [ "$model_ok" = "1" ]; then
        # 🩹 2026-08-08 [lucifer · WORDING FIX — และเขาถูก] ข้อความเดิมเขียนว่า
        #    "ตอนนี้ได้ของถูกโดยบังเอิญผ่าน default" ซึ่ง **ปลอบใจผิดเรื่อง**:
        #    มันถูกเรื่อง *engine* เท่านั้น · `default` บนเครื่องนี้ **ไม่มี bypass token**
        #    ⇒ คนอ่านคำว่า "ได้ของถูก" แล้ววางใจ ทั้งที่กำลังจะได้ ask-mode
        #    ⇒ **ระบุขอบเขตของคำว่าถูกเสมอ** — ถูกในมิติไหน ไม่ใช่ถูกลอย ๆ
        printf '    ⚠️ WARN    engine "%s" ไม่ได้ลงทะเบียน — **ได้ engine ถูกโดยบังเอิญ** ผ่าน default\n' "$engine"
        printf '               ⚠️ "ถูก" ในที่นี้คือ **มิติ engine เท่านั้น** — ดูบรรทัด perm ข้างล่างต่อ\n'
        printf '                  `default` ไม่จำเป็นต้องมี bypass token · บนเครื่องนี้ตอนนี้ **ไม่มี**\n'
        printf '               จะได้จริง: %s\n' "$probe"
        printf '               ไม่ pin: ผลขึ้นกับ *ชื่อ window* — `wake hermes -e claude` ได้ `hermes --yolo`\n'
        printf '               และ model ไม่ถูกกำหนดโดย charter ⇒ ใช้ alias ที่ pin model แทน\n'
        # ค่า verdict คงไว้แค่ PASS|FAIL|UNVERIFIED ตามที่ consumer ของ atlas grep
        # ⇒ WARN ถูกเข้ารหัสเป็น PASS + ฟิลด์ `pinned=no` แทนการเพิ่มค่าที่ 4 ที่จะทำ parse เขาพัง
        machine="${machine}enginecheck.member: $role PASS engine=$engine resolved=$probe pinned=no
"
        _vc_perm_report "$role" "$engine" "$probe"
        _vc_tier_report "$role" "$probe"
      else
        printf '    ❌ FAIL    engine "%s" ไม่ได้ลงทะเบียนใน commands ⇒ ถูกทิ้งเงียบ ๆ\n' "$engine"
        if [ -n "$hijack" ]; then
          printf '    🔴 HIJACK  ชื่อ role "%s" ตรงกับ glob "%s" ⇒ **ไม่ได้ตกไป default**\n' "$ident" "$hijack"
          printf '               glob แมตช์ *ชื่อ window* ⇒ มันชิงไปก่อน default เสมอ\n'
          printf '               เคสจริง 2026-08-07: charter สั่ง claude/sonnet-5 แต่ member ชื่อ verifier\n'
          printf '               โดน verifier* ⇒ บูตเป็น thclaws zai/glm-5.1 — **คนละ vendor คนละ CLI**\n'
        fi
        if [ -n "$probe" ]; then
          printf '               จะได้จริง: %s   ← คนละ engine กับที่ขอ\n' "$probe"
        else
          printf '               (wake probe ตอบไม่ได้แม้ใส่ --repo-path %s แล้ว — **ตอบไม่ได้ ≠ ตกไป default**\n' "$mdir"
          printf '                อย่าสรุป consequence จากบรรทัดนี้ ยิงเองเพื่อดูของจริง:\n'
          printf '                maw wake %s --dry-run -e %s --repo-path %s)\n' "$ident" "$engine" "$mdir"
        fi
        # 🩹 2026-08-08 [lucifer รายงานว่า enginereg กับ enginecheck "ขัดกัน" · reproduce แล้ว
        #    **ทั้งคู่ถูก มันตอบคนละคำถาม** และไม่มีตัวไหนบอกว่าคนละคำถาม]
        #      enginereg <e> <dir>  ถามจาก **dir ที่ผู้เรียกยื่นให้**  (มัก = charter dir)
        #      enginecheck          ถามจาก **path ของสมาชิกคนนั้นเอง** (worktree ของเขา)
        #    ถ้าสอง path อยู่คนละสายบรรพบุรุษ ⇒ REGISTERED + FAIL พร้อมกัน **ถูกทั้งคู่**
        #    ⇒ verdict ที่ใช้ตัดสินคือของ enginecheck เพราะ maw wake resolve จาก path ของสมาชิก
        #    ⇒ และ `perm=ask` ที่ตามมา **จริง** — สมาชิกจะได้ default ที่ไม่มี bypass จริง ๆ
        #    (lucifer ถามตรงจุด: *ถ้า fallback ไม่จริง perm ก็ไม่จริง* — fallback จริง จึง perm จริง)
        #    เดิมผู้ใช้ต้องเดาเองว่าทำไมสองคำสั่งไม่ตรงกัน ⇒ พิมพ์ออกมาให้เห็น
        local seen_from_charter=""
        seen_from_charter=$( ( cd "$(dirname -- "$charter")" 2>/dev/null && maw config 2>/dev/null ) \
          | python3 -c '
import json,sys
try: cfg=json.load(sys.stdin)
except Exception: sys.exit(0)
print((cfg.get("commands") or {}).get(sys.argv[1],""))' "$engine" 2>/dev/null )
        if [ -n "$seen_from_charter" ]; then
          printf '    🧭 ไม่ใช่ "ไม่มี alias" — alias **มีอยู่จริง แต่มองไม่เห็นจากที่ที่สมาชิกยืน**\n'
          printf '               จาก charter dir : REGISTERED → %s\n' "$(printf '%s' "$seen_from_charter" | cut -c1-72)"
          printf '               จาก path สมาชิก : มองไม่เห็น ⇒ ตกไป default\n'
          printf '               ⇒ `enginereg` ถามจาก dir ที่คุณยื่นให้ · `enginecheck` ถามจาก path ของสมาชิก\n'
          printf '                 สองอันนี้ตอบ **คนละคำถาม** — ตัวที่ตรงกับของจริงคือ enginecheck\n'
          printf '                 เพราะ `maw wake` resolve จาก path ของสมาชิก ไม่ใช่จากที่คุณยืน\n'
          printf '               ⇒ ดังนั้น perm ข้างล่างนี้ **เป็นของ default ที่จะได้จริง** ไม่ใช่ของ alias ที่ขอ\n'
        fi
        printf '               แก้: เพิ่ม "%s" ใน .maw/maw.config.<N>.json ที่เป็น**บรรพบุรุษของ %s**\n' "$engine" "$mdir"
        case "$mdir" in
          "$root"|"$root"/*) ;;
          *) printf '               ⚠️ path ของสมาชิกคนนี้อยู่**นอก repo** ⇒ layer ที่ %s/.maw/ **มองไม่เห็น**\n' "$root"
             printf '                  ต้องวาง layer ที่บรรพบุรุษของ path นั้น หรือใช้ worktree ใน repo\n' ;;
        esac
        machine="${machine}enginecheck.member: $role FAIL engine=$engine resolved=$probe
"
        # แม้จะ FAIL ไปแล้ว ก็ยังพ่น perm ให้ครบทุกสมาชิก — gate ที่นับ `enginecheck.perm:`
        # ต้องได้จำนวนเท่ากับจำนวนสมาชิกเสมอ ไม่งั้น "ไม่มีบรรทัด" จะอ่านได้สองความหมาย
        # (ไม่มีปัญหา vs ไม่ได้ตรวจ) — คลาสเดียวกับ `ตอบไม่ได้ ≠ ผ่าน`
        [ -n "$probe" ] && _vc_perm_report "$role" "$engine" "$probe"
        [ -n "$probe" ] && _vc_tier_report "$role" "$probe"
        fail=1
      fi
    else
      printf '    จะรันจริง  : %s\n' "$cmd"
      # ── มิติที่ 3: permission mode ──────────────────────────────────────────
      # เพิ่ม 2026-08-08 หลังทีมของ holmes ค้าง 3 pane โดยที่บรรทัด "จะรันจริง" ข้างบน
      # **พิมพ์คำสั่งที่ขาดแฟลกออกมาแล้ว** และบรรทัดถัดไปเขียนว่า ✅ PASS
      # แยก namespace เป็น `enginecheck.perm:` ไม่ยัดใน `enginecheck.member:`
      # เพราะ consumer ของ atlas grep ฟิลด์นั้นอยู่ — เพิ่มบรรทัด ไม่แก้รูปเดิม
      _vc_perm_report "$role" "$engine" "$cmd"
      _vc_trust_report "$role" "$cmd" "$mdir"
      _vc_tier_report "$role" "$cmd"
      if [ -n "$model" ]; then
        case "$cmd" in
          *"--model $model"*|*"-m $model"*|*"--model=$model"*)
            printf '    ✅ PASS    engine ถูก · model "%s" อยู่ในคำสั่งจริง\n' "$model"
            machine="${machine}enginecheck.member: $role PASS engine=$engine resolved=$cmd
" ;;
          *)
            printf '    ❌ FAIL    charter ขอ model "%s" แต่คำสั่งที่จะรันไม่มีมัน\n' "$model"
            printf '               `model:` ใน charter ไม่เคยถูกส่งให้ wake — ต้องฝังใน alias เอง\n'
            machine="${machine}enginecheck.member: $role FAIL engine=$engine resolved=$cmd
"
            fail=1 ;;
        esac
      else
        local eff; eff=$(printf '%s' "$cmd" | sed -n 's/.*--model[= ]\([^ ]*\).*/\1/p')
        printf '    ✅ PASS    engine ถูก · charter ไม่ระบุ model ⇒ ได้ %s จาก alias\n' "${eff:-ค่า default ของ engine}"
        machine="${machine}enginecheck.member: $role PASS engine=$engine resolved=$cmd
"
      fi
    fi
    echo
  done <<< "$parsed"

  # ── machine block — ยึดคอลัมน์ 0 สำหรับ gate ที่ grep แบบ anchored ────────────
  # 🏷️ atlas 2026-08-06: rc ใช้ได้ แต่ format ใช้ไม่ได้ — consumer ของเขา grep `^overall:`
  #    `^launch-identity:` `^gate.<name>:` ส่วนผมพ่น prose ไทย+emoji ย่อหน้าเข้า ไม่มี verdict
  #    ต่อสมาชิกที่ยึดคอลัมน์ 0 ⇒ เขาต้อง text-scrape ซึ่งคือความเปราะที่ anchored grep มีไว้เลี่ยง
  #    ⇒ พ่น machine block **ควบ** prose ไม่ใช่แทน (prose เป็นครึ่งที่ดีกว่าสำหรับคน — atlas)
  _vc_tier_summary "$machine"
  printf '%s\n' "$machine"
  # รวมสิ่งที่ **ผันแปรจริง** ต่อรอบ — ว่างเมื่อไม่มี ⇒ กฎของ atlas เป็นเท็จได้จริง
  local unv=""
  printf '%s\n' "$machine" | grep -q 'pinned=no' && unv="${unv}${unv:+,}unpinned-alias"
  # 2026-08-08: permission mode เป็นของ **ผันแปรต่อ charter** (ไม่ใช่ขอบเขตถาวร)
  # ⇒ ต้องอยู่ใน unverified list ที่ gate ของบ้านอื่น grep ได้ ไม่ใช่ซ่อนใน prose ไทย
  printf '%s\n' "$machine" | grep -qE 'enginecheck.perm: .* (ask|allowlist|unknown) ' \
    && unv="${unv}${unv:+,}permission-not-bypassed"
  # 2026-08-09: trust dialog = ค้างตอน boot คลาสเดียวกับ permission แค่คนละนาที
  printf '%s\n' "$machine" | grep -qE 'enginecheck.trust: .* (untrusted|unknown) ' \
    && unv="${unv}${unv:+,}codex-trust-dialog-expected"
  printf '%s\n' "$machine" | grep -q ' UNVERIFIED ' && unv="${unv}${unv:+,}member-unresolvable"
  printf '%s\n' "$machine" | grep -q 'scope=dir-absent' && unv="${unv}${unv:+,}answered-from-ancestor"
  # 🏷️ ajfon 2026-08-06: เขาแต่งชื่อ model ที่ไม่มีอยู่จริง (`gpt-5.5-codex` ทั้งที่ default
  #    ของเขาคือ `gpt-5.6-sol`) แล้ว enginecheck ตอบ `overall: PASS rc=0` — **ถูกตามนิยาม**
  #    เพราะเราตรวจว่า *สตริงตรงกัน* ไม่ได้ตรวจว่า *บัญชีเสิร์ฟได้*
  #    ⇒ แต่เราสอนให้ gate grep `^overall:` ⇒ **ขอบเขตนั้นต้องอยู่ในผลลัพธ์ ไม่ใช่แค่ในเอกสาร**
  #    ⇒ พ่นเป็น machine key ยึดคอลัมน์ 0 เพื่อให้ gate เห็นข้อจำกัดพร้อมกับคำตัดสิน
  printf '%s\n' "$VC_SCOPE_LINE"
  printf 'enginecheck.unverified: %s\n' "$unv"
  if [ $fail -eq 0 ]; then
    # 🏷️ atlas 2026-08-06: `overall: PASS` อยู่บรรทัดเดียวกับ `model-served=UNVERIFIED` ได้
    #    ⇒ gate ที่ grep แค่ `^overall:` รับ worker ที่ไม่เคยยืนยัน model —
    #    **false-green คลาสเดิม โผล่ขึ้นมาอีกชั้นข้างในตัวแก้ของมันเอง**
    #    ⇒ ต่อท้ายข้อผูกมัดไว้ในบรรทัดเดียวกัน: `grep '^overall: PASS'` เดิมยังแมตช์
    #      (ไม่ทำ parser ของใครพัง) แต่คนอ่านและ parser ที่ anchor ท้ายบรรทัดจะเห็นทันที
    echo "overall: PASS requires-post-boot-verification=true"
    echo "ENGINECHECK OK   [ขอบเขต: ไม่ได้ตรวจว่าบัญชีเสิร์ฟ model นี้ได้ · ไม่ได้ตรวจว่า prompt ถึง worker]"
    return 0
  fi
  echo "overall: FAIL requires-post-boot-verification=true"
  echo "ENGINECHECK FAILED   อย่า spawn จนกว่าจะแก้ — ทีมจะขึ้นด้วย engine ที่ไม่ได้ขอ โดยไม่มี error"
  return 1
}

# ── selftest ────────────────────────────────────────────────────────────────
# **ตัวสคริปต์เองก็ต้องถูกตรวจ** — นี่คือประเด็นทั้งหมดของไฟล์นี้
selftest() {
  local fail=0
  echo "1) binexists กับของที่มีจริง (bash)";      binexists bash            >/dev/null || fail=1
  echo "2) binexists กับของที่ไม่มี (ไม่มีจริง)";  binexists __no_such_bin__ >/dev/null && fail=1
  echo "3) procs นับตัวเองไหม (ต้องไม่นับ)"
  local n; n=$(procs __no_such_bin__)   # cmdline ของ shell นี้มีสตริงนั้นอยู่
  [ "$n" = "0" ] || { echo "   ✗ นับได้ $n ทั้งที่ควรเป็น 0"; fail=1; }
  echo "4) procs เห็นของจริง (bash > 0)";  [ "$(procs bash)" -gt 0 ] || fail=1
  # NB: ห้ามเขียน `bootprobe ... | grep -q ...` ตรง ๆ — `grep -q` ปิด pipe ทันทีที่เจอ
  #     ทำให้ bootprobe โดน SIGPIPE และ `set -o pipefail` รายงานว่า pipeline ล้มเหลว
  #     ทั้งที่มันสำเร็จ (บั๊กนี้เกิดจริงในเวอร์ชันแรกของ selftest นี้เอง 2026-08-04)
  echo "5) bootprobe เก็บ output จริง"
  local out5; out5=$(bootprobe 'echo hello-from-probe' 3)
  case "$out5" in *hello-from-probe*) ;; *) echo "   ✗ ไม่เห็น output ที่คาดไว้"; fail=1 ;; esac
  echo "5b) binexists ต้องจับ hash-cache stale ได้ (เคสที่ command -v เพียว ๆ โกหก)"
  local td; td=$(mktemp -d)
  printf '#!/bin/sh\necho hi\n' > "$td/tmpbin"; chmod +x "$td/tmpbin"
  local r5b
  r5b=$(PATH="$td:$PATH" bash -c 'tmpbin >/dev/null 2>&1; rm -f '"$td"'/tmpbin;
        if p=$(command -v tmpbin); then echo "bare-lies:$p"; fi' 2>/dev/null)
  case "$r5b" in
    bare-lies:*) # ยืนยันว่า command -v โกหกจริงในเคสนี้ แล้ว binexists ต้องไม่โกหกตาม
      PATH="$td:$PATH" bash -c "source '$PWD/ψ/teams/scripts/verify-check.sh' >/dev/null 2>&1; binexists tmpbin" >/dev/null 2>&1 \
        && { echo "   ✗ binexists ตอบ OK ทั้งที่ไฟล์ถูกลบ"; fail=1; } ;;
    *) echo "   (เชลล์นี้ไม่ cache — ข้ามเคสนี้ ไม่นับว่าผ่านหรือตก)" ;;
  esac
  rm -rf "$td"
  echo "6b) procs_cmd ต้องไม่นับคำสั่งตรวจของตัวเอง"
  local n7; n7=$(procs_cmd "__selftest_unique_marker__")
  [ "$n7" = "0" ] || { echo "   ✗ procs_cmd นับได้ $n7 ทั้งที่ควรเป็น 0"; fail=1; }
  echo "5c) relay ต้องปฏิเสธ target ที่ไม่เต็ม และ target ที่ไม่มีอยู่"
  relay "ajfon" "x" >/dev/null 2>&1 && { echo "   ✗ relay รับชื่อสั้น"; fail=1; }
  relay "99-nosuch:nosuch.0" "x" >/dev/null 2>&1 && { echo "   ✗ relay รับ session ที่ไม่มี"; fail=1; }
  echo "5d) source พร้อม positional arg ต้องไม่ทำให้ dispatcher ยิง exit"
  local r5d; r5d=$(bash -c 'source '"$PWD"'/ψ/teams/scripts/verify-check.sh; echo SOURCED-OK' _ "ข้อความยาวที่ไม่ใช่ชื่อ fn" 2>&1)
  case "$r5d" in *SOURCED-OK*) ;; *) echo "   ✗ source แล้วเชลล์ตาย: $r5d"; fail=1 ;; esac
  echo "5e) teamclosed: ตัวประธานต้องเป็น *ชื่อทีมจริง* ไม่ใช่ header row"
  # ⚠️ เวอร์ชันแรกของเทสต์นี้ใช้ `awk NR>1` → ได้ **`TEAM`** (บรรทัดแรกเป็นบรรทัดว่าง)
  #    ⇒ กับดัก substring ที่โฆษณาว่าทดสอบ atlas/atlas-codex จริง ๆ ทดสอบ TEAM/TEA
  #    = fixture Tier 1 ในไฟล์ที่ทั้งเล่มบอกว่า Tier 1 มองไม่เห็น defect ที่ผูกกับตัวประธาน
  if binexists maw >/dev/null 2>&1; then
    local first
    first=$(maw team list 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' \
            | awk '$1=="TEAM" && $2=="STORE"{h=1;next} h && NF>1 {print $1; exit}')
    case "$first" in
      ""|TEAM) echo "   (ไม่ได้ชื่อทีมจริงจาก list [ได้: '${first:-ว่าง}'] — ข้าม ไม่นับผ่าน/ตก)" ;;
      *)
        teamclosed "$first" >/dev/null 2>&1 && { echo "   ✗ teamclosed บอกว่า '$first' ปิด ทั้งที่ list โชว์อยู่"; fail=1; }
        local sub="${first%?}"
        if [ -n "$sub" ] && [ "$sub" != "$first" ] && ! tmux has-session -t "=$sub" 2>/dev/null \
           && ! tmux has-session -t "=team-$sub" 2>/dev/null; then
          teamclosed "$sub" >/dev/null 2>&1 || { echo "   ✗ teamclosed ติดกับดัก substring ที่ '$sub'"; fail=1; }
        fi ;;
    esac
    # header row ต้องไม่ถูกอ่านเป็นทีม
    teamclosed TEAM >/dev/null 2>&1 || { echo "   ✗ teamclosed อ่าน header row 'TEAM' เป็นทีม"; fail=1; }
    # เอกสารบั๊กที่เป็นเหตุให้มีฟังก์ชันนี้ — ถ้าวันไหน maw แก้แล้ว เทสต์นี้จะดังให้รู้
    maw team status "__no_such_team_$$__" >/dev/null 2>&1 \
      || echo "   (หมายเหตุ: maw team status คืน rc!=0 กับทีมที่ไม่มีแล้ว — พฤติกรรมเปลี่ยนจาก 08-04)"
  else
    echo "   (ไม่มี maw — ข้ามเคสนี้ ไม่นับว่าผ่านหรือตก)"
  fi
  echo "5f) teamclosed: วง CLOSED→LIVE→CLOSED บน session ที่สร้างเอง (ล้มได้จริงทั้งสองทิศ)"
  # ⚠️ เวอร์ชันแรกของ 5f ยืนยันแค่ "ทีมที่ live ต้องไม่ถูกตอบ CLOSED" โดยเล็งไปที่ session
  #    ของ ajfon ⇒ **มันล้มไม่ได้ขณะที่มันรัน** เพราะเงื่อนไขเดียวที่ทำให้ล้มคือ session หาย
  #    ซึ่งเป็นเงื่อนไขเดียวกับที่ทำให้เทสต์ถูกข้าม (ที่ปรึกษาจับได้ · กติกา A1.1 ของไฟล์คู่มือ)
  # ⇒ ตอนนี้สร้าง session ทิ้งของตัวเอง แล้ววัดสามจังหวะ — ตกได้ทั้งขาขึ้นและขาลง
  if binexists tmux >/dev/null 2>&1; then
    local ps="zz-vc-selftest-$$"
    if tmux has-session -t "=team-$ps" 2>/dev/null; then
      echo "   (ชื่อ probe ชนของที่มีอยู่ — ข้าม ไม่นับผ่าน/ตก)"
    else
      teamclosed "$ps" >/dev/null 2>&1 || { echo "   ✗ ก่อนสร้าง: ควรเป็น CLOSED"; fail=1; }
      if tmux new-session -d -s "team-$ps" 2>/dev/null; then
        teamclosed "$ps" >/dev/null 2>&1 && { echo "   ✗ หลังสร้าง session: ยังตอบ CLOSED = false-CLOSED"; fail=1; }
        tmux kill-session -t "=team-$ps" 2>/dev/null
        teamclosed "$ps" >/dev/null 2>&1 || { echo "   ✗ หลังฆ่า session: ควรกลับเป็น CLOSED"; fail=1; }
        tmux has-session -t "=team-$ps" 2>/dev/null && { echo "   ✗ session probe ตกค้าง"; fail=1; }
      else
        echo "   (สร้าง tmux session ไม่ได้ — ข้าม ไม่นับผ่าน/ตก)"
      fi
    fi
  else
    echo "   (ไม่มี tmux — ข้ามเคสนี้ ไม่นับว่าผ่านหรือตก)"
  fi
  echo "5g) teamclosed ต้องไม่ติด tmux prefix-match (false-ALIVE จากทีมชื่อยาวกว่า)"
  # 🔴 เคสจริงบนเครื่องนี้ [ajfon แจ้ง 2026-08-04 · ผมทำซ้ำเอง · tmux 3.4]:
  #      tmux has-session -t team-person-lookup    → rc=0  ทั้งที่ทีมนั้นถูกยุบไปแล้ว
  #      tmux has-session -t =team-person-lookup   → rc=1  (ข้อความลง **stderr**)
  #    เพราะรูปเปล่าไป prefix-match กับ team-person-lookup-r2 ของรอบถัดไป
  #    ⇒ **false-ALIVE** กับธรรมเนียมชื่อ <team> / <team>-r2 ที่เราใช้กันเองอยู่แล้ว
  #    เทสต์นี้มีไว้กันคนถัดไป (รวมทั้งผม) มาลบ "=" ทิ้งเพราะคิดว่าไม่จำเป็น
  if binexists tmux >/dev/null 2>&1; then
    local pb="zz-vc-prefix-$$"
    if tmux new-session -d -s "team-${pb}-r2" 2>/dev/null; then
      teamclosed "$pb" >/dev/null 2>&1 || { echo "   ✗ '$pb' ไม่ควร LIVE — ติด prefix-match ของ '${pb}-r2'"; fail=1; }
      teamclosed "${pb}-r2" >/dev/null 2>&1 && { echo "   ✗ '${pb}-r2' ควร LIVE"; fail=1; }
      tmux kill-session -t "=team-${pb}-r2" 2>/dev/null
      tmux has-session -t "=team-${pb}-r2" 2>/dev/null && { echo "   ✗ session probe ตกค้าง"; fail=1; }
    else
      echo "   (สร้าง tmux session ไม่ได้ — ข้าม ไม่นับผ่าน/ตก)"
    fi
  else
    echo "   (ไม่มี tmux — ข้ามเคสนี้ ไม่นับว่าผ่านหรือตก)"
  fi
  echo "5h) teamclosed: charter ที่เก็บไว้เป็นบันทึก ต้องเป็น CHARTER-ONLY ไม่ใช่ OPEN (ตกได้สองทิศ)"
  # 🏷️ prism 2026-08-08 — เขายุบ prism-cell ครบทั้ง tmux และ tool-store แล้ว แต่ teamclosed
  #    ยังตอบ OPEN จาก cwd ของเขา เพราะ `maw team list` **สร้างแถวจากไฟล์ charter** ที่เขาเก็บไว้
  #    ตามหลัก Nothing is Deleted ⇒ เครื่องมือของผมบังคับให้เขาลบบันทึกเพื่อให้ตัวเองเขียว
  # ⚠️ เทสต์นี้ต้องล้ม **สองทิศ** ไม่งั้นมันคือใบอนุญาตให้ false-CLOSED:
  #    ทิศ 1 charter เปล่า ๆ ที่ไม่เคยสปอว์น → ต้อง **ไม่ใช่** OPEN
  #    ทิศ 2 แถวที่ status ไม่ใช่ prep-only (ของค้างจริง) → ต้อง **ยัง** OPEN เหมือนเดิม
  # แขน ก) ตรรกะจัดประเภทแถว — แถวจริงที่ผมทำซ้ำได้จาก cwd ของ prism vs แถวของค้างจริง
  _vc_row_verdict "  prism-cell                    vault  11       prep-only        —" \
    | grep -qx "charter-only" || { echo "   ✗ แถว vault/prep-only ต้องเป็น charter-only"; fail=1; }
  _vc_row_verdict "  bug-fix-v1                    tool   2        no live panes    0" \
    | grep -qx "open" || { echo "   ✗ แถว tool/no-live-panes ต้องยังเป็น open — ผ่อนจนกลืนของค้างจริง"; fail=1; }
  _vc_row_verdict "  zz-live                       tool   3        2 live           0" \
    | grep -qx "open" || { echo "   ✗ แถวที่มี pane เป็น ๆ ต้อง open"; fail=1; }
  # ⚠️ แขนนี้ **ไม่ได้** ตรวจว่า maw ลิสต์ charter ออกมาเป็นแถว vault จริงไหม — สร้างเคสนั้น
  #    ในเทสต์ไม่ได้ (ลองวาง .maw/teams/*.yaml ใน tmpdir ทั้งมี/ไม่มี git init → ไม่โผล่ทั้งคู่)
  #    ⇒ ประกาศไว้ตรงนี้ว่าเป็นช่องที่เทสต์ไม่ถึง ไม่ใช่ปล่อยให้คนอ่านคิดว่าครอบแล้ว
  # แขน ข) ผิว charter บนดิสก์ — CHARTER-ONLY vs GHOST ต้องแยกกันจริง และตกได้สองทิศ
  local ctd; ctd=$(mktemp -d "${TMPDIR:-/tmp}/vc-charter-XXXXXX")
  local cn="zz-vc-charter-$$"
  mkdir -p "$ctd/.maw/teams"; printf 'name: %s\n' "$cn" > "$ctd/.maw/teams/$cn.yaml"
  local out rc
  out=$( cd "$ctd" && teamclosed "$cn" 2>&1 ); rc=$?
  case "$out" in
    *CHARTER-ONLY*) [ $rc -eq 0 ] || { echo "   ✗ CHARTER-ONLY ควร rc=0 ได้ $rc"; fail=1; } ;;
    *GHOST*) echo "   ✗ charter ล้วน ๆ ถูกนับเป็น GHOST — บังคับให้ปลดนิยามทีมเพื่อให้เขียว"; fail=1 ;;
    *) echo "   ✗ charter บนดิสก์ต้องถูกเห็น ได้: $(printf '%s' "$out" | head -1)"; fail=1 ;;
  esac
  # ทิศกลับ: มี **store dir** ด้วย ⇒ ต้องกลับไปเป็น GHOST rc=1 (residue ชนะบันทึก)
  mkdir -p "$ctd/ψ/memory/mailbox/teams/$cn"
  out=$( cd "$ctd" && teamclosed "$cn" 2>&1 ); rc=$?
  case "$out" in
    *GHOST*) [ $rc -eq 1 ] || { echo "   ✗ GHOST ควร rc=1 ได้ $rc"; fail=1; } ;;
    *) echo "   ✗ มี store dir ค้างแล้วต้องเป็น GHOST ได้: $(printf '%s' "$out" | head -1)"; fail=1 ;;
  esac
  # แขน ค) 🔴 **เคสที่แพตช์แรกของผมพลาด** [prism จับด้วย bash -x] — มีทั้งแถว vault/prep-only
  #    **และ** store dir ค้างพร้อมกัน ⇒ ต้องเป็น GHOST · ห้ามให้บันทึกบัง residue
  #    ต้องแทน `_vc_team_list_plain` เพราะสร้างแถว vault จริงในเทสต์ไม่ได้ — แต่ที่แทนคือ
  #    **แหล่งข้อมูล** ไม่ใช่ตรรกะที่กำลังทดสอบ · fixture ของ lucifer ตอบถูกโดยไม่ชนบั๊กนี้
  #    เพราะทีมสมมติ **ไม่มีแถวใน list เลย** ⇒ สองคนเทสต์เรื่องเดียวกันแล้วไม่ชนกัน
  local cn2="zz-vc-mask-$$"
  mkdir -p "$ctd/.maw/teams"; printf 'name: %s\n' "$cn2" > "$ctd/.maw/teams/$cn2.yaml"
  _vc_team_list_plain() {
    printf '  TEAM                          STORE  MEMBERS  STATUS          ZOMBIES\n'
    printf '  %-29s vault  0        prep-only        —\n' "$cn2"
  }
  mkdir -p "$ctd/ψ/memory/mailbox/teams/$cn2"
  out=$( cd "$ctd" && teamclosed "$cn2" 2>&1 ); rc=$?
  case "$out" in
    *GHOST*) [ $rc -eq 1 ] || { echo "   ✗ masking case ควร rc=1 ได้ $rc"; fail=1; } ;;
    *CHARTER-ONLY*) echo "   ✗ แถว charter บัง store-dir residue — false-green ย้ายที่ (บั๊กที่ prism จับ)"; fail=1 ;;
    *) echo "   ✗ masking case ต้องเป็น GHOST ได้: $(printf '%s' "$out" | head -1)"; fail=1 ;;
  esac
  # ทิศกลับ: เอา store dir ออก เหลือแถว vault ล้วน ⇒ ต้องกลับเป็น CHARTER-ONLY rc=0
  rm -rf "$ctd/ψ/memory/mailbox/teams/$cn2"
  out=$( cd "$ctd" && teamclosed "$cn2" 2>&1 ); rc=$?
  case "$out" in
    *CHARTER-ONLY*) [ $rc -eq 0 ] || { echo "   ✗ vault row ล้วนควร rc=0 ได้ $rc"; fail=1; } ;;
    *) echo "   ✗ แถว vault ล้วนต้องเป็น CHARTER-ONLY ได้: $(printf '%s' "$out" | head -1)"; fail=1 ;;
  esac
  unset -f _vc_team_list_plain
  _vc_team_list_plain() { maw team list 2>&1; }
  rm -rf "$ctd"
  # แขน ง) 🔭 **กวาดของจริงบนเครื่อง** [lucifer เสนอ 2026-08-08 หลังวัด fixture ตัวเองย้อนหลัง]
  #    เขาชี้ว่า fixture ของเขา *"ไม่ได้ผ่านโดยบังเอิญ — มันบกพร่องจริง"*: ทีมสมมติได้ **0 แถว**
  #    ใน `maw team list` ⇒ ผิว 2 ไม่เคยรัน · GHOST ที่ได้มาจากผิว 3 ล้วน ๆ ⇒ **ทดสอบ 1 ใน 3 ผิว
  #    แล้วเคลมทั้งก้อน** · และรูปที่จับได้อยู่ใน repo เขา **มาตลอด** เป็นข้อมูลจริง:
  #    `software-full-cycle-v62` / `-v64` มีทั้งแถว vault/prep-only และ `~/.claude/teams/<ชื่อ>/`
  #    ⇒ *"fixture ทดสอบได้แค่สิ่งที่คนเขียนนึกออก และของผมดันไปรับ blind spot อันเดียวกับ
  #       แพตช์ที่มันกำลังตรวจ"*
  #  ⚠️ แขนนี้ **ไม่แทน** แขน ค) — คนละคำถาม: ค) ถามว่า *ตรรกะถูกไหม* (deterministic ผ่าน seam) ·
  #     ง) ถามว่า *เครื่องนี้ตอนนี้มีเคสที่ถูกบังอยู่ไหม* (canary · ขึ้นกับ cwd และสภาพเครื่อง)
  #  🔑 invariant ที่ assert: **ทีมที่มี store dir ค้าง ต้องไม่มีวันได้ `CHARTER-ONLY`**
  #     (ไม่ assert ว่าเป็น GHOST เป๊ะ ๆ เพราะถ้าทีมนั้นยัง LIVE ผิว 1 ตอบก่อน — ซึ่งก็ถูก)
  #  🔴 2026-08-08 รอบสาม [lucifer จับ] — เวอร์ชันแรกของแขนนี้ **ดึงชื่อทีมด้วย `awk '{print $1}'`
  #     จากตารางที่ render ไว้ให้คนอ่าน** ⇒ ชื่อยาว **ชนคอลัมน์ STORE** จนไม่มีช่องว่างคั่น
  #     `[verified: 11 แถวบนเครื่องนี้ · เช่น 'software-full-cycle-v17-selfclosevault']`
  #     ชื่อเพี้ยนพวกนั้นไม่มีทั้ง charter และ store dir ⇒ **ถูก `continue` ทิ้งก่อนถึงตัวนับ**
  #     ⇒ มันพิมพ์ `54` ทั้งที่ candidate จริงคือ **65** · ทั้ง 11 ตัวเป็นของจริงทุกตัว
  #  🔑 **ตัวนับที่ผมเพิ่มมาเพื่อไม่ให้ 0 แอบเป็น pass ถูกคำนวณด้วยโค้ดที่มี blind spot เอง**
  #     ⇒ `54` อ่านเหมือน *ความครอบคลุม* ทั้งที่มันคือ *ความครอบคลุมลบสิ่งที่ parse ไม่ออก*
  #     (lucifer: *"รูปเดิมอีกชั้นหนึ่ง"* — และเขาถูก)
  #  ⇒ **เลิก parse ตารางไปเลย** · candidate มาจาก **ระบบไฟล์ล้วน ๆ** ซึ่งเป็นที่ที่ maw
  #    สร้างแถวมาจากมันอยู่แล้ว: charter ใน `.maw/teams/*.yaml` ∪ dir ใน 2 store
  #    (`maw team list --json` **ไม่มี** — พิมพ์ `unknown argument --json` แล้ว **exit 0**
  #     รูปเดียวกับ `maw team <typo>` ที่ rc โกหกซึ่งไฟล์นี้จดไว้แล้ว)
  #  🧮 2026-08-08 รอบสี่ [lucifer ออกแบบ · ผมเขียน · เขามีเคสจริง 88 ตัวไว้ยืนยัน] —
  #     เขาปฏิเสธข้อเสนอ baseline ของผมทั้งอัน: *"ตัวเลขคือ artifact ที่ผิด ไม่ใช่ว่าเก็บผิดที่"*
  #     **baseline ที่เก็บเป็นเลขจะเน่าเงียบเสมอไม่ว่าวางตรงไหน เพราะไม่มีใครแยกออกว่า
  #     เลขที่ลดลงคือ *เครื่องสะอาดขึ้น* หรือ *โค้ดตาบอดขึ้น*** ⇒ ใช้ 2 กลไกที่ **ไม่เก็บ state เลย**
  #  1️⃣ **conservation** — ทุก element ของ union ต้องออกทาง**ถังที่นับได้ ถังเดียว**:
  #       `swept + nostore == union` · **ฆ่าคลาส ไม่ใช่ instance**: บั๊กรอบก่อนคือ `continue`
  #       ที่ทำให้ของหลุดจาก pipeline **โดยไม่ถูกนับ** ⇒ conservation ตกทันทีจาก cwd ไหนก็ได้
  #       **รวมถึงบ้านที่มี 0 เคส** · และมัน **ไม่ assert ขนาด** จึงไม่มีอะไรให้เน่า
  #  2️⃣ **positive control** (อยู่ในแขน จ ข้างล่าง) — พิสูจน์ว่า pipeline *ยังต่อสายอยู่*
  #       ซึ่ง**บ้านที่สะอาดทดสอบไม่ได้เลยด้วยวิธีอื่น**
  #  ⚠️ lucifer พูดความย้อนแย้งของตัวเองก่อนถูกถาม: ทั้ง thread เขาเถียงว่า *fixture รับ blind spot
  #     ของสิ่งที่มันตรวจ* — จริง **สำหรับคำถามว่าตรรกะถูกไหม** (งานของแขน ค) · แต่ positive
  #     control ถาม *pipeline ยังต่อสายไหม* ซึ่งเป็นคำถามที่ fixture เป็นเครื่องมือที่ถูกต้องพอดี
  #     **ห้ามอ่านมันเป็นคำตอบของคำถามแรก** เท่านั้นเอง
  local sweepout
  sweepout=$(_vc_sweep_scan)
  printf '%s\n' "$sweepout" | grep '^   ✗' && fail=1
  local s_swept s_nostore s_union
  eval "$(printf '%s\n' "$sweepout" | sed -n 's/^SWEEP //p' | tr ' ' '\n' | sed 's/^/s_/')"
  if [ $((s_swept + s_nostore)) -ne "$s_union" ]; then
    echo "   ✗ conservation ตก: swept($s_swept) + nostore($s_nostore) != union($s_union)"
    echo "     ⇒ มี candidate หลุดออกจาก pipeline โดยไม่ถูกนับ — คลาสเดียวกับบั๊ก 2026-08-08"
    fail=1
  fi
  echo "   (กวาดของจริงจาก cwd นี้: union=$s_union swept=$s_swept nostore=$s_nostore · conservation $([ $((s_swept + s_nostore)) -eq "$s_union" ] && echo OK || echo ✗ตก)"
  echo "    candidate มาจากระบบไฟล์ ไม่ได้ parse ตาราง · swept=0 = ไม่มีเคสให้ตรวจ **ไม่ใช่ผ่าน**"
  echo "    ตัวเลขนี้แปรตาม cwd — อ่านคู่กับ cwd เสมอ ห้ามเทียบข้ามบ้าน)"
  # 🧭 2026-08-08 รอบห้า [lucifer ออกแบบ + ทดสอบบนเคสจริง 92 ตัว · สำเนาทำลาย 3 ตัว] —
  #    เขาทำซ้ำการทดลองทำลายแล้วพบว่า **A) `continue` ก่อน `union++` ไม่มีกลไกไหนจับได้เลย**
  #    (`SELFTEST OK` ทั้งที่ union หดเงียบ 92→37) · PC จับต้นน้ำได้ **เฉพาะเมื่อ blindness
  #    ครอบรูปที่มันฉีด** (สั้น 1 / ยาว 61) ⇒ conservation เฝ้าท้ายน้ำของ `union++` เท่านั้น
  #    เพราะ **ตัวหารหดตามตัวตั้ง** · PC เฝ้าเฉพาะสองรูปที่ฉีด ⇒ ไม่มีใครเฝ้าคำถาม
  #    *"source list ถูกอ่านครบไหม"* ซึ่งเป็นคลาสของบั๊ก 2026-08-08 พอดี
  #  🔑 **ไม่เก็บ state**: เทียบสอง derivation **ในรอบเดียวกัน** ไม่ใช่เทียบกับเลขที่จำไว้
  #  ⚠️ ขอบเขตที่ lucifer ประกาศเอง ไม่ได้ให้ผมไปเจอ: สองทาง **ใช้ glob list ชุดเดียวกัน**
  #     ⇒ จับ *ความไม่ตรงกัน* ได้ **ไม่ได้จับ *ความตาบอดร่วม*** — ลบ source ทั้งก้อนออกจาก
  #     ทั้งสองที่ มันจะเห็นตรงกันและเงียบพร้อมกัน · source list ยังเป็นจุดที่ต้องเชื่อจุดเดียว
  echo "5i2) independent-union: source list ต้องถูกอ่านครบ (derive ซ้ำอีกทาง ไม่ใช้โค้ดร่วมกับ _vc_sweep_scan)"
  local u_indep
  u_indep=$( { ls -d .maw/teams/*.yaml "$HOME/.claude/teams/"*/ "ψ/memory/mailbox/teams/"*/ ; } 2>/dev/null \
             | sed -e 's:/$::' -e 's:.*/::' -e 's:\.yaml$::' | sort -u | grep -c . )
  if [ "$u_indep" -ne "$s_union" ]; then
    echo "   ✗ independent-union ตก: scan นับ union=$s_union แต่ derive อิสระได้ $u_indep"
    echo "     ⇒ source list ถูกอ่านไม่ครบ **ก่อน** ถูกนับ — conservation มองไม่เห็นโดยโครงสร้าง"
    fail=1
  fi
  if [ "$u_indep" -eq 0 ]; then
    echo "   (independent=0 scan=$s_union · cwd=$PWD"
    echo "    0 = **ไม่มี candidate ในบ้านนี้ ไม่ใช่ผ่าน** — แขนนี้ไม่ได้ตรวจอะไรเลยรอบนี้)"
  else
    echo "   (independent=$u_indep scan=$s_union $([ "$u_indep" -eq "$s_union" ] && echo 'สองทางตรงกัน' || echo '**ไม่ตรงกัน**') · cwd=$PWD"
    echo "    ตัวเลขแปรตาม cwd — อ่านคู่กับ cwd เสมอ ห้ามเทียบข้ามบ้าน"
    echo "    ขอบเขต: ใช้ glob list ชุดเดียวกับ scan ⇒ จับความไม่ตรงกัน **ไม่จับความตาบอดร่วม**)"
  fi
  # 📋 2026-08-08 รอบหก [lucifer เสนอ · ผมเขียน] — **สำมะโนรูปของบ้านนี้ ไม่ใช่แค่จำนวน**
  #  🔑 ที่มา: ตาราง damage ของเราสองคน **ไม่ตรงกันที่แถว B** · บ้านเขามีชื่อ ≥30 อยู่ 11 ตัว
  #     ⇒ `independent-union` จับ B ได้ด้วย · บ้านผมไม่มีสักตัว ⇒ **PC เป็นอันเดียวที่จับได้ที่นี่**
  #     ⇒ ถ้าเขาทดสอบบ้านเดียว เขาจะอ่านว่า *PC เป็นของแถม* · ถ้าผมทดสอบบ้านเดียว ผมจะอ่านว่า
  #       *independent จับได้แค่ A* — **ผิดคนละทาง และไม่มีทางรู้จากบ้านเดียว**
  #  > lucifer: *"coverage ของกลไกไม่ใช่คุณสมบัติของกลไก มันเป็นคุณสมบัติของ **กลไกคู่กับข้อมูล
  #  > ในบ้าน** · `SELFTEST OK` สองบ้านจึงไม่ใช่การยืนยันซ้ำ มันคือการวัดคนละจุดของ matrix เดียวกัน"*
  #  ⇒ บ้านที่**ไม่มีรูปนั้นเลย** `SELFTEST OK` ของมัน **ไม่ได้พูดถึงรูปนั้นแม้แต่นิดเดียว**
  #    — รูปเดียวกับ `0 = ไม่ใช่ผ่าน` แค่ละเอียดขึ้นหนึ่งชั้น
  local n_charter n_ct n_psi n_long
  n_charter=$(ls -d .maw/teams/*.yaml 2>/dev/null | grep -c .)
  n_ct=$(ls -d "$HOME/.claude/teams/"*/ 2>/dev/null | grep -c .)
  n_psi=$(ls -d "ψ/memory/mailbox/teams/"*/ 2>/dev/null | grep -c .)
  n_long=$( { ls -d .maw/teams/*.yaml "$HOME/.claude/teams/"*/ "ψ/memory/mailbox/teams/"*/ ; } 2>/dev/null \
            | sed -e 's:/$::' -e 's:.*/::' -e 's:\.yaml$::' | sort -u | awk 'length($0)>=30' | grep -c . )
  echo "   (สำมะโนรูปของบ้านนี้: charter=$n_charter claude-teams=$n_ct psi-teams=$n_psi ชื่อยาว≥30=$n_long"
  for _s in "charter:$n_charter" "claude-teams:$n_ct" "psi-teams:$n_psi" "ชื่อยาว≥30:$n_long"; do
    [ "${_s#*:}" -eq 0 ] && echo "    ⚠ ${_s%%:*}=0 ⇒ **แขนที่เล็งรูปนี้ ไม่ได้ตรวจอะไรเลยรอบนี้** — SELFTEST OK ไม่ได้พูดถึงมัน"
  done
  echo "    ⇒ coverage เป็นคุณสมบัติของ 'กลไก × ข้อมูลในบ้าน' ไม่ใช่ของกลไก · OK สองบ้าน = วัดคนละจุดของ matrix)"
  echo "5j) positive control: pipeline ของแขน ง ต้องยัง 'อ่านอะไรได้อยู่' (บ้านสะอาดตรวจข้อนี้ไม่ได้ด้วยวิธีอื่น)"
  # 🔑 ฉีดชื่อ 2 ตัว **ตัวสั้น 1 · ตัวยาวเกินความกว้างคอลัมน์ 1** แล้ว assert ว่า swept เพิ่ม **พอดี 2**
  #    lucifer วัดขอบเขตการชนให้: **29 ตัวอักษรผ่าน · 30 ชน** (`…-v19-gated` vs `…-v20-bridge`)
  #    ⇒ คอลัมน์กว้าง 30 พอดีและไม่มีช่องคั่นเมื่อชื่อเต็มพอดี — **แต่ไม่ hardcode 30**
  #    ใช้ 60 ไปเลยเพราะความกว้างคอลัมน์เปลี่ยนได้ (คำเตือนของเขาเอง)
  #  ⚠️ ฉีดใน **tmpdir แล้ว cd เข้าไป** ไม่ใช่ใน repo ที่รันอยู่ — selftest ห้ามทิ้งรอยในบ้านคนอื่น
  #    (แขน 14 ของไฟล์นี้: *ผลข้างเคียงคือความเสียหาย*) · baseline วัดจาก tmpdir เปล่าในรอบเดียวกัน
  #    จึงไม่ต้องเก็บเลขไว้ที่ไหนเลย — ซึ่งคือทั้งประเด็นของข้อเสนอ lucifer
  local pcd base inj long
  pcd=$(mktemp -d "${TMPDIR:-/tmp}/vc-pc-XXXXXX")
  mkdir -p "$pcd/empty" "$pcd/inj/ψ/memory/mailbox/teams"
  long="zz-vc-pc-$(printf 'x%.0s' $(seq 1 52))"
  mkdir -p "$pcd/inj/ψ/memory/mailbox/teams/zz-vc-pc-s" "$pcd/inj/ψ/memory/mailbox/teams/$long"
  base=$( cd "$pcd/empty" && _vc_sweep_scan | sed -n 's/^SWEEP .*swept=\([0-9]*\).*/\1/p' )
  inj=$( cd "$pcd/inj" && _vc_sweep_scan | sed -n 's/^SWEEP .*swept=\([0-9]*\).*/\1/p' )
  if [ $((inj - base)) -ne 2 ]; then
    echo "   ✗ ฉีด 2 ชื่อ (สั้น 1 + ยาว ${#long} ตัวอักษร 1) แต่ swept ขยับ $((inj - base)) ไม่ใช่ 2"
    echo "     ⇒ pipeline อ่าน candidate ไม่ครบ — คลาสเดียวกับชื่อชนคอลัมน์ที่ lucifer จับได้"
    fail=1
  fi
  rm -rf "$pcd"
  echo "7) enginereg: engine ที่ลงทะเบียนจริง (codex) ต้อง REGISTERED"
  if maw config >/dev/null 2>&1; then
    enginereg codex >/dev/null 2>&1 || { echo "   ✗ codex ควร REGISTERED (มีใน global maw.config.50.json)"; fail=1; }
    echo "7b) enginereg: ชื่อมั่ว ๆ ต้อง UNREGISTERED ไม่ใช่ผ่าน"
    enginereg __no_such_engine__ >/dev/null 2>&1 && { echo "   ✗ รับชื่อ engine ที่ไม่มีอยู่"; fail=1; }
  else
    echo "   (ไม่มี maw / อ่าน config ไม่ได้ — ข้าม ไม่นับผ่าน/ตก)"
  fi
  echo "8) enginecheck: charter ที่ขอ engine ที่ไม่ได้ลงทะเบียน **ต้องตก**"
  # นี่คือเคสที่หลอกเราจริง: dry-run เขียว แต่ pane ได้ engine อื่น
  local td8 here8
  here8=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  td8=$(mktemp -d)
  mkdir -p "$td8/ψ/teams"
  cat > "$td8/ψ/teams/vc-probe.yaml" <<'YAML'
name: vc-probe
session: vc-probe
members:
  - role: vc-probe-bad
    engine: __no_such_engine__
    model: some-model
    worktree: false
YAML
  if maw config >/dev/null 2>&1; then
    ( cd "$td8" && bash "$here8/verify-check.sh" enginecheck vc-probe ) >/dev/null 2>&1 \
      && { echo "   ✗ enginecheck ผ่าน ทั้งที่ engine ไม่ได้ลงทะเบียน = false-PASS ตัวที่เรากลัว"; fail=1; }
    echo "8b) enginecheck: charter ที่ engine ลงทะเบียนแล้วแต่ model ไม่ตรง **ต้องตก**"
    cat > "$td8/ψ/teams/vc-probe2.yaml" <<'YAML'
name: vc-probe2
session: vc-probe2
members:
  - role: vc-probe-model
    engine: codex
    model: model-that-is-not-in-the-alias
    worktree: false
YAML
    ( cd "$td8" && bash "$here8/verify-check.sh" enginecheck vc-probe2 ) >/dev/null 2>&1 \
      && { echo "   ✗ enginecheck ผ่าน ทั้งที่ model ที่ขอไม่อยู่ในคำสั่งจริง"; fail=1; }
  else
    echo "   (ไม่มี maw — ข้าม ไม่นับผ่าน/ตก)"
  fi
  echo "8e) fixture: charter ที่มี model: แต่ **ไม่มี** engine: → model กลายเป็นชื่อ engine"
  # 🏷️ atlas 2026-08-06 ขอ fixture นี้ตรง ๆ: เขาไม่ได้ทดสอบเคสนี้จึงไม่เคลมว่า logic ผม
  #    ถูก/ผิด แต่ชี้ว่ามันสมควรมี fixture — และเขาถูก เพราะนี่คือครึ่งที่เราเพิ่งแก้กันทั้ง 4 ผิว
  local td10; td10=$(mktemp -d); mkdir -p "$td10/ψ/teams"
  printf 'name: vc-mfb\nsession: vc-mfb\nmembers:\n  - role: vc-mfb-a\n    model: __vc_model_as_engine__\n    worktree: false\n' \
    > "$td10/ψ/teams/vc-mfb.yaml"
  if maw config >/dev/null 2>&1; then
    local out10; out10=$( cd "$td10" && maw team up vc-mfb --dry-run 2>&1 )
    case "$out10" in
      *__vc_model_as_engine__*) ;;   # model string โผล่ในคอลัมน์ engine = พฤติกรรมที่เราบันทึกไว้
      *) echo "   ✗ maw ไม่ได้เอา model มาเป็น engine แล้ว — กฎที่เราสอนทั้งฟลีตตกยุค ต้องแก้เอกสาร"; fail=1 ;;
    esac
    ( cd "$td10" && bash "$here8/verify-check.sh" enginecheck vc-mfb ) >/dev/null 2>&1 \
      && { echo "   ✗ enginecheck ผ่าน charter ที่ model กลายเป็น engine ที่ไม่ได้ลงทะเบียน"; fail=1; }
  else
    echo "   (ไม่มี maw — ข้าม ไม่นับผ่าน/ตก)"
  fi
  rm -rf "$td10"
  echo "8f) engineone: โหมดสมาชิกเดี่ยว ต้องพ่น machine key ยึดคอลัมน์ 0 + rc ถูก"
  if maw config >/dev/null 2>&1; then
    # ⚠️ ห้าม `engineone ... | grep -q` ตรง ๆ — `set -o pipefail` จะเอา rc ของ engineone
    #    (ตั้งใจให้เป็น 1 ตอน FAIL) มาเป็น rc ของ pipeline ⇒ เทสต์ตกทั้งที่ output ถูก
    #    **นี่คือกับดักเดียวกับที่เขียนเตือนไว้ที่เทสต์ 5 ในไฟล์นี้เอง และผมเพิ่งเหยียบซ้ำ**
    #    ⇒ เก็บ output ใส่ตัวแปรก่อน แล้วค่อย grep
    local o10a o10b
    o10a=$(engineone codex . 2>/dev/null || true)
    case "$o10a" in
      *"$(printf '\n')overall: PASS"*|"overall: PASS"*) ;;
      *) printf '%s\n' "$o10a" | grep -q '^overall: PASS' || { echo "   ✗ engineone ไม่พ่น ^overall: PASS"; fail=1; } ;;
    esac
    printf '%s\n' "$o10a" | grep -q '^enginecheck.engine: codex PASS ' || { echo "   ✗ ไม่พ่น ^enginecheck.engine:"; fail=1; }
    engineone __no_such_engine__ . >/dev/null 2>&1 && { echo "   ✗ engineone rc=0 ให้ engine ที่ไม่มี"; fail=1; }
    o10b=$(engineone __no_such_engine__ . 2>/dev/null || true)
    printf '%s\n' "$o10b" | grep -q '^overall: FAIL' || { echo "   ✗ ไม่พ่น ^overall: FAIL"; fail=1; }
    echo "8g) engineone: ต้องแยก scope=resolved ออกจาก scope=dir-absent (atlas ข้อ i)"
    local o10c o10d
    o10c=$(engineone codex . 2>/dev/null || true)
    printf '%s\n' "$o10c" | grep -q 'scope=resolved' || { echo "   ✗ dir มีจริง แต่ไม่ได้พ่น scope=resolved"; fail=1; }
    o10d=$(engineone codex /no/such/dir/at/all 2>/dev/null || true)
    printf '%s\n' "$o10d" | grep -q 'scope=dir-absent' || { echo "   ✗ dir ไม่มี แต่ไม่ได้พ่น scope=dir-absent"; fail=1; }
    printf '%s\n' "$o10d" | grep -q 'answered-from=' || { echo "   ✗ dir-absent ต้องบอก path ที่ใช้ตอบจริง"; fail=1; }
    echo "8h) engineone: dir ไม่มี + หา alias ไม่เจอ = UNVERIFIED rc=2 ไม่ใช่ FAIL (ajfon)"
    # "ตอบไม่ได้" ≠ "ตอบว่าไม่ผ่าน" — gate ที่รันก่อน mkdir ต้องไม่สรุปว่า alias ผิด
    local o10e rc10e
    o10e=$(engineone __no_such_engine__ /no/such/dir/at/all 2>/dev/null); rc10e=$?
    [ "$rc10e" = "2" ] || { echo "   ✗ ควร rc=2 ได้ $rc10e"; fail=1; }
    printf '%s\n' "$o10e" | grep -q '^overall: UNVERIFIED' || { echo "   ✗ ควรพ่น ^overall: UNVERIFIED"; fail=1; }
    # แต่ dir ที่มีจริงและหาไม่เจอ ต้องยัง FAIL — ไม่งั้นเราลบความสามารถในการตกทิ้ง
    engineone __no_such_engine__ /tmp >/dev/null 2>&1; [ "$?" = "1" ] || { echo "   ✗ dir มีจริง+ไม่เจอ ควร rc=1"; fail=1; }
    echo "8i) enginecheck.unverified ต้อง **ว่างได้จริง** ไม่งั้นกฎของ atlas เป็นเท็จไม่ได้ (ajfon r4)"
    # เกณฑ์ที่ให้ผลเดียวเสมอ แยกแยะอะไรไม่ได้ — echo กลับทิศ
    local o10f o10g
    o10f=$(engineone codex . 2>/dev/null || true)
    printf '%s\n' "$o10f" | grep -q '^enginecheck.unverified:$' \
      || { echo "   ✗ เคสที่ถูกสมบูรณ์ ควรพ่น unverified ว่าง — ถ้าไม่ว่างเสมอ กฎจะ degenerate"; fail=1; }
    o10g=$(engineone codex /tmp/__vc_absent__ 2>/dev/null || true)
    printf '%s\n' "$o10g" | grep -q '^enginecheck.unverified: answered-from-ancestor=' \
      || { echo "   ✗ dir-absent+เจอ ควรลง unverified เป็น answered-from-ancestor"; fail=1; }
    printf '%s\n' "$o10f" | grep -q '^enginecheck.scope: out-of-scope=' \
      || { echo "   ✗ ขอบเขตถาวรต้องอยู่ namespace out-of-scope ไม่ปนกับผลที่ผันแปร"; fail=1; }
  else
    echo "   (ไม่มี maw — ข้าม)"
  fi
  echo "8j) enginelist: ทุกเลขต้องพก scope ติดตัว และ scope ต้องต่างกันจริงตาม dir (tars v3)"
  if maw config >/dev/null 2>&1; then
    local eh ei
    eh=$(enginelist . 2>/dev/null | head -1)
    ei=$(enginelist /tmp 2>/dev/null | head -1)
    case "$eh" in enginelist.scope:*dir=*layers=*) ;; *) echo "   ✗ บรรทัดแรกต้องเป็น enginelist.scope: dir=… layers=…"; fail=1 ;; esac
    [ "$eh" = "$ei" ] && { echo "   ✗ scope จากคนละ dir ออกมาเหมือนกัน = เลขยังไม่พกที่มา"; fail=1; }
  else
    echo "   (ไม่มี maw — ข้าม)"
  fi
  echo "8c) enginereg: alias ที่อยู่ใน .maw/ ของ repo ต้อง **มองไม่เห็น** จาก path นอก repo"
  # กับดักที่ที่ปรึกษาจับได้ 2026-08-06: ถ้าถามจาก cwd ของ lead เสมอ จะตอบ REGISTERED
  # ให้สมาชิกที่ worktree อยู่นอก repo — false-PASS ในประตูที่เพิ่งสร้างมากันเรื่องนี้พอดี
  if maw config >/dev/null 2>&1 && [ -f "$here8/../../../.maw/maw.config.60.json" ]; then
    enginereg codex-sol "$here8/../.." >/dev/null 2>&1 || { echo "   ✗ ในรีโปควรเห็น codex-sol"; fail=1; }
    enginereg codex-sol /tmp          >/dev/null 2>&1 && { echo "   ✗ นอกรีโปไม่ควรเห็น alias ที่อยู่ใน .maw/ ของรีโป"; fail=1; }
  else
    echo "   (ไม่มี maw หรือไม่มี layer ของ repo — ข้าม ไม่นับผ่าน/ตก)"
  fi
  echo "8d) enginereg: layer ที่บรรพบุรุษของ worktree **นอก repo** ต้องถูกเห็น (สูตรของ loom/prism)"
  # ถ้าเคสนี้ตก แปลว่า worktree นอก repo ไม่มีทางแก้แบบ local เลย ต้องไปแก้ global
  local td9; td9=$(mktemp -d)
  mkdir -p "$td9/sub" "$td9/.maw"
  printf '{"commands":{"__vc_probe_out__":"echo VC-OUT-OF-REPO"}}\n' > "$td9/.maw/maw.config.60.json"
  if maw config >/dev/null 2>&1; then
    enginereg __vc_probe_out__ "$td9/sub" >/dev/null 2>&1 || { echo "   ✗ บรรพบุรุษของ path นอก repo ควรเห็น layer"; fail=1; }
    enginereg __vc_probe_out__ /            >/dev/null 2>&1 && { echo "   ✗ path นอกสาย ไม่ควรเห็น (negative control)"; fail=1; }
  else
    echo "   (ไม่มี maw — ข้าม ไม่นับผ่าน/ตก)"
  fi
  rm -rf "$td9" "$td8"
  echo "6) pipefail trap: cmd | grep -q ต้องไม่ทำให้ผลกลายเป็นล้มเหลว"
  local rc6; echo hi | grep -q hi; rc6=$?
  [ "$rc6" = "0" ] || { echo "   ✗ grep -q rc=$rc6"; fail=1; }

  # 🩹 2026-08-06 [clean-room tester] usage เคยตก 4 verb ที่ dispatcher รับจริง
  #    ⇒ คนที่ถามเครื่องมือว่ามี verb อะไร ได้ลิสต์ที่ไม่มีตัวที่เอกสารสั่งให้ใช้
  #    รูปเดียวกับ `maw tmux --help` ที่ลิสต์มือแล้วตก `kill` — บังคับให้ตรงกันด้วยเทสต์
  echo "9) ทุก verb ที่ dispatcher รับ ต้องเป็นฟังก์ชันจริง และต้องโผล่ใน usage"
  local uout v; uout=$(verify_check_usage 2>&1)
  for v in $VERIFY_CHECK_VERBS; do
    if ! declare -F "$v" >/dev/null 2>&1; then
      echo "   ✗ '$v' อยู่ในลิสต์ dispatcher แต่ไม่มีฟังก์ชันจริง"; fail=1
    fi
    case "$uout" in
      *"$v"*) ;;
      *) echo "   ✗ '$v' รับได้แต่ไม่ถูกลิสต์ใน usage — drift แบบเดียวกับ maw tmux --help"; fail=1 ;;
    esac
  done

  # 🔑 lucifer 2026-08-06: *"ทุกเคสที่เจอวันนี้เป็นเครื่องมือที่รายงานผลโดยไม่บอกขอบเขต"*
  #    ⇒ verb ที่ให้ verdict ต้องพิมพ์ `<verb>.scope:` เสมอ · บังคับด้วยเทสต์ ไม่ใช่กฎที่เขียนเตือน
  #    (verb ที่เป็น primitive ล้วน — binexists/procs/procs_cmd/relay/selftest — ยกเว้น
  #     เพราะมันคืนตัวเลข/สถานะดิบ ไม่ได้ตัดสินอะไรแทนคนอ่าน · relay บอกขอบเขตในบรรทัด SENT อยู่แล้ว)
  echo "10) verb ที่ให้ verdict ต้องประกาศขอบเขตตัวเอง (<verb>.scope:)"
  local vsrc; vsrc=$(cat "${BASH_SOURCE[0]}")
  local vb
  for vb in alive teamclosed enginecheck enginelist bootverify; do
    case "$vsrc" in
      *"${vb}.scope:"*) ;;
      *) echo "   ✗ '$vb' ให้ verdict แต่ไม่มีบรรทัด ${vb}.scope:"; fail=1 ;;
    esac
  done

  # 🏷️ lucifer + atlas 2026-08-07: `UNREGISTERED` เดิมยุบสองสาเหตุเป็นคำเดียว
  #    · *ไม่เคยมีคีย์นี้*            ⇒ แก้ = **เพิ่ม**
  #    · *มีคีย์ แต่ในไฟล์ที่ maw ไม่อ่าน* ⇒ แก้ = **ย้าย**
  #    lucifer อ่าน 64/65 FAIL เป็นอย่างแรก แล้วเกือบไปเพิ่มคีย์ให้ 57 charter
  #    atlas ยก `UNREGISTERED` ของเครื่องมือนี้ไปใส่รายงาน T4463 หลายครั้งในวันเดียว
  #    ⇒ **ถ้อยคำของเครื่องมือคือพาหะ** — แก้ที่ต้นทาง ไม่ใช่ให้ทุกคนเติม caveat เอง
  echo "11) DEAD-LAYER: แยก 'ไม่เคยมี' ออกจาก 'มีแต่ในไฟล์ที่ maw ไม่อ่าน'"
  local td11; td11=$(mktemp -d)
  mkdir -p "$td11/.maw"
  # ไฟล์มีเลข = maw อ่าน · ไฟล์ไม่มีเลข = maw ไม่อ่าน (เพราะมีไฟล์เลขอยู่แล้ว)
  printf '{"commands":{"__vc_live__":"echo LIVE"}}\n'      > "$td11/.maw/maw.config.60.json"
  printf '{"commands":{"__vc_buried__":"echo BURIED"}}\n'  > "$td11/.maw/maw.config.json"
  if maw config >/dev/null 2>&1; then
    local o11
    # (ก) positive — คีย์ที่ฝังอยู่ในไฟล์ไม่มีเลข ต้องถูกชี้ว่า DEAD-LAYER
    o11=$(enginereg __vc_buried__ "$td11" 2>&1)
    case "$o11" in
      *DEAD-LAYER*) ;;
      *) echo "   ✗ คีย์ที่อยู่ในไฟล์ไม่มีเลข ควรถูกชี้ว่า DEAD-LAYER"; fail=1 ;;
    esac
    # 🩹 lucifer 2026-08-07: เทสต์นี้เดิมบังคับให้พ่นคำว่า "ย้าย" แบบไม่มีเงื่อนไข ⇒ มัน
    #    **ล็อกบั๊กเอาไว้** — คำสั่ง "ย้าย" ผิดสำหรับเคส (B) (คีย์อยู่ใน live layer ที่มองไม่เห็น
    #    จาก path นี้) ⇒ เทสต์ที่ยืนยันพฤติกรรมผิด ก็คือการตรวจที่ทำให้บั๊กอยู่ต่อได้
    #    ⇒ เปลี่ยนเป็นบังคับให้ **เสนอทั้งสองเคส + วิธีแยก** แทนการสั่งการแก้
    case "$o11" in
      *"(A)"*) ;;
      *) echo "   ✗ DEAD-LAYER ต้องเสนอเคส (A) อยู่เฉพาะไฟล์ตาย"; fail=1 ;;
    esac
    case "$o11" in
      *"(B)"*) ;;
      *) echo "   ✗ DEAD-LAYER ต้องเสนอเคส (B) อยู่ใน live layer ที่มองไม่เห็นจาก path นี้"; fail=1 ;;
    esac
    case "$o11" in
      *"maw config explain commands.__vc_buried__"*) ;;
      *) echo "   ✗ DEAD-LAYER ต้องแนบคำสั่งที่ **แยกสองเคสได้** ไม่ใช่สั่งการแก้เลย"; fail=1 ;;
    esac
    # (ข) negative — คีย์ที่ไม่มีอยู่ที่ไหนเลย ต้องไม่ถูกกล่าวหาว่า DEAD-LAYER
    o11=$(enginereg __vc_never_exists__ "$td11" 2>&1)
    case "$o11" in
      *DEAD-LAYER*) echo "   ✗ คีย์ที่ไม่มีจริง ถูกกล่าวหาว่า DEAD-LAYER (false accusation)"; fail=1 ;;
    esac
    # (ค) negative — คีย์ที่อยู่ในไฟล์ **ที่ maw อ่าน** ต้อง REGISTERED เฉย ๆ ไม่ใช่ DEAD-LAYER
    o11=$(enginereg __vc_live__ "$td11" 2>&1)
    case "$o11" in
      REGISTERED*) ;;
      *) echo "   ✗ คีย์ในไฟล์ที่มีเลข ควร REGISTERED"; fail=1 ;;
    esac
    case "$o11" in
      *DEAD-LAYER*) echo "   ✗ คีย์ที่ resolve ได้ ไม่ควรมี DEAD-LAYER ติดมา"; fail=1 ;;
    esac
  else
    echo "   (ไม่มี maw — ข้าม ไม่นับผ่าน/ตก)"
  fi
  rm -rf "$td11"

  # 🏷️ 2026-08-07 · พบจาก audit ตัวเอง หลัง goal-hook บอกว่ายังไม่ราบลื่น:
  #    `bootverify` เป็น **verb ที่ description ของ skill โฆษณาไว้เอง** และแทน Step 6 ทั้งขั้น
  #    **แต่ selftest ไม่เคยเรียกมันสักครั้ง** — มันโผล่ในเทสต์ที่เดียวคือ case 10
  #    ซึ่งตรวจแค่ว่า *มีบรรทัด `bootverify.scope:` อยู่ในไฟล์ไหม* ⇒ **ตรวจว่าประกาศขอบเขต
  #    ไม่ได้ตรวจว่าตัดสินถูก** · `alive` เหมือนกัน · `unstick`/`modelprobe` ไม่ถูกเอ่ยถึงเลย
  #    ⇒ คลาสเดียวกับข้อ 4 ของ guard criterion: **check ที่ไม่มี input ไหนทำให้มันตกได้**
  #    เพราะไม่มีใครเรียกมันในเทสต์ตั้งแต่แรก
  # 🏷️ input ที่ทำให้ท่าเดิม (`awk '{print $1}' | xargs -r basename`) ตก — จดไว้ตรงนี้
  #    เพราะ **guard question 4 ขอ input ที่ทำให้ check ตก** ⇒ นี่คืออันนั้น
  echo "11b) _vc_argv_basename: cmdline ที่มีขึ้นบรรทัดใหม่ + quote ต้องไม่ทำให้ผลว่าง"
  local nl_cmd="node /home/user/.npm-global/bin/codex --config effort=medium --model gpt-5.6
You are 'workflow-controller' on team 'teaching-media-cell'.
Second line with 'quotes' and --flags"
  local g1 g2
  g1=$(_vc_argv_basename "$nl_cmd" 1); g2=$(_vc_argv_basename "$nl_cmd" 2)
  [ "$g1" = "node" ]  || { echo "   ✗ arg1 ควรเป็น node (ได้ '$g1')"; fail=1; }
  [ "$g2" = "codex" ] || { echo "   ✗ arg2 ควรเป็น codex (ได้ '$g2')"; fail=1; }
  # ท่าเดิมต้องตกกับ input เดียวกัน — ถ้ามันไม่ตก แปลว่าเทสต์นี้ไม่ได้ทดสอบอะไร
  local old; old=$(printf '%s' "$nl_cmd" | awk '{print $1}' | xargs -r basename 2>/dev/null)
  [ -z "$old" ] || echo "   🟡 ท่าเดิมไม่ตกบนเครื่องนี้ (ได้ '$old') — เทสต์นี้ยังผ่าน แต่ไม่ได้พิสูจน์ regression"
  # 🏷️ เคสที่ helper เวอร์ชันแรกของผม **ทำ enginecheck พังเงียบ** — binary อยู่คนละบรรทัดกับ VAR=VAL
  #    ต้องได้คำตอบเดียวกับท่า `head -1` เดิม ไม่ใช่ค่าว่าง
  local mv_cmd; mv_cmd=$(printf 'MAW_SESSION_WINDOW=x\nclaude --model y')
  local g3; g3=$(_vc_argv_basename "$mv_cmd" 1)
  [ "$g3" = "claude" ] || { echo "   ✗ binary หลัง VAR=VAL คนละบรรทัด ควรได้ claude (ได้ '$g3')"; fail=1; }

  echo "12) bootverify: ต้องแยก 'ไม่มี session' / 'session จริงแต่ไม่ใช่ agent' ได้ (ตกได้ทั้งสองทิศ)"
  if binexists tmux >/dev/null 2>&1; then
    local bs="zz-vc-bootverify-$$" o12
    # (ก) session ที่ไม่มีจริง ⇒ FAIL rc=1 — ต้องไม่ตอบ READY
    o12=$(bootverify "$bs-nope" 2>&1); local rc12=$?
    [ "$rc12" = "1" ] || { echo "   ✗ session ที่ไม่มี ควร rc=1 (ได้ $rc12)"; fail=1; }
    case "$o12" in
      *READY*) echo "   ✗ session ที่ไม่มี ตอบ READY — false-READY คือทิศที่แพงที่สุด"; fail=1 ;;
    esac
    # (ข) session จริงที่รัน `sleep` ล้วน ⇒ ไม่ใช่ agent ⇒ ห้าม overall READY
    tmux new-session -d -s "$bs" 'sleep 30' 2>/dev/null
    if tmux has-session -t "=$bs" 2>/dev/null; then
      o12=$(bootverify "$bs" 2>&1)
      case "$o12" in
        *"overall: READY"*) echo "   ✗ pane ที่รัน sleep ไม่ใช่ agent — ห้ามรายงาน overall READY"; fail=1 ;;
      esac
      # ต้องพูดอะไรสักอย่างเกี่ยวกับ pane นั้น ไม่ใช่เงียบแล้วผ่าน
      case "$o12" in
        *"bootverify.pane:"*) ;;
        *) echo "   ✗ bootverify ไม่ได้รายงาน pane ใดเลยบน session ที่มีจริง"; fail=1 ;;
      esac
      tmux kill-session -t "=$bs" 2>/dev/null
      # (ค) พอฆ่าทิ้งแล้ว ต้องกลับไป FAIL — ยืนยันว่า (ข) ไม่ได้ผ่านเพราะบังเอิญ
      o12=$(bootverify "$bs" 2>&1); rc12=$?
      [ "$rc12" = "1" ] || { echo "   ✗ หลัง kill session ควร rc=1 (ได้ $rc12)"; fail=1; }
    else
      echo "   (สร้าง tmux session ไม่ได้ — ข้ามแขน (ข)/(ค) ไม่นับผ่าน/ตก)"
    fi
  else
    echo "   (ไม่มี tmux — ข้าม ไม่นับผ่าน/ตก)"
  fi

  # 🏷️ 2026-08-07 · ปิดช่องว่างสุดท้ายของ audit: verb ที่ dispatcher รับแต่ selftest ไม่เคยเรียก
  #    `alive` เป็น verb ที่ **ให้ verdict** (RUNNING/NONE) ⇒ ต้องตกได้ทั้งสองทิศ
  echo "13) alive: ต้องตอบ RUNNING กับของที่รันจริง และ NONE กับชื่อที่ไม่มี (ตกได้สองทิศ)"
  local a13
  a13=$(alive "zz-vc-no-such-binary-$$" 2>&1)
  case "$a13" in
    NONE*) ;;
    *) echo "   ✗ ชื่อที่ไม่มีอยู่ ควรได้ NONE"; fail=1 ;;
  esac
  case "$a13" in
    *RUNNING*) echo "   ✗ ชื่อที่ไม่มีอยู่ ตอบ RUNNING — false-RUNNING"; fail=1 ;;
  esac
  # 🩹 แขนบวกเวอร์ชันแรกใช้ `alive sleep` ⇒ **ผ่านได้แม้ไม่มี background job ของเราเลย**
  #    ถ้าเครื่องมี `sleep` อื่นรันอยู่ ⇒ **self-fulfilling** ⇒ guard ข้อ 4 กับเทสต์ของตัวเอง
  #    ⇒ ใช้ marker ที่ไม่ซ้ำกับใครบนเครื่อง + ยืนยันว่าก่อนสตาร์ตมันต้องเป็น NONE จริง
  local mk="zzvcalive$$"
  local pre; pre=$(alive "$mk" 2>&1)
  case "$pre" in
    NONE*) ;;
    *) echo "   ✗ marker ต้องยังไม่มีอยู่ก่อนเริ่ม — เทสต์นี้พิสูจน์อะไรไม่ได้"; fail=1 ;;
  esac
  # 🔑 `procs` เทียบ basename ของ **`/proc/PID/exe`** ⇒ สคริปต์ shell ใช้ไม่ได้
  #    (exe จะเป็น `bash` ไม่ใช่ชื่อไฟล์) ⇒ ต้อง **สำเนา binary จริง** มาตั้งชื่อไม่ซ้ำ
  #    [เจอตอนรันเทสต์นี้เอง: เวอร์ชันสคริปต์ตกทันที — เป็นเหตุผลที่แขนบวกต้องรันจริง]
  local mkdir_t; mkdir_t=$(mktemp -d)
  cp "$(command -v sleep)" "$mkdir_t/$mk" 2>/dev/null || { echo "   (คัดลอก sleep ไม่ได้ — ข้ามแขนบวก)"; mk=""; }
  local sp=""
  if [ -n "$mk" ]; then "$mkdir_t/$mk" 25 & sp=$!; fi
  sleep 0.3
  if [ -z "$mk" ]; then a13="RUNNING (skipped)"; fi
  [ -n "$mk" ] && a13=$(alive "$mk" 2>&1)
  case "$a13" in
    RUNNING*) ;;
    *) echo "   ✗ process ที่รันอยู่จริง ($mk) ควรได้ RUNNING"; fail=1 ;;
  esac
  [ -n "$sp" ] && { kill "$sp" 2>/dev/null; wait "$sp" 2>/dev/null; }
  rm -rf "$mkdir_t"

  # `unstick` เป็น **verb เดียวที่ส่งคีย์** ⇒ เทสต์บน session ที่สร้างเองเท่านั้น ห้ามแตะของจริง
  #    สิ่งที่ต้องพิสูจน์: มันต้อง **ไม่แตะ pane ที่ไม่มีข้อความค้าง** (ไม่มี Pasted Content)
  echo "14) unstick: ต้องไม่ส่งคีย์เข้า pane ที่ไม่มีอะไรค้าง (ผลข้างเคียงคือความเสียหาย)"
  if binexists tmux >/dev/null 2>&1; then
    local us="zz-vc-unstick-$$"
    tmux new-session -d -s "$us" 'cat > /dev/null' 2>/dev/null
    if tmux has-session -t "=$us" 2>/dev/null; then
      local before after
      before=$(tmux capture-pane -p -t "=$us" 2>/dev/null | wc -l)
      unstick "$us" 1 >/dev/null 2>&1
      after=$(tmux capture-pane -p -t "=$us" 2>/dev/null | wc -l)
      [ "$before" = "$after" ] || { echo "   ✗ unstick เปลี่ยนจอของ pane ที่ไม่มีอะไรค้าง ($before → $after)"; fail=1; }
      tmux kill-session -t "=$us" 2>/dev/null
    else
      echo "   (สร้าง session ไม่ได้ — ข้าม ไม่นับผ่าน/ตก)"
    fi
  else
    echo "   (ไม่มี tmux — ข้าม)"
  fi

  # ⚠️ `modelprobe` **ไม่มีเทสต์โดยเจตนา** — มันเปิด turn จริงกับบัญชีจริง ⇒ **เสียโควตาของทั้ง fleet**
  #    ⇒ นี่คือ **ขอบเขตที่ประกาศ ไม่ใช่ช่องที่ลืม** · ใครแก้ modelprobe ต้องรันมือเองและแนบ output
  echo "15) modelprobe: **ไม่รันในเทสต์โดยเจตนา** (เสียโควตาจริง) — ประกาศไว้ ไม่ใช่ลืม"
  declare -F modelprobe >/dev/null 2>&1 || { echo "   ✗ modelprobe ไม่มีฟังก์ชันจริง"; fail=1; }

  echo "16) mawverb: subcommand จริงต้องผ่าน · ที่ไม่มีต้องตก · และต้องพิสูจน์ธรรมเนียม rc ที่ขัดกัน"
  if binexists maw >/dev/null 2>&1; then
    mawverb up   >/dev/null 2>&1 || { echo "   ✗ 'up' มีจริง ควรผ่าน"; fail=1; }
    mawverb down >/dev/null 2>&1 || { echo "   ✗ 'down' มีจริง ควรผ่าน"; fail=1; }
    mawverb zz-not-a-real-subcommand >/dev/null 2>&1 && { echo "   ✗ subcommand ที่ไม่มี ควรตก"; fail=1; }
    # 🔑 แขนที่พิสูจน์ **เหตุผลที่ verb นี้ต้องมีอยู่** — ถ้าวันหนึ่ง maw แก้ให้ `team <typo>`
    #    คืน rc≠0 แขนนี้จะตก แล้วเราจะได้รู้ว่ากฎเปลี่ยน (และลบ verb นี้ได้)
    maw team zz-not-a-real-subcommand >/dev/null 2>&1
    local trc=$?
    [ "$trc" = "0" ] || echo "   🟡 'maw team <typo>' คืน rc=$trc แล้ว (เคยเป็น 0) — ธรรมเนียมเปลี่ยน ทบทวน mawverb"
    local terr; terr=$(maw team zz-not-a-real-subcommand 2>&1 >/dev/null | grep -c .)
    [ "$terr" = "0" ] || echo "   🟡 'maw team <typo>' เริ่มพิมพ์ลง stderr แล้ว — ธรรมเนียมเปลี่ยน"
  else
    echo "   (ไม่มี maw — ข้าม ไม่นับผ่าน/ตก)"
  fi

  # 🏷️ modelprobe เองรันในเทสต์ไม่ได้ (เสียโควตา — case 15) **แต่ตรรกะเก็บกวาดของมันทดสอบได้**
  #    บน config สังเคราะห์ ⇒ แยก "ส่วนที่แพง" ออกจาก "ส่วนที่ตรวจได้" แทนที่จะปล่อยทั้งก้อน
  echo "17) modelprobe cleanup: ลบเฉพาะบล็อกของตัวเอง · ไม่ทิ้งบรรทัดว่าง · ไม่แตะของบ้านอื่น"
  local t17; t17=$(mktemp -d)
  printf '[projects."/home/other/oracle"]\ntrust_level="trusted"\n\n[projects."%s"]\ntrust_level="trusted"\n\n[projects."/home/other/two"]\ntrust_level="trusted"\n' "$t17" > "$t17/cfg.toml"
  MP_TMP="$t17" MP_CFG="$t17/cfg.toml" python3 - <<'PY'
import os, re, pathlib
tmp = os.environ["MP_TMP"]; p = pathlib.Path(os.environ["MP_CFG"])
src = p.read_text()
pat = re.compile(r'(?m)^\n?\[projects\."' + re.escape(tmp) + r'"\]\n(?:(?!^\[).*\n?)*')
out, n = pat.subn('', src)
p.write_text(out)
PY
  local left; left=$(grep -c 'projects\."' "$t17/cfg.toml")
  [ "$left" = "2" ] || { echo "   ✗ ควรเหลือ 2 บล็อกของบ้านอื่น (เหลือ $left)"; fail=1; }
  grep -q "$t17" "$t17/cfg.toml" && { echo "   ✗ บล็อกของตัวเองยังอยู่"; fail=1; }
  grep -q '^$' "$t17/cfg.toml" && { echo "   ✗ เหลือบรรทัดว่าง — การลบไม่ใช่ inverse ของการเพิ่ม"; fail=1; }
  grep -q '/home/other/oracle' "$t17/cfg.toml" || { echo "   ✗ ลบของบ้านอื่นไปด้วย"; fail=1; }
  rm -rf "$t17"

  # 🔌 2026-08-07 — census-selftest.sh ถูกสร้างเพื่อแทน "คอมเมนต์ลงวันที่ที่เสื่อมเงียบ ๆ"
  #    แต่ /rrr พบว่า **ไม่มีอะไรเรียกมันเลย** — grep เจอแต่ prose ⇒ มันจะเสื่อมด้วยวิธีเดียวกันเป๊ะ
  #    กับสิ่งที่มันถูกสร้างมาแทน · defect shape ของ D15.8 เอง สูงขึ้นอีกชั้น สร้างในชั่วโมงเดียวกัน
  #    ⇒ ต่อสายมาที่นี่ เพราะ CLAUDE.md สั่งให้ `รัน selftest ก่อนเชื่อสคริปต์`
  echo "18) census-selftest (3 แขน — negative control / positive / regression)"
  local _cs="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/census-selftest.sh"
  if [ -x "$_cs" ]; then
    if bash "$_cs" >/dev/null 2>&1; then echo "   ✓ census 3/3"
    else echo "   ✗ census-selftest ตก — รัน $_cs เพื่อดูว่าแขนไหน"; fail=1; fi
  else
    echo "   (ไม่พบ census-selftest.sh ข้าง verify-check.sh — ข้าม ไม่นับผ่าน/ตก)"
  fi

  # 🩹 2026-08-07 — ด่านกันข้อความที่ *พังก่อนถึง relay* (backtick ถูกรันใน "...")
  #    ต้องล้มได้ทั้งสองทิศ ไม่งั้นเป็น echo: (ก) ข้อความเปื้อน error ต้องถูกปฏิเสธ
  #    (ข) ข้อความสะอาดต้อง **ไม่** ถูกปฏิเสธด้วยเหตุผลนี้ — ใช้ target มั่วเพื่อให้มันไปตกที่
  #    ด่านอื่นแทน ⇒ พิสูจน์ว่าด่านเนื้อหา *ไม่ได้* ยิง ไม่ใช่แค่ว่า rc ไม่เป็น 0
  echo "19) relay: ข้อความที่มีร่องรอย shell error ต้องถูกปฏิเสธ · ข้อความสะอาดต้องผ่านด่านนี้ไป"
  local _dirty _clean
  _dirty=$(relay "18-holmes:holmes-oracle.0" \
            "x /bin/bash: line 1: syntax error near unexpected token y" 2>&1)
  _clean=$(relay "vc-selftest-no-such-session:nope.0" "ข้อความปกติ ไม่มีร่องรอย" 2>&1)
  case "$_dirty" in
    *"ร่องรอย shell error"*) echo "   ✓ ข้อความเปื้อนถูกปฏิเสธ (ไม่ได้ส่งออก)" ;;
    *) echo "   ✗ ข้อความเปื้อน **ไม่** ถูกปฏิเสธ — ด่านนี้ไม่ทำงาน"; fail=1 ;;
  esac
  case "$_clean" in
    *"ร่องรอย shell error"*)
      echo "   ✗ ข้อความสะอาดถูกปฏิเสธด้วยด่านเนื้อหา — false positive"; fail=1 ;;
    *"ไม่พบ session"*) echo "   ✓ ข้อความสะอาดผ่านด่านเนื้อหา (ไปตกที่ด่าน target ตามคาด)" ;;
    *) echo "   ✗ ข้อความสะอาดตกด้วยเหตุที่คาดไม่ถึง — อ่าน: $_clean"; fail=1 ;;
  esac

  # 🔴 2026-08-08 — ข้อนี้เกิดจากทีมของ holmes ค้าง **5 จาก 6 pane รวม lead ของทีมเอง**
  #    โดยที่ enginecheck ตอบ ✅ PASS ให้ alias ที่จะค้างแน่นอน `[verified: permstall จริง]`
  #    เทสต์นี้ต้อง **ตกได้สองทิศ** ไม่งั้นมันเป็น echo:
  #      ทิศ ก — alias ไม่มี bypass แล้วบอกว่า bypass  (ช่องเดิมที่เปิดอยู่ 4 วัน)
  #      ทิศ ข — alias มี bypass แล้วบอกว่า ask        (false alarm ที่จะทำให้คนเลิกอ่าน)
  echo "21) permmode: ต้องแยก alias ที่จะค้าง ออกจาก alias ที่ไม่ค้าง — ตกได้ทั้งสองทิศ"
  local _pmt _pmf
  # ทิศ ก: ของจริงที่พาทีม holmes ค้าง — ตัวอักษรตรงจาก ps --ppid ของ pane ที่ค้างอยู่
  _pmt=$(_vc_permmode "claude --model claude-opus-5")
  case "$_pmt" in
    ask\|*) echo "   ✓ claude ไม่มีแฟลก → ask (เคสจริงของ holmes 2026-08-08)" ;;
    *) echo "   ✗ claude ไม่มีแฟลกแต่ไม่ได้ตอบ ask — ได้: $_pmt"; fail=1 ;;
  esac
  # ทิศ ข: alias ที่ใช้งานได้จริงต้องไม่ถูกกล่าวหา
  _pmf=$(_vc_permmode "BASH_ENV=x codex --model gpt-5.6-sol --ask-for-approval never --sandbox danger-full-access")
  case "$_pmf" in
    bypass\|*) echo "   ✓ codex --ask-for-approval never → bypass (ไม่ false alarm)" ;;
    *) echo "   ✗ codex ที่ bypass จริงถูกตอบเป็นอย่างอื่น — ได้: $_pmf"; fail=1 ;;
  esac
  # allowlist ≠ bypass — thclaws มี --allowed-tools แต่ไม่มี --accept-all ⇒ ยังค้างได้
  case "$(_vc_permmode 'thclaws --cli --allowed-tools "Read,Write"')" in
    allowlist\|*) echo "   ✓ thclaws --allowed-tools อย่างเดียว → allowlist ไม่ใช่ bypass" ;;
    *) echo "   ✗ allowlist ถูกนับเป็น bypass — คนละกลไก"; fail=1 ;;
  esac
  # 🔴 ทิศ "กล่าวหา" — codex ที่ไม่มีแฟลก **ไม่ได้แปลว่าจะถาม** ถ้า config.toml ตั้ง never ไว้
  #    ข้อนี้เกิดจาก probe ของจริง ไม่ใช่การอ่านเอกสาร (boot codex เปล่า → curl + เขียนนอก cwd
  #    → ทำให้โดยไม่ถาม) · ถ้าไม่มีแขนนี้ เครื่องมือจะตะโกนใส่ alias ที่ไม่มีปัญหา
  #    แล้วคนจะเลิกอ่านคำเตือน ซึ่งฆ่าเครื่องมือทั้งตัว
  local _pmcfg
  _pmcfg=$(_vc_permmode "CODEX_HOME=/tmp/vc-selftest-no-codex-home codex --model x")
  case "$_pmcfg" in
    ask\|*) echo "   ✓ codex ไม่มีแฟลก + ไม่มี config อ่านได้ → ask" ;;
    *) echo "   ✗ codex ที่ไม่มีทั้งแฟลกและ config ถูกตัดสินว่าผ่าน — ได้: $_pmcfg"; fail=1 ;;
  esac
  if grep -qE '^[[:space:]]*approval_policy[[:space:]]*=[[:space:]]*"never"' "$HOME/.codex/config.toml" 2>/dev/null; then
    case "$(_vc_permmode 'codex --model gpt-5.6-sol')" in
      bypass\|*) echo "   ✓ codex ไม่มีแฟลก แต่ config.toml=never → bypass (ไม่ false alarm)" ;;
      *) echo "   ✗ config บอก never แล้วยังตอบ ask — false alarm ทิศกล่าวหา"; fail=1 ;;
    esac
  else
    echo "   – ข้ามแขน config-aware: เครื่องนี้ไม่มี approval_policy=never (ไม่ใช่ผ่าน ไม่ใช่ตก)"
  fi
  # 🩹 loom 2026-08-08: `env -u VAR cmd` — `env` เป็นไบนารีจริง ตัวข้าม assignment ไม่ครอบ
  #    ⇒ เคยอ่าน engine เป็น `env` แล้วตอบ unknown ทั้งที่แฟลกอยู่ในบรรทัดเดียวกัน
  case "$(_vc_permmode 'env -u ANTHROPIC_API_KEY claude --model claude-opus-4-8 --dangerously-skip-permissions')" in
    bypass\|*) echo "   ✓ env -u NAME นำหน้า → อ่านทะลุถึง engine จริง (เคสของ loom)" ;;
    *) echo "   ✗ env prefix ยังบังไม่ให้เห็น engine จริง"; fail=1 ;;
  esac
  # ...แต่ต้องไม่กลายเป็นการเดา: มี env นำหน้าแล้วยังไม่มี bypass ต้องยังตอบ ask
  case "$(_vc_permmode 'env -u X claude --model claude-opus-5')" in
    ask\|*) echo "   ✓ env prefix + ไม่มีแฟลก → ยัง ask (ไม่ใช่ผ่านเพราะอ่านออกแล้ว)" ;;
    *) echo "   ✗ พออ่าน env ทะลุแล้วกลับตัดสินว่าผ่าน"; fail=1 ;;
  esac
  # 🧪 trust: exact-path ไม่สืบทอดจาก ancestor `[verified 2026-08-09 · 2 แขนจริงบน 0.147.0]`
  #    ทดสอบตัวอ่าน config ด้วย fixture ของตัวเอง — ไม่แตะ home จริงของใคร
  local _tcfg _td; _td=$(mktemp -d); mkdir -p "$_td/home"
  printf '[projects."/parent"]\ntrust_level = "trusted"\n' > "$_td/home/config.toml"
  machine=""
  _vc_trust_report probe "CODEX_HOME=$_td/home codex --model x" "/parent/child" >/dev/null
  case "$machine" in
    *"probe untrusted"*) echo "   ✓ trust: ancestor trusted ไม่ทำให้ลูกผ่าน (แขนที่ lucifer รันไม่ได้)" ;;
    *) echo "   ✗ trust: ตัวอ่านสืบทอดจาก ancestor ซึ่งขัดกับของจริง — ได้: $machine"; fail=1 ;;
  esac
  machine=""
  printf '[projects."/parent/child"]\ntrust_level = "trusted"\n' >> "$_td/home/config.toml"
  _vc_trust_report probe "CODEX_HOME=$_td/home codex --model x" "/parent/child" >/dev/null
  case "$machine" in
    *"probe trusted"*) echo "   ✓ trust: exact-path entry ทำให้ผ่าน (ไม่ false alarm)" ;;
    *) echo "   ✗ trust: มี entry เป๊ะแล้วยังบอกว่าไม่มี"; fail=1 ;;
  esac
  machine=""
  _vc_trust_report probe "CODEX_HOME=$_td/nonexistent codex --model x" "/parent/child" >/dev/null
  case "$machine" in
    *"probe unknown"*) echo "   ✓ trust: อ่าน config ไม่ได้ → unknown (ตอบไม่ได้ ≠ ผ่าน)" ;;
    *) echo "   ✗ trust: อ่านไม่ได้แล้วตัดสินว่าผ่าน"; fail=1 ;;
  esac
  rm -rf "$_td"; machine=""
  # 🎚️ tier: ต้องเตือนเมื่อทั้งทีมได้ tier เดียวกัน และ **ต้องเงียบเมื่อผสม**
  #    ถ้าเตือนตลอด มันคือป้ายประกาศ ไม่ใช่ด่าน — คนอ่านสองรอบก็เลิกอ่าน
  machine=""
  _vc_tier_report a "codex --model gpt-5.6" >/dev/null
  _vc_tier_report b "codex --model gpt-5.6" >/dev/null
  case "$(_vc_tier_summary "$machine")" in
    *"tier เดียวกันหมด"*) echo "   ✓ tier: ทั้งทีม tier เดียวกัน → เตือน" ;;
    *) echo "   ✗ tier: ทั้งทีมเหมือนกันแต่ไม่เตือน"; fail=1 ;;
  esac
  machine=""
  _vc_tier_report a "codex --model gpt-5.6" >/dev/null
  _vc_tier_report b "codex --model gpt-5.6-mini" >/dev/null
  case "$(_vc_tier_summary "$machine")" in
    *"tier เดียวกันหมด"*) echo "   ✗ tier: tier ผสมแล้วยังเตือน — false alarm"; fail=1 ;;
    *) echo "   ✓ tier: tier ผสม → เงียบ (ไม่ใช่ป้ายประกาศ)" ;;
  esac
  machine=""
  _vc_tier_report a "codex" >/dev/null
  case "$machine" in
    *"model=ambient effort=ambient"*) echo "   ✓ tier: ไม่ pin อะไรเลย → ambient (ไม่เดาว่าได้อะไร)" ;;
    *) echo "   ✗ tier: alias ที่ไม่ pin ถูกรายงานว่ามีค่า"; fail=1 ;;
  esac
  machine=""
  # 🩹 node shim: /proc คืน `node <path>/codex …` — index 1 คือ interpreter ไม่ใช่ engine
  #    เจอตอนกวาดฟลีตจริง ไม่ใช่ตอนอ่านโค้ด · fixture เดิมป้อน `codex` ตรง ๆ เสมอจึงไม่เคยโผล่
  case "$(_vc_permmode 'node /home/user/.npm-global/bin/codex --model x --ask-for-approval never')" in
    bypass\|*) echo "   ✓ node shim: อ่านทะลุถึง codex ไม่ใช่หยุดที่ node" ;;
    *) echo "   ✗ node shim: ยังอ่าน engine เป็น interpreter"; fail=1 ;;
  esac
  case "$(_vc_engine_basename 'node /home/user/.npm-global/bin/codex --model x')" in
    codex) echo "   ✓ engine basename: node <path>/codex → codex" ;;
    *) echo "   ✗ engine basename ผิด: $(_vc_engine_basename 'node /x/codex --model y')"; fail=1 ;;
  esac
  case "$(_vc_engine_basename 'codex --model x')" in
    codex) echo "   ✓ engine basename: รูปตรง ๆ ยังถูก (ไม่พัง regression)" ;;
    *) echo "   ✗ engine basename พังกับรูปตรง ๆ"; fail=1 ;;
  esac
  # 🩹 atlas 2026-08-09: ชื่อ process โปรแกรมตั้งเองได้ (`comm=codex-code-mode` 8 ตัวบนเครื่องนี้)
  #    ⇒ ตัวตนต้องมาจาก kernel (`/proc/<pid>/exe`) แต่ **ธง** ยังต้องมาจาก argv
  case "$(_vc_permmode 'codex-code-mode --ask-for-approval never' codex)" in
    bypass\|*) echo "   ✓ exe override: ชื่อแปลก + ธงถูก → bypass (ตัวตนจาก kernel · ธงจาก argv)" ;;
    *) echo "   ✗ exe override ไม่ถูกใช้"; fail=1 ;;
  esac
  # ⚠️ แขนนี้ผมเขียนหลวมรอบแรกจน `ask|*|bypass|*` แมตช์ทุกอย่าง = **ตกไม่ได้**
  #    ซึ่งเป็น scar ที่ไฟล์นี้ทั้งไฟล์เขียนถึง ("check ที่ทำให้ตกไม่ได้ คือ check ที่ตกไม่ได้")
  #    ⇒ บังคับให้ตกได้: ชี้ CODEX_HOME ไปที่ที่ไม่มี config ⇒ ไม่มีทั้งธงและ config ⇒ ต้อง ask
  case "$(_vc_permmode 'CODEX_HOME=/tmp/vc-no-such-home codex-code-mode --model x' codex)" in
    ask\|*) echo "   ✓ exe override ไม่ใช่ใบผ่าน — ไม่มีธง ไม่มี config ⇒ ยัง ask" ;;
    *) echo "   ✗ exe override กลายเป็นใบผ่าน"; fail=1 ;;
  esac
  # 🩹 _vc_engine_pid: ต้องหา engine เจอไม่ว่ามันอยู่ลึกกี่ชั้น และ **ต้องไม่หยุดที่ interpreter**
  #    เทสต์นี้ยิงกับ pane ของ **เซสชันนี้เอง** ⇒ เป็นข้อมูลจริง ไม่ใช่ fixture ที่ผมแต่ง
  local _selfpane _epid _eexe
  _selfpane=$(tmux display-message -p '#{pane_pid}' 2>/dev/null || true)
  if [ -n "${_selfpane:-}" ]; then
    _epid=$(_vc_engine_pid "$_selfpane" 2>/dev/null | cut -f1)
    _eexe=$(_vc_engine_pid "$_selfpane" 2>/dev/null | cut -f2)
    case "$_eexe" in
      */bin/node|/usr/bin/node|"") echo "   ✗ engine_pid หยุดที่ interpreter หรือหาไม่เจอ: [$_eexe]"; fail=1 ;;
      *codex*|*claude*|*opencode*|*thclaws*) echo "   ✓ engine_pid: เจอ engine จริงที่ความลึกใดก็ได้ (pid=$_epid)" ;;
      *) echo "   ✗ engine_pid คืน exe ที่ไม่ใช่ engine: $_eexe"; fail=1 ;;
    esac
  else
    echo "   – ข้าม engine_pid: ไม่ได้รันใน tmux (ไม่ใช่ผ่าน ไม่ใช่ตก)"
  fi
  # 🎯 placement: ตัวตรวจเชิงกลของ HALF-APPLICATION — ต้องตกได้ **สามทิศ**
  #    LEAKED (มีนอกภูมิภาค) · ABSENT (ไม่มีในภูมิภาค) · UNVERIFIED (หา anchor ไม่เจอ)
  #    ถ้าตกไม่ได้สักทิศ มันคือป้ายประกาศ ไม่ใช่ด่าน
  local _pf; _pf=$(mktemp)
  printf 'prose half\nRULE-X here in prose\n## REGION\nRULE-X here in region\nRULE-Y only here\n' > "$_pf"
  case "$(placement "$_pf" '^## REGION' 'RULE-X' 2>&1)" in
    *LEAKED*MISPLACED*|*MISPLACED*) echo "   ✓ placement: token ที่อยู่นอกภูมิภาคด้วย → LEAKED/MISPLACED" ;;
    *) echo "   ✗ placement: มีนอกภูมิภาคแต่ไม่จับ"; fail=1 ;;
  esac
  case "$(placement "$_pf" '^## REGION' 'RULE-Y' 2>&1)" in
    *"overall: PLACED"*) echo "   ✓ placement: token ที่อยู่เฉพาะในภูมิภาค → PLACED (ไม่ false alarm)" ;;
    *) echo "   ✗ placement: token ที่ถูกต้องถูกรายงานว่าผิด"; fail=1 ;;
  esac
  case "$(placement "$_pf" '^## REGION' 'RULE-Z' 2>&1)" in
    *ABSENT*) echo "   ✓ placement: token ที่ไม่มีเลย → ABSENT" ;;
    *) echo "   ✗ placement: ของที่ไม่มีถูกนับว่าผ่าน"; fail=1 ;;
  esac
  case "$(placement "$_pf" '^## NOPE' 'RULE-X' 2>&1)" in
    *UNVERIFIED*) echo "   ✓ placement: หา anchor ไม่เจอ → UNVERIFIED (ตอบไม่ได้ ≠ ผ่าน)" ;;
    *) echo "   ✗ placement: anchor หาย แล้วตัดสินว่าผ่าน"; fail=1 ;;
  esac
  rm -f "$_pf"
  # engine ที่ไม่รู้จัก ⇒ unknown ไม่ใช่ ok (กฎเดิมของไฟล์นี้: ตอบไม่ได้ ≠ ผ่าน)
  case "$(_vc_permmode 'some-future-cli --run')" in
    unknown\|*) echo "   ✓ engine ที่ไม่รู้จัก → unknown (ตอบไม่ได้ ≠ ผ่าน)" ;;
    *) echo "   ✗ engine ที่ไม่รู้จักถูกตัดสินว่าผ่าน"; fail=1 ;;
  esac

  # 🔌 2026-08-07 — copy-drift-check.sh (holmes) ตอบคำถามที่ผมถามค้างไว้: "อะไรจะเตือนเราครั้งหน้า"
  #    หลังจาก verify-check.sh สามก๊อป drift กันจน CLAUDE.md ชี้ไปที่ตัวที่อ่อนกว่า 6 verb
  #    **holmes เตือนเองว่าเครื่องมือของเขา "เขียนเสร็จก็นอนเฉย ๆ ไม่มีอะไรเรียกมัน"**
  #    — ซึ่งคือ D15.8 เป๊ะ ๆ (เครื่องมือที่สร้างมาแทนของที่เสื่อมเงียบ แล้วเสื่อมเงียบเอง)
  #    เขาจงใจไม่ wire ให้ เพราะเป็นการแก้ repo ผมตรง ๆ ⇒ **ผมตัดสินใจ wire ตรงนี้**
  #    ⚠️ ผมเป็นผู้ใช้ ไม่ใช่ผู้เขียน ⇒ selftest-author != claim-author สำหรับข้อนี้
  echo "20) copy-drift-check: สำเนาที่ deploy ด้วย cp ต้องตรง canonical (ตกได้จริง)"
  local _cd _root
  _root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)
  _cd="$_root/lab/copy-drift-check.sh"
  if [ -r "$_cd" ]; then
    local _tmp; _tmp=$(mktemp -d)
    printf 'same\n' > "$_tmp/canon"; printf 'same\n' > "$_tmp/mirror-ok"
    printf 'DIFFERENT\n' > "$_tmp/mirror-bad"
    # แขน ก: สำเนาตรง ⇒ ต้อง rc=0
    if bash "$_cd" "$_tmp/canon" "$_tmp/mirror-ok" >/dev/null 2>&1
      then echo "   ✓ สำเนาตรง → OK"
      else echo "   ✗ สำเนาตรงแต่รายงาน DRIFT — false positive"; fail=1; fi
    # แขน ข: สำเนาต่าง ⇒ ต้อง rc!=0  (ถ้าแขนนี้ผ่านไม่ได้ เครื่องมือเป็น echo)
    if bash "$_cd" "$_tmp/canon" "$_tmp/mirror-bad" >/dev/null 2>&1
      then echo "   ✗ สำเนาต่างแต่รายงานว่าตรง — เครื่องมือตกไม่ได้ ⇒ เป็น echo"; fail=1
      else echo "   ✓ สำเนาต่าง → DRIFT (ตกได้จริง)"; fi
    # ของจริง: สามก๊อปของ verify-check.sh เอง
    if bash "$_cd" "$_root/teams/scripts/verify-check.sh" \
         "$_root/../.claude/skills/oracle-team/scripts/verify-check.sh" \
         "$HOME/.claude/skills/oracle-team/scripts/verify-check.sh" >/dev/null 2>&1
      then echo "   ✓ verify-check.sh ทั้ง 3 ก๊อปตรงกัน"
      else echo "   ✗ verify-check.sh drift แล้ว — รัน $_cd เพื่อดูก๊อปไหน"; fail=1; fi
    rm -rf "$_tmp"
  else
    echo "   (ไม่พบ lab/copy-drift-check.sh — ข้าม ไม่นับผ่าน/ตก)"
  fi

  [ $fail -eq 0 ] && echo "SELFTEST OK" || { echo "SELFTEST FAILED"; return 1; }
}

# **สำคัญ**: dispatcher ต้องทำงาน *เฉพาะตอนถูกเรียกเป็นสคริปต์* เท่านั้น
# บั๊กจริง 2026-08-04: `bash -c 'source verify-check.sh; relay ... ' _ "<ข้อความ>"` →
# dispatcher เห็น $1 = ข้อความ → `unknown fn` → **`exit 2` ฆ่าเชลล์ก่อน relay จะได้รัน**
# เทสต์ Tier 1-2 ทั้งหมดมองไม่เห็น เพราะมัน source โดยไม่ส่ง positional arg
# ⇒ **เจอตอนใช้จริงครั้งแรก** — ซึ่งคือประเด็นทั้งหมดของ Tier 3
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then return 0 2>/dev/null || true; fi

# 🩹 2026-08-06 [clean-room tester] usage string และ case list เคย **แยกกันเขียน** ⇒ drift:
#    case รับ relay/enginelist/engineone/modelprobe แต่ usage ไม่ลิสต์ทั้งสี่ตัว
#    ⇒ คนที่ค้นหา verb จากตัวเครื่องมือเอง จะได้ลิสต์ที่**ไม่มีตัวที่เอกสารบอกให้ใช้**
#    ⇒ แหล่งความจริงเดียว + selftest 9) บังคับให้ทั้งสองตรงกันตลอดไป
#    (นี่คือรูปเดียวกับ `maw tmux --help` ที่ลิสต์มือแล้วตก `kill` — เราเพิ่งโดนมาเอง)
VERIFY_CHECK_VERBS="placement binexists procs procs_cmd alive bootprobe bootverify permstall unstick relay teamclosed teamresidue siblings twinfix enginereg enginelist engineone enginecheck modelprobe mawverb selftest"

verify_check_usage() {
  printf 'fn: %s\n' "$(printf '%s' "$VERIFY_CHECK_VERBS" | tr ' ' '|')"
  echo "  binexists <bin> · procs <bin> · procs_cmd <pattern> · alive <bin> · bootprobe '<cmd>' [s] [bin]"
  echo "  relay <session:window.pane> '<msg>' [--durable <slug>]  ·  teamclosed <team>"
  echo "  siblings <file> [root...] ← ไฟล์นี้มีฝาแฝดบนดิสก์ที่ยังไม่ได้แก้ไหม (ก่อน commit)"
  echo "  twinfix <fileA> <fileB>   ← ฝาแฝดคนละชื่อ: มี commit ที่ลงข้างเดียวไหม (diff ตอบไม่ได้)"
  echo "  teamresidue <team>     ← ทีมลงแล้วเหลืออะไร: systemd --user (อ่าน SUB ไม่ใช่ ACTIVE)"
  echo "                            + ~/.maw/fleet + git worktree — สามผิวที่ teamclosed ประกาศว่าไม่ตรวจ"
  echo "  enginereg <engine> [dir] · enginelist [dir] · engineone <role> <engine> [dir]"
  echo "  enginecheck <charter|team>  ·  modelprobe <alias> <dir>   ⚠ ใช้ quota จริง"
  echo "  bootverify <session>   ← หลัง spawn: pane boot ตรง engine ไหม + จอเป็นของ agent หรือ installer"
  echo "  permstall <session> [--watch [sec]]  ← **ระหว่างงาน**: worker ค้างอยู่บนคำถามไหม (อ่านอย่างเดียว)"
  echo "                            จับทั้ง permission prompt **และ** update/trust dialog ของ CLI"
  echo "                            bootverify ตอบ t=0 · permstall ตอบ t=ตอนนี้ — READY ตอน boot หมดอายุได้"
  echo "  unstick <session> [n]  ⚠ ส่ง Enter เข้า pane: เคลียร์คำสั่งที่ค้าง (ต้องมากกว่า 1 ครั้ง)"
  # 🩹 2026-08-08 [lucifer จับ] บรรทัดนี้เคยใช้ backtick ใน "..." ⇒ bash รัน `maw team <พิมพ์ผิด>`
  #    เป็น command substitution **ทุกครั้งที่พิมพ์ usage** ⇒ syntax error ลง stderr และ
  #    **เนื้อความหายไปจาก help** (ไม่ใช่แค่ noise — คำอธิบาย mawverb หายทั้งท่อน)
  #    ⇒ คลาสเดียวกับ scar `maw hey` backtick ของผมเอง **และผมเห็นมันวิ่งผ่านตอนรัน selftest
  #      ในเซสชันนี้แล้วปล่อยผ่าน** เพราะมันอยู่ท้าย output ที่ผมกำลังหาอย่างอื่นอยู่
  #    ⇒ ใช้ single-quote สำหรับบรรทัดที่มี backtick เสมอ
  echo '  mawverb <team-subcommand>  ← `maw team <พิมพ์ผิด>` คืน rc=0 + usage ลง stdout'
  echo "  placement <file> <region-anchor-regex> <token>...  ← กฎอยู่ในภูมิภาคที่บังคับ และไม่มีที่อื่น"
  echo "  selftest"
}

if [ -z "${1:-}" ]; then
  verify_check_usage
elif printf '%s\n' $VERIFY_CHECK_VERBS | grep -qxF -- "$1"; then
  "$@"
else
  echo "unknown fn: $1"; verify_check_usage; exit 2
fi
