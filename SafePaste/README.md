# SafePaste

SafePaste is a privacy-aware browser-based log sanitizer for developers, IT support staff, students, and technical users who need to remove sensitive information before sharing technical text.

## Project Status

This repository was built as an academic Human-Centered AI software engineering project. The implementation is intentionally small, local-only, dependency-free, and auditable.

## Motivation

Technical logs often contain useful debugging context mixed with emails, IP addresses, file paths, passwords, API keys, and access tokens. SafePaste helps users review and redact likely sensitive values before sending logs to AI tools, issue trackers, support systems, chat, email, or forums.

## Stakeholders

See [docs/STAKEHOLDER_MAP.md](docs/STAKEHOLDER_MAP.md) for the stakeholder map and explicit conflicts.

## Privacy Architecture

SafePaste runs entirely in the browser with no backend, no database, no analytics, no third-party scripts, no remote fonts, and no storage of pasted logs. Pasted content remains in page memory only while the page is open.

Production files do not use `fetch`, `XMLHttpRequest`, `WebSocket`, browser storage APIs, cookies, IndexedDB, external resources, or `innerHTML`.

## How To Run

Open `index.html` directly in a browser:

```text
SafePaste/index.html
```

Optional local preview for verification:

```text
node evals/static-server.js
```

Then open:

```text
http://127.0.0.1:8765/
```

## How To Test

Run from the `SafePaste/` directory:

```text
node tests/test-sanitizer.js
node evals/run-evals.js
node evals/graders/exact-property-grader.js
node evals/run-red-team.js
node evals/run-ui-smoke.js
```

To write final eval results:

```text
node evals/run-evals.js --write evals/results_final.md
```

## Repository Structure

```text
SafePaste/
  index.html
  styles.css
  app.js
  src/sanitizer.js
  tests/test-sanitizer.js
  evals/
  docs/
  history/v1/
  .claude/
```

## Methodology

The project follows a specification-first engineering loop:

1. document stakeholders and conflicts
2. write a preserved v1 specification
3. create an AI engineering harness
4. implement the smallest complete local product
5. run unit tests, evaluations, red-team checks, and static security checks
6. preserve real failures
7. iterate the implementation and final specification

Key evidence files:

- `SPEC_v1.md`
- `SPEC_FINAL.md`
- `evals/results_v1.md`
- `evals/results_final.md`
- `evals/graders/exact-property-grader.js`
- `evals/graders/human-rubric.md`
- `evals/graders/grader-comparison.md`
- `RED_TEAM.md`
- `AI_WORKLOG.md`
- `CHANGELOG.md`
- `docs/PRESENTATION_EVIDENCE.md`

## Grader Methodology

SafePaste uses two grader styles:

- Automated exact/property grading for deterministic privacy/security behavior, such as "the original secret is gone" and "required harmless context remains."
- Human rubric grading for diagnostic usefulness, readability, proportionality, and shareability.

No external model-as-judge API is used because sending logs to an external model would conflict with the local-only privacy architecture.

Manual Test 2 extended the grader evidence with a real localhost disagreement. SafePaste now preserves IPv4 loopback addresses in `127.0.0.0/8`, while continuing to redact other valid IPv4 addresses when IPv4 redaction is enabled.

Manual Test 3 extended the policy for structured account identifiers and version context. SafePaste now redacts explicit username fields such as `username=`, `user_name=`, and `user=`, preserves arbitrary names in prose, and preserves IPv4-shaped values in narrow version fields such as `release=` while still redacting explicit `client_ip=` and `server_ip=` values.

Manual Test 4 extended version context to direct prose such as `Release 1.2.3.4` and standardized current username markers on `[REDACTED_USERNAME]`.

## Known Limitations

- SafePaste uses deterministic local detection rules rather than cloud services or external AI classification.
- It cannot guarantee every possible secret format is detected.
- Local path detection is intentionally narrow.
- Browser automation failed in this environment, so actual OS clipboard permissions were not verified; `evals/run-ui-smoke.js` verifies that the app calls the Clipboard API.
