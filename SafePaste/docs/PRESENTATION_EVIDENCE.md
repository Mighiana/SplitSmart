# Presentation Evidence

## 1. Project: what and for whom

Final one-line description:
SafePaste is a local-only browser log sanitizer that helps technical users redact likely sensitive values before sharing logs.

Intended users:
Developers, IT support engineers, technical students, security/compliance reviewers, data subjects appearing in logs, and support recipients.

Screenshot recommendation:
Capture the final UI with a mixed log and sanitized output visible side by side.

## 2. Stakeholders and conflicts

| Stakeholder | Main wants | Main fears |
| --- | --- | --- |
| Developer / IT support engineer | Fast useful sanitization, readable logs | Over-redaction and lost debugging details |
| Person whose data appears in logs | Privacy and credential protection | Emails, IPs, usernames, and tokens leaking |
| Security / compliance team | Aggressive, predictable local redaction | False negatives and unsafe implementation |
| Support recipient | Enough context to solve the issue | Logs made useless by excessive redaction |

Two main conflicts:

- Privacy vs diagnostic usefulness.
- Detection sensitivity vs false positives.

Decisions caused by those conflicts:

- IPv4 addresses are redacted by default but can be preserved by user choice.
- Generic secrets require credential-like key context.
- `PWD` path values are preserved because security review showed they were false positives.

## 3. Spec: v1 -> final

| Change | Trigger | Changelog entry | Supporting evidence |
| --- | --- | --- | --- |
| Quoted JSON credential keys became explicit scope | Unit tests, EV-004, EV-005, RT-P02, SR-001 | v1.1 | `tests/test-sanitizer.js`, `evals/results_v1.md`, `RED_TEAM.md` |
| Basic and Token Authorization headers added | Security review SR-002 | v1.2 | EV-037, EV-038 |
| `PWD` removed from password aliases | Security review SR-003 | v1.3 | EV-039 |
| Static privacy scan changed from hardcoded list to recursive production scan | Security review SR-004 | v1.4 | `evals/run-evals.js` |
| Hook moved away from `grep` and fixed temp file | Manual hook failure and SR-005 | v1.5 | `evals/results_v1.md`, `.claude/hooks/pre-commit.sh` |
| External-resource scan expanded across production files | Final security review | v1.6 | `evals/run-evals.js`, `evals/results_final.md` |
| Hook path loop made space-safe without `mktemp` | Final hook smoke test | v1.7 | `AI_WORKLOG.md`, `.claude/hooks/pre-commit.sh` |

## 4. Harness

| Component | Location in repository | Purpose | Concrete example where it mattered |
| --- | --- | --- | --- |
| Persistent instruction file | `AGENTS.md` | Repeatedly tells AI agents the architecture and privacy rules | Prevented adding dependencies or network services during implementation |
| Security-review sub-agent | `.claude/agents/security-reviewer.md` | Reviews code for privacy and security regressions | Found Basic/Token Authorization gaps and `PWD` false positives |
| Hook | `.claude/hooks/pre-commit.sh` | Lightweight staged secret scan | Manual invocation exposed a portability failure that was fixed |
| Permission policy | `.claude/settings.json` | Documents approval boundaries | Keeps dependency/network/destructive actions explicit |
| Evaluation runners | `evals/run-evals.js`, `evals/run-red-team.js`, `evals/run-ui-smoke.js` | Tie behavior to spec requirements and adversarial checks | Preserved v1 failures and verified final fixes |

## 5. Evaluations

V1 result:
34/36 eval cases passed. EV-004 and EV-005 failed because quoted JSON credential keys were not redacted.

Final result:
40/40 eval cases passed after adding fixes, three security-review regression cases, and the Session 7 localhost borderline case.

Session 7 grader result:

- Automated exact/property grader: 6 cases, 28/28 property checks passed.
- Human rubric: 6 cases, 5 PASS and 1 NEEDS DISCUSSION.
- Disagreement: EV-040 localhost passed automated IP redaction but needed human discussion for diagnostic usefulness.

Most interesting failures:

- JSON credentials in `"password"` and `"apiKey"` forms remained visible in v1.
- Basic and Token Authorization headers were missed by security review.
- `PWD=/workspace/project` was over-redacted in v1.
- The first hook version used unavailable `grep` and exited successfully without scanning.

Categories tested:
API keys, passwords, emails, valid and invalid IPv4 addresses, Authorization headers, Bearer tokens, JWTs, AWS-style keys, Slack-style tokens, false positives, paths/usernames, Unicode, multiline logs, HTML-like input, static privacy checks, and accessibility/usability checks.

Representative eval cases:
EV-004, EV-005, EV-013, EV-026, EV-037, EV-038, EV-039, and EV-040.

## 5a. Graders and the human in the loop

| Grader | Location | Why chosen | Cases graded | Result |
| --- | --- | --- | --- | --- |
| Automated exact/property grader | `evals/graders/exact-property-grader.js` | SafePaste sanitizer behavior is deterministic and can be checked by properties without sending data anywhere. | 6 | 28/28 property checks passed |
| Human rubric | `evals/graders/human-rubric.md` | Diagnostic usefulness, readability, proportionality, and shareability require judgment. | 6 | 5 PASS, 1 NEEDS DISCUSSION |

Model-as-judge was not used because an external LLM API would conflict with SafePaste's local-only privacy architecture.

## 6. Honest failures

Failure:
Quoted JSON credential keys were not redacted.

Detection:
Unit tests, EV-004, EV-005, RT-P02, and SR-001.

Response:
Credential regexes were updated to support quoted JSON keys and camelCase keys.

Permanent engineering control:
JSON credential unit tests and eval cases remain in the suite.

Failure:
Basic and Token Authorization headers were missed.

Detection:
Security-review finding SR-002.

Response:
Authorization header detection was broadened to common schemes.

Permanent engineering control:
Unit tests and evals EV-037/EV-038.

Failure:
`PWD` path values were over-redacted.

Detection:
Security-review finding SR-003.

Response:
Removed `pwd` from password aliases.

Permanent engineering control:
Unit test and EV-039.

Failure:
The v1 pre-commit hook relied on unavailable `grep`.

Detection:
Manual hook invocation before the v1 commit.

Response:
Hook now uses `git grep` and avoids a fixed temp output file.

Permanent engineering control:
Hook portability is documented in `CHANGELOG.md` and v1 results.

Failure:
The first final hook hardening relied on unavailable `mktemp`.

Detection:
Manual hook test with staged file `SafePaste/src/hook path smoke.js`.

Response:
Removed the temporary file and rewrote the hook loop without `mktemp`.

Permanent engineering control:
Hook now uses a `read -r` loop and was rerun successfully against a staged path containing a space.
