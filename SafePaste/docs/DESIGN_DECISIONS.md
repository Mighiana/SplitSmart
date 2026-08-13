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
Redact valid non-loopback IPv4 addresses by default and provide a checkbox to preserve them. Preserve IPv4 loopback addresses in `127.0.0.0/8` because they are usually local diagnostic context. Preserve IPv4-shaped values in narrow version-related fields. Redact common user-directory path usernames and explicit structured username fields while preserving surrounding context.

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

## 2d. Version-Field IPv4-Shaped Values

Context:
Manual Test 3 showed `release=1.2.3.4` became `release=[REDACTED_IP_ADDRESS]`.

Options considered:
Keep purely syntactic IPv4 redaction, disable IPv4 redaction broadly, special-case one release string, or preserve IPv4-shaped values only in narrow version-related fields.

Decision:
Preserve IPv4-shaped values when immediately preceded by version-related fields such as `version=`, `release=`, `app_version=`, or `software_version=`. Continue redacting `client_ip=...`, `server_ip=...`, and other non-loopback IPv4 values.

Reason:
This resolves the automated-vs-human grader disagreement without weakening general IP protection. The rule is small enough to audit and avoids hardcoding the specific observed value.

Stakeholders affected:
Developers, support recipients, and security reviewers.

Known limitation:
The context check only covers a small set of version-related field names.

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
