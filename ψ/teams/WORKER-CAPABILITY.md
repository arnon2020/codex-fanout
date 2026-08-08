# Worker capability — where a team member's skills actually come from

`[all disk/binary facts verified 2026-08-08 · codex-cli 0.146.1 · opencode-ai · maw-rs a162427]`
**Scope of this file: the WORKER layer.** For which skill the *lead* runs, see `CLAUDE.md` §🧭.

> ⚠️ **This file was wrong for four hours on its first draft and is kept as a correction, not a
> clean sheet.** Draft 1 said *"opencode has no skill channel at all"* on the strength of one
> `find ~/.config/opencode -maxdepth 2`. That is the 08-01 defect — **verify one location,
> conclude for all locations** — committed in §1 of the very file that names the scar. opencode
> supports skills and reads **four** roots, one of which is `~/.claude/skills/`. Advisor caught it.
> ⇒ **"ไม่ได้ติดตั้ง" ≠ "ไม่มีอยู่"**, and the probe standard must be the same for every engine:
> I probed codex at the binary and opencode at a config directory, then compared the two answers
> as if they were the same measurement.

---

## The question this answers

*"skill ของ agent ในทีม และการพัฒนาความสามารถของ agent ในทีม"* — arnon, 2026-08-08.

---

## 1. Does codex read skills? — **yes, but its model may never be told** `[verified]`

⚠️ **Probe the right object.** `~/.npm-global/.../@openai/codex/bin/codex.js` is a **shim**:
`strings | grep -ci skill` → **0**, and `codex --help` lists no skills subcommand. Both are false
negatives. The real binary is `…/@openai/codex-linux-x64/vendor/x86_64-unknown-linux-musl/bin/codex`
→ **1013** `skill` strings: `$CODEX_HOME/skills/…`, `### Skill roots`, the `skills.list` /
`skills.read` contract with `{"authority":{"kind":"executor"}}`, `<skills_instructions>`,
`Failed to load environment skill at`.

🔴 **`include_skills_usage_instructions` is a per-model flag, and the models this repo boots have
it OFF.** `[verified: ~/.codex/models_cache.json]`

| model | skills usage instructions |
|---|---|
| **GPT-5.6-Sol** · Sol-WM · **Terra** · **Luna** | **`False`** |
| GPT-5.5 · GPT-5.4 · GPT-5.4-Mini · GPT-5.3-Codex-Spark | `True` |

`~/.codex/config.toml` sets `model = "gpt-5.6-sol"`, and the repo alias `codex-sol` boots
`--model gpt-5.6-sol`. ⇒ **Those workers have the skills on disk and are never told they exist.**
Installing a new skill for them changes nothing until the model changes or the instruction arrives
another way. **Not yet measured live** — the flag's exact effect is read from the cache, not
observed in a running worker.

⇒ Repo scar again: *`maw --version` proves which binary ran, not which source you read.* A
launcher shim is a different object from the program.

## 2. What each engine reads `[verified 2026-08-08]`

| engine | roots | on this machine |
|---|---|---|
| **codex** | `$CODEX_HOME/skills/` | **35 skills** at `~/.codex/skills/` (+`.system/`, `.trash/`) |
| **opencode** | `~/.claude/skills/` · `~/.agents/skills/` · `~/.config/opencode/skill` · `<repo>/.opencode/skills` | **auto-loads the lead's global inventory**; `~/.agents/skills/` has 1; this repo has no `.opencode/skills` — **atlas does**, ~10 |
| **claude** | `~/.claude/skills/` + `<repo>/.claude/skills/` | full lead inventory |

opencode's own embedded doc table:
`| External skills (auto-loaded) | ~/.claude/skills/<name>/SKILL.md, ~/.agents/skills/<name>/SKILL.md |`

⇒ 📌 **An opencode worker is not a skill-less worker — it silently inherits whatever the lead has
globally.** Corollary discovered too late: moving `codex-team` out of `~/.claude/skills/` earlier
today also removed it from every opencode member on this machine. That consequence was not known
when the move was made; it is recorded here rather than left to be rediscovered.

