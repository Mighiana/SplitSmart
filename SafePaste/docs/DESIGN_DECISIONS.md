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
Redact valid IPv4 addresses by default and provide a checkbox to preserve them. Redact common user-directory path usernames while preserving path shape.

Reason:
Default privacy protection helps data subjects and security stakeholders, while the checkbox gives developers control when exact network context matters.

Stakeholders affected:
All four stakeholder groups.

Known limitation:
The app does not classify public, private, and localhost IPs differently.

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
