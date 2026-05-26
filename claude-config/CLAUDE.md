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

## Secrets

Treat any secret encountered in prompts, outputs, or files as compromised — tell the user to rotate it.

- Do NOT hardcode API keys, passwords, PATs, certificates, or connection strings.
- Do NOT log full request/response bodies that may contain secrets without redaction.
