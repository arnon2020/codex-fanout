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

## 🔴 REFUTED BY LIVE PROBE — 2026-08-08, `PROBE-8F2A`

**The claim below that a `gpt-5.6-sol` worker "has the skills on disk and is never told they
exist" is FALSE.** A live codex worker on exactly that model **listed 45 skills by name** when
asked. `[verified: probe-1 @ 114-codex-fanout, codex 0.146.1, gpt-5.6-sol xhigh, own worktree]`

> `imagegen, openai-docs, plugin-creator, skill-creator, skill-installer, about-oracle,
> arra-oracle-search, awaken, bampenpien, bank-to-arra, bud, calver, code-to-blueprint,
> create-shortcut, deep-research, dig, find-skills, forward, github:gh-address-comments,
> github:gh-fix-ci, github:github, github:yeet, go, incubate, kien-thai, learn, …`

⇒ `include_skills_usage_instructions: False` **does not gate skill visibility.** What it *does*
gate is **unmeasured** — plausibly only the long "How to use skills" protocol preamble, while the
catalogue is listed regardless. **Do not replace one inference with another: it is now
`[unverified]`, not "harmless".**

⇒ 45 names > the 35 dirs in `~/.codex/skills/` ⇒ **plugins and `.system/` contribute skills too**
(`github:*`, `imagegen`, `skill-creator`). The skill surface is wider than the directory listing.

⇒ 🪞 **This is why the probe existed.** The flag reading was labelled a structural claim, shipped
in two commits, and used to argue *"settle the model question before writing anything."* That
advice was **wrong and would have cost a model migration nobody needed.** Reading a config field
correctly is not the same as knowing what the program does with it — the same defect as reading a
shim instead of the program, one level up: **right file, right value, invented consequence.**

The original reading, kept because the *fact* is still true and only the *conclusion* was wrong:

`include_skills_usage_instructions` is a per-model flag, and the models this repo boots have
it OFF. `[verified: ~/.codex/models_cache.json]`

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

## 5. Containment — keeping group-only skills out of main

arnon's requirement, narrowed by arnon himself to the one direction that matters:
*"แค่ไม่ให้ skill ที่ใช้เฉพาะกลุ่มไหลเข้า main ก็พอ"* — **group → main**, not main → group.
The reason is selection signal-to-noise, not storage: a bloated main makes the right skill
unpickable.

**Answer: nothing flows up, on either engine.** No mechanism in codex or opencode promotes a
project/group skill into `~/.claude/skills/`. Skills arrive in main exactly two ways, both
deliberate: **an installer puts them there**, or **someone symlinks them in**. ⇒ What arnon wants
is already guaranteed by construction. There is no hole to plug — only a discipline to hold:
**a skill born for a team never gets installed globally.**

`[scope of this absence claim: skill-root strings in both real binaries — codex reads only
$CODEX_HOME/skills; opencode reads 4 fixed roots. Neither exposes a promote/publish path. The
observed population of main is fully accounted for by install + symlink, below.]`

### But main is already crowded, and it was not leakage

`[verified 2026-08-08]` `~/.claude/skills/` = **53 real dirs + 25 symlinks = 78 entries**, and
**24 of the 25 symlinks point into one external collection**, `ghq/github.com/mattpocock/skills`:

`caveman` `diagnose` `edit-article` `git-guardrails-claude-code` `grill-me` `grill-with-docs`
`handoff` `improve-codebase-architecture` `migrate-to-shoehorn` `obsidian-vault` `prototype`
`review` `scaffold-exercises` `setup-matt-pocock-skills` `setup-pre-commit` `tdd` `to-issues`
`to-prd` `triage` `write-a-skill` `writing-beats` `writing-fragments` `writing-shape` `zoom-out`
(the 25th is `find-skills` → `~/.agents/skills/`).

⇒ **The bloat arnon predicted has already happened, and its cause is not the one this document
spent the day chasing.** It is one collection mounted wholesale, 24 deliberate acts. Some of it
is arguably universal for a coder (`tdd`, `triage`, `review`, `diagnose`); some is clearly not
(`obsidian-vault`, `writing-beats`, `migrate-to-shoehorn`). **Not this oracle's call — the owner
of those symlinks decides.**

### The design, collapsed

