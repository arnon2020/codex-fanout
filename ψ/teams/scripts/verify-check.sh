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
alive() { [ "$(procs "$1")" -gt 0 ] && echo "RUNNING  $1 ($(procs "$1"))" || echo "NONE     $1"; }

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
# ⚠️ ข้อจำกัดที่ต้องพูดตรง ๆ: ตัวนี้ยืนยันได้แค่ว่า **เขียนลง pane สำเร็จ**
#    มันยัง **ยืนยันไม่ได้ว่า agent รับเข้า turn** — ยังต้องดูการตอบกลับที่มีเนื้อหา
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
  fi
  echo "SENT      $target  [delivered · ยังไม่ยืนยันว่า agent รับเข้า turn]"
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
  echo "6) pipefail trap: cmd | grep -q ต้องไม่ทำให้ผลกลายเป็นล้มเหลว"
  local rc6; echo hi | grep -q hi; rc6=$?
  [ "$rc6" = "0" ] || { echo "   ✗ grep -q rc=$rc6"; fail=1; }
  [ $fail -eq 0 ] && echo "SELFTEST OK" || { echo "SELFTEST FAILED"; return 1; }
}

# **สำคัญ**: dispatcher ต้องทำงาน *เฉพาะตอนถูกเรียกเป็นสคริปต์* เท่านั้น
# บั๊กจริง 2026-08-04: `bash -c 'source verify-check.sh; relay ... ' _ "<ข้อความ>"` →
# dispatcher เห็น $1 = ข้อความ → `unknown fn` → **`exit 2` ฆ่าเชลล์ก่อน relay จะได้รัน**
# เทสต์ Tier 1-2 ทั้งหมดมองไม่เห็น เพราะมัน source โดยไม่ส่ง positional arg
# ⇒ **เจอตอนใช้จริงครั้งแรก** — ซึ่งคือประเด็นทั้งหมดของ Tier 3
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then return 0 2>/dev/null || true; fi

case "${1:-}" in
  binexists|procs|procs_cmd|alive|bootprobe|relay|selftest) "$@" ;;
  "") echo "fn: binexists <bin> | procs <bin> | procs_cmd <pattern> | alive <bin> | bootprobe '<cmd>' [s] [bin] | selftest" ;;
  *) echo "unknown fn: $1"; exit 2 ;;
esac
