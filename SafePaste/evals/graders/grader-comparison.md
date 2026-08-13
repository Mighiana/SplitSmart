# Grader Comparison

SafePaste uses two grader styles for selected evaluation cases:

- Automated exact/property grader: deterministic checks against sanitizer output properties.
- Human rubric grader: manual judgment over privacy, diagnostic usefulness, readability, proportionality, and shareability.

No external model-as-judge API was added. That would conflict with SafePaste's local-only privacy architecture unless explicitly approved.

## Cases Graded By Both Approaches

| Case | Automated verdict | Human verdict | Agreement/disagreement | Why | What this reveals about the specification |
| --- | --- | --- | --- | --- | --- |
| EV-001 | PASS | PASS | Agreement | API key value is removed while request ID context remains. | Deterministic property grading is well-suited to clear credential cases. |
| EV-005 | PASS | PASS | Agreement | JSON API key is removed and JSON context remains readable. | The post-v1 JSON credential fix is both machine-checkable and human-acceptable. |
| EV-013 | PASS | PASS | Agreement | Invalid IP-like fixture is preserved. | False-positive requirements can be expressed as exact preservation properties. |
| EV-029 | PASS | PASS | Agreement | Username is redacted while path shape remains useful. | Narrow path redaction supports both privacy and troubleshooting. |
| EV-039 | PASS | PASS | Agreement | `PWD=/workspace/project` is preserved. | The v1.3 change reduced a false positive that mattered to human usefulness. |
| EV-040 before Manual Test 2 refinement | PASS | NEEDS DISCUSSION | Disagreement | Automated grading confirmed valid IPv4 redaction. Human rubric found that redacting `127.0.0.1` removed important localhost debugging context. | The specification treated loopback as part of default IP redaction, but the grader disagreement exposed a real spec refinement need. |
| EV-040 after Manual Test 2 refinement | PASS | PASS | Agreement after spec change | Automated grading now checks preservation of loopback. Human rubric agrees diagnostic usefulness is improved. | The spec now distinguishes loopback from other valid IPv4 addresses. |
| EV-041 | PASS | PASS | Agreement | Automated and human graders both preserve `1.2.3.4.5`. | IPv4 detection must require complete IPv4 tokens, not substrings inside larger dotted numeric sequences. |
| EV-044 | PASS | PASS | Agreement | Automated and human graders both redact only the username segment in `/home/alice/...`. | Linux home paths are covered by the accepted local path/username policy. |
| EV-046 | PASS | PASS | Agreement | Automated and human graders both preserve `/var/log/nginx/error.log`. | The path policy must stay narrow and avoid broad Linux path redaction. |

## Automated Exact/Property Grader Run

Command:

```text
node evals/graders/exact-property-grader.js
```

Summary:

- Cases graded after Manual Test 2: 9
- Property checks: 36
- Passed: 36
- Failed: 0

