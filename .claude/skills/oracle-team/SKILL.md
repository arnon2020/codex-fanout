---
name: oracle-team
description: "Stand up a maw agent team with the engine and model each member is supposed to get — and prove they got it. Covers the full lifecycle: up (tmux), down (teardown), lead (orchestrate), status (peek), dispatch (headless codex exec). Gate 0 is the part most teams get wrong: a charter's `engine:` is only a lookup key into `commands.<name>` in a config layer visible from the WORKER's directory, and a charter's `model:` never reaches the pane — inert when `engine:` is present, and used as the engine key itself when `engine:` is absent, which misses with certainty. An unregistered name silently boots a different engine with exit 0. After spawning, `bootverify <session>` reads /proc and the pane to separate 'the right process is running' from 'the agent can actually receive a turn' — a CLI sitting on its own update or trust dialog looks identical to a ready agent from every cheaper check, and a blind Enter there presses whatever is highlighted. An alias carries a THIRD thing besides engine and model — permission mode — which no charter field can express: leave the bypass token out and every member boots correctly, passes every gate, then stalls on its first write asking a human who is not watching; `permstall <session>` is the read-only loop that catches it, because every other check in this file is measured at boot and readiness expires. Use for any of: '/oracle-team up|down|lead|status|dispatch', 'bring up the team', 'spawn coders', 'set up a codex team', 'is the team really down / what did the teardown leave behind', or whenever a member booted with the wrong engine/model, a charter's model: had no effect, workers keep asking for permission / approval and the team is not progressing, a pane is not responding to prompts, or you need per-member engine/model selection (codex vs claude, gpt vs opus) in one team. Path-agnostic — works from any oracle's repo."
argument-hint: "up [profile] [--only codex-N] | down [1,2,3] [--clean] | lead | status | dispatch [issue#] [--model X]"
---

# /oracle-team — Unified Codex Team Lifecycle

> ## ⚠️ Read this before running any verb
>
> **This file is two different things, with very different amounts of evidence behind them.**
>
> **Gate 0 + `scripts/verify-check.sh` — bind engine/model and prove it.** General. Applies to
> any team on any layout. Independently arrived at, verb-for-verb, by prism before they read
> this file, and reviewed by five oracles. Use it.
>
> **`down` (teardown) → [`references/teardown.md`](references/teardown.md) — read this one.**
> Every team leaves state behind; only the *kind* differs. Four oracles measured their own
> houses on 2026-08-06: worktrees and unmerged branches (lucifer 36, ajfon 5), stale fleet
> reservations (**130 of 143 reserved identities on this machine name sessions that no longer
> exist** — count identities, not files; one file holds up to 24), and systemd timers still
> firing at a cell that was frozen rather than torn down (prism). None of those four ships PRs.
>
> **`dispatch` / `lead` — the `gh` half stays in
> [`references/pr-workflow-verbs.md`](references/pr-workflow-verbs.md).** Those steps assume
> GitHub issues in and PRs out; **every verb in that file was defective the first time it was
> executed**, and the `gh` steps are still author-run only. Do not reach for them because the
> verb name sounds generic.
>
> | part | evidence |
> |---|---|
> | Gate 0 + `scripts/verify-check.sh` | reviewed by 5 oracles · independently reinvented by prism before reading this · detector validated at n=65 |
> | `up` | run 6× end to end. **Runs 5 and 6 found zero new defects** — but run 5 used a codex model this account cannot actually serve, so it proved booting, not working. Run 6 ran `modelprobe` first and is the one that means something |
> | `status` | exercised only inside `up` |
> | `down` | 🔴 broken on first execution. **Since then: run end-to-end against three live teams.** Per-step coverage lives in [`references/teardown.md`](references/teardown.md) — **that file is the only authority; do not restate a count here** |
> | `dispatch` / `lead` | 🔴 each run once, each broken. `dispatch`'s `codex exec` half has since completed real work; its GitHub-issue half and `lead`'s PR steps remain unrun |

---

> ## 🪞 The one pattern behind almost every defect in this skill
>
> `[named by lucifer, 2026-08-07, after two days of them]` Every wrong claim this skill has made
> was the same move: **report a signal that is easy to read as though it were the thing you
> wanted to know.**
>
> | what was reported | what it actually meant |
> |---|---|
> | `delivered` | written to the pane — **not** that anyone received it |
> | `RUNNING` | a process exists — **not** that the agent can take a turn |
> | `commit landed` | a producer claims something — **not** that it passed |
> | `branch ref` | where a ref points — **not** whether verification happened |
> | `status bar model` | what the engine chose — **not** what anyone pinned |
> | `CLOSED` | the session is gone — **not** that anything was cleaned up |
>
> lucifer's addition is the part worth keeping, because it explains why this keeps happening to
> careful people:
>
> > **มันไม่ได้เกิดจากความมักง่าย แต่เกิดจากสัญญาณที่ถูกมักวัดยากกว่าเสมอ**
> > *(it is not laziness — the correct signal is reliably the harder one to measure)*
>
> `delivered` is one line of output. Receipt needs the agent to quote your content back.
> A branch ref is one `rev-parse`. Verification status needs you to know a worktree exists and
> that a verifier detaches onto someone else's SHA. **The easy signal wins by default**, so the
> only defence is asking, deliberately, before you report:
>
> **"Is this the thing I want to know, or just the thing I can measure?"**
>
> The cost is not always yours to pay. Reading `branch ref` as *verified* produced a report that
> **accused another oracle's team of being slow while they were doing every step correctly.**
>
> ### 🪤 A second, separate class — not a variant of the one above
>
> `[atlas, 2026-08-07, after lucifer found a bug in a fix that shipped 20 minutes earlier]`
>
> The pattern above is about **propagation** — a claim that is wrong travels because the easy
> signal reads like the hard one. This one is about **verification that never had an independent
> judgment in the loop at all**:
>
> > **A selftest written by the same author, in the same sitting, as the code it tests proves
> > only that the code does what they meant. It cannot catch that what they meant was wrong.**
>
> Concretely: `DEAD-LAYER` v1 prescribed *"move that line"*, and selftest case 11 asserted the
> output contained the word **"move"**. Both came from the same head, ten minutes apart. The
> assertion **certified the defect**, and a green run was the reason it could survive. It took
> lucifer running it against real state — a key that resolves from a directory neither of us was
> standing in — to break it.
>
> ⇒ This is why every check in this skill carries a `🏷️` line naming **who measured it and from
> where**. A test's authorship is part of its evidence value. Green is not a verdict when the
> author of the test is the author of the claim.

> ## 🔤 `maw` and `maw team` disagree about what an unknown command is
>
> `[verified 2026-08-07 · c1e8797 · found by inventorying every command this skill tells you to run]`
>
> | you type | rc | message | stream |
> |---|---|---|---|
> | `maw zzz-not-a-verb` | **2** | `unknown command` | **stderr** |
> | `maw team zzz-nope` | **0** | the whole usage block | **stdout**, stderr empty |
>
> ⇒ **`maw team upp && echo OK` prints OK.** A guard written `maw team up … || fail` **can never
> fire on a typo** — the team is not created, nothing errors, and the script walks on as though it
> were. Same shape as the already-documented `maw team status <nonexistent> → rc=0`, but that was
> one verb; **this is every mistyped verb.**
>
> ```bash
> bash ~/.claude/skills/oracle-team/scripts/verify-check.sh mawverb up      # OK
> bash ~/.claude/skills/oracle-team/scripts/verify-check.sh mawverb upp     # ✗ NOSUCH, rc=1
> ```
>
> ✅ **Inventory result — every command this skill instructs you to run exists on `c1e8797`**:
> `team up|down|list|plan|preflight|resume|spawn|status` all present; top-level
> `config hey peek send-enter serve ls wake inbox tmux` all present. **No missing verbs.** The
> defect is not absence, it is that **absence would not have announced itself.**
>
> 🔑 The house rule this is the second instance of: **read rc *and* output for every command, and
> never carry a convention over from the command you just ran** — the same binary uses opposite
> conventions one level apart. Selftest case 16 pins both, and warns if `maw` ever changes them.

## QUICKSTART — never built a team before? Run exactly this.

This is a complete, working sequence, in order, with nothing assumed. It was run end-to-end
on 2026-08-06 and produced a live two-member team on two different models. Substitute the
five values in the first block; change nothing else until it works once.

**Step 0 — check the prerequisites. Each one fails silently if missing.**

```bash
command -v maw  >/dev/null || { echo "STOP: maw is not on PATH"; exit 1; }
command -v tmux >/dev/null || { echo "STOP: tmux is not on PATH"; exit 1; }
git rev-parse --show-toplevel >/dev/null 2>&1 \
  || { echo "STOP: not inside a git repository — see 'no repo?' below"; exit 1; }

# 🔴 …and "inside A repo" is not "inside YOUR repo". Decide deliberately, do not inherit cwd.
CAND=$(git rev-parse --show-toplevel)
printf 'about to build the team in: %s\n' "$CAND"
case "$CAND" in
  *"/.claude/worktrees/"*) echo "STOP: that is a worktree — pick the real project root or an empty dir"; exit 1 ;;
esac
[ "${ROOT:-}" = "$CAND" ] || { echo "STOP: set ROOT yourself to confirm this is the intended repo:  export ROOT=$CAND"; exit 1; }
```
Why this is a real step, not boilerplate: `ROOT=$(git rev-parse --show-toplevel)` outside a
repo sets `ROOT` to the **empty string**, and every path after it silently becomes
`/.maw/...`, `/agents/...`. Nothing errors until a confusing failure several steps later.

> 🔴 **The gate only caught *absence* of a repo until 2026-08-07 — never *the wrong repo*.**
> `[third clean-room tester]` Their cwd was a **worktree of a repository they had been forbidden
> to write to**. `git rev-parse --show-toplevel` succeeded, so Step 0 passed *loudly*, and
> `ROOT=$(...)` would have planted the charter, the config layer and every member directory
> inside it. The escape hatch existed — set `ROOT` yourself — but was reachable **only from the
> "no repo" branch**, which they never hit.
> ⇒ The prose asks *"no repo?"*; the failure they actually had was **"not *your* repo"**, and
> nothing checked it. Now `ROOT` must be stated explicitly, so inheriting a cwd is never enough.

> **No repo? `maw team up` still needs one.** `[verified — an earlier version of this callout
> said "everything else is identical", which was false]`
> ```
> $ maw team up <team>          # from a directory with no .git anywhere above it
> team spawn: repo root not found (.git)
> $ echo $?
> 0                             # ← rc=0. A gate checking the exit code calls this a success.
> ```
> A team can still live outside your oracle repo — `~/.maw-teams/<team>/<role>` is a normal
> layout — but that directory must itself be a git repo. Set `ROOT=~/.maw-teams/$TEAM`,
> `mkdir -p "$ROOT"`, **`git init "$ROOT"`**, and use it everywhere below; the config layer
> goes at `$ROOT/.maw/maw.config.60.json`. Trade-off: that layer is then in nobody's *shared*
> git, so it vanishes on a machine move and the symptom is a silently wrong engine, not an error.

> ⚠️ **`maw` returns rc=0 on several of its failures.** Three of the four ways this procedure
> can break exit 0 with the error only on stdout. Read the output; never branch on `$?` alone.

```bash
# ── things you choose ────────────────────────────────────────────────────────
TEAM=myteam-v1                       # unique across the machine
SESSION=$TEAM                        # tmux session name
ROOT=$(git rev-parse --show-toplevel) # your repo — or ~/.maw-teams/$TEAM, see above
A=${TEAM}-alpha                      # member 1 — MUST be prefixed with $TEAM (see step 3)
B=${TEAM}-beta                       # member 2
```

**Step 1 — register the engines you want, with the model baked in, then PROVE the model works.**

> 💸 **Run `modelprobe` on each new codex alias before Step 2, not after Step 6.** A model your
> account cannot serve boots fine and prints itself in the banner; only a real turn finds out.
> One probe per alias, once:
> ```bash
> bash ~/.claude/skills/oracle-team/scripts/verify-check.sh modelprobe <alias> "$ROOT"
> #   overall: PASS model-served=yes     ← proceed
> #   overall: FAIL model-served=no      ← fix the alias now, before you build a team on it
> ```
>
> ⚠️ **`modelprobe` is codex-only** — on any other engine it returns
> `UNVERIFIED reason=only-codex-supported-by-this-probe`. `[named 2026-08-07 by a clean-room
> tester]` The gap matters more than it sounds: **this skill tells you to mix engines precisely
> because that is how you get two different models** — so on a normal 2-member team, **half of it
> has no scripted model-served check at all**, and the skill never said so.
>
> **Proving a claude member's model, until something scripted exists** — two rungs, and they are
> not equivalent:
>
> | evidence | what it proves | what it does not |
> |---|---|---|
> | `/proc` cmdline via `bootverify` (`model=… flag-pinned`) | the flag you passed | ❌ nothing about what the account served — this is one rung above reading your own config back |
> | claude's own `/status` in the pane → `Model: sonnet (claude-sonnet-5)` | **the engine's own answer for that pane** | the account could still refuse mid-session |
> | **a real turn in that pane** — send `Reply with exactly: OK-<token>` and read `<token>` back (**command below — it was missing until 2026-08-07**) | **that pane, that account, right now** | nothing about the *alias* in isolation |
>
> ⇒ `modelprobe` proves **alias + account**, not that pane. `/status` + a real turn proves **that
> pane**, not the alias. Neither subsumes the other; a mixed team needs both halves done
> differently, and **the claude half is manual today.**
>
> ### ✉️ How to actually send that turn — the command this file forgot to include
>
> `[the third clean-room tester's #1 finding: "SKILL.md prescribes the evidence and gives no
> command … the top rung of the skill's own evidence ladder, unimplemented"]`
>
> ```bash
> W="${A}-oracle"                      # the member's window name
> T="=${SESSION}:${W}"                 # ALWAYS the "=" form — the bare one prefix-matches
> TOKEN="OK-$$"
> tmux send-keys -t "$T" -l "Reply with exactly: $TOKEN"   # -l = literal, no key-name parsing
> tmux send-keys -t "$T" Enter                              # submit as a separate call
> sleep 6
> tmux capture-pane -p -t "$T" | grep -F "$TOKEN" \
>   && echo "✓ that pane, that account, answered right now" \
>   || echo "✗ no answer yet — peek before concluding; codex may be holding it unsubmitted"
> ```
>
> **`-l` matters**: without it `tmux` interprets words like `Enter`, `Space` or `C-c` inside your
> text as keys. **Two calls matter**: some engines take the text and the newline separately, and
> codex in particular can sit on a filled composer showing `[Pasted Content N chars]` — which
> `bootverify` reports as `QUEUED-NOT-SUBMITTED`. If that appears, `unstick <session>` clears it.
>
> ⚠️ **This gap survived three rewrites because everyone testing already knew tmux.** The skill
> demanded evidence it never taught anyone to produce.
>
> 🔑 The tester's own summary is worth keeping: *"I did not count `bootverify`'s `/proc` line —
> that is the flag I passed, one rung above a config file."* **They refused their own easiest
> evidence.** That is the discipline this whole file is about, arrived at by someone who had read
> only this file.
>
> #### 🟢 opencode — the third engine, measured at last
>
> `[prism, 2026-08-07, from freshly respawned panes, passive read only — no keys sent]`
>
> opencode was the engine nobody had ever checked; this skill could not even say how to *ask* it.
> It turns out to be **the easiest of the three**:
>
> | question | answer |
> |---|---|
> | does it show its model? | **yes, passively, always** — the status bar reads `Build auto · GLM 5.2 Z.AI (GLM) · high`: **provider + model + effort on one line, no command needed** |
> | does `bootverify` read it correctly? | **yes** — `proc=opencode model=zai/glm-5.2 (flag-pinned) cmd=opencode --model zai/glm-5.2 --auto`, clean on both panes, **no `proc=?`** |
> | where does the model come from with no `--model`? | **UNVERIFIED** — prism's `~/.config/opencode/config.json` declares a provider and two models but **no top-level default**; `opencode models` lists `opencode/big-pickle` first, which *might* be a built-in default. **They refused to state it without running opencode bare, which was outside what I asked.** |
>
> ⇒ **Model evidence per engine, current state:**
> **codex** — scripted (`modelprobe`, spends a real turn) · **opencode** — passive status bar,
> no script needed · **claude** — manual only (`/status` + a real turn); `modelprobe` returns
> `UNVERIFIED reason=only-codex-supported-by-this-probe`.
>
> 🔑 Note the shape of prism's third answer: they had a plausible candidate (`opencode/big-pickle`)
> and **labelled it unverified rather than reporting it**, because confirming it needed a spawn
> nobody had authorised. *"ถือเป็น unverified ส่วนนี้ ไม่ใช่คำตอบ."* That is the same refusal atlas
> made with `CANNOT VERIFY`, in a house that had every incentive to just answer the question.
This is the only place a model can be expressed. Filename must be `maw.config.<digits>.json`
with a number above 50.

