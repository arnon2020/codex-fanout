# skillmerge backups — recovered from `/tmp`, 2026-08-07

**Why this folder exists**: commit `9fc1d27` merged the repo-local and global copies of
`oracle-team/SKILL.md`. The pre-merge originals — including **249 repo-unique lines** that exist
nowhere else — were written to `/tmp/claude-1000/skillmerge/` and left there.

A repo whose first principle is *Nothing is Deleted* had the only copy of a unique artifact sitting
in a directory the OS is entitled to wipe. This was Next Step #5 in
`ψ/memory/retrospectives/2026-08/07/17.05_ten-rules-zero-repairs.md`.

`[verified 2026-08-07 21:1x +07: sha256sum of each file compared against its /tmp source — 4/4 OK]`

| file | what it is |
|---|---|
| `repo.bak` | pre-merge repo-local `.claude/skills/oracle-team/SKILL.md` (the 249 unique lines) |
| `global.bak` | pre-merge `~/.claude/skills/oracle-team/SKILL.md` |
| `appendix.md` | the repo-local appendix block kept out of the global skill |
| `msg.txt` | the merge note written at the time |

**Not a deletion of the `/tmp` copies** — they were copied, not moved, and left in place. If they
survive, nothing is lost; if they are wiped, this is the surviving copy.

⚠️ **This folder was also the reason `.gitignore` gained `!ψ/archive/`.** Before that line, moving
something into the archive made it durable *for the session*, not *for the history* — precisely the
failure mode this move was meant to fix. Copying a file into an ignored directory looks identical to
preserving it, and `git commit` exits 0 either way.