## 3. 🔴 Isolation and capability are currently a trade

**Already on record** — `oracle-team/SKILL.md:1599`: *"credential pool at `~/.codex-team/<N>` |
🔴 no-ops. `~/.codex-team/` is empty"*. Confirmed today: `ls -A ~/.codex-team/` → **0 entries**, no
`~/.codex-<oracle>/` home exists. `setup-codex-home.sh` reads from that pool, so its `[ -d "$src" ]`
guard makes it print `⚠ skip $i: … missing` and **do nothing**. It is not silent and it strips
nothing today.

**What is new here:** **no engine alias sets `CODEX_HOME`** (`.maw/maw.config.60.json`: 8 commands,
none mention it) and **the charter member schema has no `env:`** (`TeamCharterMember122` =
role/name/model/cwd/engine/target/prompt/worktree/worktree_opt_out/branch — TEACHING-LEDGER).
⇒ Every codex worker inherits the default `CODEX_HOME=~/.codex`, which is **why they have skills
at all**. `maw team preflight` reports the cost: `✗ CODEX_HOME isolation: lit-scout+corpus-builder
share /home/user/.codex` (field notes 08-04).

> ⚠️ **The failure is conditional, not automatic.** If someone seeds `~/.codex-team/$i` with
> `auth.json` but not `skills`, the per-item `[ -e "$src/$item" ]` test fails for `skills` alone
> and the isolated worker comes up **skill-less while every other check stays green**. Seed
> `skills` in the same change as the isolation fix, or point the symlink at `~/.codex`.

## 4. 🕳️ The gap: the inventory is an *oracle's*, not a *coder's*

`.arra-oracle-skills.json` — v26.7.16, installed **2026-07-17**, `"agent": "codex"`. What the
coders carry: `about-oracle` `awaken` `bampenpien` `bud` `calver` `oracle-title-forge`
`oracle-combine-blogs` `resonance` `who-are-you` `youtube-research` `watch-channel` `kien-thai` …
Coding-adjacent, generously counted: `code-to-blueprint`, `verification-gate-fail-closed`,
`arra-oracle-search`, `bank-to-arra`, `research-scoping-and-coverage`, `deep-research`.

**Nothing in the set is about being a coder on this team** — no dispatch contract, no done-criteria
format, no worktree/branch discipline, no report-back shape, no "what evidence must accompany a
DONE". Those rules exist in `ψ/teams/` on the **lead's** disk, where the worker cannot reach them.
Not a missing feature — a **distribution** failure, the class this repo already named: *ความรู้มี
พันธะเรื่องการกระจาย — การถือไว้เป็น defect แม้เนื้อหาจะถูก*.

Related: field notes 08-04 line 417 — this repo has **no tracked `AGENTS.md`**, the other thing
codex reads at cwd ⇒ a worker gets **zero** role and zero persona from the repo it works in.

## 5. ⚠️ What is NOT verified

All of the above is disk and binary. **No live worker has been observed loading or invoking a
skill.** On this repo's evidence ladder that is far below the top rung — *agent refers to the
content* is the only thing that proves a turn was entered. Probe before teaching any of it onward:
spawn one codex worker and one opencode worker, ask each to name a skill it can see, and require a
quote that appears only in that `SKILL.md`.

---

## Next moves, cheapest first

1. **Probe** — one codex + one opencode worker, level-4 evidence. §1–§2 are structural until then.
2. **Settle the model question before writing anything.** On `gpt-5.6-sol` the usage instructions
   are `False`; a new skill may be invisible. Either boot a `True` model for coders, or carry the
   contract in the dispatch text / `AGENTS.md` where the flag cannot gate it.
3. **Write the missing coder skill** — dispatch contract · done-criteria · worktree/branch
   discipline · report-back shape. Install to `~/.codex/skills/` **and** a root opencode reads.
4. **Add a tracked `AGENTS.md`** so role/persona survive with no skill install and no flag.
5. **Repair the seeder before using it** so isolation stops costing capability.
