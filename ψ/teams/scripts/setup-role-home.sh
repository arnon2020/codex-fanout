#!/usr/bin/env bash
# setup-role-home.sh <role> [repo-root] — give a codex worker a CODEX_HOME whose skill root is
# THIS TEAM'S skills for that role, and nothing else.
#
# WHY THIS EXISTS ALONGSIDE setup-codex-home.sh:
#   setup-codex-home.sh seeds from the shared pool ~/.codex-team/<N>, which is EMPTY on this
#   machine [verified 2026-08-08: ls -A ~/.codex-team/ -> 0 entries]. Its `[ -d "$src" ]` guard
#   therefore skips every home, prints "⚠ skip", creates nothing, and exits 0. It also solves a
#   DIFFERENT problem (sqlite/lock isolation across oracles). This script solves capability:
#   what a worker can SEE.
#
# WHAT IT IS FOR [verified 2026-08-08 · codex 0.146.1 · gpt-5.6-sol · exit 0]:
#   $CODEX_HOME/skills/ is codex's ONLY skill root. Point it at one role's folder and that
#   worker's catalogue becomes exactly what the charter chose. Measured, not reasoned:
#   catalogue went 35 oracle skills -> 7, the role skill appeared, and the worker SELECTED it
#   unprompted ("I'm using the team-coder skill because...") and quoted a token that exists
#   nowhere else on this machine.
#
# THREE THINGS THAT FAIL QUIETLY — all three cost real time here:
#   1. CODEX_HOME under /tmp: codex refuses to create its PATH helper binaries and only WARNS,
#      then proceeds. Guarded below.
#   2. Nesting is <root>/<name>/SKILL.md. One directory off = zero skills, exit 0, no message.
#      Guarded below.
#   3. A pinned CODEX_HOME loses ~/.codex/config.toml — including `model` and
#      `model_reasoning_effort` (oracle-team/SKILL.md:1608). config.toml is COPIED, not skipped.
#
# WHY skills/ IS A REAL DIRECTORY OF SYMLINKS AND NOT ONE SYMLINK TO THE REPO
#   [verified 2026-08-08: codex wrote 616K into $CODEX_HOME/skills/.system/ on first boot —
#    imagegen, openai-docs, plugin-creator, skill-creator, skill-installer, review-agent]
#   The skill root is a directory codex WRITES TO. Symlink it straight at a git-tracked folder
#   and codex commits 616K of its own built-ins into your repo. So: skills/ belongs to the
#   private home, and each skill is linked in BY NAME. That also lets a role carry a couple of
#   universal skills alongside its own without copying anything.
#
# NOT ISOLATED, and it cannot be: those .system skills stay visible whatever you do. Isolation
#   of the skill ROOT is total; isolation of the CATALOGUE is not.
#
# Idempotent. Paths are $HOME-relative so this survives a path move and an owner handoff.

set -euo pipefail

ROLE="${1:?usage: setup-role-home.sh <role> [repo-root]}"
ROOT="${2:-$(git rev-parse --show-toplevel)}"
SRC="$HOME/.codex"                    # the live codex home we borrow credentials/config from
DEST="$HOME/.codex-fanout/$ROLE"      # this role's private home
SKILLS="$ROOT/ψ/teams/skills/$ROLE"   # the team's skills for this role — in git, one source

