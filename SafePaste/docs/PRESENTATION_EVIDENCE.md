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

- Non-loopback IPv4 addresses are redacted by default but can be preserved by user choice.
- Loopback IPv4 addresses are preserved after Manual Test 2 showed localhost redaction harmed diagnostic usefulness.
- IPv4-shaped values in narrow version fields are preserved after Manual Test 3 showed release context was over-redacted.
- Direct prose version contexts are preserved after Manual Test 4 showed `Release 1.2.3.4` was over-redacted.
- Explicit structured username fields are redacted while arbitrary names in prose are preserved.
- Current username replacement markers are standardized on `[REDACTED_USERNAME]`.
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
| Grader methodology added and localhost disagreement recorded | Session 7 requirement | v1.8 | `evals/graders/grader-comparison.md` |
| IPv4 token boundary fixed | Manual Test 2 F1 | v1.9 | `evals/manual_test_2.md`, EV-041 |
| Loopback addresses preserved | Manual Test 2 F2 and grader disagreement | v1.10 | EV-040, EV-042, EV-043 |
| Linux home usernames redacted narrowly | Manual Test 2 F3 | v1.11 | EV-044 through EV-047 |
| Structured username fields redacted | Manual Test 3 F4 | v1.12 | `evals/manual_test_3.md`, EV-048 through EV-051 |
| Version-field IPv4-shaped values preserved | Manual Test 3 F5 and grader disagreement | v1.13 | EV-052 through EV-057 |
| Prose version IPv4-shaped values preserved | Manual Test 4 F6 and grader disagreement | v1.14 | `evals/manual_test_4.md`, EV-058 through EV-064 |
| Username marker standardized | Manual Test 4 consistency review | v1.15 | EV-029, EV-044, EV-045 |
| Sentence-final standalone IPv4 redaction fixed | Manual Test 5 F7 | v1.16 | `evals/manual_test_5.md`, EV-065 through EV-071 |

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
71/71 eval cases passed after Manual Test 5 fixes.

Session 7 grader result:

- Automated exact/property grader: 19 cases, 80/80 property checks passed.
- Human rubric: 19 current cases passed; preserved before-refinement judgments include EV-040 NEEDS DISCUSSION, EV-048 FAIL, EV-052 FAIL, EV-058 FAIL, and EV-065 FAIL.
- Disagreements: EV-040 originally passed automated IP redaction but needed human discussion for diagnostic usefulness; Manual Test 2 refined the spec to preserve `127.0.0.0/8`. EV-052 exposed a Manual Test 3 syntactic-IP vs version-context disagreement; Manual Test 4 extended that same issue to direct prose `Release`/`Version` contexts. Manual Test 5 F7 was not a grader disagreement after adding the correct property: both graders failed the visible standalone IPv4 address before the fix.

Most interesting failures:

- JSON credentials in `"password"` and `"apiKey"` forms remained visible in v1.
- Basic and Token Authorization headers were missed by security review.
- `PWD=/workspace/project` was over-redacted in v1.
- The first hook version used unavailable `grep` and exited successfully without scanning.
- Manual Test 2 F1: `1.2.3.4.5` became `[REDACTED_IP_ADDRESS].5`.
- Manual Test 2 F3: `/home/usman/...` did not redact the username.
- Manual Test 3 F4: `username=musman24`, `user_name=alice_dev`, and `user=bob-admin` remained visible.
- Manual Test 3 F5: `release=1.2.3.4` became `release=[REDACTED_IP_ADDRESS]`.
- Manual Test 4 F6: `Release 1.2.3.4 passed QA yesterday.` became `Release [REDACTED_IP_ADDRESS] passed QA yesterday.`
- Manual Test 4 consistency review: current product used both `[REDACTED_USER]` and `[REDACTED_USERNAME]` for username redaction.
- Manual Test 5 F7: `Connection received from 192.168.20.50.` remained unchanged because a sentence-ending period blocked IPv4 token matching.

