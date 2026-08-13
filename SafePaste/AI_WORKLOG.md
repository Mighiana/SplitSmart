# AI Worklog

This file records meaningful AI-assisted engineering decisions and real failures. It intentionally omits trivial command-by-command noise.

## Entries

### 2026-08-13: Project initialization

- Task: Establish SafePaste methodology and preserved v1 requirements before writing product code.
- Instruction given: Build SafePaste as a privacy-aware local browser sanitizer with stakeholder analysis, v1 specification, harness, evaluations, red-team testing, and honest evidence.
- What AI produced: Initial repository structure, README skeleton, stakeholder map, `SPEC_v1.md`, `AGENTS.md`, and changelog skeleton.
- Accepted: Accepted after SafePaste files were staged, committed, and pushed while unrelated workspace changes were left untouched.
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

### 2026-08-13: Security-review-driven fixes

- Task: Address real v1 failures and security-review findings.
- Instruction given: Fix JSON credential redaction, Basic/Token Authorization headers, `PWD` false positives, static scan coverage, and hook portability without weakening tests.
- What AI produced: Updated sanitizer rules, unit tests, eval cases EV-037 through EV-039, red-team cases RT-P13 through RT-P15, recursive production scanning, and a revised hook.
- Accepted: Accepted after local tests passed.
- Manual changes: None outside the documented patches.
- Failure or surprise: Browser automation through the in-app browser failed because the Node REPL kernel hit a filesystem permission error outside the workspace.
- Resulting control: Added `evals/run-ui-smoke.js` to verify UI wiring with a mocked DOM/clipboard and documented that OS clipboard permission remains not browser-verified.

### 2026-08-13: Final harness hardening

- Task: Address final security-reviewer low-severity harness findings.
- Instruction given: Make external-resource eval scanning fully recursive and verify the pre-commit hook handles staged filenames with spaces.
- What AI produced: Recursive external-resource scanning and an initial `mktemp`-based hook path loop.
- Accepted: Partially; the eval fix was accepted, but the hook needed another revision.
- Manual changes: Removed a temporary staged file named `hook path smoke.js` after the hook test.
- Failure or surprise: The revised hook still failed in this environment because `mktemp` was unavailable.
- Resulting control: Replaced the `mktemp` approach with a pipe/read loop that handles spaces and does not rely on `grep` or fixed temp files; reran the hook successfully against the staged spaced filename.

### 2026-08-13: Session 7 grader extension

- Task: Extend SafePaste evaluation methodology with automated and human-style graders.
- Instruction given: Add two grader styles without removing the existing eval set, include localhost as a borderline case, compare grader verdicts, and document any specification implications.
- What AI produced: `evals/graders/exact-property-grader.js`, `evals/graders/human-rubric.md`, `evals/graders/grader-comparison.md`, EV-040, and a localhost unit regression test.
- Accepted: Accepted after grader and test runs.
- Manual changes: Human rubric judgments were applied manually by the AI-assisted development evaluator, not by an external study participant.
- Failure or surprise: Automated grading passed EV-040, while the human rubric marked it `NEEDS DISCUSSION` because localhost redaction harms debugging context.
- Resulting control: Updated `SPEC_FINAL.md` and `CHANGELOG.md` to document localhost redaction as a human-in-the-loop judgment call.

### 2026-08-13: Manual Test 2 follow-up

- Task: Continue the engineering loop from real manual Test 2 results.
- Instruction given: Fix IPv4 substring false positives, resolve loopback policy, investigate Linux home path username coverage, update graders/docs, and rerun all checks.
- What AI produced: `evals/manual_test_2.md`, new unit regressions, EV-041 through EV-047, sanitizer fixes, grader updates, and specification/changelog/design-decision updates.
- Accepted: Accepted after unit tests, full evals, graders, red-team, UI smoke, static checks, secret scan, hook, commit, and push passed.
- Manual changes: None outside the documented code and evidence patches.
- Failure or surprise: Local reproduction confirmed all three user-observed findings before code changes. The Linux `/home/` detector existed conceptually, but a leading word-boundary prevented matching paths that start with `/home/`.
- Resulting control: Complete-token IPv4 detection, loopback preservation policy, Linux home-path username tests/evals, and updated grader comparison.

### 2026-08-13: Manual Test 3 follow-up

- Task: Continue the engineering loop from real manual Test 3 results.
- Instruction given: Preserve prior evidence, keep `SPEC_v1.md` unchanged, investigate structured username coverage and version/IP false positives, update graders/docs, and rerun checks.
- What AI produced: `evals/manual_test_3.md`, new unit regressions, EV-048 through EV-057, structured username redaction, narrow version-field IPv4 preservation, grader updates, and specification/changelog/design-decision updates.
- Accepted: Accepted after unit tests, full evals, exact/property grader, red-team, UI smoke, static checks, and secret scan passed.
- Manual changes: None outside the documented code, test, eval, and evidence patches.
- Failure or surprise: Adding the structured `user=` policy intentionally changed the expected handling of JSON `"user":"sam"` in the password JSON test and RT-P02; it is now redacted as a username rather than preserved as harmless context.
- Resulting control: Explicit username-field tests/evals, arbitrary-name preservation tests/evals, version-field IPv4 false-positive tests/evals, and updated grader comparison for the F5 automated-vs-human disagreement.

