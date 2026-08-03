#!/usr/bin/env bash
# verify-check.sh — primitives ที่ "ตรวจแล้วไม่โกหก" สำหรับคำถาม 4 ข้อที่หลอกเราทั้งวัน 2026-08-03
#
# ทุกฟังก์ชันในนี้เกิดจากความพลาดจริง ไม่ใช่ทฤษฎี — ดู ψ/teams/VERIFY-THE-CHECK.md
#   binexists  ← config string ตรง แต่ symlink ชี้ไปที่ไม่มีไบนารี (thclaws)
#   procs      ← pgrep -f นับคำสั่งตรวจของตัวเอง (ตอบ 2 ทั้งที่เหลือ 0)
#   bootprobe  ← ทิ้ง stderr แล้วสรุปว่า engine พัง ทั้งที่มัน boot สำเร็จ
#   (ไม่มี kill helper โดยตั้งใจ — `pkill -f` ฆ่า probe ของตัวเองมาแล้ว)
#
# ใช้:  source ψ/teams/scripts/verify-check.sh   หรือ   bash verify-check.sh <fn> <args>
set -uo pipefail

# ── binexists <name-or-path> ────────────────────────────────────────────────
# ตอบว่า "เรียกได้จริงไหม" ไม่ใช่แค่ "มีชื่ออยู่ใน PATH ไหม"
# จับ dangling symlink ได้ ซึ่ง `command -v` เพียงอย่างเดียวจับไม่ได้
binexists() {
  local n="${1:?usage: binexists <name>}" p
  p=$(command -v -- "$n" 2>/dev/null) || { echo "MISSING   $n  (ไม่อยู่ใน PATH)"; return 1; }
  if [ ! -e "$p" ]; then
    echo "DANGLING  $n -> $p  (symlink ชี้ไปที่ไม่มีอยู่จริง)"; return 1
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
  echo "6b) procs_cmd ต้องไม่นับคำสั่งตรวจของตัวเอง"
  local n7; n7=$(procs_cmd "__selftest_unique_marker__")
  [ "$n7" = "0" ] || { echo "   ✗ procs_cmd นับได้ $n7 ทั้งที่ควรเป็น 0"; fail=1; }
  echo "6) pipefail trap: cmd | grep -q ต้องไม่ทำให้ผลกลายเป็นล้มเหลว"
  local rc6; echo hi | grep -q hi; rc6=$?
  [ "$rc6" = "0" ] || { echo "   ✗ grep -q rc=$rc6"; fail=1; }
  [ $fail -eq 0 ] && echo "SELFTEST OK" || { echo "SELFTEST FAILED"; return 1; }
}

case "${1:-}" in
  binexists|procs|procs_cmd|alive|bootprobe|selftest) "$@" ;;
  "") echo "fn: binexists <bin> | procs <bin> | procs_cmd <pattern> | alive <bin> | bootprobe '<cmd>' [s] [bin] | selftest" ;;
  *) echo "unknown fn: $1"; exit 2 ;;
esac