| Case ID | Expected property | Actual behavior | Result | Reason |
| --- | --- | --- | --- | --- |
| EV-001 | Original sensitive value no longer appears: `abc1234567890SECRET` | Value absent from sanitized output. | PASS | Sensitive value was removed. |
| EV-001 | Expected marker or harmless context appears: `api_key=` | Expected text present. | PASS | Required marker/context was preserved. |
| EV-001 | Expected marker or harmless context appears: `[REDACTED_API_KEY]` | Expected text present. | PASS | Required marker/context was preserved. |
| EV-001 | Expected marker or harmless context appears: `request_id=req-42` | Expected text present. | PASS | Required marker/context was preserved. |
| EV-001 | Detected category includes `API_KEY` | Categories: `API_KEY` | PASS | Expected category was reported. |
| EV-001 | Redaction count is 1 | Redaction count: 1 | PASS | Redaction count matched. |
| EV-005 | Original sensitive value no longer appears: `abc1234567890SECRET` | Value absent from sanitized output. | PASS | Sensitive value was removed. |
| EV-005 | Expected marker or harmless context appears: `"apiKey"` | Expected text present. | PASS | Required marker/context was preserved. |
| EV-005 | Expected marker or harmless context appears: `[REDACTED_API_KEY]` | Expected text present. | PASS | Required marker/context was preserved. |
| EV-005 | Expected marker or harmless context appears: `"mode":"test"` | Expected text present. | PASS | Required marker/context was preserved. |
| EV-005 | Detected category includes `API_KEY` | Categories: `API_KEY` | PASS | Expected category was reported. |
| EV-005 | Redaction count is 1 | Redaction count: 1 | PASS | Redaction count matched. |
| EV-013 | Must preserve values: sanitized output equals input | `Parser saw 999.999.999.999 in a bad fixture` | PASS | Output preserved exactly as required. |
| EV-013 | Detected category excludes `IP_ADDRESS` | Categories: none | PASS | Unexpected category was absent. |
| EV-013 | Redaction count is 0 | Redaction count: 0 | PASS | Redaction count matched. |
| EV-029 | Original sensitive value no longer appears: `usman` | Value absent from sanitized output. | PASS | Sensitive value was removed. |
| EV-029 | Expected marker or harmless context appears: `C:\Users\[REDACTED_USER]` | Expected text present. | PASS | Required marker/context was preserved. |
| EV-029 | Expected marker or harmless context appears: `\Desktop\secret.log` | Expected text present. | PASS | Required marker/context was preserved. |
| EV-029 | Detected category includes `PATH_OR_USERNAME` | Categories: `PATH_OR_USERNAME` | PASS | Expected category was reported. |
| EV-029 | Redaction count is 1 | Redaction count: 1 | PASS | Redaction count matched. |
| EV-039 | Must preserve values: sanitized output equals input | `PWD=/workspace/project npm test` | PASS | Output preserved exactly as required. |
| EV-039 | Detected category excludes `PASSWORD` | Categories: none | PASS | Unexpected category was absent. |
| EV-039 | Redaction count is 0 | Redaction count: 0 | PASS | Redaction count matched. |
| EV-040 | Must preserve values: sanitized output equals input | `Localhost: 127.0.0.1` | PASS | Output preserved exactly as required after policy refinement. |
| EV-041 | Must preserve values: sanitized output equals input | `1.2.3.4.5` | PASS | Output preserved exactly as required. |
| EV-044 | Original sensitive value no longer appears: `alice` | Value absent from sanitized output. | PASS | Username was removed. |
| EV-046 | Must preserve values: sanitized output equals input | `/var/log/nginx/error.log` | PASS | Non-home system path remained unchanged. |

## Human Rubric Summary

The human rubric was applied manually in [human-rubric.md](human-rubric.md).

- Current cases graded: 9
- Current overall PASS: 9
- Overall FAIL: 0
- Preserved before-refinement judgment: 1 NEEDS DISCUSSION for EV-040

## Disagreement Analysis

EV-040 was the key disagreement before Manual Test 2 policy refinement.

Input:

```text
Localhost: 127.0.0.1
```

Before Manual Test 2 policy refinement:

```text
Localhost: [REDACTED_IP_ADDRESS]
```

After Manual Test 2 policy refinement:

```text
Localhost: 127.0.0.1
```

Original automated grader result:
PASS, because the valid IPv4 value is removed, the redaction marker appears, the `Localhost:` label remains, the `IP_ADDRESS` category is reported, and the redaction count is 1.

Human rubric result:
NEEDS DISCUSSION, because localhost is often important debugging context and does not carry the same privacy risk as many public or private network addresses.

Specification inspection:
Manual Test 2 showed this was more than a communication gap. The final policy now preserves IPv4 loopback addresses in `127.0.0.0/8`, while continuing to redact other valid IPv4 addresses when IPv4 redaction is enabled.

Action taken:

- Updated EV-040 to require loopback preservation.
- Added EV-041 through EV-047 for Manual Test 2 findings.
- Added loopback, dotted-sequence, and Linux path regression tests.
- Updated `SPEC_FINAL.md`, `CHANGELOG.md`, `DESIGN_DECISIONS.md`, and `AI_WORKLOG.md`.
- Reran unit tests, evals, and the automated exact/property grader.

## Unresolved Judgment Call

SafePaste now preserves IPv4 loopback addresses by default. A security/privacy evaluator may prefer uniform IP masking, but the accepted final policy prioritizes diagnostic usefulness for `127.0.0.0/8` because it usually identifies the local machine rather than a remote person or organization.