### 2026-08-13: Manual Test 4 follow-up

- Task: Continue the engineering loop from real manual Test 4 results.
- Instruction given: Preserve prior evidence and `SPEC_v1.md`, fix prose version-like IPv4 false positive, review username marker consistency, add tests/evals, update docs/graders, and rerun checks.
- What AI produced: `evals/manual_test_4.md`, new unit regressions, EV-058 through EV-064, direct `Version`/`Release` prose context handling, current marker standardization on `[REDACTED_USERNAME]`, and spec/changelog/design/grader updates.
- Accepted: Accepted after unit tests, full evals, exact/property grader, red-team, UI smoke, static checks, secret scan, hook, commit, and push passed.
- Manual changes: None outside the documented code, test, eval, and evidence patches.
- Failure or surprise: `version:` and `release:` already preserved before the fix, but direct `Version 1.2.3.4` and `Release 1.2.3.4` did not. Current output also used two username markers for the same concept.
- Resulting control: Prose version-context regression tests/evals, non-version prose IP redaction tests/evals, and unified current username marker expectations.

### 2026-08-13: Manual Test 5 follow-up

- Task: Continue the engineering loop from real manual Test 5 results.
- Instruction given: Preserve prior evidence, keep `SPEC_v1.md` unchanged, fix the standalone IPv4 false negative before sentence punctuation, add tests/evals, update evidence, and freeze the core sanitizer after full regression success unless another high-severity privacy/security regression appears.
- What AI produced: `evals/manual_test_5.md`, unit regressions for sentence-ending IPv4 redaction and preservation guards, EV-065 through EV-071, exact/property grader coverage for EV-065, EV-069, and EV-071, and a narrow IPv4 token-boundary fix.
- Accepted: Accepted after focused unit tests, evals, and automated grader checks passed; final full-suite verification is recorded in `evals/results_final.md`.
- Manual changes: None outside the documented code, test, eval, and evidence patches.
- Failure or surprise: The IPv4 validator and policy were correct, but the regex boundary rejected IP candidates followed by any dot, so a normal sentence-ending period caused `192.168.20.50.` and `10.1.2.3.` to remain visible.
- Resulting control: Sentence-punctuation IPv4 unit tests, EV-065 and EV-066 privacy evals, EV-069 through EV-071 preservation guards, and a core sanitizer freeze after F7 unless a high-severity privacy/security regression is found.

### 2026-08-13: Manual Test 6 final methodology close-out

- Task: Complete the final SafePaste methodology pass after real manual Test 6 results.
- Instruction given: Treat the core sanitizer as frozen unless a high-severity privacy/security failure is found; record `Firmware 1.2.3.4 installed successfully.` as a known borderline limitation and human-vs-automated-grader disagreement rather than adding another keyword exception.
- What AI produced: `evals/manual_test_6.md`, EV-072, updated exact/property grader selection, human rubric judgment, grader comparison, design decision, red-team limitation note, final spec limitation clarification, README known limitation, presentation evidence, and final results refresh.
- Accepted: Accepted after complete unit tests, evals, exact/property grader, red-team, UI smoke, static/privacy scan, and secret scan were rerun.
- Manual changes: None outside the documented evidence and documentation patches.
- Failure or surprise: The automated grader passes the firmware case under current privacy behavior, while the human rubric marks it `NEEDS DISCUSSION` because it is likely firmware-version context.
- Resulting control: The firmware case is preserved as a known limitation and grader disagreement. No sanitizer feature change was made because this is not a high-severity privacy/security regression.

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
-> Hook updated to use `git grep`; a later `mktemp` portability failure was also fixed with a pipe/read loop.

### Intermediate hook fix depended on unavailable `mktemp`

AI behavior
-> The first final hook hardening used `mktemp` to handle filenames safely.

Why it was problematic
-> Manual hook verification printed `mktemp: command not found` and exited with failure.

How it was detected
-> Running the hook against a staged file named `SafePaste/src/hook path smoke.js`.

Human response
-> Remove the temporary file and patch the hook again.

Permanent control added
-> Hook now uses `git diff --name-only | while IFS= read -r file` with explicit status handling.

### Automated and human graders disagreed on localhost

AI behavior
-> The automated property grader treated `Localhost: 127.0.0.1` as a successful default IP redaction.

Why it was problematic
-> A human rubric found that redacting localhost can damage diagnostic usefulness even when privacy/security properties pass.

How it was detected
-> Session 7 grader comparison across EV-040.

