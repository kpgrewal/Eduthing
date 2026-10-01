# Eduthing

Practical tools built with AI assistance (Claude) and tested on real Windows machines. The focus is small, useful utilities that solve everyday IT support problems.

## Projects

| Project | Description |
|---|---|
| [servicedesk-toolkit](servicedesk-toolkit/) | Dependency-free PowerShell scripts for Level 2 service desk: system health, network triage, event log summary, safe temp cleanup, software inventory, AD user status, printer and drive repair, and a KB article generator. |

## How I work

- I describe the problem and the constraints, and AI drafts the code.
- I run everything on real machines and fix what breaks. For example, the health script originally assumed WinRM even for local runs, and that was caught and fixed in testing.
- Anything that deletes data gets a preview mode (`-WhatIf`) first.

More projects to come.
