# AI Worklog

This file records meaningful AI-assisted engineering decisions and real failures. It intentionally omits trivial command-by-command noise.

## Entries

### 2026-08-13: Project initialization

- Task: Establish SafePaste methodology and preserved v1 requirements before writing product code.
- Instruction given: Build SafePaste as a privacy-aware local browser sanitizer with stakeholder analysis, v1 specification, harness, evaluations, red-team testing, and honest evidence.
- What AI produced: Initial repository structure, README skeleton, stakeholder map, `SPEC_v1.md`, `AGENTS.md`, and changelog skeleton.
- Accepted: Pending verification and commit.
- Manual changes: None at this stage.
- Failure or surprise: Existing workspace is a different Flutter project with unrelated modified debug-symbol files, so SafePaste is being created in a contained `SafePaste/` subdirectory.
- Resulting control: Stage and commit only SafePaste files; do not modify or revert unrelated workspace changes.

### 2026-08-13: Initial sanitizer and unit tests

- Task: Build the smallest local browser sanitizer and deterministic unit tests.
- Instruction given: Implement isolated sanitizer logic and test required categories including password JSON and API key JSON.
- What AI produced: Static UI, `src/sanitizer.js`, and `tests/test-sanitizer.js`.
- Accepted: Accepted as v1 evidence, but not final behavior.
- Manual changes: None before the first test run.
- Failure or surprise: The first unit test run passed 16/18 tests but failed quoted JSON key cases for `"password":"..."` and `"apiKey":"..."`.
- Resulting control: Preserve the failure in v1 results and add/fix JSON key handling after the initial evaluation snapshot.

### 2026-08-13: Harness verification

- Task: Manually invoke the SafePaste pre-commit hook before committing v1 evidence.
- Instruction given: Run the hook against the staged SafePaste files.
- What AI produced: The hook printed `grep: command not found` and exited with status 0.
- Accepted: Not accepted as final harness behavior.
- Manual changes: None before recording the failure.
- Failure or surprise: The hook depended on `grep`, which was not available in the shell used for invocation, so the hook did not actually scan.
- Resulting control: Preserve the failure in `evals/results_v1.md`; update the hook after the v1 snapshot to use `git grep` or fail closed.

## Most Important AI Failures

### Initial sanitizer missed quoted JSON credential keys

AI behavior
-> The first sanitizer implementation handled unquoted credential keys but missed quoted JSON keys.

Why it was problematic
-> JSON logs and config snippets are common, and missing those values could leak credentials.

How it was detected
-> Unit tests failed 2 cases, evals failed EV-004 and EV-005, red-team failed RT-P02, and the security reviewer reported SR-001.

Human response
-> Preserve the failing evidence before fixing.

Permanent control added
-> JSON credential tests and eval cases remain in the suite.

### Initial hook depended on unavailable `grep`

AI behavior
-> The pre-commit hook used `grep` without verifying the command existed.

Why it was problematic
-> Manual invocation in this environment printed `grep: command not found` and exited successfully, giving a false sense of protection.

How it was detected
-> Running `sh SafePaste/.claude/hooks/pre-commit.sh` against staged files.

Human response
-> Preserve the failure in v1 results before fixing.

Permanent control added
-> Planned hook update to use `git grep` or fail closed.
