# Design Decisions

## 1. Local-Only Architecture

Context:
SafePaste processes logs that may contain secrets or personal data.

Options considered:
Use a backend or external AI classifier, or keep all processing local.

Decision:
Keep all production behavior in static HTML, CSS, and vanilla JavaScript.

Reason:
Local deterministic processing best supports the non-negotiable privacy invariant that pasted content is never transmitted.

Stakeholders affected:
People whose data appears in logs; security / compliance team; developers.

Known limitation:
Pattern-based detection is less capable than a server-side or AI classifier for novel secret formats.

## 2. Privacy vs Troubleshooting Usefulness

Context:
IP addresses and paths can be sensitive but may also be diagnostically important.

Options considered:
Always redact, never redact, or provide user-controlled behavior.

Decision:
Redact valid non-loopback IPv4 addresses by default and provide a checkbox to preserve them. Preserve IPv4 loopback addresses in `127.0.0.0/8` because they are usually local diagnostic context. Redact common user-directory path usernames while preserving path shape.

Reason:
Default privacy protection helps data subjects and security stakeholders. Manual Test 2 showed that localhost redaction can be disproportionately harmful for debugging, so loopback addresses are preserved while the checkbox still gives developers control when other exact network context matters.

Stakeholders affected:
All four stakeholder groups.

Known limitation:
The app distinguishes loopback from other IPv4 addresses, but it does not separately classify public and private non-loopback ranges.

## 2a. Complete IPv4 Tokens

Context:
Manual Test 2 showed that `1.2.3.4.5` became `[REDACTED_IP_ADDRESS].5`.

Options considered:
Keep the broad regex, special-case `1.2.3.4.5`, or require IPv4 candidates to be complete tokens.

Decision:
Require IPv4 candidates to be complete tokens and preserve valid-looking substrings inside larger dotted numeric sequences.

Reason:
Special-casing one input would not address the root cause. Complete-token detection better supports false-positive control.

Stakeholders affected:
Developers, support recipients, and security reviewers.

Known limitation:
The rule is still regex-based and may not understand every surrounding syntax used in network tooling.

## 2b. Linux Home Path Usernames

Context:
Manual Test 2 showed `/home/usman/projects/safepaste/server.log` was not redacted even though the accepted path policy covers recognized home-directory forms.

Options considered:
Leave Linux paths unchanged, redact entire paths, or redact only the username segment for recognized home-directory prefixes.

Decision:
Redact only the username segment for `/home/name/...`, `/Users/name/...`, and Windows `C:\Users\name\...`; preserve non-home system paths.

Reason:
This protects personal usernames without destroying path shape or useful diagnostic context.

Stakeholders affected:
People whose data appears in logs, developers, and support recipients.

Known limitation:
Only common home-directory forms are handled.

## 3. Detection Sensitivity vs False Positives

Context:
Broad regexes can remove useful technical identifiers.

Options considered:
Redact any long string, redact only strong credential contexts, or add many specialized detectors.

Decision:
Use strong contextual detectors for generic API keys and passwords, plus specific token patterns for known formats.

Reason:
This protects high-risk values without destroying normal build IDs, trace IDs, versions, or `PWD` path values.

Stakeholders affected:
Developers, support recipients, and security / compliance reviewers.

Known limitation:
Custom secret formats without recognizable context may remain unredacted.

## 4. Regex Simplicity vs Coverage

Context:
The project needs to be auditable for a university presentation.

Options considered:
Use a complex parser, many dependencies, or a small rule list with validators.

Decision:
Use a small ordered rule list with category labels, replacement labels, and IPv4 validation.

Reason:
The behavior is easier to inspect, test, and explain.

Stakeholders affected:
Security reviewers and developers.

Known limitation:
Rules can overlap and do not understand every syntax edge case.

## 5. Zero Dependencies vs Richer Features

Context:
Dependencies could provide UI components or secret-scanning libraries.

Options considered:
Install libraries or keep zero runtime dependencies.

Decision:
Use no runtime dependencies.

Reason:
Zero dependencies reduce supply-chain risk and support the "open index.html" launch requirement.

Stakeholders affected:
Security / compliance team and developers.

Known limitation:
The UI and detection capabilities are intentionally modest.
