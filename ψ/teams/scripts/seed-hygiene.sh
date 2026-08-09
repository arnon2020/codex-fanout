#!/usr/bin/env bash
# seed-hygiene.sh <path-to-role-config.toml>
#
# ล้าง trust ที่ **สืบทอดมาโดยไม่ตั้งใจ** ตอน seed role home ด้วยการ copy `config.toml`
#
# ── ทำไมต้องมี ─────────────────────────────────────────────────────────────
# role home ถูก seed ด้วย `cp ~/.codex/config.toml` ⇒ พก `[projects."<path>"]`
# ของ **ทั้งฟลีต** ติดไปด้วย `[verified 2026-08-09 · lucifer วัด]` บ้านหนึ่งพก entry
# ของ tars 16 · atlas 3 · loom 1 · sage 1 ทั้งที่งานตัวเองไม่เคยแตะ path พวกนั้น
#
# 🔴 อันที่เป็นเรื่อง **ตอนนี้** ไม่ใช่เงื่อนไขอนาคต:
#      [projects."/tmp"]
#      trust_level = "trusted"
#    `/tmp` **มีอยู่จริง** และ **mode 1777 ใครก็เขียนได้** ⇒ codex ที่ถูกเรียกด้วย `cwd`
#    เป็น `/tmp` **เป๊ะ** จะ **ไม่ถาม trust** แล้วโหลด project-local config / hooks /
#    exec policies ให้ทันที ⇒ เป็นไดอะล็อกที่ทั้งฟลีตตกลงกันคืน 2026-08-08 ว่า
#    **ห้ามตอบโดยไม่อ่าน** — แต่ถูกตอบไว้ล่วงหน้าแล้ว สำหรับไดเรกทอรีที่ใครก็เดินเข้าไปได้
#
# ⚖️ **ตัดเฉพาะ bare `/tmp` — ไม่แตะ `/tmp/<อะไรก็ตาม>`**
#    เพราะ **trust เทียบ path เป๊ะ ไม่สืบทอดจาก ancestor**
#    `[verified 2026-08-09 · codex 0.147.0 · ARM A/B ตกได้สองทิศ · lucifer วัดแขนบวก ผมยิงแขนลบ]`
#      ARM A  trust แค่ `[projects."/home/user"]` · cwd เป็นลูก ⇒ **ยังขึ้น dialog**
#      ARM B  trust ที่ path ลูกเป๊ะ ⇒ **ไม่ขึ้น**
#    ⇒ entry `/tmp/<ชื่อ>` ที่ path หายไปแล้ว ต้องมีคนสร้างชื่อ **เป๊ะนั้น** ก่อนถึงมีผล
#      = **housekeeping ไม่ใช่ช่องโหว่** ⇒ อย่าให้สองระดับนี้แบกน้ำหนักเท่ากัน
#      (lucifer เป็นคนตัดสัญญาณเตือนที่ผมตั้งไว้สูงเกินลงมาให้ถูกขนาด — ด้วยหลักฐานของคืนเดียวกัน)
#
# ── ทำไมต้องอยู่ที่ *จุด seed* ไม่ใช่แค่ล้างต้นทาง ──────────────────────────
# ล้าง `~/.codex` อย่างเดียว **ไม่จบ**: สำเนาที่ seed ไปแล้วไม่เปลี่ยน และ role home
# ที่ถูกสร้าง**ใหม่**จาก home ที่ยังไม่ได้แก้ จะ **import กลับมา**
# ⇒ **เป็นวงจร ไม่ใช่ขยะกองเดียว** (lucifer ตั้งชื่อ 2026-08-09)
#
# ── ทำไมเป็นไฟล์เดียว ไม่ใช่ก๊อปสี่ที่ ─────────────────────────────────────
# repo นี้มีสคริปต์ที่ copy `config.toml` อยู่ ≥4 ตัว การฝัง logic เดียวกันสี่ที่คือ
# รูปเดิมที่เราเจียนกันมาทั้งคืน (`verify-check.sh` เคย drift สามก๊อป · pattern list ที่
# แก้ที่เดียวแล้วเหลืออีกสองที่) ⇒ **แหล่งเดียว ทุกตัวเรียก** และ `copy-drift-check.sh`
# เฝ้าสำเนาที่ deploy ไป
#
# ⚠️ ขอบเขต: ตัวนี้ **ไม่** ลบ entry ของบ้านอื่นที่ติดมา (`/home/user/ghq/.../<oracle>`)
#    — ผิดคน ผิดสิทธิ์ และไม่ใช่ hazard ที่วัดได้ · ตัวนี้ตอบเรื่องเดียวคือ bare `/tmp`
set -uo pipefail

cfg="${1:?usage: seed-hygiene.sh <role-config.toml>}"
[ -f "$cfg" ] || { echo "seed-hygiene: ไม่มีไฟล์ $cfg — ข้าม (ไม่ใช่ error)" >&2; exit 0; }

grep -q '^\[projects\."/tmp"\]' "$cfg" || exit 0     # ไม่มีอะไรต้องทำ

bak="$cfg.bak-seed-hygiene-$(date +%Y%m%d-%H%M%S)"
cp -p "$cfg" "$bak"

python3 - "$cfg" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
# บล็อกเริ่มที่หัวข้อ แล้วกินจนถึงหัวข้อถัดไป — จับ `/tmp` เป๊ะเท่านั้น
s2, n = re.compile(r'\n\[projects\."/tmp"\]\n(?:(?!\n\[).)*', re.S).subn('\n', s)
if n:
    open(p, 'w', encoding='utf-8').write(s2)
print(f'seed-hygiene: ตัด [projects."/tmp"] ออก {n} บล็อก จาก {p}', file=sys.stderr)
PY

# 🔒 ห้ามส่ง config ที่ parse ไม่ได้ให้ worker — ตกแล้วคืนสำรองทันที
if python3 -c 'import tomllib,sys; tomllib.load(open(sys.argv[1],"rb"))' "$cfg" 2>/dev/null; then
  rm -f "$bak"
  exit 0
fi
echo "seed-hygiene: TOML พังหลังแก้ — คืนไฟล์สำรองแล้ว ไม่แตะต่อ ($bak)" >&2
cp -p "$bak" "$cfg"
exit 1
