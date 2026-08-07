#!/usr/bin/env bash
# ambient-signature.sh — stamp ค่า model/reasoning ที่ทุก census/enginecheck พึ่งโดยปริยาย
# แต่ไม่มีใครลงลายเซ็น จนกว่ามันจะขยับแล้วตัวเลขเก่ากลายเป็นวัดกับเป้าที่เคลื่อนแล้ว
#
# ปัญหาที่แก้: 2026-08-07 holmes รายงาน ~/.codex/config.toml = gpt-5.6-sol/xhigh
# ทั้งที่เคย verify ว่าเป็น gpt-5.5/high มาก่อนในวันเดียวกัน — มีคนอื่นเปลี่ยนซ้ำ ไม่รู้ใคร ไม่รู้เมื่อไหร่
# ⇒ ทุก census ตัวเลขวันนี้ วัดเทียบกับเป้าที่ขยับอย่างน้อยสองครั้งโดยไม่มีลายเซ็น
#
# read-only ล้วน — ไม่แก้ไฟล์ใดๆ แค่ hash + stamp เพื่อให้เปรียบเทียบรอบถัดไปได้
#
# ใช้: ambient-signature.sh              → พิมพ์ signature ปัจจุบัน
#      ambient-signature.sh --diff <old> → เทียบกับ signature เก่าที่บันทึกไว้

set -euo pipefail

CODEX_CFG="$HOME/.codex/config.toml"
CODEX_MEDIA_CFG="$HOME/.codex/state_5.sqlite"   # ไม่ hash ตัวนี้ ใหญ่เกิน — แค่เช็คว่ามีการเขียนล่าสุดเมื่อไหร่

sig() {
  local ts model effort maw_cfg_hash
  ts=$(date -Iseconds 2>/dev/null || date)

  if [ -f "$CODEX_CFG" ]; then
    model=$(/usr/bin/grep -m1 '^model' "$CODEX_CFG" 2>/dev/null | sed -E 's/^model[[:space:]]*=[[:space:]]*"([^"]*)".*/\1/')
    effort=$(/usr/bin/grep -m1 '^model_reasoning_effort' "$CODEX_CFG" 2>/dev/null | sed -E 's/.*=[[:space:]]*"([^"]*)".*/\1/')
    codex_mtime=$(stat -c '%Y' "$CODEX_CFG" 2>/dev/null || echo "?")
  else
    model="(no-file)"; effort="(no-file)"; codex_mtime="?"
  fi

  echo "ambient-signature @ $ts"
  echo "  host: $(hostname 2>/dev/null || echo '?')"
  echo "  codex.model: $model"
  echo "  codex.model_reasoning_effort: $effort"
  echo "  codex_config_mtime: $codex_mtime  ($(date -d "@$codex_mtime" -Iseconds 2>/dev/null || echo '?'))"

  echo "  maw_layers:"
  for f in ~/.config/maw/maw.config.*.json; do
    [ -e "$f" ] || continue
    h=$(sha256sum "$f" 2>/dev/null | cut -d' ' -f1 | cut -c1-12)
    m=$(stat -c '%Y' "$f" 2>/dev/null || echo "?")
    echo "    $(basename "$f"): sha256=${h}... mtime=$m"
  done
}

case "${1:-}" in
  --diff)
    old="${2:?ต้องระบุไฟล์ signature เก่า}"
    new=$(mktemp)
    sig > "$new"
    echo "=== เก่า ($old) ==="
    cat "$old"
    echo "=== ใหม่ (เดี๋ยวนี้) ==="
    cat "$new"
    echo "=== diff ==="
    diff "$old" "$new" && echo "(ไม่ต่างกัน)"
    rm -f "$new"
    ;;
  *)
    sig
    ;;
esac
