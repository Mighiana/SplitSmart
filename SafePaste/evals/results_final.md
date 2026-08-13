# SafePaste Final Evaluation Results

These results were refreshed after adding the Session 7 grader extension and EV-040.

## Commands Run

- `node tests/test-sanitizer.js`
- `node evals/run-evals.js --write evals/results_final.md`
- `node evals/graders/exact-property-grader.js`
- `node evals/run-red-team.js`
- `node evals/run-ui-smoke.js`

## Unit Test Results

- Total unit tests: 22
- Passed: 22
- Failed: 0

## Exact/Property Grader Results

- Grader file: `evals/graders/exact-property-grader.js`
- Cases graded: 6
- Property checks: 28
- Passed: 28
- Failed: 0

## Human Rubric Results

- Rubric file: `evals/graders/human-rubric.md`
- Cases graded manually: 6
- Overall PASS: 5
- Overall FAIL: 0
- Overall NEEDS DISCUSSION: 1
- Disagreement case: EV-040 localhost.

## Red-Team Results

- Product red-team cases: 15
- Passed: 15
- Failed: 0

## UI Smoke Result

- `node evals/run-ui-smoke.js`: PASS
- Verified with mocked DOM/clipboard: sanitize button, redaction summary, category rendering, copy button Clipboard API call, and clear/reset behavior.
- Not verified: actual OS/browser clipboard permission, because in-app browser automation previously failed with a Node REPL filesystem permission error.

## Differences From v1

- Eval cases increased from 36 to 40.
- V1 eval score: 34/36.
- Final eval score: 40/40.
- Unit tests increased from 18 to 22.
- V1 unit score: 16/18.
- Final unit score: 22/22.

## Grader Finding

EV-040 showed that automated and human-style graders can disagree without a sanitizer defect:

- Input: `Localhost: 127.0.0.1`
- Current output: `Localhost: [REDACTED_IP_ADDRESS]`
- Automated verdict: PASS
- Human verdict: NEEDS DISCUSSION

This led to a final specification clarification: localhost remains redacted by default, but reviewers should treat localhost as a human-in-the-loop diagnostic usefulness judgment and consider disabling IPv4 redaction when exact localhost context matters.

## Remaining Known Limitations

- Pattern-based detection cannot guarantee every possible secret format is removed.
- Local path/username detection is intentionally narrow.
- The app does not classify localhost, private, and public IPv4 ranges differently; all valid IPv4 addresses are redacted by default unless the user disables IP redaction.
- Browser automation could not verify live UI interaction or OS clipboard permission in this environment; local server HTTP 200 and UI smoke tests were verified earlier.

## Summary

- Total eval cases: 40
- Passed: 40
- Failed: 0
- Failure IDs: None

## Case Results

| ID | Layer | Category | Stakeholder | Requirement | Result |
| --- | --- | --- | --- | --- | --- |
EV-001 | product | secret/api-key | Security / compliance team | R5, R12 | PASS
EV-002 | product | secret/api-key | Person whose data appears in the logs | R5, R12 | PASS
EV-003 | product | secret/api-key | Security / compliance team | R5, R12 | PASS
EV-004 | product | secret/api-key | Security / compliance team | R5, R12 | PASS
EV-005 | product | secret/api-key | Security / compliance team | R5, R12 | PASS
EV-006 | product | false-positive | Developer / IT support engineer | R14 | PASS
EV-007 | product | email | Person whose data appears in the logs | R4 | PASS
EV-008 | product | email | Person whose data appears in the logs | R4 | PASS
EV-009 | product | email | Developer / IT support engineer | R4, R12 | PASS
EV-010 | product | email | Developer / IT support engineer | R12, R14 | PASS
EV-011 | product | ip | Person whose data appears in the logs | R6 | PASS
EV-012 | product | ip | Security / compliance team | R6 | PASS
EV-013 | product | ip | Developer / IT support engineer | R6, R14 | PASS
EV-014 | product | ip | Support recipient | R10, R12 | PASS
EV-015 | product | authentication/token | Security / compliance team | R5 | PASS
EV-016 | product | authentication/token | Security / compliance team | R5 | PASS
EV-017 | product | authentication/token | Security / compliance team | R5 | PASS
EV-018 | product | authentication/token | Security / compliance team | R5 | PASS
EV-019 | product | false-positive | Developer / IT support engineer | R14 | PASS
EV-020 | product | false-positive | Support recipient | R12, R14 | PASS
EV-021 | product | false-positive | Developer / IT support engineer | R12, R14 | PASS
EV-022 | product | false-positive | Developer / IT support engineer | R12, R14 | PASS
EV-023 | product | malformed/edge | Developer / IT support engineer | R2, R3 | PASS
EV-024 | product | malformed/edge | Person whose data appears in the logs | R4, R12 | PASS
EV-025 | product | malformed/edge | Support recipient | R5, R12 | PASS
EV-026 | product | adversarial/security | Person whose data appears in the logs | R4, PS4 | PASS
EV-027 | product | adversarial/security | Developer / IT support engineer | R5, R14 | PASS
EV-028 | product | adversarial/security | Security / compliance team | R4, R5, R8 | PASS
EV-029 | product | path-or-username | Person whose data appears in the logs | R13 | PASS
EV-030 | engineering | privacy/static | Security / compliance team | R1, PS1, PS3, AI1 | PASS
EV-031 | engineering | privacy/static | Person whose data appears in the logs | PS2, AI2 | PASS
EV-032 | engineering | privacy/static | Security / compliance team | PS3 | PASS
EV-033 | engineering | privacy/static | Security / compliance team | PS4, AI6 | PASS
EV-034 | engineering | privacy/static | Security / compliance team | PS8, AI4 | PASS
EV-035 | engineering | accessibility/usability | Developer / IT support engineer | A2 | PASS
EV-036 | engineering | accessibility/usability | Developer / IT support engineer | A4, A5 | PASS
EV-037 | product | authentication/token | Security / compliance team | R5 | PASS
EV-038 | product | authentication/token | Security / compliance team | R5 | PASS
EV-039 | product | false-positive | Developer / IT support engineer | R12, R14 | PASS
EV-040 | product | borderline/ip-diagnostic | Developer / IT support engineer | R6, R10, R12 | PASS
