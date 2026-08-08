# Worker capability — where a team member's skills actually come from

`[all disk/binary facts verified 2026-08-08 · codex-cli 0.146.1 · maw-rs a162427]`
**Scope of this file: the WORKER layer.** For which skill the *lead* runs, see `CLAUDE.md` §🧭.

---

## The question this answers

*"skill ของ agent ในทีม และการพัฒนาความสามารถของ agent ในทีม"* — arnon, 2026-08-08.

The first honest answer is that **the lead's skills and the worker's skills are different
inventories on different disks, and nothing connects them.** `oracle-team` and `codex-team` live
in `~/.claude/skills/`, which **only Claude Code reads**. A codex worker cannot load either one,
ever. A charter cannot hand a worker a Claude Code skill.

---

## 1. Does codex read skills at all? — **yes** `[verified]`

⚠️ **Probe the right object.** The npm entry `~/.npm-global/.../@openai/codex/bin/codex.js` is a
**shim**: `strings | grep -ci skill` → **0**, and `codex --help` lists no skills subcommand. Both
readings are false negatives. The real binary is

```
~/.npm-global/lib/node_modules/@openai/codex/node_modules/@openai/codex-linux-x64/
  vendor/x86_64-unknown-linux-musl/bin/codex
```

→ **1013** `skill` strings, including `$CODEX_HOME/skills/.system/imagegen/...`, `### Skill roots`,
the `skills.list` / `skills.read` tool contract with `{"authority":{"kind":"executor"}}`, the
`<skills_instructions>` prompt tag, and `Failed to load environment skill at`.
`include_skills_usage_instructions` is a **per-model** field of `ModelInfo` (39 elements) — so
whether the usage preamble is injected is a *model* property, not a global one. **Not measured
per model here.**

⇒ This is the repo's own scar again — *`maw --version` proves which binary ran, not which source
you read.* A launcher shim is a different object from the program.

## 2. What workers actually get today

| engine | reads | today |
|---|---|---|
| **codex** | `$CODEX_HOME/skills/` | **37 skill dirs** at `~/.codex/skills/` |
| **opencode** | — | **no skills directory exists** `[find ~/.config/opencode -iname '*skill*' → 0]` — capability must go **in the dispatch text** |
| **claude** | `~/.claude/skills/` + repo `.claude/skills/` | the full lead inventory |

## 3. 🔴 The finding: isolation and capability are currently mutually exclusive

`setup-codex-home.sh` gives each worker a private `CODEX_HOME` and **symlinks `skills` in from
`~/.codex-team/$i`**. That pool is **empty** — `ls -A ~/.codex-team/` → **0 entries** — so the
script's own `[ -d "$src" ]` guard makes it **skip every iteration and do nothing**. No
`~/.codex-<oracle>/` home exists on this machine.

Meanwhile **no engine alias sets `CODEX_HOME`** (`.maw/maw.config.60.json`: 8 commands, none
mention it) and **the charter member schema has no `env:`** (`TeamCharterMember122` =
role/name/model/cwd/engine/target/prompt/worktree/worktree_opt_out/branch — TEACHING-LEDGER).

⇒ Every codex worker inherits the default `CODEX_HOME=~/.codex`. **They get all 37 skills only
because isolation is not in effect.** `maw team preflight` already reports the cost:
`✗ CODEX_HOME isolation: lit-scout+corpus-builder share /home/user/.codex` (field notes 08-04).

> **Fix isolation with the seeder as written and every worker loses every skill**, silently — the
> symlink loop would point at an empty pool. Seeding `~/.codex-team/$i/skills` must land in the
> same change as the isolation fix, or the fix is a capability regression wearing a green check.

## 4. 🕳️ The gap: the inventory is an *oracle's*, not a *coder's*

`.arra-oracle-skills.json` — v26.7.16, installed **2026-07-17**, `"agent": "codex"`, 27 listed
(37 on disk). What the coders carry: `about-oracle` `awaken` `bampenpien` `bud` `calver`
`oracle-title-forge` `oracle-combine-blogs` `resonance` `who-are-you` `youtube-research`
`watch-channel` `kien-thai` …

Coding-adjacent, generously counted: `code-to-blueprint`, `verification-gate-fail-closed`,
`arra-oracle-search`, `bank-to-arra`, `research-scoping-and-coverage`, `deep-research`.

**Nothing in the set is about being a coder on this team** — no dispatch contract, no
done-criteria format, no worktree/branch discipline, no report-back shape, no "what evidence must
accompany a DONE". Those rules exist in this repo, in `ψ/teams/`, on the **lead's** disk, where
the worker cannot reach them. That is the capability gap, and it is not a missing feature — it is
a **distribution** failure, the defect class this repo already named: *ความรู้มีพันธะเรื่องการ
กระจาย — การถือไว้เป็น defect แม้เนื้อหาจะถูก*.

Related: field notes 08-04 line 417 — this repo has **no tracked `AGENTS.md`**, the other thing
codex reads at cwd ⇒ a worker gets **zero** role and zero persona from the repo it works in.

## 5. ⚠️ What is NOT verified

Everything above is disk and binary. **No live worker has been observed loading or invoking a
skill.** On this repo's evidence ladder that is well below the top rung — *agent refers to the
content* is the only thing that proves a turn was entered. Before any of this is taught onward,
the probe is: spawn one codex worker, ask it to name a skill it can see, and require it to quote
something only that `SKILL.md` contains.

---

## Next moves, cheapest first

1. **Probe** — one worker, one question, level-4 evidence. Until then §1–§2 are structural claims.
2. **Write the missing coder skill** into `~/.codex/skills/` (dispatch contract · done-criteria ·
   worktree/branch discipline · report-back shape). This is the actual answer to "พัฒนาความ
   สามารถของ agent" — the workers are coders carrying an oracle's toolkit.
3. **Add a tracked `AGENTS.md`** so role/persona survive without a skill install.
4. **Repair the seeder before using it** — populate `~/.codex-team/$i` (or re-point the symlink at
   `~/.codex`) so isolation and capability stop being a trade.
5. **opencode has no skill channel at all** — for those members, capability lives in the dispatch
   text and nowhere else. Do not assume parity with codex.
