# SafePaste Final Specification

This final specification reflects implementation, v1 evaluation, red-team testing, and security review. `SPEC_v1.md` remains preserved as the pre-implementation baseline.

## 1. Product Description

SafePaste is a local browser-based log sanitizer for people who need to share technical text while reducing the risk of leaking sensitive information. A user pastes logs, runs local deterministic detection rules, reviews the original and sanitized text side by side, and copies sanitized text only after review. The app has no backend, no database, no login, no analytics, no remote resources, and no external AI API. SafePaste remains a review aid rather than a guarantee that all secrets are detected.

## 2. Intended Users

Primary users:

- developers
- IT support engineers
- technical students
- technical users preparing logs for AI tools, support systems, issue trackers, chat, email, or forums

Secondary users:

- people whose data appears in logs
- security and compliance reviewers
- support recipients who need enough context to troubleshoot

## 3. Stakeholder Map

The stakeholder map remains in [docs/STAKEHOLDER_MAP.md](docs/STAKEHOLDER_MAP.md). The final implementation keeps the two key conflicts visible:

- Privacy vs diagnostic usefulness: IP addresses are redacted by default, but users can disable IPv4 redaction when troubleshooting needs exact network context.
- Detection sensitivity vs false positives: high-risk credential contexts are redacted, while ordinary build IDs, UUID-like trace IDs, semantic versions, and `PWD` path values are preserved.

## 4. Functional Requirements

- R1: Application works entirely client-side.
- R2: User can paste arbitrary text.
- R3: Application produces sanitized output.
- R4: Application detects email addresses.
- R5: Application detects common credentials and tokens, including key/value secrets, quoted JSON credential keys, JWTs, Bearer tokens, Basic/Token Authorization headers, AWS-style access keys, and recognizable Slack-style tokens.
- R6: Application detects valid IPv4 addresses and does not classify invalid octets as IPv4.
- R7: Application shows detected sensitive-data categories.
- R8: Application shows a redaction count.
- R9: User can copy sanitized output.
- R10: User can choose whether IPv4 addresses are redacted.
- R11: User can review original and sanitized text before sharing.
- R12: Application preserves non-sensitive context where practical.
- R13: Local file paths and usernames are redacted only for common user-directory path forms that are reasonably detectable.
- R14: Ordinary short identifiers such as `abc123xyz`, UUID-like trace IDs, semantic versions, and path-like `PWD` values remain unchanged unless there is stronger evidence they are sensitive.
- R15: The app provides a clear/reset action.

## 5. Privacy And Security Requirements

- PS1: Pasted user content must never be sent over the network by the production app.
- PS2: Pasted logs must not be stored in localStorage, sessionStorage, cookies, IndexedDB, backend storage, or other persistence.
- PS3: The app must not include tracking, analytics, telemetry, third-party scripts, remote fonts, or remote CDN libraries.
- PS4: User-controlled content must be handled with safe DOM APIs; use textarea values, `textContent`, and node creation rather than `innerHTML`.
- PS5: Production files must not hardcode API keys, passwords, secrets, or credentials.
- PS6: Failing tests must not be removed or weakened merely because they fail.
- PS7: Expected outputs must not be hardcoded just to satisfy evaluations.
- PS8: Packages must not be installed silently.
- PS9: External services must not be added without explicit human approval.
- PS10: Destructive actions must require confirmation.

## 6. Accessibility Requirements

- A1: The app must be keyboard usable through native controls.
- A2: Textareas and controls must have visible labels or clear accessible names.
- A3: The page must use semantic header, main, section, heading, button, textarea, label, and status patterns.
- A4: Focus indicators must be visible.
- A5: Status updates must be understandable without relying solely on color.
- A6: Buttons must have clear accessible names.

## 7. AI Development Rules

- AI1: Never add production network calls.
- AI2: Never persist pasted text.
- AI3: Never delete or weaken failing tests to get a pass.
- AI4: Ask before adding dependencies or package installation.
- AI5: Never bypass security hooks.
- AI6: Prefer safe DOM APIs for user-controlled content.
- AI7: Run sanitizer tests after modifying sanitizer logic.
- AI8: Surface ambiguous requirements and document trade-offs.
- AI9: Preserve `SPEC_v1.md` after implementation begins.
- AI10: Record real failures and do not fabricate development history.

## 8. Finalized Borderline Decisions

### Localhost and Private IPs

`127.0.0.1`, private IPv4 ranges, and public IPv4 addresses are redacted by default because IP information may reveal environment or user details. The UI includes a user-controlled checkbox to preserve IPv4 addresses when exact network context is needed for troubleshooting.

### `PWD=` Values

`PWD=/some/path` is not treated as a password because `PWD` commonly means present working directory in shell logs. The final sanitizer preserves `PWD` values and handles usernames through the narrower path detector.

### JSON Credential Keys

Quoted JSON keys such as `"password":"..."`, `"apiKey":"..."`, and `"client_secret":"..."` are in scope because JSON logs and config snippets are common.

## 9. Known Limitations

- Detection is deterministic and pattern-based; it cannot prove that every secret is removed.
- The app does not parse all programming languages, structured logs, or custom secret formats.
- Local path detection is intentionally narrow to reduce false positives.
- Browser-level OS clipboard permission was not verified because in-app browser automation failed in this environment; a no-dependency UI smoke test verified that the copy button calls the Clipboard API.
- A temporary local verification server exists under `evals/` for testing only. The production app remains static and can be opened directly from `index.html`.

## 10. Changes From v1

- Added explicit JSON credential coverage after unit/eval/red-team failures.
- Added Basic and Token Authorization header coverage after security review.
- Removed broad `pwd` password alias after security review found path false positives.
- Expanded static privacy eval scanning to recursively scan production code files.
- Updated the pre-commit hook to avoid `grep` dependency and fixed temp files.
