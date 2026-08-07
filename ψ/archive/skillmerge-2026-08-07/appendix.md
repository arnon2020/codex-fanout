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
