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

  local out; out=$(maw hey "$target" "$msg" 2>&1); local rc=$?
  echo "$out" | head -1 | cut -c1-100
  if [ $rc -ne 0 ]; then echo "FAILED    maw hey exit=$rc — ยังไม่ถึง อย่าอ้างว่าส่งแล้ว"; return 1; fi
  case "$out" in *delivered*) ;; *) echo "SUSPECT   ไม่เห็นคำว่า delivered ใน output — อ่าน output เต็มก่อนสรุป"; return 1 ;; esac

  local eout; eout=$(maw send-enter "$target" 2>&1); local erc=$?
  [ $erc -ne 0 ] && { echo "FAILED    send-enter exit=$erc"; return 1; }

  if [ -n "$durable" ]; then
    local f="ψ/inbox/$(date +%Y-%m-%d_%H-%M)_codex-fanout_${slug}.md"
    { printf -- '---\nfrom: codex-fanout\nto: %s\ntimestamp: %s\nchannel: tmux + durable inbox\n---\n\n' \
        "$sess" "$(date -Iseconds)"; printf '%s\n' "$msg"; } > "$f"
    echo "DURABLE   $f"
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
teamclosed() {
  local t="${1:?usage: teamclosed <team-name>}"
  local unreachable="" found="" rc_open=0

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
    lout=$(maw team list 2>&1); lrc=$?
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
      echo "OPEN      $t  ยังอยู่ใน maw team list"
      printf '          %s\n' "$row"; return 1
    fi
  else
    unreachable="$unreachable maw(ไม่มีไบนารี)"
  fi

  # ── ผิว 3+4: ไดเรกทอรีค้าง 2 สโตร์ + charter (ทั้งคู่เทียบ CWD ยกเว้น tool store) ──
  # ⚠️ ไดเรกทอรี "ไม่มี" ≠ "ตรวจไม่ได้" — ไม่มี = ตรวจแล้วไม่เจอ ต้องไม่ดันไปเป็น UNKNOWN
  #    ไม่งั้นฟังก์ชันนี้จะตอบ UNKNOWN ตลอดกาลจาก repo ที่ไม่มี .maw/teams/ =
  #    **ตัวตรวจที่ไม่มีวันตอบ CLOSED ก็คือตัวตรวจที่ไม่มีใครเรียก** (รูปเดียวกับกฎที่ไม่มีใครอ่าน)
  #    ที่ "ตรวจไม่ได้" จริงมีอย่างเดียวคือ **ไบนารีหาย** — ผิวนั้นเงียบโดยไม่รู้ผล
  local ghosts=""
  [ -d "$HOME/.claude/teams/$t" ]    && ghosts="$ghosts ~/.claude/teams/$t"
  [ -d "ψ/memory/mailbox/teams/$t" ] && ghosts="$ghosts ψ/memory/mailbox/teams/$t"
  [ -f ".maw/teams/$t.yaml" ]        && ghosts="$ghosts .maw/teams/$t.yaml"

  if [ -n "$ghosts" ]; then
    echo "GHOST     $t  ไม่มี session และไม่อยู่ใน list แต่ยังมีของค้าง:$ghosts"
    echo "          (ย้ายเข้า archive ด้วย mv — ย้อนกลับได้ ต่างจาก delete)"
    return 1
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
  echo "teamclosed.scope: ตรวจ=tmux,list,store/vault · **ไม่ตรวจ**=git worktree/branch, ~/.maw/fleet, systemd/cron"
  echo "          ⇒ CLOSED = 'session ไม่อยู่แล้ว' **ไม่ใช่** 'เก็บกวาดครบ' — ดู references/teardown.md"
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
        echo "bootverify.pane: $w NOT-READY screen=cli-update-dialog · engine รันอยู่ · แก้: เคลียร์จอด้วยเลขที่เจาะจง (3=Skip) **ห้าม Enter เปล่า** จะกด 'Update now'"
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
    local msrc="flag-pinned"
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
      *"Update available!"*|*"Press enter to continue"*|*"1. Update now"*|*"trust this folder"*)
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
        printf '    ⚠️ WARN    engine "%s" ไม่ได้ลงทะเบียน — ตอนนี้ได้ของถูกโดยบังเอิญผ่าน default\n' "$engine"
        printf '               จะได้จริง: %s\n' "$probe"
        printf '               ไม่ pin: ผลขึ้นกับ *ชื่อ window* — `wake hermes -e claude` ได้ `hermes --yolo`\n'
        printf '               และ model ไม่ถูกกำหนดโดย charter ⇒ ใช้ alias ที่ pin model แทน\n'
        # ค่า verdict คงไว้แค่ PASS|FAIL|UNVERIFIED ตามที่ consumer ของ atlas grep
        # ⇒ WARN ถูกเข้ารหัสเป็น PASS + ฟิลด์ `pinned=no` แทนการเพิ่มค่าที่ 4 ที่จะทำ parse เขาพัง
        machine="${machine}enginecheck.member: $role PASS engine=$engine resolved=$probe pinned=no
"
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
        printf '               แก้: เพิ่ม "%s" ใน .maw/maw.config.<N>.json ที่เป็น**บรรพบุรุษของ %s**\n' "$engine" "$mdir"
        case "$mdir" in
          "$root"|"$root"/*) ;;
          *) printf '               ⚠️ path ของสมาชิกคนนี้อยู่**นอก repo** ⇒ layer ที่ %s/.maw/ **มองไม่เห็น**\n' "$root"
             printf '                  ต้องวาง layer ที่บรรพบุรุษของ path นั้น หรือใช้ worktree ใน repo\n' ;;
        esac
        machine="${machine}enginecheck.member: $role FAIL engine=$engine resolved=$probe
"
        fail=1
      fi
    else
      printf '    จะรันจริง  : %s\n' "$cmd"
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
  printf '%s\n' "$machine"
  # รวมสิ่งที่ **ผันแปรจริง** ต่อรอบ — ว่างเมื่อไม่มี ⇒ กฎของ atlas เป็นเท็จได้จริง
  local unv=""
  printf '%s\n' "$machine" | grep -q 'pinned=no' && unv="${unv}${unv:+,}unpinned-alias"
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
VERIFY_CHECK_VERBS="binexists procs procs_cmd alive bootprobe bootverify unstick relay teamclosed enginereg enginelist engineone enginecheck modelprobe selftest"

verify_check_usage() {
  printf 'fn: %s\n' "$(printf '%s' "$VERIFY_CHECK_VERBS" | tr ' ' '|')"
  echo "  binexists <bin> · procs <bin> · procs_cmd <pattern> · alive <bin> · bootprobe '<cmd>' [s] [bin]"
  echo "  relay <session:window.pane> '<msg>' [--durable <slug>]  ·  teamclosed <team>"
  echo "  enginereg <engine> [dir] · enginelist [dir] · engineone <role> <engine> [dir]"
  echo "  enginecheck <charter|team>  ·  modelprobe <alias> <dir>   ⚠ ใช้ quota จริง"
  echo "  bootverify <session>   ← หลัง spawn: pane boot ตรง engine ไหม + จอเป็นของ agent หรือ installer"
  echo "  unstick <session> [n]  ⚠ ส่ง Enter เข้า pane: เคลียร์คำสั่งที่ค้าง (ต้องมากกว่า 1 ครั้ง)"
  echo "  selftest"
}

if [ -z "${1:-}" ]; then
  verify_check_usage
elif printf '%s\n' $VERIFY_CHECK_VERBS | grep -qxF -- "$1"; then
  "$@"
else
  echo "unknown fn: $1"; verify_check_usage; exit 2
fi
