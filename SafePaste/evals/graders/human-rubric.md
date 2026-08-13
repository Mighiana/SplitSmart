# Human Rubric

This rubric was created before applying manual case judgments for the Session 7 grader comparison. It is intended for human-in-the-loop review of sanitized SafePaste outputs, especially where deterministic privacy properties do not fully answer whether the result is useful or proportionate.

No external LLM or model-as-judge API is used. That choice preserves SafePaste's local-only privacy architecture. Exact/property grading is appropriate for deterministic security and privacy checks; diagnostic usefulness and proportionality require human judgment.

## Rubric Items

For each item, choose `PASS`, `FAIL`, or `UNSURE`.

| ID | Criterion | PASS | FAIL | UNSURE |
| --- | --- | --- | --- | --- |
| H1 Privacy | Sensitive information that should be protected is removed. | The sensitive value is absent or safely replaced. | Sensitive information remains visible. | It is unclear whether the value is sensitive or adequately protected. |
| H2 Diagnostic usefulness | Enough technical context remains to understand or troubleshoot the log. | The useful surrounding context remains. | Redaction removes information needed to understand the issue. | A domain expert would need to decide if the remaining context is enough. |
| H3 Readability | The sanitized result remains understandable. | The output is clear and readable. | The output is confusing or structurally broken. | The output is partly readable but may be ambiguous. |
| H4 Proportionality | The tool does not redact harmless information unnecessarily. | Redactions feel scoped to likely sensitive values. | Harmless or highly useful values are unnecessarily redacted. | The sensitivity/usefulness trade-off is unclear. |
| H5 Shareability | The evaluator would be comfortable sharing the sanitized output. | The output appears appropriate to share for support or AI assistance. | The output still seems unsafe or unusable to share. | The evaluator would ask for more context before sharing. |

Overall verdict:

- `PASS`: The sanitized output is privacy-protective and useful enough to share.
- `FAIL`: The output either leaks sensitive information or loses too much important context.
- `NEEDS DISCUSSION`: The output is not clearly wrong, but a human stakeholder decision is needed.

Confidence:

- 1: very low confidence
- 2: low confidence
- 3: moderate confidence
- 4: high confidence
- 5: very high confidence

## Manual Rubric Run

Evaluator:
AI-assisted development evaluator applying the human rubric manually. This is not an external user study, and a course human evaluator can override these judgments.

Date:
2026-08-13

| Case | Input | Current sanitized output | H1 Privacy | H2 Diagnostic usefulness | H3 Readability | H4 Proportionality | H5 Shareability | Overall verdict | Confidence | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| EV-001 | `api_key=abc1234567890SECRET request_id=req-42` | `api_key=[REDACTED_API_KEY] request_id=req-42` | PASS | PASS | PASS | PASS | PASS | PASS | 5 | Credential is removed and request context remains. |
| EV-005 | `{"apiKey":"abc1234567890SECRET","mode":"test"}` | `{"apiKey":"[REDACTED_API_KEY]","mode":"test"}` | PASS | PASS | PASS | PASS | PASS | PASS | 5 | JSON structure and mode context remain readable. |
| EV-013 | `Parser saw 999.999.999.999 in a bad fixture` | `Parser saw 999.999.999.999 in a bad fixture` | PASS | PASS | PASS | PASS | PASS | PASS | 4 | Invalid IP-like fixture is preserved, which supports false-positive control. |
| EV-029 | `Error opening C:\Users\usman\Desktop\secret.log` | `Error opening C:\Users\[REDACTED_USER]\Desktop\secret.log` | PASS | PASS | PASS | PASS | PASS | PASS | 4 | Username is protected while path shape and filename remain useful. |
| EV-039 | `PWD=/workspace/project npm test` | `PWD=/workspace/project npm test` | PASS | PASS | PASS | PASS | PASS | PASS | 4 | `PWD` is interpreted as working-directory context, not a password. |
| EV-040 | `Localhost: 127.0.0.1` | `Localhost: [REDACTED_IP_ADDRESS]` | PASS | FAIL | PASS | FAIL | UNSURE | NEEDS DISCUSSION | 4 | Privacy behavior matches the automated IP rule, but localhost is often essential debugging context. This is acceptable only if the evaluator knows IP redaction can be disabled. |