> 🔴 **`$ROOT/.maw` is correct only if your members live UNDER `$ROOT`.** The layer must sit
> at a **common ancestor of the member directories**, and nothing else. `[lucifer 2026-08-06 —
> their 10-role team runs from `~/.maw-teams/<team>/<role>/`, which sees only the global
> layer, so every role fell through to claude-opus-5 while the charter asked for codex-xhigh]`
>
> ```bash
> # members under $ROOT/agents/<role>      → LAYER_DIR="$ROOT/.maw"
> # members under ~/.maw-teams/<team>/<role> → LAYER_DIR=~/.maw-teams/<team>/.maw
> # members under ${STATE_ROOT}/<role>     → LAYER_DIR="${STATE_ROOT}/.maw"
> cd "<one member's directory>" && maw config sources   # ← your layer MUST appear
> ```
> Check it from a member's directory, not from where you are standing. See 0a for the table.

```bash
mkdir -p "$ROOT/.maw"       # ← or LAYER_DIR from the box above
cat > "$ROOT/.maw/maw.config.60.json" <<'JSON'
{ "commands": {
    "team-codex-hi": "codex --model <MODEL-A> --ask-for-approval never --sandbox danger-full-access",
    "team-codex-lo": "codex --model <MODEL-B> --ask-for-approval never --sandbox danger-full-access"
} }
JSON
```
> ## 🔴 An alias carries THREE things, not two — engine · model · **permission mode**
>
> `[verified 2026-08-08: --help of each binary on the machine + a live team that stalled]`
>
> This file taught engine and model for four days and **never named the third**. A charter has
> no field for permission either — so, exactly like model, **the only place it can be expressed
> is inside the alias command string.** Leave it out and the alias is still valid, still
> registered, still resolves to the right engine and the right model — and the worker stops at
> its **first write or first shell command** and waits for a human who is not watching.
>
> | engine | token that stops the asking | source |
> |---|---|---|
> | `codex` | `--ask-for-approval never` (or `--dangerously-bypass-approvals-and-sandbox`) | `codex --help` |
> | `claude` | `--dangerously-skip-permissions` (or `--permission-mode bypassPermissions`) | `claude --help` |
> | `opencode` | `--auto` — ⚠️ *"auto-approve permissions that are **not explicitly denied**"*, so a deny-list still stalls it | `opencode --help` |
> | `thclaws` | `--accept-all` (or `--permission-mode auto`) | `thclaws --help` |
>
> ⚠️ **The alias is not the only layer that can satisfy this — and that cuts both ways.**
> `[verified 2026-08-08: booted a bare `codex` with no flags, told it to curl and to write a
> file outside its cwd — it did both without asking, because `~/.codex/config.toml` sets
> `approval_policy = "never"` machine-wide]` So a codex alias with no bypass token may be
> perfectly fine here, and a checker that reads only the command string would cry wolf at it.
> `enginecheck` therefore reads `$CODEX_HOME/config.toml` (falling back to `~/.codex`) before
> calling a codex alias `ask`. ⚠️ But a persisted config **does not travel with the charter** —
> hand the charter to another machine and the protection is gone while the alias looks
> unchanged. Put the token in the alias anyway; treat the config as a reason not to panic, not
> as the answer.
>
> ⚠️ **`--allowed-tools` is not a bypass.** It is an allowlist — a different mechanism, and one
> that still blocks the moment the model reaches for a tool outside the list. An alias carrying
> only `--allowed-tools` reads as safe and is not.
>
> 🕳️ **Why `enginecheck` used to bless this.** It printed the resolved command — permission flag
> visibly absent — on the line directly above `✅ PASS`, and its declared out-of-scope list
> (`model-served, prompt-delivery, account-quota`) **did not contain the word permission**. So
> this was not a known-open gap; it was an unnamed dimension. It now prints a `perm=` verdict per
> member and emits `enginecheck.unverified: permission-not-bypassed` for gates to grep. **It
> warns rather than fails** — an ask-mode worker is a legitimate choice for a read-only probe or
> a supervised team; the tool's job is to make "this will stall" visible *before* spawn, not to
> decide for the team's owner.
>
> ⇒ 🪜 A **registered** alias is not a **working** alias. Add the row to Gate 0's question:
> *does each member get the engine, the model, **and the permission mode** it needs?*

> ## 🎚️ Gate 0's fourth question: does each role get a tier that FITS it?
>
> The other three ask *will the worker function*. This one asks *are you overpaying, and is the
> hard role underpowered* — and until 2026-08-09 nothing in this file asked it at all.
>
> `[verified 2026-08-09 · scripts/model-tier-census.py over 10 layer files, 61 aliases]`
> Of the 19 aliases that pin reasoning effort: **xhigh 9 · medium 8 · high 1 · low 1**. And
> **9 aliases pin neither model nor effort**, so they ride whatever `config.toml` happens to say.
>
> ⇒ 🔑 **A team where every role got the same tier usually means nobody chose.** It reads like
> diligence. It is the default leaking through — the role that reads files and reports pays what
> the role that designs the architecture pays, and a genuinely hard role can sit on `low` with
> nothing on screen to say so.
>
> `enginecheck` now prints `🎚️ tier model=… effort=…` per member and a team line:
> ```
> enginecheck.tiers: members=3 distinct-model=1 distinct-effort=1 all-ambient=0
>   🎚️ ทุก role ในทีมนี้ได้ tier เดียวกันหมด (3 สมาชิก)
> ```
> It stays **silent when tiers are mixed** — a warning that always fires is a sign, not a gate.
>
> ### What is measured here, and what is judgment — do not blur them
>
> **Measured:** where a model can be expressed (only inside the alias command string, same rule
> as `model:`); what each alias resolves to; `model_reasoning_effort` is an ordinal codex defines
> itself (`low < medium < high < xhigh`), so effort **is** comparable.
> **Not measured, and this file will not pretend otherwise:** that any model is "better" than
> another. No benchmark was run here. Rank effort; report model names.
>
> ### A default worth overriding deliberately
>
> Pick by the **shape of the role's work**, not its seniority in the org chart:
>
> | the role's work is… | argues for | why |
> |---|---|---|
> | reading, grepping, summarising, reporting — answer is *in* the material | smaller model, lower effort | the hard part is retrieval, not reasoning; extra effort buys re-derivation you already have |
> | mechanical transformation with a spec — rename, port, apply a known pattern | smaller model, low/medium | correctness is checkable by a test; failure is cheap and visible |
> | cross-file reasoning, "why is this broken", design under constraints | larger model, high/xhigh | the failure mode is a *plausible wrong answer*, which no cheap check catches |
> | adversarial review, verifying someone else's claim | larger model — and a **different family** if possible | a verifier that shares the producer's blind spot verifies nothing |
>
> ⚠️ **The tiering only pays off if the cheap roles are genuinely cheap work.** Dropping a role's
> tier without narrowing its job produces worse output at lower cost, which is not a saving. If
> you cannot say in one sentence what makes a role's work mechanical, it is not mechanical.
>
> ⚠️ **An `ambient` member is not "the default tier" — it is "whatever that home's config says
> today".** Someone editing an unrelated `config.toml` silently retiers the team. Pin it.

**Finding model names that actually work — one per engine, they are not interchangeable:**

**First: see what is already registered.** On a machine with an existing fleet, most of the
aliases you need may exist already — and nothing else in this doc tells you how to look:

```bash
bash ~/.claude/skills/oracle-team/scripts/verify-check.sh enginelist "$ROOT"
#   enginelist.count: 22
#   enginelist.engine: codex        model=-               cmd=… codex --ask-for-approval never …
#   enginelist.engine: claude-opus  model=claude-opus-5   cmd=claude --model claude-opus-5 …
```
`enginelist` is dir-aware — run it **from a path your member will use**. An alias with
`model=-` pins no model; it takes whatever the engine's own default is.

