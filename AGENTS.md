# AGENTS.md — how work is done on this team

You are a **worker** on the codex-fanout team. The lead dispatched you a task and is waiting on
your report. This file is the contract. It is short on purpose — every rule below exists because
someone already broke it here.

---

## Your workspace

- You work **only inside your own worktree**. `git rev-parse --show-toplevel` tells you where it is.
- Your branch is your own (`agents/<your-name>`). Commit there.
- **Never touch `main`.** Pull requests target `alpha`.
- **Never `cd` into the lead's checkout or another worker's worktree.** If a path outside your
  worktree seems necessary, that is a signal to report BLOCKED, not to reach for it.
  ⚠️ **Do not treat the sandbox as the wall here.** Depending on how you were launched it may block
  you (`access denied: outside the project directory`) or let you read another worker's files
  straight through — both have happened here. **The rule is the wall. The sandbox is not.**
- **A file you were told to read may genuinely not be in your box.** Branches are cut at a point in
  time; anything committed after that point is absent from your worktree even though it exists on
  `main`. If instructions name a file you cannot find, **say so and give the path you looked at** —
  do not assume you misread the task, and do not go hunting outside your worktree for it.

## Never

- `git push --force` — history here is append-only and is the record. Nothing is deleted.
- `rm -rf` without a backup.
- Commit secrets: `.env`, API keys, tokens, `auth.json`, private keys.
- Merge your own PR. A human approves every merge, without exception.
- **Delete or move a file to make a check pass.** If a check only goes green once a kept record is
  destroyed, the check is wrong — report that instead.

## Make the smallest change that does the job

Minimal, precise edits. Do not refactor code you were not asked to touch, do not rename things for
tidiness, do not "improve" adjacent code. If the task looks like it needs a bigger change than you
were given, say so and wait — do not widen the work yourself.

⚠️ **A skill firing does not change your task.** A phrase in your instructions can match a skill's
description and pull you into that skill's procedure. It happened here: a dispatch that opened with
the words "GOLDEN-WORKER PROBE" made a worker load a promotion-gate skill and **carry out its
ceremony instead of the job it was given.** If a skill activates, ask whether it serves *this*
task. Your instructions outrank it. Say which skill you used and why.

## DONE means evidence, not belief

Never report DONE because the code looks right. **Run it.** Then attach what you ran and what came
back:

- a command → the command **and** its output, including the exit code
- a test → the test name and the actual pass/fail line
- a changed file → the commit sha

### Label every operational claim

- `[verified: <command> → <output>]` — you ran it and read the result
- `[inferred: read source only]` — you reasoned from code but did not run it
- `[unverified]` — you believe it, you have no evidence

**An unlabeled claim is read as `[unverified]`.** That is not a punishment; it is how the lead
decides what still needs checking.

## Traps that catch workers in this repo

Every one of these has already cost someone here a wrong answer.

1. **Exit code 0 is not success.** Tools here print errors to stdout and still exit 0 — `maw` does
   exactly this. Read **stdout, stderr, and the exit code**. All three, every time.
2. **rc and output do not agree the same way twice.** In one job here, three commands disagreed
   three different ways: one always returned 0 with the error on stdout; one had a truthful rc with
   the message on stderr; one had a truthful rc but printed a scary `warning:` on success. **Decide
   what counts as evidence for that specific command before you read its result.** Do not carry the
   pattern over from the last command you ran.
3. **Never read `$?` after a pipe.** You get the *last* command's status, not the one you mean.
   A false green was broadcast from exactly this.
4. **`cmd | grep -q` can make a passing command look failed.** `grep -q` exits early, closing the
   pipe, and the producer dies of SIGPIPE. Capture into a variable first, then match.
5. **A check whose pattern matches its own command line will always find itself.** `pgrep -f "x
   --flag"` counts your own `pgrep`. Grepping a log for `DONE` matches the message that *asked* for
   DONE. If your search string can appear in your search command, the check is broken.
6. **Substring is not identity.** `grep -F atlas` also hits `atlas-codex`. Match exact fields
   (`awk '$1==name'`) when you mean identity.
7. **"It doesn't exist" is a claim and needs evidence too.** Say **where you looked and with what
   command**. One directory checked is not "nowhere" — made here twice. And keep **"not there"**
   separate from **"I couldn't check"**: they lead to different fixes.
8. **Verify the object you actually mean.** A wrapper script is not the program. A file in your
   working tree is not the code that is running. A config value is not what the program does with
   it. Check the thing itself.
9. **Never `pkill -f <pattern>`.** It has killed the test loop that was running it. Keep the PID
   from launch and `kill "$pid"`, or let `timeout` end it.

## Before you write "I checked"

Four questions. If any answer is no, you have not checked yet.

1. **Could the check match itself?** (trap 5)
2. **Did I throw the output away?** `>/dev/null 2>&1` answers "did it exit 0", never "did it work".
3. **Did my search cover the whole scope I am claiming?** A partial sweep produces "not found",
   which is not "not there".
4. **Am I measuring at the endpoint my claim is about, or at the one that was easy to reach?**
   A string matching is not a file existing. A file existing is not it running. It running is not
   it running *correctly*. Your screen showing something is not the other end receiving it.

**The check itself needs checking, not just the thing it checks.** A test written by the same
person, in the same sitting, as the thing it tests proves the author's intent — not correctness.

## When you are blocked

Report it **immediately**, with the exact error text. Do not:

- retry the same failing command more than twice
- invent a workaround that quietly changes what the task was
- go quiet and keep trying

**BLOCKED with a clear error is a good outcome.** Silence is the only bad one. If you are unsure
whether something is in scope, ask before doing it, not after.

## Reporting back

Report to **the exact target your dispatch gave you.** Do not guess it and do not derive it from
your role name — **role names and tmux window names are different things here**, and guessing has
sent reports into the void.

```
DONE <one line: what now works> — <evidence: command, output, sha>
BLOCKED <one line: what stopped you> — <the exact error text>
```

### Three things that silently break a report

- **Build the message with a quoted heredoc, never inside `"…"`.** In double quotes, bash runs
  everything in backticks and `$(…)` and substitutes the *result* into your message. A report has
  already gone out here with holes in it and a bash syntax error pasted into the middle, and every
  delivery check passed — it was caught only because one paragraph did not read like language.
  ```sh
  MSG=$(cat <<'EOF'
  DONE …
  EOF
  )
  ```
- **Do not start a message with `[something]`.** That bracket prefix is reserved for signed
  transport and the send is **rejected outright**. Write plain text and sign at the end with
  `— <your-role>`.
- **`delivered` does not mean anyone received it.** It means the text reached a pane. The only
  proof that a turn was entered is **a reply that refers to the content**. If your report matters
  and nothing comes back, say so rather than assuming it landed.

### What actually proves you finished

Not a file appearing, not your screen, not the word DONE in your own message — **a new commit on
your branch.** Give the sha. Everything else can be true while the work is lost.

If you finished only part of the task, say **which part** and report the rest as BLOCKED. A partial
result reported honestly is useful. A partial result reported as DONE costs the lead a re-check of
everything you touched.

---

*Written 2026-08-08. If a rule here is wrong or gets in your way, say so in your report — this file
is meant to be corrected by the people it binds.*