⚠️ **The 3-tier tree drawn earlier in this conversation was over-engineered for the stated
requirement.** Once the requirement is one-directional, per-role roots and the `skills/extraRoots`
alias machinery stop being necessary. Recorded rather than quietly dropped, because the smaller
answer only appeared *after* arnon narrowed the question — which is the useful lesson.

```
📁 <repo>/
├── ψ/teams/skills/ ........... skills born for the team — in git, one source
│   👁️ codex worker:   ~/.codex-<oracle>/N/skills ──symlink──▶ here
│   👁️ opencode:       <repo>/.opencode/skills/ (cwd-relative, picked up free)
│   🚫 never installed to ~/.claude/skills/  ← the whole rule
└── .claude/skills/ ........... lead only

🏠 ~/.claude/skills/ .......... universal only · shared by every oracle ·
                                cannot be trimmed unilaterally
```

| what | rule |
|---|---|
| **the one rule** | a skill born for a team lives in `<repo>/ψ/teams/skills/` and is **never installed globally** |
| **codex** | symlink `$CODEX_HOME/skills` → the team folder (per-worker home keeps sqlite isolated — `setup-codex-home.sh` already has `skills` in `SYMLINK_ITEMS`) |
| **opencode** | `<repo>/.opencode/skills/` — cwd-relative, no setup |
| **one decision, not ours** | the 24 `mattpocock` symlinks: keep, drop, or make repo-scoped |

### 🎯 If the team is all codex — which it usually is here

arnon, mid-thread: *"ลูกทีมเป็น codex จะทำอย่างไรล่ะ มันไม่ใช่ claude"*. Fair — most of §5 above is
framed around `~/.claude/skills/`, and **codex cannot see that directory at all.**

For a codex-only team the containment question is **already solved and always was**:

| | codex worker |
|---|---|
| `~/.claude/skills/` (54 + 25 symlinks) | **invisible** — not a root codex reads |
| the 24 `mattpocock` symlinks | **irrelevant** — cannot reach a codex worker |
| what *is* their "main" | **`~/.codex/skills/` — 35 skills**, seen by every codex worker today |
| why they see all 35 | `CODEX_HOME` is unset ⇒ default `~/.codex` ⇒ one shared main (§3) |

⇒ **Restating the requirement in codex's own terms**: *"main มีแค่ skill ที่ทุกคนจำเป็น"* means
trimming **`~/.codex/skills/`**, not `~/.claude/skills/`. And that directory is **far easier to
act on** — it is not the shared Claude Code root every oracle depends on, and its current 35 are
an oracle catalogue installed once on 2026-07-17 (§4), not something the fleet is relying on.

⇒ **The move for a codex team is a single lever**: give each worker a `CODEX_HOME` whose
`skills/` symlinks to `<repo>/ψ/teams/skills/<role>/`. That one change simultaneously
(a) fixes the SQLite collision, (b) gives per-role skill sets, and (c) makes what a worker can see
**exactly** what the charter chose — because `$CODEX_HOME/skills/` is codex's *only* skill root.
Nothing else can leak in, and nothing can leak out.

📌 **Unresolved, and it only affects the *other* direction** — whether opencode can be told to
skip its auto-loaded `~/.claude/skills/` root. `"skills": {` exists in its config schema; the
bundled/minified binary did not yield the semantics. **`[unresolved — not "no such option"]`**
Out of scope now that the requirement is group→main only; it returns if main→group ever matters.

## 5b. PROBE-8F2A — what the live worker actually did `[2026-08-08]`

Setup: `ψ/teams/probe-agentsmd.yaml` · 1 member · engine `codex-sol` → `codex --model gpt-5.6-sol`
· own worktree `agents/probe-agentsmd` off `main` · `maw team apply … --apply`.

**Three things the spawn path taught, before the answer even arrived:**

- `maw team up` takes a **team name, not a charter path**. `maw team apply <team.yaml> --apply` is
  the verb that reads a charter. `maw team up <path>` prints `charter not found` **and exits 0** —
  the lying-rc trap, again.
- `maw team preflight` earned its place: it caught **3 real blockers** (worktree dir absent,
  `.maw-engine` unreadable, and **no codex trust entry** for the worktree path in
  `~/.codex/config.toml`). All three would have produced a confusing half-boot.