Human response
-> Manual Test 2 adopted a policy change: preserve IPv4 loopback addresses in `127.0.0.0/8`.

Permanent control added
-> EV-040, loopback preservation tests, `human-rubric.md`, `grader-comparison.md`, and a `SPEC_FINAL.md` refinement that preserves `127.0.0.0/8`.

### IPv4 detector redacted substrings inside larger dotted numeric sequences

AI behavior
-> The IPv4 regex matched `1.2.3.4` inside `1.2.3.4.5`.

Why it was problematic
-> It created a false positive and produced confusing output: `[REDACTED_IP_ADDRESS].5`.

How it was detected
-> Manual Test 2 F1 and local reproduction.

Human response
-> Add a regression test and eval before fixing.

Permanent control added
-> Complete-token IPv4 detection plus EV-041.

### Linux home path usernames were not redacted

AI behavior
-> The path detector did not redact `/home/usman/...` because its leading boundary prevented matching a path starting with `/home/`.

Why it was problematic
-> The accepted path policy covers reasonably detectable local home-directory usernames.

How it was detected
-> Manual Test 2 F3 and local reproduction.

Human response
-> Add Linux home-path and non-home-path regression tests before fixing.

Permanent control added
-> Linux home-path username redaction plus EV-044 through EV-047.

### Structured username fields remained visible

AI behavior
-> The sanitizer preserved `username=musman24`, `user_name=alice_dev`, and `user=bob-admin`.

Why it was problematic
-> Explicit account identifiers have a strong privacy signal and can identify the person whose data appears in logs.

How it was detected
-> Manual Test 3 F4 and local reproduction.

Human response
-> Treat `SPEC_v1.md` as ambiguous, resolve the final policy in `SPEC_FINAL.md`, and add failing tests/evals before fixing.

Permanent control added
-> Structured username unit tests plus EV-048 and EV-049, with EV-050 and EV-051 preserving arbitrary names.

### Version fields were over-redacted as IP addresses

AI behavior
-> The sanitizer redacted `release=1.2.3.4` as an IP address.

Why it was problematic
-> The automated syntactic redaction looked privacy-protective, but human review found it removed useful software version context.

How it was detected
-> Manual Test 3 F5, local reproduction, and the grader-disagreement analysis.

Human response
-> Preserve IPv4-shaped values only in narrow version-related fields; continue redacting explicit IP fields.

Permanent control added
-> Version-field unit tests plus EV-052 through EV-057.

### Prose release/version context was over-redacted as an IP address

AI behavior
-> The sanitizer redacted `Release 1.2.3.4 passed QA yesterday.` as an IP address.

Why it was problematic
-> Automated syntactic IP redaction looked privacy-protective, but human review found it removed obvious release-version context.

How it was detected
-> Manual Test 4 F6 and local reproduction.

Human response
-> Extend the existing version-context policy only to direct `Version` and `Release` prose associations, without broad NLP or disabling IP redaction.

Permanent control added
-> Prose version-context unit tests plus EV-058 through EV-064.

### Standalone IPv4 addresses before sentence periods were not redacted

AI behavior
-> The sanitizer preserved `Connection received from 192.168.20.50.` because the IPv4 regex rejected candidates followed by any dot.

Why it was problematic
-> The value was a valid standalone non-loopback IPv4 address in normal network prose, so leaving it visible was a privacy/security false negative.

How it was detected
-> Manual Test 5 F7 and local reproduction, then a failing unit regression and failing evals EV-065 and EV-066 before the production fix.

Human response
-> Treat this as an implementation bug against the existing final policy, not a new specification ambiguity; add failing tests/evals before changing `src/sanitizer.js`.

Permanent control added
-> IPv4 sentence-punctuation boundary tests plus EV-065 through EV-071.

### Ambiguous firmware version context is over-redacted

AI behavior
-> The frozen sanitizer redacts `Firmware 1.2.3.4 installed successfully.` as an IP address.

Why it was problematic
-> A human evaluator may reasonably interpret `1.2.3.4` as firmware version context, so redaction can reduce diagnostic usefulness.

How it was detected
-> Manual Test 6 and local reproduction.

Human response
-> Record the case as a known limitation and human-vs-automated-grader disagreement; do not add a speculative keyword exception.

Permanent control added
-> EV-072, `manual_test_6.md`, human rubric and grader-comparison entries, and a documented sanitizer freeze unless a high-severity privacy/security regression is found.

### Username replacement labels were inconsistent

AI behavior
-> The sanitizer used `[REDACTED_USER]` in home paths and `[REDACTED_USERNAME]` in structured username fields.

Why it was problematic
-> The two labels represented the same conceptual category, which made current product output and grading evidence less consistent.

How it was detected
-> Manual Test 4 consistency review and local reproduction.

Human response
-> Standardize current product, tests, evals, and live docs on `[REDACTED_USERNAME]`.

Permanent control added
-> Updated path username tests/evals and documented that historical evidence files preserve prior observed labels.
