# Changelog

All meaningful changes must describe what changed, why it changed, stakeholder impact, and mapped requirement.

## v0.1

Changed:
Created the preserved stakeholder map, `SPEC_v1.md`, README skeleton, `AGENTS.md`, and initial worklog.

Why:
The project requires specification-first development and traceable stakeholder analysis before product implementation.

Stakeholder impact:
Clarifies privacy, diagnostic usefulness, compliance, and support-recipient trade-offs before implementation choices are made.

Mapped requirement:
Methodology phase 0 and phase 1.

## v1.0

Changed:
Implemented the first local-only SafePaste UI, isolated sanitizer, unit tests, eval runner, 36-case eval set, red-team runner, and v1 results.

Why:
The project needed a smallest complete browser implementation before meaningful testing and iteration could happen.

Stakeholder impact:
Gave developers a usable review flow while giving security and privacy stakeholders concrete behavior to evaluate.

Mapped requirement:
R1-R15, PS1-PS10, A1-A6.

Known v1 failures:
Unit tests and evals showed that quoted JSON credential keys were not redacted. The security reviewer also found Basic/Token Authorization header gaps, `PWD` false positives, narrow static scan coverage, and a portability issue in the pre-commit hook.

## v1.1

Changed:
Credential rules now redact quoted JSON keys such as `"password":"..."`, `"apiKey":"..."`, and `"client_secret":"..."`.

Why:
Unit tests failed `redacts password JSON` and `redacts API key JSON`; evals failed EV-004 and EV-005; red-team case RT-P02 failed.

Stakeholder impact:
Improves protection for people whose data appears in JSON logs and addresses security/compliance concerns about common credential formats.

Mapped requirement:
R5, R12.

## v1.2

Changed:
Authorization header detection now redacts Basic and Token schemes in addition to Bearer and bare long header values.

Why:
Security-review finding SR-002 showed that `Authorization: Basic ...` and `Authorization: Token ...` could remain visible.

Stakeholder impact:
Reduces credential leak risk for security/compliance stakeholders and data subjects.

Mapped requirement:
R5.

## v1.3

Changed:
Removed `pwd` from broad password aliases and added a regression test/eval for `PWD=/workspace/project`.

Why:
Security-review finding SR-003 showed that `PWD` path values were redacted as passwords, harming diagnostic usefulness.

Stakeholder impact:
Improves developer trust and support-recipient usefulness while still redacting `password` and `passwd` keys.

Mapped requirement:
R12, R14.

## v1.4

Changed:
Static privacy evals now discover production `.html`, `.css`, and `.js` files recursively while excluding docs, tests, evals, history, and harness metadata.

Why:
Security-review finding SR-004 showed that a hardcoded production-file list could miss future source files.

Stakeholder impact:
Improves security/compliance confidence that privacy invariants remain checked as the project grows.

Mapped requirement:
PS1-PS4, AI1, AI2, AI6.

## v1.5

Changed:
The pre-commit hook now uses `git grep` against staged SafePaste production/harness files and no longer writes matches to a fixed temp file.

Why:
Manual hook invocation found `grep: command not found` with exit status 0, and security-review finding SR-005 identified fixed-temp-file risk.

Stakeholder impact:
Makes the harness more portable and avoids leaving possible secret matches in a shared predictable temp path.

Mapped requirement:
PS5 and harness component 3.

## v1.6

Changed:
External-resource eval scanning now checks all production `.html`, `.css`, and `.js` files, not only `index.html`.

Why:
Final security-review finding showed EV-032 could miss a future external URL in CSS or another production script.

Stakeholder impact:
Improves security/compliance confidence that no remote scripts, fonts, imports, or CDN references are introduced.

Mapped requirement:
PS3, AI1.

## v1.7

Changed:
The pre-commit hook now handles staged file paths with spaces using a `read -r` loop and no longer depends on `mktemp`.

Why:
Final hook testing with a staged file named `hook path smoke.js` showed that `mktemp` was unavailable in this environment.

Stakeholder impact:
Improves hook portability and reduces the chance that a staged file is skipped because of whitespace in its path.

Mapped requirement:
PS5 and harness component 3.

## v1.8

Changed:
Added Session 7 grader methodology with an automated exact/property grader, a human rubric, a grader comparison, EV-040 for localhost, and a localhost unit regression test.

Why:
The grader comparison showed that automated IP redaction can pass while human diagnostic-usefulness judgment still needs discussion for `Localhost: 127.0.0.1`.

Stakeholder impact:
Makes the privacy vs diagnostic usefulness conflict more visible for developers, support recipients, and security reviewers without changing SafePaste's default local-only redaction behavior.

Mapped requirement:
R6, R10, R12, Human-Centered AI Session 7.

## v1.9

Changed:
IPv4 detection now requires complete IPv4 tokens and preserves larger dotted numeric sequences such as `1.2.3.4.5`.

Why:
Manual Test 2 F1 showed that the previous detector redacted a valid-looking four-octet substring inside a larger dotted numeric sequence, producing `[REDACTED_IP_ADDRESS].5`.

Stakeholder impact:
Improves developer trust and diagnostic usefulness by reducing false-positive redaction.

Mapped requirement:
R6, R12, R14.

## v1.10

Changed:
IPv4 loopback addresses in `127.0.0.0/8` are now preserved by default while other valid IPv4 addresses remain redacted when IPv4 redaction is enabled.

Why:
Manual Test 2 F2 and the grader comparison showed a real stakeholder/specification conflict: automated privacy grading considered localhost redaction successful, while human diagnostic-usefulness grading considered it unnecessarily destructive.

Stakeholder impact:
Improves troubleshooting usefulness for developers and support recipients while retaining privacy defaults for non-loopback IPv4 addresses.

Mapped requirement:
R6, R10, R12.

## v1.11

Changed:
Linux home-directory usernames in `/home/name/...` are now redacted by replacing only the username segment; non-home paths such as `/var/log/nginx/error.log` and `/usr/local/bin` remain unchanged.

Why:
Manual Test 2 F3 showed `/home/usman/projects/safepaste/server.log` remained visible even though the accepted username/path policy covers reasonably detectable local home paths.

Stakeholder impact:
Improves privacy for people whose local usernames appear in logs while preserving diagnostic path context for support recipients.

Mapped requirement:
R13, R12, R14.