> ## 🔴 `enginecheck` used to give different verdicts for the same charter depending on where you stood — **fixed; here is why it happened**
>
> `[found by a clean-room tester · verdict-flip measured independently by ajfon and by this
> author · scope narrowed by lucifer and prism · 2026-08-06]`
>
> **The mechanism, which matters more than the rule** (ajfon's point: a reader who memorises
> "run it from the charter's repo" will still be caught by the next variant):
>
> 1. maw discovers config layers by **walking the ancestors of a directory** and merging every
>    `.maw/maw.config.<N>.json` it finds.
> 2. `enginecheck` used to derive that directory from **the caller's cwd** (git root of cwd,
>    falling back to cwd itself when you are not in a repo at all).
> 3. So a **project-level layer living in the charter's own repo is invisible from anywhere
>    else** — every engine resolves to the empty string, and the charter FAILs.
> 4. Relative `worktree:` paths compound it: from `/tmp` the member scope became
>    literally `/tmp/agents/<role>`.
>
> Measured, same charter, same absolute path passed every time:
>
> | | before fix | after fix |
> |---|---|---|
> | from the charter's repo | ✅ PASS | ✅ PASS |
> | from a member dir inside it | ✅ PASS | ✅ PASS |
> | from an unrelated repo | ❌ **FAIL** | ✅ PASS |
> | from `/tmp` | ❌ **FAIL** | ✅ PASS |
> | *unregistered engine, any cwd* | ❌ FAIL | ❌ **FAIL** (negative arm holds) |
>
> **Fixed**: `enginecheck` now anchors to the **charter's own directory**, so the verdict no
> longer depends on where the caller stands. It prints `enginecheck.anchor: charter-dir` to say
> so. The old behaviour told a tester `ENGINECHECK FAILED อย่า spawn จนกว่าจะแก้` — *"do not
> spawn until you fix it"* — about a charter that was already correct, naming a fix already in
> place.
>
> **Who was exposed, measured in their own houses:**
> - **Only charters with RELATIVE `worktree:`/`cwd:` are affected** (lucifer). Absolute paths are
>   completely immune: their `ws-parity-port` gave PASS 4/4 across four cwds. Their exposure was
>   **2 of 65 charters**; prism's was **0 of 8**, having deliberately used absolute paths since
>   porting, to dodge the `${VAR}`-does-not-expand trap.
> - **ajfon produced the verdict flip** that settles it: `ajfon-rag-bench.yaml`, whose aliases
>   live in a **project layer inside its own repo** — PASS from that repo, FAIL from `/tmp` and
>   from `$HOME`. They found it only because they went looking after being asked to re-check.
> - **lucifer could not produce a flip and said so** rather than assuming: their only layer is
>   user-level `maw.config.50.json`, visible from everywhere, so the scope moved but the verdict
>   never changed. **Recorded as "no evidence of a flip in that house", not "no flip."** That
>   distinction is why ajfon's case was worth hunting.
>
> ⚠️ **Wording corrected by lucifer**: it is the caller's **cwd** (git root of cwd, else cwd),
> not "the caller's git root" — from `/tmp`, which is no repo at all, it used `/tmp` directly.
>
> ### 🔴 `UNREGISTERED` used to mean two things, and the fix differs
>
> `[2026-08-07 · found by loom → measured by lucifer → confirmed both ways by atlas → selftest 11]`
>
> An engine name that does not resolve has **two** possible causes, and the old output collapsed
> them into one word:
>
> | cause | what the fix is | how it looked before |
> |---|---|---|
> | the key exists nowhere | **add** it to a numbered layer that is an ancestor of the member's path | `UNREGISTERED` |
> | the key exists — in a config file maw does not read | **move** that line into a layer maw reads | `UNREGISTERED` |
>
> On this machine **9 keys are invisible from a directory with no repo-local layer** — including
> `codex-xhigh`, which **57 of lucifer's charters request**. lucifer read their 64/65 FAIL as
> cause 1 and was about to add a key to 57 charters; the real job was far smaller. atlas quoted
> this tool's own `UNREGISTERED` into their T4463 reports several times the same day.
>
> ⚠️ **That sentence said "9 keys live only in the dead file" until an hour later, and it was
> wrong for 3 of the 9** — I measured from `/tmp`, where the only live layer is the user-level
> one, then stated the result as if it held from every vantage. Per-key, checked from 7 vantage
> points: **6 are (A)**; `claude-opus-headless` is **(B)** with the same command; **`codex-xhigh`
> and `codex-medium` are (B) carrying a *different command string* than the dead file's.** So
> "move the 9 lines" is safe only for the six — for those two, moving the dead file's version to
> user level hands a **different engine** to any house lacking its own layer. ⇒ An absence claim
> must carry the scope it searched, and **a bulk remedy needs a per-item classification first.**
>
> ⇒ 🔑 **A right conclusion reached by the wrong reason is not safe — the fix inherits the
> reason, not the conclusion.** And it is invisible, because *the verdict is identical either way.*
>
> `enginereg` now prints a `🔴 DEAD-LAYER` block naming the file and the line when — and only
> when — the key is genuinely present in a file absent from `maw config sources`. It decides
> "dead" by **asking maw which files it loads**, never by re-deriving the `maw.config.<N>.json`
> naming rule (a second copy of that rule would drift silently). If `maw config sources` cannot
> be read it prints **nothing** rather than guessing — a false accusation costs more than silence.
>
> ⚠️ **The wording of a check is part of the check.** This one travelled into other houses'
> reports unquestioned. Fixing it downstream would have meant every reader adding the caveat by
> hand, forever.
>
> #### 🔴 …and the first version of that fix had the same bug one level up
>
> `[lucifer, 2026-08-07, 20 minutes after it shipped — found by running it, not reading it]`
>
> v1 printed the DEAD-LAYER block **and prescribed the remedy: "move that line."** Correct for
> `codex-xhigh`. **Wrong for `codex-medium` asked from `/tmp`** — that key *is* in a file maw
> reads (`lucifer-oracle/.maw/maw.config.60.json`); that layer simply isn't visible from `/tmp`.
> Anyone following the advice would have edited the dead file and left the real problem — a
> layer scoped too narrowly — completely intact.
>
> | | what is true | correct fix |
> |---|---|---|
> | **(A)** | the key is **only** in the dead file | move the line into a layer maw reads |
> | **(B)** | the key is in the dead file **and** in a live layer this path cannot see | the dead file is a **decoy** — fix the layer's scope, or the member's path |
>
> The tool **knows** only "this key sits in a file that isn't loaded." It **cannot know** whether
> the key also lives in a live layer elsewhere — by definition, since that layer is invisible from
> here. v1 let it prescribe anyway.
>
> > lucifer: *"DEAD-LAYER was about to become the new carrier in place of UNREGISTERED — a label
> > that is more correct than before but still broader than the truth will still send people to
> > fix the wrong thing."*
>
> v2 **stops prescribing**. It names both cases and hands back the one command that separates
> them: `maw config explain commands.<engine>`, run from wherever you believe the key used to
> work — resolves anywhere ⇒ (B); `FINAL null` everywhere ⇒ (A).
>
> 🩹 **My own selftest was holding the bug in place.** Case 11 asserted the output contained the
> word *"move"* unconditionally — so it **certified the wrong behaviour**, and a green run was the
> reason the bug could survive. ⇒ 🔑 **A selftest written alongside the code by the same author
> checks that the code does what was intended; it cannot check whether the intent was right.**
> Someone outside has to run it against real state.
>
> ### Was *your* earlier result affected? Three reasons a verdict is cwd-invariant
>
> Between them the four houses covered every case, and only the last one can flip:
>
> | why it cannot flip | who | check |
> |---|---|---|
> | **paths are absolute** — nothing to resolve | prism (0/8 exposed), lucifer (63/65) | `grep -E '(worktree\|cwd):' charter` → all start with `/` |
> | **failure is global *unreadability*** — no layer maw reads has the key, so no cwd exists from which it resolves ⚠️ **this row said "registered in no layer anywhere" until 2026-08-07 and that was false** — atlas's engine (`codex-xhigh`) **is** registered, in the unnumbered `~/.config/maw/maw.config.json`, which maw never loads. Same verdict, different root cause, **different fix** (move the line, not invent a key) | atlas (T4463, FAIL 4/4) | ⚠️ **`enginereg` from two *unrelated* dirs has the same always-passes flaw as row 3** — `/tmp` and `/var` both say UNREGISTERED for `codex-xhigh`, which **is** registered in two repos. Run it from **the member's own directory** and read the `🔴 DEAD-LAYER` block |
> | ⚠️ **~~the only layer is user-level~~ — RETRACTED 2026-08-07, see below** | lucifer | ~~`maw config sources` from two unrelated dirs → identical~~ **this check can only ever confirm itself** |
> | **no `worktree:` declared at all** — every member falls back to `mdir="$root"`, so there is no relative path to resolve | tars (`research-team.charter.yaml`, same result from 3 dirs) | check (d) in Step 4b fires — ✅ **now proven on real data, both arms, same charter**, see below |
> | 🔴 **repo-scoped presence + relative paths** — the alias lives in a project layer inside the charter's repo | **ajfon's `ajfon-rag-bench`** | this is the shape that flips |
>
> atlas's framing is the one to keep: *"this particular charter is cwd-invariant because its
> failure mode is global-absence, not repo-scoped-presence"* — a narrower and checkable claim
> than "my result was fine." **(Read row 2's retraction above: "global absence" turned out to be
> "global unreadability" for atlas's key. The framing survives; the instance it was applied to
> did not.)**
>
> #### ✅ Check (d)'s positive arm — the longest-open gap in this file, now closed on real data
>
> `[verified 2026-08-07 · same charter, two revisions, check (d) run verbatim as shipped]`
>
> (d) — *every member needs `worktree:` or `cwd:`* — had **only a negative arm** for days: every
> charter available to test it declared paths, so it had never been observed to fire on anything
> real. tars's `research-team.charter.yaml` was the one known case, and it now supplies both arms:
>
> ```
> committed 5a8066a (2026-06-29)  → 🔴 FIRES — researcher, scope_reviewer, verifier, banker
> working tree today              → 🟢 silent
> ```
>
> Between those two revisions the roles were also renamed
> `researcher` → `research-team.charter-researcher` — **that is check (c)'s fleet-uniqueness
> prefix**, applied to the same file. So both Step 4b checks show a before and an after in real
> state, on someone else's charter, in their own repo. *(The remediation is uncommitted in tars's
> working tree; I am reporting what the file does, not asserting why they changed it — tars owns
> that.)*
>
> ⚠️ **What this cost me**: I had written into this table that tars's charter *"declares no
> `worktree:` anywhere"* in the present tense, and repeated it to them as a falsifiable
> prediction. **By the time I checked, it was false** — and running (d) against today's file
> returns 🟢, which reads like *the check is broken* rather than *the defect was fixed.*
> ⇒ 🔑 **A claim about another house's state is perishable, and a stale one fails in the
> direction that discredits your own tool.** Cite the revision, not the file.
>
> #### ⚠️ Row 3 is retracted, and the check attached to it could never have failed
>
> `[found by auditing this table, 2026-08-07 — not reported by anyone]`
>
> It claimed lucifer's verdict was cwd-invariant *because the only layer is user-level*, and
> offered this check: **`maw config sources` from two unrelated dirs → identical.**
>
> `lucifer-oracle` **has a project layer.** Measured:
>
> ```
> cd /tmp                → 50 user  /home/user/.config/maw/maw.config.50.json
> cd lucifer-oracle      → 50 user  …/maw.config.50.json
>                          60 project  …/lucifer-oracle/.maw/maw.config.60.json   ← not identical
> ```
>
> So the reason was false for the house credited with it. **And the check cannot detect that**:
> "two unrelated dirs" is satisfied by any two directories that happen to sit outside a repo with
> a layer — `/tmp` and `/var` agree perfectly and tell you nothing. It is a check whose passing
> condition is *choosing the right pair of directories*, which is the vantage-point artifact this
> whole section exists to warn about, **written into the section itself.**
>
> ⇒ **Replacement — the pair must include the place that matters, not two arbitrary places:**
>
> ```bash
> # one of the two dirs MUST be a member's own directory (mdir), not a neutral one
> for d in /tmp "$MEMBER_DIR"; do echo "--- $d"; ( cd "$d" && maw config sources ); done
> ```
>
> Identical output ⇒ the member sees nothing beyond user level ⇒ the verdict is cwd-invariant
> **for that member**. Different ⇒ a project layer is in play and the verdict must be taken from
> `mdir`, never from where you happen to be standing.
>
> 🔑 **A check that can only be satisfied is not a check.** Before shipping one, ask the third
> guard question — *if it fires, is what it accuses true?* — **and its inverse: can it fail at
> all, and what input makes it fail?** Row 3's had no such input.
>
> ⚠️ **The replacement has a hole at exactly the moment it is meant to run** `[atlas, 2026-08-07]`
> — at Gate 0 the member dirs **do not exist yet**, so you cannot `cd "$MEMBER_DIR"`. atlas's
> substitute is stronger than the literal test and is what to use pre-spawn:
>
> ```bash
> # 1. is there ANY layer anywhere in the tree the members will live under?
> find "$ROOT" -name 'maw.config.*.json' -print          # zero hits ⇒ nothing can appear below
> # 2. then the nearest existing ancestor is a sound proxy for what the member will see
> for d in /tmp "$ROOT"; do echo "--- $d"; ( cd "$d" && maw config sources ); done
> ```
>
> Zero hits from `find` is what licenses the proxy: nothing between `$ROOT` and an unborn member
> dir can introduce a layer that is already absent at `$ROOT`. **With hits, the proxy is void** —
> resolve per member after spawn instead. atlas insisted on recording the proxy reasoning rather
> than letting *"I ran the new command"* stand in for *"I tested the literal thing"*, which is
> the same conflation this section is about. (`enginereg` already walks to the nearest existing
> ancestor internally, so it needs no such workaround — this applies to raw `maw config sources`.)
>
> ✅ **The `find` gate is itself a check that can fail — and it failed on the real case.**
> lucifer ran it against the three roots they actually use:
>
> | root | hits | proxy |
> |---|---|---|
> | `lucifer-oracle` | **1** (`.maw/maw.config.60.json`) | ❌ **void** |
> | `maw-rs` | 0 | ✅ sound |
> | `~/.maw-teams/lucifer-fullstack-v1` | 0 | ✅ sound |
>
> **`lucifer-oracle` is the one root of the three where the proxy is void — and it is the one
> they measured n=65 from.** The gate would have stopped them *before* measuring rather than
> catching it a day later. That is what question 4 buys, stated as a passing input.
>
> > lucifer: *"I ran more commands from 11 vantage points and felt I had checked — but all 11
> > were places that **have** a layer. **The number of runs went up; the thing I specified was
> > still untested.** Selection bias does not go away by running more."*
>
> 🧭 **atlas's structural bound on the proxy — it is not symmetric with lucifer's error.**
> `discover_config_layers` walks **up** from cwd. A repo root is a **strict ancestor** of
> `coder-1` when `worktree:` is a path-relative child, so the member sees *everything the root
> sees plus anything between them* — and the tree-wide `find` rules out the "between." A root
> proxy therefore **cannot overstate** what the member will see. lucifer's error was the other
> shape: measuring from a point that is **not** an ancestor of the target, which can see layers
> that never apply to it. ⚠️ **The bound evaporates for out-of-tree member dirs** (e.g.
> evidence-cell's worktrees outside the repo) — a repo-root proxy gives them no guarantee at all.
>
> 🔴 **And lucifer, running the corrected pair, found their own n=65 was measured from a
> privileged vantage**: `lucifer-oracle` sees `50 + 60`, but the actual member dirs mostly see
> **`50` only** (`~/.maw-teams/lucifer-fullstack-v1/architect`, `maw-rs/agents/wsparity-coder`).
> **The direction matters more than the admission** — they measured from where *more* config is
> visible, so the error **under-reports failures**: ⇒ **64/65 FAIL is a floor, not an overestimate.**
> Two consequences they surfaced: `ws-parity-port` is **genuinely clean** (its members see layer
> 50, and `codex` really is in layer 50 — not borrowing lucifer's 60), while `lucifer-dev-v1`
> passes Gate 0b **only because its members sit inside lucifer's repo** — move them under
> `~/.maw-teams/` and it breaks with nothing to warn you.
>
> **All six houses ran this against their own charters and each identified its own reason** —
> and tars's is the one that closes the loop back on Step 4b: their charter is invariant
> *because it declares no `worktree:` anywhere*, which is precisely the defect check (d) exists
> to catch. **The property that made their result trustworthy is the same property that makes
> their charter wrong.** Nobody said "I stood in the right place"; every one of them named a
> mechanism and gave the command that settles it.
>
> 🪞 **atlas also caught themselves first, and the mechanism is worth borrowing**: this harness
> **persists cwd across separate tool calls**, so their `cd /tmp && …` in one call silently
> carried into the next, and both "vantage points" were actually `/tmp`. The diff came back
> identical and they nearly reported *"confirmed, no cwd-dependence"* off it. They caught it by
> **printing `pwd` before trusting the second run.** Same root as the `send-enter` incident on
> this repo the same day: *trusting a state you have not just looked at.*
>
> ⇒ `enginelist` remains dir-aware **on purpose** — run it from a path your member will use.
> `enginecheck` no longer is. **They answer different questions, so they anchor differently.**

### 🔧 A member is booting as the wrong vendor — how to actually fix it

`[measured 2026-08-07, with controls]` lucifer's `verifier` asked for `engine: claude,
model: sonnet-5` and booted as **`thclaws --model zai/glm-5.1`**. The fix is not what it looks
like, so measure before you reach for the workaround:

| what you try | result | why |
|---|---|---|
| rename the role so it misses the glob (`verifier` → `qa-verifier`) | ✅ no longer hijacked — but lands on **`commands.default`**, still not what the charter asked | dodges step 4, never reaches step 1 |
| register the alias, layer **not visible** from the member dir | ❌ **still hijacked** | step 1 misses, so the glob catches it at step 4 |
| register the alias in a layer **visible from the member dir** | ✅ **wins — the glob never applies** | step 1 beats step 4 |

```bash
# the decisive check, from the MEMBER's directory:
cd <member dir> && maw config sources        # your layer must appear here
```

> ✅ **Confirmed on a real 10-role charter, with the control inside the same charter.**
> `[lucifer, 3 members × 2 arms, real member dirs under ~/.maw-teams/, all dry-run]` One
> charter, three members, **the only variable is whether the engine is registered**:
>
> | member | `engine:` | registered? | resolves to |
> |---|---|---|---|
> | `coder-1` | `codex` | ✅ user layer, visible everywhere | **codex — not hijacked** ← the control |
> | `coder-2` | `hound-codex-oracle` | ❌ | `claude --model claude-opus-5` (default) |
> | `verifier` | `claude` | ❌ | **`thclaws --model zai/glm-5.1`** (glob `verifier*`) |
>
> `coder-1` sitting in the same charter, under the same globs, **unhijacked** is what proves the
> ladder still works. lucifer's summary: *"ไม่ใช่ glob แข็งจนกดทับทุกอย่าง แต่เป็นขั้น 1 พลาด
> แล้ว glob เลยได้ไป."* Two members fail for **different reasons** — one to default, one to
> another vendor — and only the second is a glob problem.
>
> Layer visibility measured the same way: their repo layer is seen from
> `agents/1-frontend-engineer` (**inside** the repo) and **not** seen from
> `~/.maw-teams/lucifer-fullstack-v1/{architect,verifier}`. Predicted, then checked.

> 🪞 **I almost published the opposite conclusion.** My first test used aliases registered in
> *my* repo's layer against a member living in `~/.maw-teams/…`, where that layer is invisible.
> Every variant returned `thclaws`, which reads exactly like *"the glob beats everything, a
> registered alias cannot save you."* **The control saved it**: a non-glob name with the same
> aliases returned the plain default too — proving `-e` was not being read *at all*, so the run
> could not say anything about globs. Re-tested with the alias in an ancestor of the member dir:
> the glob loses. **A test whose control fails has not produced a negative result — it has
> produced nothing**, and the difference between those two is a fleet-wide false alarm.

**For teams under `~/.maw-teams/<team>/<role>`, a layer inside your repo cannot be seen.** Put it
at an ancestor of the member paths — `~/.maw-teams/<team>/.maw/maw.config.60.json` — or the
charter's `engine:` silently misses and glob or default decides for you.

> ## 💸 Which model a role *should* get — the question this file never asked
>
> `[raised by arnon 2026-08-07; measured here the same hour]`
>
> Everything above is about **proving** a member got the model you asked for. **None of it asks
> whether you should have asked for that model.** Measured across every alias `maw` can resolve
> on this machine — 34 aliases in 7 layer files:
>
> | | count |
> |---|---|
> | aliases requesting **`claude-opus-5`** (top tier) | **10** — the single most requested model |
> | aliases requesting a cheap tier (`haiku`, `mini`) | **2** |
> | aliases that tune reasoning effort **at all** | **2 of 34** |
> | aliases pinning **neither** model nor effort → ambient | **8** |
>
> And the two ambient defaults everything falls back to:
>
> ```
> commands.default        →  claude --model claude-opus-5
> ~/.codex/config.toml    →  model = "gpt-5.6-sol",  model_reasoning_effort = "xhigh"
> ```
>
> 🔴 **So the failure this entire skill exists to catch — the silent fallthrough — lands on the
> most expensive model on the machine, at the highest reasoning effort.** Unregistered alias,
> dead-file key, typo'd engine name, missing layer: every one of those paths ends at
> `commands.default`. Two days of documenting *"you silently get the wrong engine"* never once
> said **"and the wrong one is the dearest one you own."**
>
> ⇒ 🔑 **A team that boots correctly can still be built wrong.** Gate 0 passing means each member
> got what the charter asked for; it says nothing about whether a verifier needed opus to say
> PASS/FAIL, and **quota exhausted mid-run is a failure mode with no error message** — the team
> simply stops finishing work.
>
> **Pick the tier from what the role actually does**, not from what is available:
>
> | role does | tier | why |
> |---|---|---|
> | mechanical edits, renames, formatting, running a fixed checklist | **cheapest** (`haiku`, `*-mini`, effort `low`) | the work is transcription; a bigger model buys nothing and costs the whole team's runway |
> | verify / review against stated criteria | **mid** (`sonnet`, effort `medium`) | judgement, but bounded by criteria someone else wrote |
> | design, root-cause, cross-cutting tradeoffs, adversarial review | **top** (`opus`, `gpt-5.6-sol`, effort `high`/`xhigh`) | this is where the tier actually changes the answer |
> | lead / orchestration | **mid**, not top | mostly routing and bookkeeping between short reasoning steps |
>
> ⚠️ **Reasoning effort is a second, independent dial and almost nobody turns it** — 2 of 34
> aliases set it. On codex, `model_reasoning_effort=low` on a cheap model is a different cost
> class again from the same model at `xhigh`. Set both, per role, in the alias.
>
> 🔬 **Check what your charter will actually cost before spawning**, since `enginecheck` already
> resolves the real command per member:
>
> ```bash
> bash ~/.claude/skills/oracle-team/scripts/verify-check.sh enginecheck <charter> \
>   | grep -E 'enginecheck.member|unpinned-alias'
> #   a member line ending in  pinned=no   ⇒ on the ambient default — the top tier, by accident
> #   no pinned= line at all               ⇒ that member IS pinned. This is the good case.
> ```
>
> ⚠️ **`pinned=yes` does not exist.** `enginecheck` only ever emits `pinned=no`
> (`verify-check.sh:1218`), so a correctly-pinned team produces **zero `pinned=` lines** — which
> looks identical to *"my grep was wrong."* `[found 2026-08-07 by the third clean-room tester,
> whose output had no `pinned=` at all and who could not tell whether that was the pass or a typo]`
> Grep for **`unpinned-alias`** in the `enginecheck.unverified:` line instead — that field is
> always printed, so its **absence is meaningful** and its presence names the problem.
>
> **`pinned=no` is not only a stability problem, it is a bill.** The existing
> `enginecheck.unverified: unpinned-alias` flag has been reporting this all along; we read it as
> *"the model could change under you"* and never as *"you are paying top rate for a role that
> may not need it."*
>
> ### 🔃 Worse than "wrong model": the fallthrough **inverts** cheap-tier intent
>
> `[atlas and ajfon, independently, within minutes of the census — 2026-08-07]`
>
> Because every miss lands on `commands.default` = `claude --model claude-opus-5`, **asking for a
> cheap model and asking for nothing produce the same result — the dearest one.** Two houses
> measured it on their own charters:
>
> | charter | asked for | resolves to |
> |---|---|---|
> | atlas `mixed-team-T1506` | **`claude-haiku-4-5-20251001` ×3** — the cheap tier, by name | `null` ⇒ **`commands.default` = opus-5** |
> | ajfon `ajfon-research-team` | 3 roles incl. **`measure-runner`** (mechanical: run tools, report numbers) | **all 3** → `claude --model claude-opus-5` |
>
> 🔑 **The author who bothered to name the cheap model gets the same bill as the author who named
> nothing — and no signal distinguishes them.** ajfon's `measure-runner` is the cleanest case:
> by the table above it belongs on the cheapest tier available, and the fallthrough puts it on
> the most expensive one on the machine.
>
> **atlas's wider scan: 9 of 9 charter files in their repo contain at least one engine value that
> resolves to `null`** — only bare `codex` resolved at all. *(Scoped honestly: measured from the
> repo root, not from each worker's spawn cwd, and some of those charters look historical. The
> claim is "these would misfire if used today from this cwd", not "these all misfired.")*
>
> ⇒ So the cost question is not a separate concern bolted onto Gate 0 — **it is the same defect,
> priced.** Every `enginecheck` FAIL you have ever waved through was also a line item.
>
> 🔬 Census your own machine: `ψ/teams/scripts/model-tier-census.py` **(repo-local to
> codex-fanout — copy it, it takes no arguments and only reads)**.

**Then, model names for a NEW alias** — one lookup per engine, they are not interchangeable:

| engine | how to list what your account serves |
|---|---|
| codex | `grep '^model' ~/.codex/config.toml` — this gives **one** value, the current default. `codex --help` documents the `-m` flag but **does not enumerate valid values** |
| claude | ⚠️ **`claude --help` does NOT list them** — see the correction below. Ask the binary by giving it a wrong one: `claude --model zzz -p hi 2>&1 \| grep -o 'alias[^)]*)'` → on 2.1.224 replies `alias (opus, sonnet, fable)`. Read the list **on your machine**. ⚠️ this line shipped a **different, non-matching regex** (`aliases\?([^)]*)`) for four hours — it requires `alias(` with no space, and the real text has one, so it printed **nothing, silently** |
| opencode | `opencode models` prints every `provider/model` it can reach |

🔑 **Getting two DIFFERENT models is the step people get stuck on.** codex exposes only its
current default by the route above, so there may be **no way to discover a second codex model
locally**. The reliable answer is to make the second member a **different engine** — codex for
one, claude for the other. Mixing engines in one team is normal and is what the per-member
aliases are for. Do not invent model names to fill the gap.

> ### 🔴 The claude row was false, and it was the one place a newcomer could not proceed
>
> `[found 2026-08-07 by a clean-room agent given only this skill · confirmed here on 2.1.224]`
>
> This table used to say *"`claude --help` lists the aliases it accepts."* It does not:
>
> ```
> $ claude --help | grep -c -- '--model'
> 0                      # only --fallback-model exists; no list, no error, silent dead end
> ```
>
> Combined with *"Do not invent model names"* two lines below, the documentation **closed both
> doors**: no way to obtain a name, and an instruction not to guess one. The tester finished the
> task only because a usable name had been inherited from an earlier run — **a real newcomer
> stops here.** Every other defect found this year has been a check that lied; this one was
> simply an instruction that could not be followed.
>
> **The route that works** — ask the binary by handing it a name it cannot have:
>
> ```bash
> claude --model zzz-not-a-model -p hi 2>&1 | grep -o 'alias[^)]*)'
> #   → Switch to a public model alias (opus, sonnet, fable)
> ```
>
> ❌ **RETRACTED — this block said `rc=0` in bold for about four hours. It is `rc=1`.**
> `[measured without a pipeline, 2026-08-07; caught by the second clean-room tester]`
>
> ```
> out=$(claude --model zzz-not-a-model -p hi 2>&1); rc=$?   # rc=1
> ```
>
> My original reading was `… 2>&1 | head -8; echo "rc=$?"` — **`$?` was `head`'s exit code, not
> claude's.** That is the pipeline-rc trap this repository has a selftest for, committed **in the
> same session in which I documented it**, and the false value then travelled to six oracles.
>
> **What is actually true**, and it is narrower than what I claimed:
> - `claude --model <typo> -p …` (**headless**) → **rc=1**, and says *"There's an issue with the
>   selected model … It may not exist or you may not have access to it."* It does signal.
> - What happens to a **long-running pane** started from an alias with a bad `--model` was
>   **never measured** — by me or anyone. Do not assume it matches the headless case in either
>   direction.
>
> ⇒ So the earlier line *"same family as `maw team <typo>` returning 0"* was **wrong**: `maw team`
> genuinely returns 0 and creates nothing; `claude -p` returns 1. **I generalised one binary's
> convention onto another — the exact error this file warns about two sections up.**
> Read the model back per Step 6 regardless; that advice never depended on the exit code.

**Step 2 — create each member's working directory. It must exist before spawn.**

```bash
mkdir -p "$ROOT/agents/$A" "$ROOT/agents/$B"
```

**Step 3 — write the charter.** Two rules that will otherwise cost you an hour:
member names must be **unique across the whole fleet** (prefix with the team name), and every
member needs a real path — `worktree:` or `cwd:`, either works. With neither, the member boots
in whatever repo its *name* is registered to and your engine aliases are invisible there.
Write `engine:` only; a `model:` line does not reach the pane and is actively harmful without
an `engine:` beside it (see 0c).

```bash
mkdir -p "$ROOT/ψ/teams"
cat > "$ROOT/ψ/teams/$TEAM.yaml" <<YAML
name: $TEAM
session: $SESSION
members:
  - role: $A
    name: $A                  # the "member identity" referred to elsewhere in this doc
    engine: team-codex-hi
    worktree: agents/$A       # RELATIVE to \$ROOT (absolute also works)
  - role: $B
    name: $B
    engine: team-codex-lo
    worktree: agents/$B
YAML
```

`project:` and `branch:` are omitted because **`maw team up` does not need them**.

> ⚠️ **But `maw team preflight` does — and it will fail this charter.** `[found by ajfon,
> 2026-08-06]` An earlier version of this doc told you to drop those fields in Step 3 and then,
> in Gate 0, to stop if preflight is red. Those two instructions contradicted each other.
>
> **`maw team preflight` cannot pass before a spawn, by construction.** Even with every field
> present it returns rc=1 on:
> - `✗ spawn ordering: session '<x>' does not exist before spawn` — true by definition when
>   you are about to create it
> - `✗ codex trust: <role> missing trusted project entry … in ~/.codex/config.toml` — see the
>   prerequisite below
>
> ⇒ **Do not gate on preflight before spawning.** Read it for the checks that *are* meaningful
> pre-spawn (role uniqueness, artifact collisions, CODEX_HOME isolation, worktree collisions)
> and ignore the two above. The check that decides whether to proceed is **Step 4**, which can
> fail for exactly one reason and no other.

> 🔑 **codex trust — a prerequisite nothing else here mentions, and the *cause* of the trust
> prompt listed in Step 6.** codex refuses to run unattended in a directory it has not been
> told to trust, so a fresh member directory stalls on `Is this a project you created or one
> you trust?`. Either clear it interactively at Step 6, or pre-seed it before spawning:
> ```bash
> printf '\n[projects."%s"]\ntrust_level="trusted"\n' "$ROOT/agents/$A" >> ~/.codex/config.toml
> ```
> ⚠️ `~/.codex/config.toml` is **shared machine-wide state**. Appending a project entry is
> additive and low-risk; do not edit anything else in that file for a team bring-up.

**Step 4 — prove the aliases are actually visible.** Not optional: `maw team preflight` and
`maw team up --dry-run` are both green even when this is broken.

```bash
cd "$ROOT/agents/$A"
maw config sources        # your maw.config.60.json MUST be listed here
maw wake "$A" --no-attach --dry-run -e team-codex-hi        --repo-path "$ROOT/agents/$A"
maw wake "$A" --no-attach --dry-run -e __no_such_engine__   --repo-path "$ROOT/agents/$A"
cd "$ROOT"
```

> 🔁 **More than two or three members? Do not eyeball this.** `[lucifer 2026-08-06 — at 10
> roles the two-command form is 20 invocations compared by hand, and the doc shipped no loop]`
> Either run `scripts/verify-check.sh enginecheck <charter>`, which does exactly this per
> member and prints a verdict, or loop it yourself:
> ```bash
> while IFS=$'\t' read -r ROLE DIR ENG; do
>   real=$(maw wake "$ROLE" --no-attach --dry-run -e "$ENG"                --repo-path "$DIR" 2>&1 | sed -n 's/^ *command: *//p')
>   ctrl=$(maw wake "$ROLE" --no-attach --dry-run -e __no_such_engine__    --repo-path "$DIR" 2>&1 | sed -n 's/^ *command: *//p')
>   [ -n "$real" ] && [ "$real" != "$ctrl" ] \
>     && echo "OK   $ROLE  $real" \
>     || echo "FAIL $ROLE  (alias not read — same as control, or no output)"
> done < <(your role/dir/engine triples)
> ```
Read both `command:` lines. **They must differ.** Identical output means your alias was
discarded and both fell through to the same default — fix that before going on.

> ### ✅ What Gate 0 is actually worth: a spawn that was stopped
>
> `[atlas, 2026-08-07, with direct human authorization to proceed]` They were cleared to bring up
> `rnd-cell` — a 3-role research/verify/plan cell whose entire point is **cross-family**
> verification. `enginecheck` returned `overall: FAIL` and named why:
>
> | role | charter asks for | would actually boot |
> |---|---|---|
> | `researcher` | `gpt-5.4-codex` | codex with **no `--model` at all** → whatever `config.toml` currently says; the requested name may not exist any more |
> | `planner` | a codex-family engine | **plain `claude-opus-5`** — *the same vendor as the oracle running the cell* |
> | `verifier` | glm-5.1 via thclaws | lands close, **but only because `verifier` glob-matches** — right answer by luck, which is what `pinned=no` exists to flag |
>
> The `planner` row is the one to remember. Booting `claude-opus-5` there is not merely the wrong
> model — **it collapses a cross-family cell into one that verifies itself**, which is a failure
> of the team's *purpose* caught by a check that only reads *command strings*. Nothing at runtime
> would have looked broken; three panes would have come up and worked.
>
> atlas also found the charter forbids the spawn in its own header
> (`spawn_policy: no-exec-from-atlas-pane`), reported **both** blockers to the human rather than
> picking whichever was more convenient, and stopped. Their framing: *"I checked, found two real
> reasons, and they hold regardless of who's asking."*
>
> ⇒ **Gate 0's value is not only that a team boots correctly — it is that a team which would
> defeat its own design never gets spawned.** That is worth more than any teardown, because
> nothing needs tearing down.

**Step 4b — pre-spawn checklist. Three things that are cheap now and expensive after spawn.**

> `[found by lucifer 2026-08-06, running Gate 0 against a real un-spawned 4-role charter]`
> Gate 0 caught all three **before any process started** — but lucifer caught them because they
> remembered from a review round, **not because this document led them there.** That is the gap
> this step closes. Their verdict on the rest: *"Gate 0 + up ในรูปแบบปัจจุบัน ใช้กับงานจริงของผมได้
> และคุ้ม — จับ 3 อย่างในไม่กี่นาทีโดยไม่ต้อง spawn."*

```bash
# ── These three are used by every check below and are NOT set anywhere earlier in
#    the QUICKSTART. Pasted without them, check (a) compares against an empty string
#    and passes silently — the exact failure the step exists to prevent.
: "${TEAM:?set TEAM — the team name}"
: "${ROOT:?set ROOT — your team repo root, NOT whatever repo you happen to stand in}"
CHARTER="${CHARTER:-$ROOT/ψ/teams/${TEAM}.yaml}"
[ -f "$CHARTER" ] || { echo "✗ no charter at $CHARTER — set CHARTER explicitly"; return 1 2>/dev/null || exit 1; }

# (a) 🔴 Is the team's session the session YOU live in?
#     `tmux display-message` with NO client attached does NOT return empty — it returns
#     tmux's most-recently-active session, i.e. SOMEONE ELSE'S. Measured: from an agent
#     outside tmux it returned `113-tars`, an unrelated live oracle. Anchor to $TMUX_PANE;
#     if $TMUX is unset you are not in any session and no collision is possible.
if [ -n "${TMUX:-}" ] && [ -n "${TMUX_PANE:-}" ]; then
  SELF=$(tmux display-message -p -t "$TMUX_PANE" '#{session_name}' 2>/dev/null)
else
  SELF=""
fi
SESS=$(grep -m1 '^session:' "$CHARTER" | awk '{print $2}')
[ -n "$SELF" ] && [ "$SELF" = "$SESS" ] && cat <<EOF
🔴 charter session '$SESS' IS YOUR OWN SESSION.
   The team spawns as windows beside you, and teardown's session-level kill
   would terminate you along with it. Give the team its own session, or never
   run 'tmux kill-session' for it. (See references/teardown.md Step 1.)
EOF

# (b) 🟡 .gitignore, per worktree — NOT per team. Same charter can be safe for
#     some members and unsafe for others when members live in different repos.
#     `worktree: true|false` are FLAGS, not paths — filter them out explicitly.
#     [found by ajfon 2026-08-06] `worktree: true` on a lead role reached the loop as the
#     candidate path "true"; it was skipped only because `[ -d "true" ]` happens to be false.
#     A check that survives on a coincidence is not passing, it is getting lucky.
grep -E '^\s*(worktree|cwd):' "$CHARTER" | awk '{print $2}' \
  | grep -vxE 'true|false|~|\.' | while read -r wt; do
  # Resolve WITHOUT requiring existence — this runs before spawn, so it never exists yet.
  case "$wt" in /*) abs="$wt" ;; *) abs="${ROOT:-$PWD}/$wt" ;; esac
  parent=$(dirname "$abs")
  [ -d "$parent" ] || continue                       # the PARENT exists pre-spawn; the worktree does not
  owner=$(git -C "$parent" rev-parse --show-toplevel 2>/dev/null) || continue
  # check-ignore matches paths, not files — it answers correctly for a path that does not exist.
  git -C "$owner" check-ignore -q "$abs" 2>/dev/null \
    || echo "🟡 $abs will sit inside $owner un-ignored — untracked forever, one 'git add .' from committed"
done

# (c) 🟡 Member names should be prefixed with the team name. ONE line per charter, not per role:
#     lucifer's n=65 run fired 357/357 times, which is noise nobody reads.
unpref=$(grep -E '^\s*-?\s*role:' "$CHARTER" | awk '{print $NF}' | grep -vc "^${TEAM}" || true)
tot=$(grep -cE '^\s*-?\s*role:' "$CHARTER" || true)
[ "${unpref:-0}" -gt 0 ] && echo "🟡 $unpref/$tot roles in $(basename "$CHARTER") lack the '$TEAM' prefix — matters ONLY if anything calls bare 'maw wake <role>'; check with: grep -rn \"maw wake\" your scripts"

# (d) 🔴 Every member needs worktree: or cwd:. Absent is NOT a harmless default.
python3 - "$CHARTER" <<'PY'
import re,sys
src=open(sys.argv[1]).read()
blocks=re.split(r'(?=^\s*-\s*role:)', src, flags=re.M)
missing=[]
for b in blocks:
    m=re.search(r'role:\s*(\S+)', b)
    if not m: continue
    if re.search(r'worktree:\s*false', b): continue          # lead windows opt out on purpose
    if not re.search(r'(?:worktree|cwd):\s*\S+', b): missing.append(m.group(1))
if missing:
    print(f"🔴 no worktree:/cwd: for {', '.join(missing)} — maw falls back to the IDENTITY directory,")
    print("   so these members run in the oracle's own repo, several of them in the SAME directory,")
    print("   with no isolation and nothing for teardown to remove. Declare a path per member.")
PY
```

> **(a)** lucifer's charter declared `session: 84-lucifer`, their own oracle's session. Teardown
> would have killed them. Nothing warned.
> **(b)** Their four members span two repos: `maw-rs/agents/` **is** ignored, `maw-ui-lite/agents/`
> **is not** — *the same charter, safe for half its members.* A single team-level check passes and
> misses the other two. This is where lucifer's 15 stray directories came from.
> ### ✅ Step 4b's evidence — four houses, measured before and after the fix
>
> `[2026-08-06]` Each ran the same charter with the same commands; **only the skill changed.**
>
> | house | (a) session | (b) gitignore | (c) prefix | (d) worktree | Step 2b orphans |
> |---|---|---|---|---|---|
> | **lucifer** n=65 | 🔴 found `t4527-wake-parity.yaml`, a **second** charter on their own session they did not know existed | **0 → 8** · negative arm holds (`maw-rs` 0, genuinely ignored) | 357 → **65 lines** | 0/65 — negative arm only | — |
> | **ajfon** | 🔴 fires — charter says `40-ajfon`, they run in `40-ajfon` | **0 → 3/3**, confirmed with `check-ignore -v` rc=1 | 3 → 1 line | correctly silent | **found all 5 stranded worktrees, `ahead` 2/0/7/4/7 — matching their manual count exactly** |
> | **atlas** | true negative | **0 → 2**, sanity-checked directly, not taken from loop output | 4 → 1 line | — | — |
> | **prism** | true negative | silent (member dirs are not git repos) — **skips, does not error** | 8 → 1 line | correctly silent | — |
>
> **(a) is the one that justifies the whole step**: it fired in *two* houses, and in lucifer's it
> found a charter they had no memory of. **(d) has a passing negative arm and no positive
> evidence yet** — lucifer's 65 charters all declare a path, so only tars has a real case.
> Recorded as *unproven*, not as *passing*.

> **(c)** Roles named `coder-a` / `verifier-rs`: `maw wake coder-a --dry-run` from either repo
> resolved to **`maw-rs` — the repository, not the member.** `team up` passes `--wt` so spawn
> still works, but any bare `wake` is aimed somewhere unpredictable.
>
> ⚠️ **(c) is conditional, and the earlier wording overstated it.** `[prism, 2026-08-06]` It
> fired on all 8 of their roles, so prism did what this document should have: **checked whether
> the risk it warns about is reachable in their design.** `grep` found no bare `maw wake <role>`
> anywhere in their scripts — they use `maw team spawn --cwd --engine` throughout — and
> `maw wake refract-scope --dry-run` failed *cleanly* (`oracle repo not found`) rather than
> fuzzy-matching, because no oracle on the machine shares that name. **True positive, much lower
> severity than written.** The risk belongs to *calling bare `wake`*, not to *naming a role
> without a prefix* — a warning that does not say what makes it dangerous invites being ignored
> for the cases where it is.

**Step 5 — spawn.**

```bash
maw team up "$TEAM" --dry-run     # sanity: roles + engines listed
maw team up "$TEAM"               # real
```

> ## 🔴 Step 5b — LOOK at the pane before you send it anything. Not optional.
>
> `[verified the hard way, 2026-08-06 — this upgraded a binary for every oracle on the machine]`
>
> After `up`, a codex pane may not be sitting at the agent's prompt at all. It can be sitting on
> **codex's own interactive screen** — an update offer, a trust-this-directory question, a
> release-notes pager. **`maw send-enter` presses whatever is on screen.** In this author's run it
> pressed:
>
> ```
> ✨ Update available! 0.146.0 -> 0.146.1
> › 1. Update now (runs `npm install -g @openai/codex`)
>   2. Skip
>   Press enter to continue
> ```
>
> **Result: `npm install -g @openai/codex` upgraded codex globally for every oracle on this
> shared machine, and codex then printed "Please restart Codex" and exited — the window
> disappeared.** The prompt was never delivered to any model. One blind `send-enter` mutated
> shared state irreversibly and killed the worker.
>
> ```bash
> # ALWAYS, before the first send — one command, whole team, read-only:
> bash ~/.claude/skills/oracle-team/scripts/verify-check.sh bootverify "$SESSION"
> ```
> ```
> bootverify.pane: coder-a  READY proc=codex model=gpt-5.6-sol cmd=codex --model gpt-5.6-sol …
> bootverify.pane: coder-b  NOT-READY screen=cli-update-dialog — ห้ามส่ง Enter จะกด 'Update now'
> bootverify.pane: coder-c  PROCESS-GONE — pane เหลือแต่ shell (engine ตายหรือยังไม่ boot)
> overall: NOT-READY — อย่าเพิ่งส่งอะไรเข้า pane ที่ยังไม่ READY
> ```
> It reads `/proc` for what is **actually running** and `capture-pane` for **whose screen it
> is**, sends nothing, and presses nothing. `NOT-READY` on a pane whose process is running and
> correct is the case that matters — that is precisely the state that upgraded this machine.
>
> `[tested against four pane shapes]` engine as the pane process itself · engine as a child of a
> shell (the `maw wake` shape) · a live process showing the update dialog · a bare shell where
> the engine died. The first version walked only child processes and reported `PROCESS-GONE` for
> panes that were running the engine directly — found by testing it, not by reading it.
>
> Or read it yourself with `maw peek "${SESSION}:${ROLE}-oracle" | tail -20` and answer one
> question: **is this screen the agent's, or the CLI's own?** Only send once it is the agent's.
>
> 🔑 **This also breaks a rung of the evidence ladder that looked solid.** `/proc` confirmed the
> pane was running `codex --model gpt-5.6-sol …` — the exact alias, correct flags. That claim was
> **true and useless**: the process was right while the screen belonged to an installer. So
> insert a rung:
>
> | rung | means |
> |---|---|
> | `delivered` | text written to the pane |
> | `capture-pane` shows it | it is in *a* input box — **possibly the CLI's, not the agent's** |
> | **`/proc` cmdline correct** | **right process, right model — says NOTHING about readiness** |
> | screen is the agent's own prompt | it can now receive a turn |
> | agent quotes your content back | it entered a turn |
> | **— every rung above is measured at t=0 —** | **and none of them stays true** |
> | **no permission prompt on screen *right now*** | **it can still act — expires continuously** |
>
> **A correct process is not a ready agent**, and the two are indistinguishable from every check
> above the last two.
>
> ### 🔴 …and a ready agent is not a working agent an hour later
>
> `[verified 2026-08-08 ~22:2x +07 · tmux capture-pane + ps --ppid on a live team]`
>
> Every rung above answers **"can it start?"**. None answers **"is it still going?"** — and the
> way a team dies in practice is the second one. A real team, `pivot-registry-expand`, six
> members, all six booted clean and **passed the top rung** (received turns, answered, began
> work). Then:
>
> ```
> permstall.count: panes=6 blocked=5
>   🔴 BLOCKED  integrator-oracle          Do you want to proceed?
>   🔴 BLOCKED  prober-thai-gov-oracle     Do you want to create prober-thai-gov.md?
>   🔴 BLOCKED  prober-intl-corp-oracle    Do you want to proceed?
>   🔴 BLOCKED  prober-academic-alt-oracle Do you want to proceed?
>   🔴 BLOCKED  reviewer-oracle            This command requires approval
>       proc=claude --model claude-opus-5
>       perm=ask  (no --dangerously-skip-permissions ⇒ asks on every write/bash)
> ```
>
> **Five of six, including the team's own lead.** Each one sitting on a question, burning
> wall-clock, indistinguishable from "thinking" to every check that existed before this one.
>
> ⇒ 🔑 **This is also the honest answer to "why didn't the lead go look at the workers?"** The
> lead *did* verify — at boot, exactly as this file instructed — saw READY, and went to do
> something else. **Nothing anywhere said readiness expires.** That is a defect in this
> document, not in the lead's diligence. A boot-time gate cannot be the last gate.
>
> ```bash
> # after spawn, and then ON A LOOP for as long as the team is alive — read-only, sends nothing:
> bash ~/.claude/skills/oracle-team/scripts/verify-check.sh permstall "$SESSION"
> ```
>
> 🔴 **`permstall` also sweeps for the CLI's own dialogs, not just permission prompts — and it
> did not until 2026-08-09.** The owner named this as the thing they hit most often: *a new codex
> version lands, the worker boots into "update?", and the lead never goes back to check whether
> it is sitting there.* Tested: a pane frozen on `✨ Update available!` returned **`blocked=0`**
> from the version of this tool shipped hours earlier — **a false green inside the tool built to
> kill false greens.** `bootverify` does catch it, but `bootverify` is a **one-shot at t=0**, and
> a new version can be published at any hour: the worker spawned after lunch meets a dialog the
> morning's worker never saw. A boot gate cannot cover a hazard that arrives on someone else's
> release schedule.
>
> Output now carries `kind=`, because the remedies are opposite:
> ```
> 🔴 BLOCKED  worker-3  [cli-dialog]  ✨ Update available! 0.147.0 -> 0.148.0
> 🔴 BLOCKED  worker-5  [permission]  Do you want to proceed?
> ```
> `permission` → grant it, or restart with a bypass token in the alias.
> `cli-dialog` → **read the number off that screen**; a blind Enter takes the highlighted item,
> which on the update dialog is `Update now` and rewrites the binary for every agent on the box.
>
> ```bash
> # the answer to "the lead forgets to look" is not a reminder — leave it running:
> bash ~/.claude/skills/oracle-team/scripts/verify-check.sh permstall "$SESSION" --watch 60
> #   prints ONLY when the state changes, so it can sit in a pane overnight without becoming noise
> ```
>
> ⚠️ **Both detectors require a banner AND an adjacent numbered option in the last 15 lines.**
> A single keyword is not enough and the looser version was measured doing harm: sweeping the
> live fleet, a *working* worker was reported BLOCKED because the Thai word for "permission"
> appeared in prose it had just written. **A sweep that cries wolf gets turned off, which returns
> you to the original problem by a longer road.** Validated across 22 live panes: zero false
> positives, both dialog kinds still caught.
>
> 🩹 And the same sweep exposed a defect that only live panes could show: `/proc` returns
> `node /home/user/.npm-global/bin/codex …`, so reading argv[1] gave **`node`** and every codex
> worker reported `perm=unknown`. Fixtures always fed `codex …` directly, so it could not appear
> in a test. **The string an alias declares and the string `/proc` returns are not the same
> string**, and this checker is used against both.
>
> ⚠️ `no-prompt-visible` **does not mean the worker is working** — it means no question is on
> screen *at this instant*. A prompt that scrolled out of the capture buffer is invisible to it.
> **That is why it is a loop, not a gate.**
>
> 🔴 **`permstall` deliberately cannot fix anything.** Pressing `Yes` in a pane grants a
> permission on behalf of that team's human. If the team is yours, read the option number off
> the live screen (never hardcode it — see the update-dialog lesson above). If it is someone
> else's, send them the evidence and let their human decide.
>
> 📏 **Sweep, don't sample.** The first pass at this looked at four panes and reported three
> blocked. The full sweep found **five, plus the lead**. A team-shaped problem needs a
> team-shaped read.
>
> ### The dismissal pattern that already works — prism's, not invented here
>
> prism's launcher never hit this, and **not because they were more careful — because of
> structure.** Their `team_dismiss_startup_prompts` **greps for the banner first and sends the
> Skip number, never a bare Enter**:
>
> ```bash
> # match the specific screen, then send the specific answer for THAT screen
> if maw peek "$T" | grep -qF 'Update available!'; then
>   tmux send-keys -t "=$T" '3' Enter        # ⚠️ SEE BELOW — do not copy this 3
> fi
> if maw peek "$T" | grep -qF 'Is this a project you created or one you trust'; then
>   tmux send-keys -t "=$T" '1' Enter        # 1 = "Yes, I trust this folder"
> fi
> ```
>
> **Never send a naked Enter to a screen you have not matched.** A blind Enter takes the
> *highlighted default*, and on the update screen the default is **"Update now"** — which runs
> `npm install -g` against the whole machine.
>
> ### 🔴 …and the number in that snippet is not portable either
>
> `[found 2026-08-07 by a clean-room agent, who read the live menu instead of trusting us]`
>
> Three places in this project disagreed about which key means Skip, because **the menu changes
> between codex versions**:
>
> | codex | menu | "Skip" is |
> |---|---|---|
> | 0.146.0 | `1. Update now` · `2. Skip` | **2** |
> | 0.146.1 | `1. Update now` · `2. Skip` · `3. Skip until next version` | **2** — and **3 writes a persistent preference into shared codex state** |
> | 0.147.0 | **no update dialog at all** (it is current). A fresh worktree lands on the **trust** dialog instead: `1. Yes, continue` · `2. No, quit` | **n/a — and the highlighted default is now `1`, which GRANTS trust** |
>
> > 🔴 **That last row inverts what a blind Enter does — and this machine reached it the hard
> > way.** `[verified 2026-08-08 ~23:5x: codex --version → 0.147.0; binary mtime 23:52; booted
> > a fresh dir and read the screen]` Hours earlier, a member pane in another oracle's team took
> > `1` on the 0.146.1 update dialog **before its lead had touched that pane**, ran `npm install
> > -g @openai/codex`, and upgraded codex for **every oracle on this machine**. Second
> > occurrence of the incident this section was written about, different house, five days apart.
> >
> > ⇒ 🔑 **The lesson most people took from the first occurrence — "learn which number Skip
> > is" — is the wrong lesson, and this row proves it.** The index that was *catastrophic* on
> > 0.146.1 is the index that is *required* on 0.147.0. **No number is safe to know in
> > advance**, because the hazard belongs to *(version × pane state)*, not to the CLI. Only two
> > things generalize: **match the banner first**, then **read the number off the pane you just
> > matched**.
> >
> > ⇒ ⚠️ **A bare Enter takes the highlighted item, and the pane looks identical either way.**
> > If any spawn path in your stack sends Enter to "clear startup screens", it is not dismissing
> > a dialog — it is **answering an unread question about shared state**. After an incident like
> > this, audit that path, not the operator.
> >
> > ⇒ ⏳ **Every claim tagged to codex 0.146.x on this machine now measures a binary that no
> > longer exists.** `valid-if: codex --version`
> >
> > 🩹 **…and that `valid-if` is itself half wrong — corrected the same night.**
> > `codex --version` reads the file **on disk**: it answers *"what will the next boot get"*,
> > never *"what is this pane running"*. A pane that booted before the swap keeps executing the
> > replaced binary — `readlink /proc/<pid>/exe` on one of them returns
> > `…/@openai/.codex-dmd5Al78/…/bin/codex **(deleted)**`, because the kernel holds the inode.
> > `[verified 2026-08-09]` ⇒ for a claim measured against a **live pane**, check
> > `readlink /proc/<child-pid>/exe` (child, not pane pid — the pane is a bare shell) or read
> > that pane's own status bar. Found by ajfon before me: their worker ran 0.146.1 straight
> > through the upgrade.

> ## 🤝 Trust is matched on the EXACT path — it does **not** inherit from an ancestor
>
> `[verified 2026-08-09 · codex 0.147.0 · both arms, throwaway CODEX_HOME, no shared state touched]`
>
> This is the same class as the permission dimension — **a pane that boots, looks alive, and
> sits on a question** — only it fires at t=0 instead of at first write.
>
> | arm | config | cwd | result |
> |---|---|---|---|
> | A | only `[projects."/home/user"]` trusted | `/home/user/.tmp-trustprobe/armA` | **full trust dialog** |
> | B | + `[projects."/home/user/.tmp-trustprobe/armB"]` | `…/armB` | **boots straight to the prompt** |
>
> `/home/user` is an ancestor of every worktree on this machine and is trusted — **and it still
> asks.** That is why one house's codex home carries 38 per-worktree entries under a parent that
> was already trusted; they are not redundant. (lucifer measured arm A and declared, correctly,
> that their delete-arm never ran; arm B is the missing half, run here.)
>
> ```bash
> # pre-spawn, touches no pane, needs no boot:
> grep -cF "[projects.\"$MEMBER_WORKTREE\"]" "$CODEX_HOME/config.toml"   # 1 = clean · 0 = it will sit
> ```
> `enginecheck` now prints this per codex member (`🤝 trust` / `🟠 trust`) and emits
> `enginecheck.unverified: codex-trust-dialog-expected`.
>
> ⚠️ **Read the right home.** This machine has **at least six codex homes** — aliases that set
> their own `CODEX_HOME` per role. A check that reads `~/.codex` answers for one of them and
> silently speaks for all. `enginecheck` reads the home *that alias points at*.
>
> ⛔ **Do not clear this dialog with a bare Enter.** On 0.147.0 the highlighted default is
> `1. Yes, continue` — it grants trust unread. On 0.146.1 the same index was `Update now`.
>
> Step 6's table said `2`, prism's snippet says `3`, and `verify-check.sh`'s own remedy line said
> **`(3=Skip)`** — mislabelled, **in the hint attached to the check whose entire lesson is "never
> press blindly."** On 0.146.1 that hint would have had you write shared state to dismiss a
> dialog.
>
> ⇒ 🔑 **Hardcoding any number is the defect.** The rule is the one prism's structure already
> implies but the snippet undercuts: **match the banner, then read the number off the pane you
> just matched, and prefer the option that leaves no trace.** `verify-check.sh` now prints the
> version-dependent menu instead of a number.
>
> 🪞 The tester got this right by doing exactly what the surrounding prose says and **ignoring the
> literal we shipped** — which is the strongest evidence that an example can contradict its own
> lesson and still be copied.
>
> ⏳ **This was known for five days and happened anyway.** lucifer banked it on **2026-08-01
> against codex 0.145**: *"dialog-clearing loop ของ `spawn_team_member.sh` ไม่ match →
> spawn fail-closed"*, ending with **"Script ยังไม่ patch."** The knowledge was written down,
> searchable, and correct — and nothing stood between it and a hand pressing Enter.
> **It also got worse across versions:** on 0.145 the mismatch failed *closed* (spawn just
> didn't start); on 0.146 it fails *open* — the Enter lands on a live menu item and mutates the
> machine. **A defect that fails closed can become the same defect failing open after an upgrade
> you did not make.** This is the case for a matched-dismissal helper rather than a rule saying
> "be careful."
Two failures you will probably hit here, and neither error explains itself:

- **`charter not found: <team>`** — `maw team up` looks for the charter **relative to your
  current directory** (`./.maw/teams/<team>.yaml`, then `./ψ/teams/<team>.yaml`). Step 4 left
  you inside a member directory. `cd "$ROOT"` and re-run. Nothing is wrong with the charter.
- **`exited with exit status: 1`** — almost always a member name that is ambiguous
  fleet-wide. The message names no member; re-run the failing one by hand to see the reason:
  `maw wake "$A" --no-attach --session "$SESSION" -e team-codex-hi`

**Step 6 — check every member booted. A spawn that "succeeded" often has not.**

```bash
bash ~/.claude/skills/oracle-team/scripts/verify-check.sh bootverify "$SESSION"
```

**That is the whole step for any team size.** It lists every window itself, reads `/proc` for
what is running and `capture-pane` for whose screen it is, and reports READY / NOT-READY /
PROCESS-GONE per pane with the remedy for each. Read-only — sends nothing, presses nothing.

> 🔴 **This step used to be two hardcoded `capture-pane` lines and it did not survive contact
> with a real team.** `[lucifer, after spawning a live 3-member team and reading a 10-role
> charter, 2026-08-07]` Two members means two lines you can paste; **ten means a loop nobody
> wrote**, and one fixed `sleep` is wrong because members finish booting at different times.
> Their verdict: *"ขั้นที่ scale ไม่ขึ้นคือ Step 6 — `bootverify` แก้ข้อนี้ไปแล้วทั้งข้อ
> ควรยก bootverify ขึ้นมาแทนที่ Step 6 ไปเลย ไม่ใช่วางไว้เป็น 5b."* Done.
>
> On their live run `bootverify` returned `overall: READY panes=3`, **and they checked its
> verdict by eye** rather than trusting it: all three sat at a real agent prompt, `gpt-5.6-sol
> medium`, no dialog. A tool's verdict confirmed against the thing it claims to measure.

**If you want to read a pane yourself**, the traps below still apply — `bootverify` handles them
for you, but you will hit them the moment you look manually.

🔴 **The window is named `<role>-oracle`, not `<role>`.** `maw team up` appends the suffix.
Targeting `$SESSION:$A` makes tmux prefix-match, return one useless line, and **exit 0** —
which reads as "member is up and quiet". Always list the real names first:

```bash
tmux list-windows -t "=$SESSION" -F '#{window_name}'      # the '=' prevents prefix matching
for W in $(tmux list-windows -t "=$SESSION" -F '#{window_name}'); do
  echo "=== $W ==="; tmux capture-pane -p -t "=$SESSION:$W" | grep -n . | head -30
done
```
🔴 **Do not use `| tail -25` here.** The engine banner sits in the *upper* half of the pane and
the bottom is blank padding, so `tail` prints **nothing at all** — at the exact step where you
are told to read the model. Empty output there reads as "dead pane" and is the single most
misleading moment in this procedure. `grep -n .` drops the blank lines instead.

First-boot prompts that stall a member — each one leaves it looking merely quiet:

| what you see | engine | clear it with |
|---|---|---|
| `✨ Update available!` | codex | `tmux send-keys -t "=$SESSION:${A}-oracle" 2 Enter` (`2` = "Skip"; `1` would upgrade the shared binary — read the menu, the numbering is not guaranteed) |
| `Is this a project you created or one you trust?` | claude | `tmux send-keys -t "=$SESSION:${B}-oracle" 1 Enter` (`1` = "Yes, I trust this folder") |
| a bare shell prompt `❯` | any | the engine never started — go back to step 4 |

⏳ **`model: loading` occupies the exact line you are told to read.** After clearing a prompt,
the codex banner shows `model:       loading` before the real value appears.

**Do not use a fixed sleep — poll.** Timings observed on this machine ranged from ~25s to
~35s across three runs (n=3, single machine, one codex version), and a reviewer correctly
pointed out that this doc previously carried three different numbers for the same wait. Any
constant here is a guess dressed as a measurement:

```bash
for _ in $(seq 30); do
  tmux capture-pane -p -t "$SESSION:${A}-oracle" | grep -q 'model:.*loading' || break
  sleep 3
done
```
Then read the banner. **Never accept the first banner you see.**

🔴 **The banner does NOT prove the account can serve that model.** `[verified 2026-08-06 by
sending a real turn]` A pane boots cleanly and prints `model: gpt-5.6-mini xhigh` in its own
UI, and the first actual request returns:
```
ERROR: {"status":400,"message":"The 'gpt-5.6-mini' model is not supported when using Codex with a ChatGPT account."}
```
The same command with `gpt-5.6-sol` completed the task and wrote the file. So the engine
accepts the flag, reports it, and only the **first real turn** discovers the account cannot
use it. Every earlier version of this document called the banner "the only check that covers
whether the account can serve the model" — that was wrong, and the example aliases shipped
here used exactly the model that fails.

**The banner tells you the flag arrived. Only a real turn tells you it works.** This is what
`model-served=UNVERIFIED` has been pointing at the whole time — it is not boilerplate.

```bash
bash ~/.claude/skills/oracle-team/scripts/verify-check.sh modelprobe <alias> <dir>
#   modelprobe.engine: codex-sol    PASS model=gpt-5.6-sol  served=yes
#   modelprobe.engine: codex-medium FAIL model=gpt-5.6-mini served=no  "message":"The
#     'gpt-5.6-mini' model is not supported when using Codex with a ChatGPT account."
```
💸 **It sends one real turn and costs quota** — that is the point; nothing cheaper can answer
the question. Run it **once per new engine**, before trusting a team to it. Both arms verified
above on the same account minutes apart. codex only; other engines report UNVERIFIED rather
than guessing.

**What the banner does establish** — that your alias reached the engine. Per engine:
- **codex** — banner line `model: <MODEL> <effort>` and the status bar repeat it
- **claude** — the banner scrolls away; use `tmux send-keys -t "=$SESSION:${B}-oracle" "/status" Enter`
  then peek, and read `Model: <alias> (<full-id>)`

**Step 7 — tear down.**

```bash
tmux kill-session -t "=$SESSION"
ls ~/.maw/fleet/ | grep -i "$SESSION"      # usually EMPTY — see below
rm -f ~/.maw/fleet/"$SESSION".json         # only if the line above printed something
```

**Which of those two lines you need depends on how the team was started, and the difference
is not obvious:** `maw wake` run directly writes `~/.maw/fleet/<session>.json`, and
`tmux kill-session` does not remove it — the stale entry keeps answering to those member
names and breaks the next spawn with an ambiguity error. **`maw team up` does not appear to
write one at all.** So run the `ls` and only delete what actually exists; a bare `rm -f`
succeeds either way and teaches you nothing.

Note also that a team created this way does **not** show up in `maw team list` even while it
is alive — do not use that command to decide whether a team is running. `tmux list-sessions`
is the source of truth.

If every step above passes (0, 1, 2, 3, 4, 4b, 5, 5b, 6, 7 — ten, not eight; an earlier version said eight and never said which two did not count), the mechanism is working and the rest of this skill is about
running the team, not standing it up.

**QUICKSTART is the procedure. Gate 0 below is the reference** — same job, more depth on
*why* each check exists. If the two ever disagree, QUICKSTART is the one that has been run;
report the discrepancy.

### What this skill does and does not cover

- **A one-member team is valid.** Nothing requires two. The QUICKSTART uses two only because
  two different models is the case that exposes the engine/model binding. A single verifier,
  scout, or one-off worker is a normal team — drop member B.
- **`up` and `status` are engine-agnostic. `lead`, `dispatch`, and `down --clean` are not** —
  they assume a GitHub-PR-and-tests workflow (issues, PRs, merged branches). A team whose
  members read an inbox and write a verdict, or run measurements, can use `up`/`status` and
  should ignore the other three rather than try to fit them.
- **Gate 0 proves what will BOOT. It says nothing about independence.** If you are standing up
  a verifier to check your own work, this skill cannot tell you whether that verifier is
  meaningfully independent of you — same account, same machine, possibly the same model
  family. Producer-≠-verifier is your call to make and to defend; the engine binding being
  correct is not evidence of it.
- **There is no budget step, and for a permanent lane you need one.** Engines here share
  machine-wide accounts; a codex status bar showing `weekly 77% left` is a shared pool, not
  yours. A one-off team is noise; a standing lane is a budget decision before it is a config
  decision.
- **Requires `python3`** — both `scripts/verify-check.sh` and any step here that parses config
  shell out to it. If your environment is deliberately grep/sed-only, use the raw `maw config`
  and `maw wake --dry-run` commands, which need neither.

> ## 🧭 Test record — what has actually been run, and what has not
>
> 🔴 **This table used to restate run counts and drifted out of step with the one at the top of
> the file.** `[found by a clean-room tester, 2026-08-06]` It gave `up` as 4× where the header
> said 6×, and `down` as "run once on a throwaway repo" while two other places said "never run
> against a real team" and "three live teams" — **four different answers to one question**, all
> under headings that promise what has actually been run. Counts now live in **exactly two
> places** and nowhere else:
>
> | verb | where its coverage is stated |
> |---|---|
> | `up`, `status`, `dispatch`, `lead` | the table at the **top of this file** |
> | `down` / teardown | [`references/teardown.md`](references/teardown.md), per step |
>
> **If you are about to write a run count anywhere else in this skill, don't.** A coverage claim
> that appears twice will disagree with itself the first time either half is updated, and a
> reader deciding whether to trust a verb gets to pick which number they like.
>
> **Everything below the QUICKSTART describing `down`/`lead`/`dispatch` is unverified**, and
> two reviewers found real defects in it (a `head -N` that is a syntax error, a `$N` that is
> never set, a hardcoded `--base alpha`, and a lead-detection rule that contradicts the
> QUICKSTART's own naming rule). Treat those sections as a sketch. `up`, Gate 0 and
> `scripts/verify-check.sh` are the parts with evidence behind them.
>
> Reviewer-reported defect counts, so you can judge whether the list is closed: fresh-agent
> round 1 → 5 blockers / 12 guesses · round 2 → 4 blockers / 10 guesses · atlas → 8 findings ·
> ajfon → 7 defects + a claims audit. **Each round found new ones, so no round is an upper
> bound.** If a step still assumes knowledge you do not have, that is a defect in this
> document, not in you — say which step and what you had to guess.

---

One skill, five verbs. Reads everything from the charter (`ψ/teams/*.yaml`).

```
/oracle-team up                       # spawn tmux panes from charter
/oracle-team up codex3                # spawn specific profile
/oracle-team up --only codex-3        # spawn one member
/oracle-team down                     # safe teardown all coders
/oracle-team down 1,2,3               # partial teardown
/oracle-team down --clean             # teardown + delete merged branches
/oracle-team lead                     # one peek/merge/dispatch/nudge cycle
/oracle-team status                   # peek all, no action
/oracle-team dispatch                 # headless codex exec all open issues
/oracle-team dispatch 1,2,3           # dispatch specific issues
/oracle-team dispatch --model o3      # override model
```

## Two modes

| Mode | Verb | How | Tracking |
|------|------|-----|----------|
| **tmux panes** | `up` | `maw team up` — persistent TUI coders | `maw peek` |
| **headless** | `dispatch` | background Agent → `codex exec` — fire-and-forget | harness notifies on completion |

**Headless** means: no tmux pane, no persistent agent. You spawn a cheap background Agent whose
only job is to run one `codex exec …` to completion and report back. Use
`run_in_background: true` so the Claude Code harness tracks it and notifies you when it finishes
— **never a shell `&`**, which the harness cannot see. (Some older notes call this the
`/forward-bg` pattern; that is just a name for this shape, not a command you can run.)

> 🩹 **Two operational notes recovered on 2026-08-07 during a re-sync.** Both existed in the
> pre-2026-08-06 version of this file and were dropped when `dispatch`/`down`/`lead` were split
> out to `references/` — neither landed in the new home, so they were live in no copy at all.
>
> - **Use the harness's `run_in_background: true`, never a shell `&`.** A backgrounded shell job
>   is **invisible to the Claude Code harness** — nothing tracks it and nothing notifies on
>   completion, so the orchestrator waits on an event that will never arrive.
> - **`omx --madmax` starts working the moment it boots.** It does not idle waiting for
>   instructions the way the other engines do, so a charter prompt for an omx member **must**
>   open with an explicit *"WAIT for a task via `maw hey`"* or the member will begin
>   auto-exploring the repo before it has been told what the job is.

---

## Step 0: Init — resolve charter dynamically

```bash
date "+🕐 %H:%M %Z (%A %d %B %Y)"
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
```

If a profile name is given (e.g. `up codex3`), resolve charter:
```bash
CHARTER="$ROOT/ψ/teams/team-${PROFILE}.yaml"
```
Otherwise **make the operator name the team — do not guess.**

```bash
# ❌ NOT `ls …/*.yaml | head -1`. [found by tars 2026-08-06] Real houses have many charters
#    — 11 in ajfon-teams, 20+ in lucifer — so picking the first alphabetically selects the
#    wrong team silently and every later step operates on it.
if [ -z "${TEAM:-}" ]; then
  echo "Charters here — pass TEAM=<name> (the FILE STEM, see below):" >&2
  # .json charters are real and a *.yaml glob silently misses them — lucifer's .maw/teams
  # holds 67 files, 2 of which are .json. [lucifer 2026-08-06]
  ls "$ROOT"/ψ/teams/*.yaml "$ROOT"/ψ/teams/*.json \
     "$ROOT"/.maw/teams/*.yaml "$ROOT"/.maw/teams/*.json 2>/dev/null | xargs -rn1 basename >&2
  exit 1
fi
CHARTER=$(ls "$ROOT"/ψ/teams/"$TEAM".yaml "$ROOT"/ψ/teams/"$TEAM".json \
             "$ROOT"/.maw/teams/"$TEAM".yaml "$ROOT"/.maw/teams/"$TEAM".json 2>/dev/null | head -1)
[ -f "$CHARTER" ] || { echo "no charter for '$TEAM'" >&2; exit 1; }
```

> 🔑 **`maw team up <team>` matches the FILE STEM, not the `name:` inside the charter.**
> `[found by tars 2026-08-06]` A file called `research-team.charter.yaml` whose `name:` is
> `research-team` must be brought up as `maw team up research-team.charter` — using the
> `name:` gives `charter not found`. Several houses use the `<name>.charter.yaml` convention
> (9 files in atlas, 1 in tars), so this bites immediately there.

**Session: take it from the charter, not from where you happen to be sitting.**

```bash
# ❌ NOT `tmux display -p '#S'`. [found by tars 2026-08-06] That is the session the OPERATOR
#    is in. Anyone driving a team from outside its session — the normal case for
#    `status`/`lead` across houses — then peeks the wrong session every time and sees nothing.
SESSION=$(grep -m1 '^session:' "$CHARTER" | sed 's/^session:[[:space:]]*//')
: "${SESSION:=$TEAM}"        # charters may omit it; maw defaults to the team name
```

From the charter, extract:
- `name` → TEAM name (for `maw team up/down`)
- `project` → REPO slug (for `gh pr list`, `maw wake`)
- `members` → list of codex roles + engines
- `session` → override if set in charter
- `headless.model` → default model for dispatch
- `headless.reasoning_effort` → default reasoning effort
- `headless.engines` → per-coder codex exec command

Count coders (exclude lead where `worktree: false`):
```bash
CODERS=$(python3 -c "
import re
text = open('$CHARTER').read()
roles = re.findall(r'role:\s*(\S+)', text)
# A lead is a member with worktree: false — NOT one literally named 'lead'.
# The QUICKSTART tells you to prefix every role with the team name, so a lead in a
# conforming charter is called e.g. 'myteam-lead' and an == 'lead' test never matches it.
# [found by ajfon 2026-08-06] With that test, the lead falls into CODERS and \`down\` kills it.
blocks = re.split(r'(?=^\s*-\s*role:)', text, flags=re.M)
leads = {m.group(1) for b in blocks
         if (m := re.search(r'role:\s*(\S+)', b)) and re.search(r'worktree:\s*false', b)}
print(' '.join(r for r in roles if r not in leads and r != 'lead'))
")
```
⚠️ **This block itself is still untested.** The lead-detection rule was wrong until a reviewer
read it; assume it carries similar defects and check before relying on it.

> 📌 **Corrected 2026-08-06** — this used to add *"and every verb below except `up`, has never
> been run."* No longer true, and leaving it would have made the file understate its own
> evidence: `down` has since been executed end-to-end against **three** live teams, teardown
> Steps 0–5 have all been run at least once, and `dispatch`'s `codex exec` path completed real
> work. See `references/teardown.md` for what is run, sandboxed, or still only reviewed —
> **that file is the authority on coverage, not this line.**

Parse the subcommand from `$ARGUMENTS`:
- First token = verb (`up`, `down`, `lead`, `status`, `dispatch`)
- Remaining tokens = verb-specific args

---

## Verb: `up` — Spawn tmux panes from charter

Idempotent: skip live, relaunch dead, create missing.

### Gate 0: bind engine + model, then prove it (MANDATORY, before preflight)

> Path-agnostic — everything below computes from YOUR repo and YOUR team. Nothing here
> depends on another oracle's files or scripts. `[verified 2026-08-06 · maw-rs 325db65 ·
> proven end-to-end by booting two live workers onto two different models]`

**The one rule:** `engine:` in a charter is a *lookup key*, not a setting. It only takes
effect if `commands.<name>` exists in a config layer visible **from the directory the worker
runs in**.

> 📐 **"Visible from where" — the phrase this document leans on hardest, and it has two
> answers depending on the verb.** `[prism 2026-08-06: they lost real time to this]`
>
> | verb | resolves the layer from |
> |---|---|
> | `maw team up` / `maw wake` | the **member's** path (`--repo-path`) |
> | `maw team spawn` | the **caller's** cwd — not the member's `--cwd` |
>
> So a layer at the team state root alone is invisible to `spawn`, and a layer in your repo
> alone is invisible to the members. Teams using both verbs need **two byte-identical
> copies** — one in the repo (also gets it into git, which fixes the machine-move problem)
> and one at the members' common ancestor.
>
> **"Registered" also means one specific thing:** an exact key in `commands`. `engines` is a
> different map that nothing reads, and glob keys only apply on the window-name path — never
> to an `engine:` lookup.
>
> 🟢 One piece of good news from prism's run: `maw team spawn` **fails loudly** here
> (`engine '<x>' not resolvable — known: […]`, exit 1) because it goes through an exact-key
> resolve that throws. It is `wake`'s fallthrough chain that substitutes silently. `maw wake` has no `--model` flag anywhere in the binary, so **a model can only
live inside the alias's command string.** One alias name = one command = one model. Two
members naming the same alias get the same model, necessarily.

`model:` in a charter never reaches the pane. When `engine:` is present it is inert. When
`engine:` is **absent**, it is worse than inert — the model string is used as the engine
lookup key and silently misses (see 0c). Treat `model:` as a comment; put the real value in
the alias.

When the key is missing maw does **not** error. It falls through silently:
`commands.<engine>` → `commands.<window-name>` → `commands.<oracle>-oracle` → glob →
`commands.default`. Exit 0, no warning, and the pane boots a *working but wrong* engine.

#### 0a. Where the layer file goes

The layer must sit in an **ancestor of the worker's working directory** — not where you
happen to be typing. Find where your workers actually run, then pick:

| Your members' worktrees | Put the layer at |
|---|---|
| `<repo>/agents/<role>` (in-repo) | `<repo>/.maw/maw.config.60.json` — also in git, survives a machine move |
| `~/.maw-teams/<team>/<role>` | `~/.maw-teams/<team>/.maw/maw.config.60.json` |
| `${YOUR_STATE_ROOT}/<role>` | `${YOUR_STATE_ROOT}/.maw/maw.config.60.json` |

- **Filename must match `maw.config.<digits>.json`.** A plain `maw.config.json` (no digits)
  is **never read as a layer** — it is a legacy fallback used only when no numbered file
  exists anywhere. Editing it looks like it worked and changes nothing.
- **Pick N > 50.** Global user config is N=50; higher N merges later and wins. If two layers
  share the same N, the **deeper** one wins — you do not need a unique number.
- **Scope it exactly to the team.** Never put a layer at a directory that is an ancestor of
  *other* teams (e.g. `~/.maw-teams/.maw/`) — that silently binds engines for teams that
  never asked for them.
- **`maw config set` cannot do this** — it supports only `node|port`. Write the file.
- If you also use `maw team spawn` (not just `up`), that verb resolves from the **caller's
  cwd**, so the layer is needed in **both** places: your repo *and* the team state root.

```bash
mkdir -p "$LAYER_DIR"          # "$ROOT/.maw"  or  "$TEAM_STATE_ROOT/.maw"
cat > "$LAYER_DIR/maw.config.60.json" <<'JSON'
{ "commands": {
    "codex-hi":  "codex --model <MODEL-A> --ask-for-approval never --sandbox danger-full-access",
    "codex-lo":  "codex --model <MODEL-B> --ask-for-approval never --sandbox danger-full-access",
    "claude-hi": "claude --model <MODEL-C> --dangerously-skip-permissions"
} }
JSON
```

Charter then references the **alias name** — and `model:` is documentation only:

```yaml
members:
  - role: coder-1
    engine: codex-hi
  - role: reviewer
    engine: claude-hi
```

#### 0b. Prove it — a check that can actually fail

`maw team preflight` and `maw team up --dry-run` are **both green on this defect**. The
dry-run echoes the engine out of the charter you just wrote; it cannot fail. Ask maw what
will *really* launch, from the worker's own path:

```bash
cd "$MEMBER_DIR"                    # the directory that member will run in
maw config sources                  # your layer file MUST appear in this list
maw config explain commands.codex-hi   # "FINAL null" ⇒ not registered from here

# decisive: the real launch line, plus a control that is deliberately unregistered
# <member-identity> = the member's `name:` from the charter (falls back to `role:` if unset)
maw wake <member-identity> --no-attach --dry-run -e codex-hi           --repo-path "$MEMBER_DIR"
maw wake <member-identity> --no-attach --dry-run -e __no_such_engine__ --repo-path "$MEMBER_DIR"
```
Ignore the session name in that output. Standalone `maw wake --dry-run` invents one
(`would wake … in session '76-<name>'`) that has nothing to do with your `session:` — only the
`command:` line matters here.

🔴 **"Both outputs are the same" is NOT the test. Three different failures produce it, and
two have nothing to do with your engine.** `[prism 2026-08-06, running it against a live cell]`

| real cause | what you see | naive reading |
|---|---|---|
| the alias genuinely is not read | two identical `command:` lines | correct ✅ |
| you omitted the positional target | `usage: maw wake <target\|all> …` twice | "engine not read" ❌ |
| the target is a team ROLE, not a registered oracle | `wake: repo not found for <x>` twice | "engine not read" ❌ |

**The real test: both invocations must actually PRODUCE a `command:` line, and those two lines
must differ.** No `command:` line at all means the probe never ran — that is UNVERIFIED, not
a failed engine, and chasing it as a config problem wastes the time prism lost to it.

```bash
real=$(maw wake "$A" --no-attach --dry-run -e team-codex-hi      --repo-path "$DIR" 2>&1 | sed -n 's/^ *command: *//p')
ctrl=$(maw wake "$A" --no-attach --dry-run -e __no_such_engine__ --repo-path "$DIR" 2>&1 | sed -n 's/^ *command: *//p')
if   [ -z "$real" ] || [ -z "$ctrl" ]; then echo "UNVERIFIED — probe did not resolve; check the target name and --repo-path"
elif [ "$real" = "$ctrl" ];            then echo "FAIL — alias not read"
else                                        echo "OK — $real"; fi
```

> ⚠️ `maw wake` resolves its target against the **oracle registry**, not against your team's
> roles. A member name that is not a registered oracle only resolves because `--repo-path`
> is supplied — omit it and you get `repo not found`, which is the second false positive
> above. `scripts/verify-check.sh enginecheck` does not have this hole: it reads the merged
> config directly and uses the wake probe only as corroboration.

#### Scripted form — shipped with this skill, no other repo needed

```bash
VC=~/.claude/skills/oracle-team/scripts/verify-check.sh

bash "$VC" enginelist <dir>               # WHICH aliases exist here — start with this

bash "$VC" enginecheck <charter|team>     # whole roster, per member, from each member's path
bash "$VC" engineone <engine> <dir>       # ONE engine, ONE directory — for single-worker gates
bash "$VC" modelprobe <alias> <dir>       # 💸 SENDS A REAL TURN — the only thing that proves
                                          #    the account can serve that model. Costs quota.
bash "$VC" teamclosed <team>              # is the team really gone (asks tmux first, not maw)
bash "$VC" selftest                       # run this before trusting any of the above
```

### The other scripts shipped in `scripts/` — status, because it is not what you'd assume

`[lucifer 2026-08-06: none of these were referenced anywhere in this document, while one of
them describes the exact failure mode at 9-10 roles that the document lists as a symptom with
the wrong cause]`

| script | what it is | status **on this machine** |
|---|---|---|
| `setup-codex-home.sh`, `codex-setup.ts`, `codex-local.ts`, `codex-local.sh` | give each codex member its **own `CODEX_HOME`**, seeded from a shared credential pool at `~/.codex-team/<N>` | 🔴 **no-ops.** `~/.codex-team/` is empty, so it finds no pool, creates nothing, prints a paste-ready engine block pointing at directories that do not exist — and **exits 0** |

**Why you may still need what they do.** Without a per-member `CODEX_HOME`, every codex member
shares `~/.codex`. `maw team preflight` flags this (`✗ CODEX_HOME isolation: … share
/home/user/.codex`) and the script headers describe losers of the SQLite/PID race booting to a
**bare shell** — which is the "bare shell prompt" symptom in Step 6 whose cause this document
otherwise gets wrong. Observed fine with 2-5 concurrent members; the scripts were written after
17+ raced on one home.

⚠️ **A pinned `CODEX_HOME` also loses `~/.codex/config.toml`** — including `model` and
`model_reasoning_effort`. Copy or symlink that file into each home, or pin both in the alias.

```bash
```

Both emit **anchored machine keys at column 0** alongside the human output, so a gate can
`grep` rather than scrape prose:

```
enginecheck.member: <role> PASS|FAIL|UNVERIFIED engine=<name> resolved=<cmd> [pinned=no]
enginecheck.engine: <name> PASS|FAIL|UNVERIFIED resolved=<cmd> scope=resolved|dir-absent [answered-from=<path>]
enginecheck.scope: out-of-scope=model-served,prompt-delivery,account-quota
enginecheck.unverified: [<comma-list>]          ← EMPTY when this run had no variable gaps
overall: PASS|FAIL|UNVERIFIED requires-post-boot-verification=true
```
Every line is emitted on every run, in that order, with `overall:` last. `enginecheck.member:`
repeats once per member in roster mode and is absent in `engineone`; `enginecheck.engine:`
is the reverse.

**Two namespaces, deliberately separate** `[ajfon, 2026-08-06]`:

| line | meaning |
|---|---|
| `enginecheck.scope: out-of-scope=…` | things this tool **can never** measure, whatever it is run against. A constant. **Not** a result. |
| `enginecheck.unverified: …` | gaps **in this particular run** — `unpinned-alias`, `member-unresolvable`, `answered-from-ancestor=<path>`, `asked-dir-does-not-exist`. **Empty means none.** |

> Why they are split: an earlier version put both in one line, hardcoded, so **every run
> always carried an UNVERIFIED field**. The rule below then evaluated true forever, the
> three-value contract collapsed to FAIL / not-FAIL, and `overall: PASS` became a value that
> was printed but must never be trusted. A criterion that always returns the same answer
> discriminates nothing — the same defect this whole check exists to prevent, pointed the
> other way.

### 🔴 `overall:` means ENGINE RESOLUTION ONLY. It is never total readiness.

**Do not gate on `grep '^overall:'` alone.** `overall: PASS` can and does print on the same
output as `model-served=UNVERIFIED` — the alias resolves to the command you asked for, and
nothing here knows whether your account will serve that model. A consumer reading only
`overall:` admits a worker that was never confirmed. That is the same false-green shape this
whole check exists to prevent, one level up.

**Parse four fields. This is the interface:**

| field | read it as |
|---|---|
| `overall:` | engine resolution — **necessary, never sufficient** |
| `enginecheck.unverified:` | **non-empty ⇒ this run had a real gap.** Empty ⇒ it did not. |
| `pinned=` | `no` ⇒ you got the right binary **by luck**, via `default`; a window-name change breaks it |
| `scope=` | `dir-absent` ⇒ the answer came from `answered-from=<path>`, **not** the directory you asked about |

> **Rule: `overall: PASS` + non-empty `enginecheck.unverified:` ⇒ treat as UNVERIFIED,
> never PASS.** `[atlas T4543 contract, 2026-08-06; bound to the variable namespace after
> ajfon showed the original form could never be false]`
>
> `enginecheck.scope: out-of-scope=…` is **not** part of that rule. It is a standing
> declaration of what the tool cannot see at all, and folding it in makes the rule
> unfalsifiable. It still tells you the real thing: **only a post-spawn banner settles whether
> the account serves the model.**

> 🔬 **Measuring rc: never through a pipe.** `[holmes 2026-08-06 — they nearly filed a bug
> against this tool because of it]`
> ```bash
> verify-check.sh engineone __no_such__ "$PWD" | tail -6; echo $?   # → 0, that is TAIL's rc
> verify-check.sh engineone __no_such__ "$PWD" >/tmp/o 2>&1; echo $? # → 1, the script's rc
> ```
> A pipeline's status is its **last** command's, so piping to `tail`/`head`/`grep` to read the
> output silently discards the verdict you were checking. This bites reviewers hardest: it
> makes a correct tool look like it inherited the rc=0 disease, and a phantom bug report costs
> more than a real one — it sends the author to fix something that is not broken. It is also
> the same trap that produced four real defects in this skill's own history.

`rc` 0=PASS · 1=FAIL · 2=UNVERIFIED. **UNVERIFIED is not a pass** — it means the check could
not answer, which is different from answering "fine". Concretely: `engineone <alias> <dir>`
where `<dir>` does not exist yet returns **UNVERIFIED rc=2**, not FAIL — it answered from an
ancestor, so it cannot tell "alias absent" from "we looked in the wrong place". A gate that
runs before `mkdir` must not read that as a bad alias. A directory that *does* exist and has
no such alias still returns FAIL rc=1.

> **Parser compatibility, measured — not asserted** `[ajfon, 2026-08-06]`. The
> `requires-post-boot-verification=true` suffix on `overall:` was added after these lines were
> first published. It does **not** break `grep '^overall: PASS'` or `awk '$1=="overall:"'`. It
> **does** break `grep '^overall: PASS$'` and `grep -x 'overall: PASS'`. If you anchored to
> end-of-line, drop the anchor.

Requires `maw` and `python3` on PATH. If your gate deliberately stays on grep/sed only, use
the raw `maw` commands above instead — they need neither.

After spawning, confirm on the engine's own UI (`maw peek <session>:<window>`) that the
status bar shows the model you asked for. That is the only layer of evidence that covers
whether the account can actually serve that model — nothing before it does.

#### 0b-2. Also check the CHARTER → PLAN path. Gate 0b structurally cannot.

Gate 0b tests the **alias → command** path: you supply `-e` by hand, so it proves the alias
resolves. It never touches the **charter → plan** path — what engine maw decides each member
gets *from your charter*. A charter can pass 0b completely and still boot the wrong engine.

```bash
maw team up "$TEAM" --dry-run       # read the `engine` COLUMN, member by member
```

🔴 **Everything under `defaults:` is dead except `worktree`.** `[lucifer 2026-08-06, clean A/B
plus a grep of the whole crate; I reproduced both]` maw resolves engine as
`-e flag → member.engine → member.model → "claude"` — **`defaults` is not in that chain.**

The dead list, checked against the source rather than guessed:
`defaults.engine` · `defaults.branch` · the entire `engines:` map · `model:`.
The **only** survivor is a bool derived from whether the key `defaults.worktree` exists
(`team_preflight_checks.rs:41`). Everything else is parsed, stored, and never consulted.

> 🪞 **There is a green unit test whose NAME is the false-confidence surface.**
> `team_core.rs:763` is called
> `team_charter_preserves_defaults_engines_and_coerces_yaml_worktree_true` and asserts that
> `defaults.get("branch")` and `engines.get("omx-1")` round-trip through the parser
(`"omx-1"` is maw's own fixture string in that test — **not an engine you can use**; nothing
called `omx` exists on this machine). That is
> true and proves only that the **parser stores** them — never that anything **consumes**
> them. A suite passing with a test named *preserves_defaults_engines* reads like "defaults
> and engines work". This is how a dead field survives with CI green, and it is the same shape
> as a script that exits 0 having done nothing: **the check ran, it passed, and it cannot see
> the thing it appears to cover.**

```
charter: defaults: {engine: codex-xhigh}, no per-member engine:
plan:    supervisor-watchdog  claude  …  -e claude     ← codex-xhigh appears nowhere, rc=0
control: same defaults + per-member engine: codex-medium
plan:    frontend-engineer    codex-medium  …          ← per-member DOES reach
```

Their exposure: **45 of 60 charters** carrying a `defaults.engine` have **zero** per-member
`engine:` — the dominant pattern, not an edge case. A house whose `defaults.engine` happens to
be `claude` never notices, because the substitution matches what it wanted.

⚠️ `enginecheck` reports this charter as FAIL — but until this was found it named the wrong
cause, because it parses via `maw team plan`, which has **already** substituted `claude`. It
now reads `defaults:` from the file directly and says so before anything else. A tool that
inherits the substitution it is meant to detect cannot see it.

> ✅ **The detector is validated at n=65, not by me.** `[lucifer 2026-08-06]` Run across their
> whole corpus: **65 charters · 45 warned · 20 quiet · 0 mismatches.** The 45 are exactly the
> pure-`defaults` set; of the 20 quiet, 15 have per-member `engine:` and 5 have no `defaults:`
> at all. **Both arms matter and the quiet arm is the harder one** — a detector that shouts at
> everything is as useless as one that never shouts. I had verified it at n=2.

#### 0c. Naming and worktree — the two things that make `maw team up` exit 1

`maw team up` builds `maw wake <member-name> ... -e <engine>` per member. That wake must
resolve, and two independent rules decide whether it does:

- **Member names must be unique across the WHOLE FLEET, not just your team.** A generic
  name collides with every other team using it and wake dies on ambiguity:
  ```
  wake: 'verifier' matches multiple targets. Found nearby:
    1. session job2b-oracle-scan  2. session previews-port  3. session t4526-rs-fixes  ...
  ```
  `team up` then exits 1 while `--dry-run` stayed green. Prefix every role with the team:
  `refract-scope`, `st-alpha` — not `coder-1`, `verifier`, `reviewer`.

- **Give every member a `worktree:` path — or a `cwd:`, either works.** `team up` resolves
  it as `member.worktree` → falls back to `member.cwd` → falls back to **the identity string**
  (`team_up_helpers.rs:236`). With `worktree: false` it sends no `--repo-path` at all, so wake
  resolves the name against the oracle registry and boots the member **in whatever repo that
  name is registered to — not your team's repo.** Your config layer is invisible there and
  the alias silently does not apply. With a real path, `team up` passes `--repo-path`, which
  both puts the member in the right tree *and* removes the requirement that the name be a
  registered oracle. The path must already exist.

- **🔴 `team up` does not expand `${VARS}` in a path — not even exported ones.**
  `[verified 2026-08-06 by running it]` A charter with `cwd: ${TEST_ROOT}/ev-a` passes
  `--dry-run` showing the literal string, then dies at spawn:
  ```
  team spawn: canonicalize <repo>/${TEST_ROOT}/ev-a failed: No such file or directory
  ```
  The variable is treated as a literal directory name and appended to the repo path. If your
  team's layout is defined by an environment variable — a common pattern for cells whose
  state lives outside any repo — **`maw team up` cannot launch it at all**, and you need
  your own launcher that expands the path before calling maw. Use literal or repo-relative
  paths in any charter you intend to bring up with this skill.

- **🔴 A member with `model:` and no `engine:` uses the MODEL STRING as its engine name.**
  `team up` resolves engine as `-e flag` → `member.engine` → **`member.model`** → `"claude"`
  (`team_up_helpers.rs:235`). So `model: gpt-5.5` alone produces `wake -e gpt-5.5`, which is
  not a registered command, and falls through silently. `model:` is genuinely inert *only*
  when `engine:` is also present. Never write `model:` without `engine:`.

```
charter:  - role: mfb-a
            model: gpt-5.5        # no engine:
dry-run:  mfb-a  mfb-a  gpt-5.5  missing  would fresh wake -e gpt-5.5
                        ^^^^^^^ the model string became the engine name
```

```yaml
members:
  - role: st-alpha
    name: st-alpha            # team-prefixed, unique fleet-wide
    engine: t-codex-sol
    worktree: agents/st-alpha  # exists, and makes the layer visible
```

#### 0d. Clean up after a team, or the next one fails

`maw wake` registers the session in `~/.maw/fleet/<session>.json`, and **`tmux kill-session`
does not remove it.** Stale entries keep answering to their member names and cause the
ambiguity failure above for whoever spawns next. After tearing a team down:

```bash
tmux kill-session -t "$SESSION"
rm -f ~/.maw/fleet/"$SESSION".json      # otherwise the names stay claimed
```

#### 0e. Traps confirmed by running them

- **`maw team up -e <engine>` overrides every member's charter engine.** One flag flattens a
  mixed-engine team (`a=codex-hi, b=claude-hi` → both become the flag's value). Omit `-e`
  unless you mean "everyone on this one engine".
- **`maw team resume` respawns every role as `claude`** — it never forwards engine. Prefer
  `maw team up`, which reads the charter.
- **`engines:` inside a charter is a dead field.** maw's parser stores it; no code reads it.
  Engine commands belong in the config layer.
- **✅ Invented member names are fine — as long as the member has a path.** `[verified by two
  independent testers, 2026-08-06]` A name that is in no registry resolves normally once
  `worktree:`/`cwd:` gives `team up` a `--repo-path`:
  ```
  wake <invented-name> --dry-run -e codex --repo-path <dir>   → resolves, rc=0
  wake <invented-name> --dry-run -e codex                     → wake: repo not found for <name>, rc=1
  ```
  This matters most for exactly the case you are probably here for: **a brand-new lane — a
  verifier, a scout, a one-off cell — has an unregistered name by definition.**

  > ❌ **This bullet previously said the opposite** — "member identities must already be
  > wake-resolvable… you cannot invent arbitrary member names" — which contradicted 0c three
  > bullets above and made readers with a new lane stop before starting. It was never true,
  > not merely stale: it described the no-path case as if it were the general rule. Grepping
  > for outdated wording would never have found it — only running the case did.

  **Without a path there are TWO different failures, and one of them exits 0.**
  `[lucifer 2026-08-06 — my first correction of this bullet named only the first form and
  called the second nonexistent, which over-corrected in the other direction]`
  ```
  wake: repo not found for <name>                                    rc=1
  wake: '<name>' was not found exactly. Found nearby: …              rc=0   ← fuzzy candidates exist
  ```
  The second is the common one on a populated fleet, and **`maw team up` swallows it**: the
  name half-matches something, nothing spawns, and the exit code says fine.

  Name collisions are still real when a member has **no** path (see the fleet-unique rule in
  0c), so keep prefixing roles with the team name. With a path, a collision-prone name like
  `verifier` also resolves — measured in dry-run only.
- **Reasoning effort does not come from the alias.** For codex it comes from
  `$CODEX_HOME/config.toml` (`model_reasoning_effort`); the status bar shows both
  (`<model> xhigh`). Pin it there or add the flag to the alias.
- **First boot can stall on codex's "Update available!" prompt** and never reach the engine
  UI. This is why the post-spawn peek below is mandatory, not optional.

> This is also the root cause of the "`Opus` in the status bar when the charter said codex"
> failure listed further down — carried here as a symptom for a long time without its cause.

```bash
maw team preflight "$CHARTER"
```

🔴 **Do NOT stop just because preflight is red.** It cannot pass before a spawn: `spawn
ordering: session does not exist before spawn` is true by definition, and `codex trust:
missing trusted project entry` fires on any member directory codex has not been told to trust
(see the QUICKSTART Step 3 note — that is also the cause of the trust prompt in Step 6).

Read preflight for the checks that *are* meaningful pre-spawn — role uniqueness, existing
artifact collisions, CODEX_HOME isolation, worktree path collisions — and stop on **those**.
The gate that decides whether to proceed is Gate 0b above, which fails for exactly one reason.

With `--only`:
```bash
maw team up "$TEAM" --only "$ONLY_ROLE"
```

Without:
```bash
maw team up "$TEAM"
```

### Verify step (MANDATORY after spawn)

Poll each coder until its banner is real, then check. **Do not use a fixed sleep** — measured
boot-to-real-banner ran ~25s to ~35s (n=3, one machine, one codex version), and an earlier
version of this block said 10s, which is short enough to read `model: loading` and believe it.

```bash
for ROLE in $CODERS; do
  echo "=== $ROLE ==="
  for _ in $(seq 30); do
    tmux capture-pane -p -t "${SESSION}:${ROLE}-oracle" | grep -q 'model:.*loading' || break
    sleep 3
  done
  # grep -n . not tail: the banner is in the pane's UPPER half, tail prints blank padding
  tmux capture-pane -p -t "${SESSION}:${ROLE}-oracle" | grep -n . | head -30
done
```

For each coder, verify against charter:

| Check | How to verify | Bad sign |
|-------|---------------|----------|
| Engine correct? | peek shows `gpt-5.5` not `Opus` | Claude Code booted instead of the codex engine you asked for |
| Model right? | peek status bar: `gpt-5.5 xhigh` | `low` = prompt misunderstanding |
| Worktree right? | peek shows `agents/1-codex-N` | wrong dir or main checkout |
| Waiting for task? | idle prompt or "waiting for maw hey" | auto-exploring (whoami, inbox, oracle ls) |
| Alive? | status bar visible | bare shell `❯` = engine died |

**If any check fails:**
1. Kill the bad coder: `tmux kill-window -t "=${SESSION}:${ROLE}-oracle"`, then verify with `tmux list-windows`. **Not `maw tmux kill "$SESSION:$ROLE-oracle"`** — that subcommand exists but resolves only the numeric `session:INDEX.PANE` form, so a window *name* never matches (rc=1, "pane not found", window survives).
2. Clean worktree: `mv agents/1-${ROLE} /tmp/cleanup-...`
3. Fix root cause (config, engine name, reasoning_effort)
4. Relaunch: `maw team up "$TEAM" --only "$ROLE"`
5. Re-verify

**Common failures:**
- `Opus 4.8` / `Opus 5` in status bar when the charter asked for codex → **the engine name
  was not registered in `commands`, so it was silently discarded and resolution fell through
  to `commands.default` (which is claude).** Gate 0 catches this before you spawn; the old
  advice "use `codex-tN` instead" only worked because those names happened to be registered.
  `[verified 2026-08-06: wake coder-1 -e codex-xhigh → claude --model claude-opus-5]`
- `gpt-5.5 low` → CODEX_HOME config has `model_reasoning_effort = "low"` → set to `xhigh`
- Garbage files in worktree → model too dumb to parse prompt → fix reasoning_effort
- Auto-exploring → some engines start working the moment they boot, before your first `maw hey`
  → put "WAIT for maw hey before doing anything" in the charter prompt

Report table: role, engine (expected vs actual), model, worktree, status (pass/fail).

---

## Verbs `down` / `dispatch` / `lead` — moved to `references/`

🔴 **Split out on 2026-08-06 because every one of them was defective on first execution** --
`down` committed a `.env` file, `down --clean` deleted an unrelated branch, `dispatch` built a
malformed command under `--dangerously-bypass-approvals-and-sandbox`, `lead` produced
`--base ''`. All are fixed there.

- **[`references/teardown.md`](references/teardown.md)** — `down`, universal. Applies to every
  team, PR or not. Peer-confirmed as needed by atlas, ajfon, prism and lucifer, two of whom
  have leftovers right now that these steps target.
  ⚠️ **The per-step evidence claim that used to sit here was stale against `teardown.md` itself**
  (this file said Steps 0/3/4 unexecuted; that file's own table says Steps 0, 2, 2b, 5 ran on
  2026-08-07, Step 3 ran by ajfon, Step 1 only partially, Step 4 never). **Two surfaces, two
  different claims, shipped in one session** — the shape this file-set warns about. Corrected
  2026-08-07: **do not restate that table here. Read it in `teardown.md`, which owns it.**
- **[`references/pr-workflow-verbs.md`](references/pr-workflow-verbs.md)** — the `gh`-dependent
  half of `dispatch` and `lead`: GitHub-issue intake, PR review and merge. Author-run only, and
  the issue-intake path has never been run at all.

> ⚠️ A second-order finding worth carrying: the rule *"merge greens immediately (standing
> approval)"* was removed from `lead` and **survived in this file's rules list** until ajfon's
> read caught the neighbouring problem. Fixing one site is not fixing the claim —
> `grep` every surface.

They also assume a workflow this skill does not otherwise require: GitHub issues in, PRs out,
members in disposable git worktrees. If your team returns a verdict or a measurement, they do
not apply -- two reviewers reported exactly that.

**Everything above this line -- Gate 0, `up`, and `scripts/verify-check.sh` -- is the part with
evidence behind it.**

## Verb: `status` — Read-only peek

Same as `lead` Step 1 + Step 2 (peek + PR list), but takes NO action.
No dispatch, no merge, no nudge. Just report.

```bash
# 🔴 FIRST — one command, whole team, read-only. A stalled team looks exactly like a busy team
#    in the per-role peek below, because a permission question renders as a quiet screen.
bash ~/.claude/skills/oracle-team/scripts/verify-check.sh permstall "$SESSION"   # rc=1 ⇒ someone is blocked

for ROLE in $CODERS; do
  echo "=== $ROLE ==="
  maw peek "${SESSION}:${ROLE}-oracle" 2>&1 | grep -n . | head -12
done
echo "--- PRs ---"
BASE_DETECTED=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
BASE="${BASE:-${BASE_DETECTED:-main}}"
gh pr list --repo "$PROJECT" --base "$BASE" --state open 2>/dev/null || echo "no PRs"
```

---

## Principles

1. Lead orchestrates, coders code — lead NEVER writes code itself.
2. Charter is the source of truth — session, members, engines, headless config all from yaml.
3. `tmux kill-window -t "=$SESSION:$W"` for windows, then VERIFY it is gone — never `maw team down --only` (broken). `maw tmux kill` takes only `session:INDEX.PANE`, never a window name, and piping it hides the rc=1.
4. Never `git worktree remove --force` — commit-save first.
5. Branches survive worktree removal → committed work is never lost.
6. Always brace zsh vars: `"${SESSION}:${ROLE}-oracle"` not `$SESSION:$ROLE`.
7. Never push or merge to `main`. **`alpha` is not a universal base** — it was this author's
   repo's convention, hardcoded here and in `lead`. ajfon has no `alpha` and no PRs at all.
   Detect the base (`git symbolic-ref --short refs/remotes/origin/HEAD`), fall back to `main`.
8. 🔴 **Never merge a PR without human approval.** An earlier line here read *"merge greens
   immediately (standing approval)"* — it was removed from `lead` on 2026-08-06 and **survived
   in this list**, which is exactly the single-surface-fix failure this file warns about
   elsewhere. It violated both prism's owner rule and this repo's own golden rules. Report
   merge candidates; a human merges.
8b. 🔴 **Readiness expires — verify on a loop, not at a gate.** Every check in this file above
    `permstall` is measured at boot. A member that booted clean, took a turn, and started
    working can be sitting on `Do you want to proceed?` twenty minutes later, silent and
    indistinguishable from thinking. On 2026-08-08 a six-member team had **five blocked,
    including its own lead**, and the lead had verified correctly — at boot. Run
    `permstall "$SESSION"` on the same cadence you peek, and **sweep every pane; do not sample
    a few.** The prevention is upstream (a bypass token in the alias, see Gate 0's third
    dimension); this is the detection that has to exist anyway.
9. NO-GAP dispatch: next task in same message as done confirmation.
10. Context handling differs per engine — check before assuming auto-compaction.
11. `SendMessage` does not reach a tmux pane — always use `maw hey`, and prefer
    `verify-check.sh relay` so the target is validated and `delivered` is actually read.
12. For Rust: build gate = `cargo test` + `cargo clippy -- -D warnings`.
13. Headless dispatch uses background Agent (run_in_background=true), NOT shell `&`.
14. Haiku wraps codex exec — cheap wrapper, real work is codex (gpt-5.5/o3).
15. Escalate to `/oracle-team up` (tmux panes) when headless coders need interactive debugging.

---

<!-- ═══ REPO-LOCAL APPENDIX — not part of the global skill ═══
     Everything above this line is a verbatim copy of ~/.claude/skills/oracle-team/SKILL.md.
     To re-sync: `cp ~/.claude/skills/oracle-team/SKILL.md <this file>` then re-append this block.
     Keep it last and self-contained so the copy stays a clean overwrite. -->

## 📌 Repo-local: where this repo's engine/model evidence lives

The global skill is deliberately **path-agnostic** — it will not point at any one oracle's files.
This repo does have that evidence, so the pointer lives here instead of upstream:

- **`ψ/teams/ENGINE-AND-MODEL.md`** — full resolution ladder, the upstream `maw-rs` findings
  (`team_up_apply.rs:149` forwards only `-e <name>`; `maw wake` has no `--model` flag; `model:`
  is validated then dropped at `:186`; `engines:` is a map nothing reads), and the
  `<repo>/.maw/maw.config.60.json` registration pattern.
  `[verified 2026-08-06 · maw-rs 325db65]`
  ⚠️ `325db65` is **not reachable from any `Soul-Brews-Studio/maw-rs` head** — it is fork-local.
  `[verified 2026-08-07: merge-base --is-ancestor against upstream/main and upstream/alpha]`
  The citation still names the source that was read; it does **not** name shipped upstream code.

- **`ψ/teams/VERIFY-THE-CHECK.md`** — the checklist this repo runs before writing "ตรวจแล้ว",
  including D15.x on scopes that truncate silently, and why `maw team down`'s own `rc=0`
  is not evidence (see `references/teardown.md` Step 1).

- **`ψ/teams/TEACHING-LEDGER.md`** — who currently holds which claim, so a retraction can be
  routed rather than announced into the air.

## 📌 Repo-local: verbs proven by real use, and by whom

`[verified 2026-08-07 — live teams, not dry runs]`

| verb | status | evidence |
|---|---|---|
| `up` + `bootverify` | ✅ real use | ajfon (`ajfon-rag-bench`) — caught codex sitting on an update dialog |
| `dispatch` | ✅ real use | codex-fanout (`realtest-verbs-v1`) — 2 workers, ground truth matched their reports |
| `lead` | ✅ real use | same run |
| `down` | 🔴 **broken** | same run — see `references/teardown.md` Step 1 D1/D2/D3 |
| `status` / `list` | 🔴 do not trust | pre-existing; `verify-check.sh teamclosed` instead |

**Standing rule from arnon (2026-08-07):** do not call any of this "done" on the strength of a
dry run, an audit, or a green `enginecheck`. Those find documentation and logic bugs only.
A verb is proven for the version that was actually exercised — and each repair has, so far,
tended to carry the next defect inside it.
