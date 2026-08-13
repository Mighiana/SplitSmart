# SafePaste

SafePaste is a privacy-aware browser-based log sanitizer for developers, IT support staff, students, and technical users who need to remove sensitive information before sharing technical text.

## Project Status

This repository is being built as an academic Human-Centered AI software engineering project. The implementation is intentionally small, local-only, and auditable.

## Motivation

Technical logs often contain useful debugging context mixed with emails, IP addresses, file paths, passwords, API keys, and access tokens. SafePaste helps users review and redact likely sensitive values before sending logs to AI tools, issue trackers, support systems, chat, email, or forums.

## Stakeholders

See [docs/STAKEHOLDER_MAP.md](docs/STAKEHOLDER_MAP.md) for the stakeholder map and explicit conflicts.

## Privacy Architecture

SafePaste is designed to run entirely in the browser with no backend, no database, no analytics, no third-party scripts, and no storage of pasted logs. Pasted content must remain in memory only while the page is open.

## How To Run

Open `index.html` directly in a browser, or serve the folder with a local static server.

## How To Test

Unit tests and evaluations will be added after the first implementation.

## Repository Structure

```text
SafePaste/
  index.html
  styles.css
  app.js
  src/sanitizer.js
  tests/test-sanitizer.js
  evals/
  docs/
  history/v1/
  .claude/
```

## Methodology

The project follows a specification-first engineering loop:

1. document stakeholders and conflicts
2. write a preserved v1 specification
3. create an AI engineering harness
4. implement the smallest complete local product
5. run unit tests, evaluations, red-team checks, and static security checks
6. preserve real failures
7. iterate the implementation and final specification

## Known Limitations

The initial limitation is intentional scope: SafePaste uses deterministic local detection rules rather than cloud services or external AI classification.
