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
| EV-040 | PASS | NEEDS DISCUSSION | Disagreement | Automated grading confirms valid IPv4 redaction. Human rubric finds that redacting `127.0.0.1` can remove important localhost debugging context. | The specification is explicit about default IP redaction plus user opt-out, but this case should remain documented as a human-in-the-loop judgment call. |

## Automated Exact/Property Grader Run

Command:

```text
node evals/graders/exact-property-grader.js
```

Summary:

- Cases graded: 6
- Property checks: 28
- Passed: 28
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
| EV-040 | Original sensitive value no longer appears: `127.0.0.1` | Value absent from sanitized output. | PASS | Sensitive value was removed. |
| EV-040 | Expected marker or harmless context appears: `Localhost:` | Expected text present. | PASS | Required marker/context was preserved. |
| EV-040 | Expected marker or harmless context appears: `[REDACTED_IP_ADDRESS]` | Expected text present. | PASS | Required marker/context was preserved. |
| EV-040 | Detected category includes `IP_ADDRESS` | Categories: `IP_ADDRESS` | PASS | Expected category was reported. |
| EV-040 | Redaction count is 1 | Redaction count: 1 | PASS | Redaction count matched. |

## Human Rubric Summary

The human rubric was applied manually in [human-rubric.md](human-rubric.md).

- Cases graded: 6
- Overall PASS: 5
- Overall FAIL: 0
- Overall NEEDS DISCUSSION: 1

## Disagreement Analysis

EV-040 is the only disagreement.

Input:

```text
Localhost: 127.0.0.1
```

Current output:

```text
Localhost: [REDACTED_IP_ADDRESS]
```

Automated grader result:
PASS, because the valid IPv4 value is removed, the redaction marker appears, the `Localhost:` label remains, the `IP_ADDRESS` category is reported, and the redaction count is 1.

Human rubric result:
NEEDS DISCUSSION, because localhost is often important debugging context and does not carry the same privacy risk as many public or private network addresses.

Specification inspection:
`SPEC_FINAL.md` already states that localhost and private IPs are redacted by default and that the user can disable IPv4 redaction when exact network context is needed. The disagreement does not require changing product behavior, but it does expose a specification communication gap: the final spec should explicitly name this as a human-in-the-loop judgment call rather than only a settled implementation decision.

Action taken:

- Added EV-040 to the eval set.
- Added a localhost unit regression test.
- Updated `SPEC_FINAL.md` to document the Session 7 grader finding.
- Updated `CHANGELOG.md` because the grader finding caused a specification/documentation change.
- Reran unit tests, evals, and the automated exact/property grader.

## Unresolved Judgment Call

SafePaste still redacts localhost by default. A security/privacy evaluator may prefer that consistent rule; a developer or support recipient may prefer preserving localhost for troubleshooting. The current product resolves this by defaulting to privacy and leaving an IPv4 opt-out under user control.
