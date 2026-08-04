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
    # 🩹 2026-08-04: `.gitignore` มี `ψ/*` ⇒ ไฟล์นี้ **ไม่เข้า git** ถ้าไม่ `-f`
    #    วันที่ผมเลิกใช้ `git add -f ψ/` ไฟล์ durable ตัวแรกหลังกฎใหม่ตกทันที **เงียบสนิท**
    #    `git commit` exit 0 · ledger เขียนว่า durable ครบ · ไม่มีอะไรเตือน
    #    ⇒ ไฟล์บนดิสก์อย่างเดียว = durable ต่อ session **ไม่ใช่ต่อประวัติ**
    if git rev-parse --git-dir >/dev/null 2>&1 && git check-ignore -q -- "$f" 2>/dev/null; then
      echo "WARN      $f ถูก .gitignore — ต้อง 'git add -f' ไม่งั้น durable แค่ต่อ session"
    fi
  fi
  echo "SENT      $target  [delivered · ยังไม่ยืนยันว่า agent รับเข้า turn]"
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
  echo "CLOSED    $t  ไม่มี tmux session · ไม่อยู่ใน list · ไม่มีของค้างใน store/vault/charter"
  echo "          [ขอบเขต: vault + charter อ่านจาก CWD ปัจจุบัน — ทีมของ oracle อื่นอยู่ใน repo เขา]"
  return 0
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
  binexists|procs|procs_cmd|alive|bootprobe|relay|teamclosed|selftest) "$@" ;;
  "") echo "fn: binexists <bin> | procs <bin> | procs_cmd <pattern> | alive <bin> | bootprobe '<cmd>' [s] [bin] | teamclosed <team> | selftest" ;;
  *) echo "unknown fn: $1"; exit 2 ;;
esac
