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
Redact valid non-loopback IPv4 addresses by default and provide a checkbox to preserve them. Preserve IPv4 loopback addresses in `127.0.0.0/8` because they are usually local diagnostic context. Preserve IPv4-shaped values in narrow version-related contexts. Redact common user-directory path usernames and explicit structured username fields while preserving surrounding context.

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

## 2c. Structured Username Fields

Context:
Manual Test 3 showed `username=musman24`, `user_name=alice_dev`, and `user=bob-admin` remained visible.

Options considered:
Leave all non-path usernames visible, redact arbitrary names anywhere in text, or redact only explicit structured username/account fields.

Decision:
Redact values of explicit username fields such as `username=`, `user_name=`, `user-name=`, and `user=`, including quoted JSON equivalents when practical. Preserve `name=Muhammad` and prose such as `User alice reported...`.

Reason:
Explicit account fields have a strong privacy signal. Arbitrary personal-name detection would create too many false positives and damage diagnostic usefulness.

Stakeholders affected:
People whose data appears in logs, developers, and support recipients.

Known limitation:
Only simple account-like field values are handled; arbitrary names in prose are intentionally out of scope.

## 2d. Version-Context IPv4-Shaped Values

Context:
Manual Test 3 showed `release=1.2.3.4` became `release=[REDACTED_IP_ADDRESS]`. Manual Test 4 showed `Release 1.2.3.4 passed QA yesterday.` became `Release [REDACTED_IP_ADDRESS] passed QA yesterday.`

Options considered:
Keep purely syntactic IPv4 redaction, disable IPv4 redaction broadly, special-case one release string, add broad natural-language interpretation, or preserve IPv4-shaped values only in narrow direct version contexts.

Decision:
Preserve IPv4-shaped values when immediately preceded by narrow version-related fields such as `version=`, `release=`, `app_version=`, or `software_version=`, and when directly associated with strong prose keywords such as `Version 1.2.3.4` or `Release 1.2.3.4`. Continue redacting `client_ip=...`, `server_ip=...`, `Server 10.20.30.40 failed`, `Client 8.8.8.8 disconnected`, and other non-loopback IPv4 values.

Reason:
This resolves the automated-vs-human grader disagreement without weakening general IP protection. The rule is small enough to audit, avoids hardcoding the specific observed value, and does not introduce broad NLP.

Stakeholders affected:
Developers, support recipients, and security reviewers.

Known limitation:
The context check only covers a small set of version-related field names and direct `Version`/`Release` prose associations. Manual Test 6 showed that `Firmware 1.2.3.4 installed successfully.` is likely firmware-version context to a human but remains redacted under the frozen deterministic policy.

## 2e. Username Replacement Marker

Context:
Manual Test 4 consistency review found that path usernames used `[REDACTED_USER]`, while structured username fields used `[REDACTED_USERNAME]`.

Options considered:
Keep both labels, use separate categories for path usernames and structured usernames, or standardize on one replacement label.

Decision:
Standardize current product output on `[REDACTED_USERNAME]` for both home-path usernames and explicit structured username fields.

Reason:
Both labels represent the same conceptual category: account or local usernames. One marker improves readability, grading consistency, and presentation clarity.

Stakeholders affected:
Developers, support recipients, security reviewers, and people whose usernames appear in logs.

Known limitation:
Historical evidence files still contain the markers that were actually observed in prior runs.

## 2f. IPv4 Sentence Punctuation Boundary

Context:
Manual Test 5 showed `Connection received from 192.168.20.50.` remained visible because the IPv4 detector rejected any candidate followed by a dot.

Options considered:
Keep rejecting all trailing dots, allow all trailing dots, special-case the observed sentence, or allow a trailing dot only when it behaves like sentence punctuation.

Decision:
Treat a dot after an IPv4 candidate as sentence punctuation only when it is followed by the end of input, whitespace, or closing punctuation. Continue preserving dotted numeric sequences such as `1.2.3.4.5` and hostname-embedded values such as `https://10.20.30.40.example.com/status`.

Reason:
This fixes the privacy/security false negative without hardcoding the exact sentence or weakening the previous false-positive protections.

Stakeholders affected:
People whose IP information appears in logs, security reviewers, developers, and support recipients.

Known limitation:
The rule remains a deterministic token-boundary rule and does not parse every possible log grammar.

## 2g. Frozen Sanitizer After Manual Test 6

Context:
Manual Test 6 confirmed the post-F7 regression suite but identified `Firmware 1.2.3.4 installed successfully.` as a borderline over-redaction.

Options considered:
Add `Firmware` as another version keyword, add broader semantic/NLP classification, or document the limitation and keep the sanitizer frozen.

Decision:
Do not add another keyword exception. Keep the core sanitizer frozen unless a high-severity privacy/security failure is found.

Reason:
SafePaste's privacy architecture relies on narrow, auditable, local deterministic rules. Expanding contextual exceptions one keyword at a time can make behavior harder to reason about and may increase false-negative risk.

Stakeholders affected:
Developers, support recipients, people whose data appears in logs, and security reviewers.

Known limitation:
Some ambiguous IPv4-shaped version strings may be over-redacted when they fall outside the explicitly supported contexts.

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