- The window came up as **`probe-1-oracle`**, not `probe-1` — the repo's own golden rule, live.
  And `bootverify` caught the pane **sitting on the codex update dialog** with *"Update now"*
  highlighted. A blind Enter there runs `npm install -g` against the whole machine. Read the menu,
  send `2` (Skip). `relay()` also correctly **REFUSED** a target missing its `.pane`.

**The answer:**

1. **AGENTS.md is reachable and was quoted verbatim** — final line, exactly, including em-dash.
2. **Trap 2 quoted word-for-word**, markdown formatting and all.
3. **45 skills listed by name** (see the refutation above).

🔑 **Unprompted, it answered in the file's own format**: `1. Yes. [verified: sed -n '1,$p'
AGENTS.md → exit 0]` — the evidence label `AGENTS.md` defines, applied on its first turn without
being asked to. **That is the strongest evidence in this document that the file works.**

⚠️ **But the probe does not prove auto-load, and the question was mine to get right.** The worker
ran `git rev-parse --show-toplevel` and then `sed -n '1,$p' AGENTS.md` — **it went and read the
file because the question named it.** That proves *reachable and obeyed*, not *injected at session
start*. Asking "is there a file named AGENTS.md" **built the answer into the question**. The clean
test names no file: ask a team-rule question cold and see whether it answers or goes looking — and
it needs a **fresh** worker, because this one now has the whole file in context.

## 5c. PROBE-C4D1 — ✅ AGENTS.md **is** auto-injected `[verified 2026-08-08]`

The clean re-run PROBE-8F2A could not do. Fresh worker (`probe-2`, `gpt-5.6-sol`, own worktree,
`Context 0% used`), a question that **names no file**, and an explicit instruction: *answer only
from what is already in your context; do not read, open, list, grep or search any file; if you
would need to look something up, reply exactly `NEED-TO-LOOK`.*

| asked | answered |
|---|---|
| what must accompany a DONE report? | *"The command and its output (including exit code), test name and actual pass/fail line, and changed-file commit SHA"* |
| what happens to a claim with no label? | *"An unlabeled claim is read as `[unverified]`."* ← **verbatim** |
| which branch do PRs target? | *"Pull requests target alpha."* |

**No `NEED-TO-LOOK`. No command executed** — the transcript shows no `Ran …` line, and context went
0% → 2%, the cost of a reply, not of reading a 90-line file.

⇒ **codex injects `AGENTS.md` from the working directory at session start** — and, corrected
2026-08-08 by prism + a 5-arm re-probe here, **it walks UP to the git root and stops there.**

| cwd | `AGENTS.md` location | answer |
|---|---|---|
| subdirectory inside the repo | repo root | ✅ correct — walk-up works |
| the directory holding the file | there | ✅ correct |
| **a nested git root** | one level up, outside that git root | 🔴 `NEED-TO-LOOK` — **does not cross** |

⇒ 🔑 **A git worktree is its own git root**, so the main repo's `AGENTS.md` **never reaches a
worker in a worktree.** That is the mechanism behind ajfon's morning finding — his patch was
necessary, not precautionary — and it is why loom's and lucifer's render-into-every-worktree
designs were already right.

⚠️ **Two probe-design lessons from the same run.** My first question ("what do you do when a check
only goes green after a kept record is destroyed?") was answered correctly **and proves nothing** —
the model can produce that answer unaided. The usable question had an *arbitrary* answer (which
branch PRs target). And the control taught something unplanned: with no `AGENTS.md` anywhere, it did
**not** say `NEED-TO-LOOK` — it guessed `main`. ⇒ **A correct answer may not have come from the file
at all if the answer matches a common default. Pick a value that differs from the convention.** A worker knows the
team's rules **before it is told anything**. This is the one claim in this document that reached
the top of the evidence ladder by a probe designed not to give away its own answer.

⇒ **Consequence for the design in §5**: `AGENTS.md` is strictly stronger than a skill for anything
every member must obey — no install, no `CODEX_HOME`, no symlink, no model flag, and **no decision
by the worker about whether the rule applies**. A skill must be *selected*; `AGENTS.md` is simply
*present*. Reserve skills for what only some roles need, or for procedures too long to keep in a
file every worker carries on every turn.

## 5d. PROBE-9B7E — injection holds at 160 lines `[verified 2026-08-08]`

PROBE-C4D1 proved injection of a **90-line** file. `AGENTS.md` then grew to **160**. That proof
does not carry across a 78% change, so this re-probe asks only about sections added **after**
C4D1 — a correct answer proves injection at the new size *and* that the new prose is legible.

Fresh worker, `Context 0% used`, no file named, `NEED-TO-LOOK` offered. **4/4, no command run,
finished at 3%:**

- *"A new commit on your branch proves completion. A file appearing, your screen, or 'DONE' in your
  own message does not."*
- *"The check is broken because it can match its own command line and falsely report a hit."*
- *"Your instructions govern; a skill activating does not change the task."*
- *"No. The sandbox is not a reliable boundary; the worktree rule is the boundary."*

⇒ 📌 **A size claim needs its own probe.** "It worked before" is not evidence about a file that has
since changed — the same shape as `valid-if:` on a stale dependency. Re-probe on material growth.

## 6. ✅ CLOSED 2026-08-08 — a live worker loaded, selected, and used a role skill

> ⚠️ **What this section used to say was stale against §1 of this same file.** It read *"No live
> worker has been observed loading or invoking a skill"* — written before PROBE-8F2A, three
> sections above, watched a worker list 45 of them. **A document can go out of date against
> itself**, and nothing in the writing process catches it: each section was true when written, and
> §6 is the one a reader reaches last. Kept visible rather than silently overwritten.

**PROBE-R0LE, `[verified 2026-08-08 · codex 0.146.1 · gpt-5.6-sol · exit 0 · two runs]`**

`CODEX_HOME=$HOME/.codex-fanout/coder codex exec … </dev/null`, question naming no file:

| run | skill | what the worker did |
|---|---|---|
| 1 | throwaway, containing `RECEIPT-QX7K2` — `grep`-unique on this machine | quoted it verbatim |
| 2 | the real `team-coder` | answered *"a one-line restatement of the dispatch's done-criteria"* |

Both times it announced the selection itself, unprompted: *"I'm using the `team-coder` skill
because…"* — then read it. **The catalogue swapped**: 35 oracle skills gone, the role's skill
present. `auth.json` as a symlink meant no re-login.

⇒ 🔑 **This is rung 4 for the skill channel** — not "the file is reachable" but "the worker chose
it and answered out of it". It also settles §1's leftover: on `gpt-5.6-sol`, with
`include_skills_usage_instructions: False`, **a newly installed skill is both visible and usable.**

> 🔴 **RETRACTED SAME DAY, and the retraction is the finding.** `[lucifer, 2026-08-08]`
> "the worker chose it" was written as a general property. **Both runs had a catalogue of exactly
> one skill.** lucifer holds a contradicting measurement of his own — *"workers inherit
> `~/.codex/skills` but never invoke a skill by topic match; the name must be called in the role
> contract"* `[his, 2026-08-05, rechecked against codex 0.146.1 today]`.
>
> The two may not conflict at all: **the hypothesis is that catalogue size is the variable** —
> 35 skills → no selection, 1–2 scoped to the role → selection. Neither of us has measured it.
> ⇒ If true, the conclusion is **stronger** than what was written: trimming the catalogue is not
> hygiene, it is the *precondition* for selection working at all — and loading a worker with many
> skills makes it use fewer, not more. If false, the name must be called in the dispatch every
> time, and a per-role `CODEX_HOME` buys cleanliness only.
> ⇒ **A single arm cannot isolate the variable.** lucifer's two-arm design (large catalogue vs
> role-scoped, same question, same protocol) is the correct test; mine was one arm read as if it
> were two. Sent to all 7 as `[unconfirmed]`, not only to the one who objected.
> ⇒ 🪞 This is the repo's own scar — *verify one property → conclude for all* — committed **inside
> the paragraph that ships the proof**, in a packet that warns other people about that scar.
>
> 🔬 **NARROWED SAME DAY BY tars** `[his measurement, 2026-08-08, live codex exec]` — his
> `researcher` had a catalogue of **7** (5 built-ins + `find-skills` + the role skill) and
> **selection still worked**: correct answers from both `researcher` and `scope_reviewer`, no file
> named. ⇒ **"n must be 1" is dead.** The boundary sits somewhere between 7 and 35, *or the
> variable is not size at all.* Still nobody's measurement isolates it — do not close it.

## 6b. 📮 What came back from the fleet — the parts that changed this document

Seven leads got the packet; six replied. Three findings altered what is written above.

**🔴 `AGENTS.md` is codex's carrier, not *the* carrier** `[loom, atlas, independently]`
This document and the packet both said "put team-wide rules in `AGENTS.md`" without ever naming
the engine that reads it. **claude does not read `AGENTS.md` — its carrier is `CLAUDE.md`.** In a
mixed-engine team the same rule set must be rendered into more than one carrier or the claude
members silently receive nothing. loom's split: `AGENTS.md` = shared rules only · `.brief.md` =
role text pointing at it · `CLAUDE.md` = both concatenated. **My omission, caught twice before I
noticed it once.**

**🔍 holmes's 2×2 beats every probe run here** `[verified: 6 exec calls, codex 0.146.1]`
Each worker was asked **its own** role's question (exact quote returned) **and the other role's**
(`NEED-TO-LOOK`). One matrix proves presence *and* isolation; every probe in §6 proves only
presence. He phrase-checked uniqueness with a narrow-scope `rg` first, and threw out his own first
design after realising it tested the wrong file. **Adopt the matrix; a single positive arm is the
weaker instrument.**

**✅ `setup-role-home.sh` corroborated by a second house** — holmes ran it for two roles and
compared `ambient-signature.sh` before/after: `codex_config_mtime` identical (`1786182939`), so
`~/.codex/config.toml` is copied, never mutated. The script's central safety claim is no longer
single-source.

**Also worth carrying:** loom found the *"`AGENTS.md` is a renamed brief"* failure **already
present in his own house** — a guard doing `cp "$prompt_file" "$cwd/AGENTS.md"` delivered the
shared rules **three times** per worker (brief + `AGENTS.md` + argv), and he measured **93% of all
brief bytes as one block repeated nine times**. He found it by reading his own code before writing
over it, not by being careful. ⇒ **Check for it before building anything new.**

### The four traps, every one found by running it

None of these is reachable by reading, and none of them fails loudly.

1. **codex writes 616K of its own built-ins into `$CODEX_HOME/skills/.system/` on first boot**
   (`imagegen`, `openai-docs`, `plugin-creator`, `skill-creator`, `skill-installer`,
   `review-agent`). ⇒ **the skill root is a directory codex writes to.** Symlink it straight at a
   git-tracked folder and codex commits its built-ins into the repo. `skills/` must belong to the
   private home, with each skill linked in **by name** — which also lets one role carry a few
   universal skills without copying anything. ⇒ 📌 **This corrects §5's diagram**, which drew the
   symlink at the root.
2. **`CODEX_HOME` under `/tmp`** — codex refuses to create its PATH helpers, **warns, and
   proceeds**.
3. **`codex exec` hangs forever without `</dev/null`** — prints *"Reading additional input from
   stdin…"* even though the prompt was passed as an argument. Cost 12 minutes and two timeouts.
4. **Nesting is `<root>/<name>/SKILL.md`** — one directory off gives zero skills at exit 0.
   `ln -sfn` onto an existing **real** directory silently links *inside* it. Caught by real usage
   in the first minute, which is the whole argument for real usage.

Plus, from `oracle-team/SKILL.md:1608` and confirmed here: **a pinned `CODEX_HOME` loses
`~/.codex/config.toml`**, including `model` and `model_reasoning_effort`. Copy it.

### What is still not isolable — and is not even stable

`.system/` and plugin skills stay visible whatever the charter says. **Isolation of the skill ROOT
is total; isolation of the CATALOGUE is not.** And the remainder moved **7 → 11** between two runs
of the same command (`github:*` appeared in the second). ⇒ **A measurement without a mechanism.**
Do not promise anyone a fixed catalogue; this is the claim in today's fan-out most likely to fall.

`ψ/teams/scripts/setup-role-home.sh` guards traps 2–4 and replaces `setup-codex-home.sh`, which
no-ops (§3). ⚠️ **Still owed: none of this has gone through `maw team up`** — it is `codex exec`
direct. The full spawn loop is unproven.

---

## Next moves, cheapest first

1. **Probe** — one codex + one opencode worker, level-4 evidence (quote a string that exists only
   in one `SKILL.md`). §1–§2 are structural claims until this runs, and it settles the §1 model
   flag in the same shot.
2. **Settle the model question before writing anything.** On `gpt-5.6-sol` the usage instructions
   are `False`; a new skill may be invisible. Either boot a `True` model for coders, or carry the
   contract in the dispatch text / `AGENTS.md` where the flag cannot gate it.
3. **Create `<repo>/ψ/teams/skills/`** and write the missing coder skill — dispatch contract ·
   done-criteria · worktree/branch discipline · report-back shape. **Do not install it globally**
   (§5). Point `$CODEX_HOME/skills` at it; opencode picks it up from `.opencode/skills/`.
4. **Add a tracked `AGENTS.md`** so role/persona survive with no skill install and no flag.
5. **Repair the seeder before using it** so isolation stops costing capability (§3).
6. **Owner's call, not ours** — the 24 `mattpocock` symlinks in main (§5).

---

## 📡 Banked to Arra — and the bank is not yet a distribution `[2026-08-08]`

Two entries written, split per `bank-to-arra` step 2 (the draft was one packet with a "Plus:" in
it — two findings, two categories, so two calls):

- `pattern_2026-08-08_codex-injects-agentsmd-from-cwd-at-session-start` (`category:agent-orchestration`)
- `learning_2026-08-08_codex-includeskillsusageinstructionsfalse-does` (`category:dev-tooling`)

Both return `success: true` with IDs, and both files exist on disk at
`~/.arra-oracle-v2/ψ/memory/learnings/` — **not** in this repo, because Arra banks into its own
vault regardless of the `project:` field.

🔴 **But neither is searchable yet — and my first proof of that was worthless.**

> ⚠️ **Correction, caught by arnon asking "reindex อะไรว่ะ".** I first showed "not findable" by
> searching **`PROBE-C4D1`** and getting `ftsMatches: 0`. **That token is not in the document** —
> `grep -c` → **0**. It only ever lived in the `verified_by` *parameter*, which does not land in the
> file body. **I searched for a word I never wrote, then blamed the index.** Then I proposed
> "reindex" as the fix — **there is no such verb**; Arra exposes 13 tools and none touches the
> index. A guessed remedy for a defect proven by a broken probe.
>
> **The conclusion survives on real evidence:** `cwd` appears in the entry's own *title*; `fts` for
> `cwd` returns 6 documents and **mine is not among them**. FTS itself is healthy — it returns hits
> for every probe. The new entries are simply absent from it.
>
> ⇒ 🪞 **Being accidentally right is worse than being wrong**, because nothing forces a recheck.
> The claim shipped in a commit and would have stood if one word in a summary had gone unquestioned.
The write response says `"embedding": "enqueued"` — async, and the FTS index has not taken them.

⇒ **`arra_learn` returning success means written, not findable.** That is the same shape as every
other lesson today — `delivered` is not received, a file on my disk is not a file on theirs, a
`git commit` is not distribution — arriving one layer further out. This repo already records the
root: `awaken/SKILL.md` step 5.2 claims *"auto-memory layer picks up new files automatically — no
separate API call needed"*, and that claim is **false**.

⇒ **Do not report "banked" as done.** Report it as written, and **re-probe with a distinctive
single token before claiming the fleet can find it.** Unresolved here: what actually
closes the gap. **Not** "reindex" — that verb does not exist. `[unverified]`, and this time
genuinely not guessed.

---

## 🪞 I ran this whole probe without opening my own manual `[arnon caught it, 2026-08-08]`

*"ลืมอ่าน skill หรือเปล่า"* — yes.

`oracle-team/SKILL.md` is 2,057 lines, lives in this repo, and **I declared it PRIMARY for team
lifecycle six commits earlier today.** It already documents every obstacle I then discovered by
trial and error: `charter not found` (`:1128`), that **`maw team up <team>` matches the FILE STEM,
not the `name:` inside the charter** (`:1382`), the codex update dialog (7 places), the codex trust
entry (4 places). I spawned three workers by guessing, holding the manual.

Same for `arra_search`: `CLAUDE.md` requires invoking `/search-arra` first. Five calls, zero
invocations.

⇒ **This is the defect this entire document is about, aimed at its author.** *ความรู้มีพันธะเรื่อง
การกระจาย — การถือไว้เป็น defect แม้เนื้อหาจะถูก.* I spent a day fixing "the worker never receives
the rules" while not reading the rules I wrote. **A skill that exists, is correct, is installed,
and is not opened is worth exactly as much as one that was never written.**

⇒ The recovery was not mine either: `preflight` caught the missing trust entry and `bootverify`
caught the pane sitting on the update dialog with *Update now* highlighted. Without those two the
blind Enter would have run `npm install -g` against the machine. **The guardrails worked; the
operator did not.**

⇒ 📌 Concrete: **before any `maw team` verb, open `oracle-team/SKILL.md` first.** Not "consider
it" — open it. The check on whether that happened is cheap: did a `Read`/`grep` of the skill appear
before the first `maw team` call?

## 7. ✅ SEAM CLOSED — `CODEX_HOME` เดินทางผ่าน `maw team apply → wake → pane → process` จริง

`[verified 2026-08-08 · spawn จริงผ่าน maw · วัดที่ `/proc/<pid>/environ` ไม่ใช่ `cmdline`]`

หนี้ที่ทั้งฟลีตประกาศไว้ทั้งวัน: ผม · tars · holmes · lucifer **รัน `codex exec` ตรงกันหมด**
ซึ่ง **ข้ามชั้น engine-resolution ของ `maw wake` ไปทั้งชั้น** ⇒ recipe ที่แจกไป 7 บ้าน
**พิสูจน์แล้วที่ปลายทาง แต่ไม่ได้พิสูจน์ที่ท่อ** · ปิดแล้ว:

| pid | อะไร | `CODEX_HOME` |
|---|---|---|
| pane pid | `-bash` | **ไม่มี** |
| ลูกของมัน | `node …/codex --model gpt-5.6-sol` | **`/home/user/.codex-fanout/coder`** ✅ |

⇒ **env prefix ใน alias ผูกกับ `codex` ไม่ใช่กับ shell** — shell ที่ถือ pane ไม่มีค่านี้
ใครวัดที่ pane pid จะสรุปว่า **ไม่ถึง** ทั้งที่ถึง ⇒ **วัดที่ลูก ไม่ใช่ที่ pane**

### สิ่งที่เส้นทางจริงสอน และ `codex exec` สอนไม่ได้

- **`maw team preflight <path>` จับ 3 blocker ก่อน spawn** — worktree ยังไม่มี · `.maw-engine`
  อ่านไม่ได้ · **ไม่มี codex trust entry** — และมันเช็ค trust ที่ **`~/.codex-fanout/coder/config.toml`
  คือ `CODEX_HOME` ของ role เอง ไม่ใช่ `~/.codex`** ⇒ maw อ่าน alias เจอจริง
  `preflight <ชื่อทีม>` **ล้มด้วย `charter read failed`** — ต้องให้ **path**
- 🔴 **`maw team down <team>` ล้ม**: `refuse missing target before teardown: …:seam-1`
  window จริงชื่อ **`seam-1-oracle`** ⇒ **golden rule เดิมอยู่ในตัว `down` เองด้วย**
- 🔴 **`teamclosed` ตอบ `CLOSED` ทั้งที่ window ยังรันอยู่** — มันหา **session ชื่อทีม**
  แต่ทีมนี้เกิดเป็น **window ในเซสชันที่มีอยู่แล้ว** ⇒ **มองไม่เห็นเลย**
  ⇒ ⚠️ **`teamclosed` เชื่อได้เฉพาะทีมที่มี session เป็นของตัวเอง** · ต้องเก็บด้วย `tmux kill-window`
- ⚠️ **update dialog โผล่ตอน boot จริง** (`0.146.1 → 0.147.0`) โดยมี **`1. Update now (runs
  npm install -g)` เป็นค่า default** · `bootverify` จับได้และตอบ **NOT-READY** ถูกต้อง
  **กด `2` และลูกศรไม่ขยับ selection** ⇒ ไม่เสี่ยง Enter · เก็บทีมแทน
  ⇒ **`codex exec` ไม่มี dialog นี้เลย** — อีกอย่างที่เส้นทางจริงเท่านั้นที่เจอ