Categories tested:
API keys, passwords, emails, structured usernames, valid and invalid IPv4 addresses, loopback IPv4, dotted numeric false positives, version-field and prose-version IPv4-shaped values, sentence-final IPv4 punctuation, hostname-embedded IPv4-shaped values, explicit IP fields, non-version prose IP addresses, Authorization headers, Bearer tokens, JWTs, AWS-style keys, Slack-style tokens, false positives, paths/usernames, Linux home paths, Unicode, multiline logs, HTML-like input, static privacy checks, and accessibility/usability checks.

Representative eval cases:
EV-004, EV-005, EV-013, EV-026, EV-037, EV-038, EV-039, EV-040, EV-041, EV-044, EV-046, EV-048, EV-050, EV-052, EV-055, EV-058, EV-062, EV-065, EV-069, and EV-071.

## 5a. Graders and the human in the loop

| Grader | Location | Why chosen | Cases graded | Result |
| --- | --- | --- | --- | --- |
| Automated exact/property grader | `evals/graders/exact-property-grader.js` | SafePaste sanitizer behavior is deterministic and can be checked by properties without sending data anywhere. | 19 | 80/80 property checks passed |
| Human rubric | `evals/graders/human-rubric.md` | Diagnostic usefulness, readability, proportionality, and shareability require judgment. | 19 current cases plus preserved before/after evidence | 19 current PASS; before-refinement EV-040 remains NEEDS DISCUSSION, EV-048 FAIL, EV-052 FAIL, EV-058 FAIL, and EV-065 FAIL |

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

Failure:
IPv4 substring false positive.

Detection:
Manual Test 2 F1 and local reproduction showed `1.2.3.4.5` became `[REDACTED_IP_ADDRESS].5`.

Response:
IPv4 detector now requires complete IPv4 tokens.

Permanent engineering control:
Unit test plus EV-041.

Failure:
Linux home path username was not redacted.

Detection:
Manual Test 2 F3 and local reproduction showed `/home/usman/projects/safepaste/server.log` remained unchanged.

Response:
Path detector now redacts only the username segment for `/home/name/...`.

Permanent engineering control:
Unit tests plus EV-044 through EV-047.

Failure:
Structured username fields remained visible.

Detection:
Manual Test 3 F4 and local reproduction showed `username=musman24`, `user_name=alice_dev`, and `user=bob-admin` were unchanged.

Response:
Added a narrow structured username detector for explicit account fields and quoted JSON equivalents.

Permanent engineering control:
Unit tests plus EV-048 through EV-051.

Failure:
Version-field value was over-redacted as an IP address.

Detection:
Manual Test 3 F5 and grader comparison showed `release=1.2.3.4` became `release=[REDACTED_IP_ADDRESS]`.

Response:
Added a narrow version-field context exception while keeping `client_ip=` and `server_ip=` redaction.

Permanent engineering control:
Unit tests plus EV-052 through EV-057.

Failure:
Prose release/version context was over-redacted as an IP address.

Detection:
Manual Test 4 F6 and local reproduction showed `Release 1.2.3.4 passed QA yesterday.` became `Release [REDACTED_IP_ADDRESS] passed QA yesterday.`

Response:
Extended the narrow version-context exception to direct `Version` and `Release` prose associations.

Permanent engineering control:
Unit tests plus EV-058 through EV-064.

Failure:
Standalone IPv4 before sentence punctuation was not redacted.

Detection:
Manual Test 5 F7 and local reproduction showed `Connection received from 192.168.20.50.` remained unchanged.

Response:
IPv4 token-boundary handling now treats sentence-ending periods as punctuation while preserving larger dotted numeric sequences and hostname-embedded values.

Permanent engineering control:
Unit tests plus EV-065 through EV-071.

Consistency finding:
Username replacement labels were inconsistent.

Detection:
Manual Test 4 review showed home-path usernames used `[REDACTED_USER]` while structured username fields used `[REDACTED_USERNAME]`.

Response:
Current product output, tests, evals, and live docs now standardize on `[REDACTED_USERNAME]`.

Permanent engineering control:
Updated path username tests/evals while preserving historical evidence files unchanged.
