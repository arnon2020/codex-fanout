---
name: team-coder
description: The dispatch loop a coder on this team runs — how to turn a dispatch into a finished, evidenced branch. Use when you have been given a coding task with done-criteria and need to know how to run it to completion, what to do when the criteria cannot be met, and what shape the PR and the report take.
---

# team-coder

> **Why this is a skill and not a line in `AGENTS.md`** — **criteria go in `AGENTS.md`;
> procedures are skill-shaped.** `[the line is lucifer's, 2026-08-08 — sharper than the version
> that was here first, which could only say what did NOT belong in a skill, never why]`
>
> A criterion is short, always relevant to the role, and **something the worker must not be free
> to decide does not apply** — so it belongs in the file that is injected on every turn. A
> procedure is long, needed only while that work is actually happening, and loading it always is a
> tax on every turn of that role's context. This file is procedure end to end. Nothing here
> restates `AGENTS.md`; where the two touch, `AGENTS.md` wins.

---

## 1. Before you write anything: restate the done-criteria

A dispatch has done-criteria whether or not they were labelled. Find them and **write them back in
one line** as the first thing in your working notes. If you cannot state them in one line, you do
not have a task yet — reply asking for the criterion, and say what is ambiguous.

**If your restatement is wider than the dispatch, you have already widened the work.** Narrow it.

## 2. Own the loop

You are not asked to make an attempt. You run `implement → run it → read the failure → fix` until
the criteria are met or you are genuinely stuck. The lead is not watching your intermediate steps
and does not want them.

- **Run before you believe.** Code that looks right is not evidence, and the loop does not exit
  on "it should work now".
- **Two failures of the same command is the stop signal**, not the third and fourth. Change your
  approach or report BLOCKED.
- **Do not silently redefine the task to something you can finish.** A workaround that changes what
  was asked is a BLOCKED with a suggestion, not a DONE.

## 3. Commits

- One logical change per commit. A commit that mixes a fix with a rename is a commit nobody can
  revert.
- **Commit as you go, not at the end.** An uncommitted worktree is work that does not exist —
  a branch is the only thing that survives your pane dying.
- The message says what changed and why, not which files you touched. `git diff` already knows the
  files.

## 4. When the task needs something outside your worktree

This is the most common real blocker here, and the wrong move is always the same: reaching for it.

1. Say **what** you need and **why the task cannot proceed without it**.
2. Give the **exact path** you looked at.
3. Report BLOCKED and stop. Do not copy the file in, do not recreate it from memory, do not
   `cd` to it.

**A file that is missing from your worktree may exist on `main`** — branches are cut at a point in
time. That is information for the lead, not a puzzle for you to solve.

## 5. The PR

Open one only when the dispatch asked for one. Otherwise hand back the branch and its sha.

- Target `alpha`. Never `main`. Never merge it yourself.
- **Body = what changed · why · the evidence you already collected in §6.** No summary of the
  diff — the diff is right there.
- If the branch contains anything the dispatch did not ask for, either remove it or name it
  explicitly in the body. Unannounced extra changes are what makes a lead re-review everything.

## 6. What you hand back

The report format itself is in `AGENTS.md`. What is coder-specific is **which evidence counts**:

| you changed | the evidence is |
|---|---|
| behaviour | the command you ran and its output, including the exit code |
| something tested | the test name and the actual pass/fail line, not "tests pass" |
| any file at all | the commit sha — nothing else proves the work survived |

Attach the evidence you collected **during** the loop. Evidence assembled afterwards from memory is
how a report ends up describing a run that never happened.

## 7. Partial work

Say which part is done and report the rest as BLOCKED, with the sha of what landed. A partial
result reported honestly is useful and gets picked up. A partial result reported as DONE costs the
lead a re-check of everything you touched, and they will find it.