# ── guard 1: /tmp ────────────────────────────────────────────────────────────────────────────
case "$DEST" in
  /tmp/*|/var/tmp/*)
    echo "REFUSED   CODEX_HOME under a temp dir — codex declines to create its PATH helpers"
    echo "          and only WARNS, then proceeds. Pick a path under \$HOME."; exit 2 ;;
esac

# ── guard 2: the skills folder must contain <name>/SKILL.md, not SKILL.md ────────────────────
if [ ! -d "$SKILLS" ]; then
  echo "REFUSED   no skills folder for role '$ROLE' at: $SKILLS"; exit 2
fi
found=$(find "$SKILLS" -mindepth 2 -maxdepth 2 -name SKILL.md | wc -l)
if [ "$found" -eq 0 ]; then
  echo "REFUSED   $SKILLS has no <name>/SKILL.md inside it."
  echo "          codex nests as <root>/<name>/SKILL.md. A SKILL.md placed directly in the"
  echo "          root yields ZERO skills and exit 0 — the failure prints nothing."
  echo "          found instead:"; ls -A "$SKILLS" | sed 's/^/            /'; exit 2
fi

# ── build ────────────────────────────────────────────────────────────────────────────────────
mkdir -p "$DEST"

# symlinked: shared, never write-locked. auth.json is why the worker does not have to log in.
for item in auth.json prompts hooks.json; do
  [ -e "$SRC/$item" ] && ln -sfn "$SRC/$item" "$DEST/$item"
done

# copied: the worker owns these. config.toml carries model + reasoning effort — a pinned
# CODEX_HOME without it silently loses both.
for item in config.toml version.json installation_id models_cache.json; do
  [ -e "$SRC/$item" ] && [ ! -e "$DEST/$item" ] && cp "$SRC/$item" "$DEST/$item"
done

# ── 2026-08-09 · จุด seed: ล้าง trust ที่สืบทอดมาโดยไม่ตั้งใจ ────────────────
# `config.toml` ที่ copy มา พก `[projects."<path>"]` ของทั้งฟลีตติดมาด้วย · อันที่เป็นเรื่อง
# **ตอนนี้** คือ bare `[projects."/tmp"]` (มีอยู่จริง · mode 1777) — เหตุผลเต็ม ขอบเขต และ
# หลักฐาน ARM A/B อยู่ในหัวไฟล์ `seed-hygiene.sh` **ที่เดียว ไม่ก๊อปมาไว้ที่นี่**
# แหล่งเดียว ไม่ใช่ก๊อปสี่ที่ — ดูเหตุผลเต็มในหัวไฟล์ seed-hygiene.sh
"$(dirname -- "${BASH_SOURCE[0]}")/seed-hygiene.sh" "$DEST/config.toml" || true

# the whole point: skills/ is OURS, and each of the role's skills is linked in by name.
# A stale link from a previous run whose skill has since been renamed must go, or the worker
# keeps seeing a skill the charter no longer gives it.
if [ -e "$DEST/skills" ] && [ ! -d "$DEST/skills" ]; then rm -f "$DEST/skills"; fi
mkdir -p "$DEST/skills"
for link in "$DEST/skills"/*; do
  [ -L "$link" ] && rm -f "$link"
done
names=""
while IFS= read -r skilldir; do
  name=$(basename "$skilldir")
  ln -sfn "$skilldir" "$DEST/skills/$name"
  names="$names $name"
done < <(find "$SKILLS" -mindepth 2 -maxdepth 2 -name SKILL.md -printf '%h\n')

echo "✓ $DEST"
echo "  skills/ owned by the home; linked in by name:$names"
echo "         source: $SKILLS"
echo "  auth   -> $SRC/auth.json (symlink — no re-login)"
echo ""
echo "Register this in <repo>/.maw/maw.config.60.json under \"commands\", then run"
echo "verify-check.sh enginecheck <charter> before spawning:"
echo ""
echo "    \"codex-role-$ROLE\": \"CODEX_HOME=\$HOME/.codex-fanout/$ROLE codex --model gpt-5.6-sol --ask-for-approval never --sandbox danger-full-access\","
echo ""
echo "Verify with a live worker (NOT with --dry-run — that only echoes the charter back):"
echo ""
echo "    CODEX_HOME=\$HOME/.codex-fanout/$ROLE codex exec --model gpt-5.6-sol \\"
echo "      'List by name every skill you can see.' </dev/null"
echo ""
echo "  ⚠ the </dev/null is required. Without it codex exec prints"
echo "    'Reading additional input from stdin...' and hangs forever, even though the prompt"
echo "    was passed as an argument."
