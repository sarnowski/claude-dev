# User-wide Claude Code preferences

## Communication

State results and decisions directly. Acknowledge mistakes plainly and fix them.

- Do NOT pad responses with summaries of what was just done — the diff is visible.
- Do NOT make excuses when something failed — say what broke, then fix it.
- Do NOT claim something is fixed when the fix is only a comment change or a rename.

## Effort estimation

When estimating the size of a change, give a rough count of lines added / changed / deleted. That's the only signal that's grounded in something you can actually inspect.

- Do NOT estimate in time ("half a day", "6 hours", "a sprint").
- Do NOT estimate in people, agent-runs, or sessions.
- Do NOT translate code size into wall-clock time. Agent time estimates are wrong every time.

## Engineering principles

### Make failures visible

When something can't work, raise an error with a clear message and let it propagate to logs, traces, and user feedback. This is the opposite of "defensive programming" — apply the BEAM ecosystem's "Let It Crash" mantra everywhere, not just in Erlang/Elixir. We want code to fail loudly when assumptions break, not to paper over the breakage.

- Do NOT add in-memory caches "for performance".
- Do NOT add fallbacks, silent retries, or default values that paper over the real failure.
- Do NOT add try/except that swallows the cause.

(Persisting state in a session, database, or token store is not a cache. If you genuinely think a real cache is warranted, discuss before adding.)

### Implement end-to-end

Finish the task in one go. If it turns out larger than expected, surface that before committing — never ship a partial implementation framed as complete.

- Do NOT defer parts to "next session" silently.
- Do NOT leave TODO comments for work that was in scope.
- Do NOT mark work complete when only some of it landed.

### Target state only

After a refactor, the codebase should look like the new design — old paths removed, callers updated.

- Do NOT keep dead code "just in case".
- Do NOT leave both old and new implementations side by side.
- Do NOT add backwards-compatibility shims unless we are in an actual migration that needs them.

### Code is the source of truth

When documentation disagrees with code, the code wins. Fix the docs to match reality, or fix the code if the documentation describes the correct intent.

- Do NOT write documentation that contradicts the implementation.
- Do NOT write tests for things the framework already guarantees (e.g. metrics export, framework defaults).

## Workflow

### Verify before declaring done

After implementing a feature, exercise it end-to-end the way a user would: run the app locally, hit it with dev scripts / curl / a browser, observe logs. For deployed changes, check pod status and logs.

- Do NOT mark work complete based on "the build passes" alone.
- Do NOT commit code you haven't run.
- If the environment genuinely prevents verification (e.g. browser-only UX you can't see), say so explicitly instead of claiming success.

### Plan only when warranted, delete the plan when done

For larger work, write a plan and align first. Once the work is in, delete planning files — git is the record.

- Do NOT keep `PLAN.md` / `ISSUES.md` / `REMEDIATION_PLAN.md` / similar around after the work has landed.
- Do NOT plan when the task is small enough to just do.

## Documentation

Documentation is load-bearing — bad documentation is worse than none, because it actively misleads. The rules here are not optional.

### Three locations, nothing else

All documentation lives in exactly one of three places. Pick the one a reader would actually look in.

- **README.md** — what the project is: goals, core architecture, data flows, and how to build / test / run locally.
- **CLAUDE.md** — how to work in the project: workflow, code style, agent notes, and a clear **Definition of Done** as a mechanically verifiable checklist (e.g. "all tests green including smoke tests, lint clean, app runs locally").
- **Code documentation** — package-, module-, and function-level docs, inline with the code.

Anything outside these three is forbidden:

- Do NOT create a `docs/` folder, `adrs/` folder, `decisions/` folder, `design/` folder, `architecture/` folder, or any other parallel documentation tree.
- Do NOT write ADRs, RFCs, or standalone design documents. Rationale belongs at the layer it applies to: system-level in README.md, workflow in CLAUDE.md, local design choices in the relevant package or function docs.
- Do NOT leave planning files (`PLAN.md`, `ISSUES.md`, `NOTES.md`, `TODO.md`, etc.) in the tree after work has landed — git is the record.

### Code documentation — describe intent, not behavior

Code is the source of truth for *what* happens. Documentation exists to convey what cannot be read from the code: the goal the code is meant to achieve, the constraint that shaped it, the non-obvious reason behind a choice. Keep it short and precise — every line of doc is a line that has to be kept true.

- Do NOT describe what the code does — the code already says it. Prose that mirrors code drifts out of sync the moment the code is refactored, and stale documentation is actively harmful: it lies to the next reader, who then has to read the code anyway to find out the doc is wrong.
- Do NOT restate type signatures, framework defaults, or things the test suite already verifies. If a reader can derive it from the surrounding code, the comment is noise.
- Do NOT document implementation details on a public API. Describe the contract — what callers can rely on (inputs, outputs, errors, side effects). Implementation details change; the contract should not.
- Do NOT write speculative or aspirational documentation. Describe what *is*, not what someone hopes will be.
- Do NOT leave `// TODO` comments. If something is unfinished, finish it or surface it to the user. In the very rare case a TODO is truly unavoidable, a ticket reference is not required — but the bar for leaving one is high.

### Keep documentation true

Documentation is part of the change. If a change makes existing docs wrong, update or delete them in the same change — never in a follow-up.

- Do NOT update code and leave the surrounding doc comment describing the old behavior.
- Do NOT keep "historical" notes about what the code used to do — git has that.
- When in doubt, delete. A missing doc forces the reader to read the code (which is correct anyway); a wrong doc misleads them (which is worse than having nothing).

## Secrets

Treat any secret encountered in prompts, outputs, or files as compromised — tell the user to rotate it.

- Do NOT hardcode API keys, passwords, PATs, certificates, or connection strings.
- Do NOT log full request/response bodies that may contain secrets without redaction.
