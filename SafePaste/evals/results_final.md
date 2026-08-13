# SafePaste Final Evaluation Results

Refreshed after Manual Test 6 close-out on 2026-08-13.

## Commands Run

```text
node tests/test-sanitizer.js
node evals/run-evals.js --write evals/results_final.md
node evals/graders/exact-property-grader.js --write evals/graders/exact-property-results.md
node evals/run-red-team.js
node evals/run-ui-smoke.js
rg -n "fetch\(|XMLHttpRequest|WebSocket|localStorage|sessionStorage|indexedDB|document\.cookie|innerHTML|https?://|<script[^>]+src=|TODO.*security|bypass" SafePaste
rg -n 'AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}|sk-[A-Za-z0-9]{20,}|-----BEGIN .*PRIVATE KEY-----|password\s*[:=]\s*[^,\s;}{]{8,}|api[_-]?key\s*[:=]\s*[A-Za-z0-9_./+=-]{16,}' SafePaste
```

## Final Methodology Results

- Unit tests: 37 total, 37 passed, 0 failed.
- Eval cases: 72 total, 72 passed, 0 failed.
- Automated exact/property grader: 20 cases, 86 property checks, 86 passed, 0 failed.
- Human rubric: 20 current cases graded; 19 PASS, 0 FAIL, 1 NEEDS DISCUSSION for EV-072.
- Red-team cases: 15 total, 15 passed, 0 failed.
- UI smoke: PASS.
- Privacy/static scan: contextual documentation, tests, evals, history, local static server, local script tags, and scan-pattern hits only; no production network, persistence, cookie, or unsafe DOM finding.
- Secret scan: synthetic fixtures in tests/evals/history/docs only; no production hardcoded credential finding.
- Network/persistence API review: production app remains static/local-only and does not use `fetch`, `XMLHttpRequest`, `WebSocket`, storage APIs, cookies, IndexedDB, or `innerHTML`.
- Remaining failures from executed checks: none.

## Manual Test 6 Known Limitation

- Input: `Firmware 1.2.3.4 installed successfully.`
- Current output: `Firmware [REDACTED_IP_ADDRESS] installed successfully.`
- Automated exact/property verdict: PASS under the current deterministic privacy policy.
- Human rubric verdict: NEEDS DISCUSSION because the value is likely firmware-version context and redaction can reduce diagnostic usefulness.
- Action taken: documented as a known limitation and grader disagreement; no sanitizer change was made because the core sanitizer is frozen unless a high-severity privacy/security regression appears.

## Summary

- Total eval cases: 72
- Passed: 72
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
EV-041 | product | false-positive/ip | Developer / IT support engineer | R6, R12, R14 | PASS
EV-042 | product | borderline/ip-diagnostic | Developer / IT support engineer | R6, R10, R12 | PASS
EV-043 | product | borderline/ip-diagnostic | Developer / IT support engineer | R6, R10, R12 | PASS
EV-044 | product | path-or-username | Person whose data appears in the logs | R13, R12 | PASS
EV-045 | product | path-or-username | Person whose data appears in the logs | R13, R12 | PASS
EV-046 | product | false-positive/path | Support recipient | R12, R14 | PASS
EV-047 | product | false-positive/path | Support recipient | R12, R14 | PASS
EV-048 | product | structured-username | Person whose data appears in the logs | R13, R12 | PASS
EV-049 | product | structured-username | Person whose data appears in the logs | R13, R12 | PASS
EV-050 | product | false-positive/username | Developer / IT support engineer | R12, R14 | PASS
EV-051 | product | false-positive/username | Developer / IT support engineer | R12, R14 | PASS
EV-052 | product | false-positive/ip-version | Developer / IT support engineer | R6, R12, R14 | PASS
EV-053 | product | false-positive/ip-version | Developer / IT support engineer | R6, R12, R14 | PASS
EV-054 | product | false-positive/ip-version | Developer / IT support engineer | R6, R12, R14 | PASS
EV-055 | product | ip | Security / compliance team | R6, R12 | PASS
EV-056 | product | ip | Security / compliance team | R6, R12 | PASS
EV-057 | product | false-positive/ip-version | Developer / IT support engineer | R6, R12, R14 | PASS
EV-058 | product | false-positive/ip-version | Developer / IT support engineer | R6, R12, R14 | PASS
EV-059 | product | false-positive/ip-version | Developer / IT support engineer | R6, R12, R14 | PASS
EV-060 | product | false-positive/ip-version | Developer / IT support engineer | R6, R12, R14 | PASS
EV-061 | product | false-positive/ip-version | Developer / IT support engineer | R6, R12, R14 | PASS
EV-062 | product | ip | Security / compliance team | R6, R12 | PASS
EV-063 | product | ip | Security / compliance team | R6, R12 | PASS
EV-064 | product | ip | Security / compliance team | R6, R12 | PASS
EV-065 | product | ip | Security / compliance team | R6, R12 | PASS
EV-066 | product | ip | Security / compliance team | R6, R12 | PASS
EV-067 | product | ip | Security / compliance team | R6, R12 | PASS
EV-068 | product | ip | Security / compliance team | R6, R12 | PASS
EV-069 | product | false-positive/ip-version | Developer / IT support engineer | R6, R12, R14 | PASS
EV-070 | product | false-positive/ip-version | Developer / IT support engineer | R6, R12, R14 | PASS
EV-071 | product | false-positive/ip-hostname | Developer / IT support engineer | R6, R12, R14 | PASS
EV-072 | product | known-limitation/ip-firmware-version | Developer / IT support engineer | R6, R12, R14 | PASS
