# Methodology

This document describes *how* CVEs are organised in `cairn`. It does not contain analysis of any specific CVE — that lives in each crate's own `README.md`, written by the owner as they reproduce the vulnerability.

## One crate per CVE

Every CVE lives in its own crate under `crates/`, named exactly `cve-YYYY-NNNNN` (lowercase, hyphenated). Each crate is self-contained: its own `Cargo.toml`, its own dependencies, its own optional target requirements, its own runtime artifacts, its own notes. Removing or rewriting one crate never touches another.

The crates are part of a single Cargo workspace so that:

- shared utilities (`crates/common`) are reused without copy-paste;
- a single `cargo check --workspace` confirms the whole repo still builds;
- there is exactly one `Cargo.lock`, one rustfmt config, one clippy config, one toolchain pin.

The scope is intentionally broad. CVEs in this repo may target the Linux kernel, userspace memory-corruption bugs, web applications, cryptographic libraries, supply-chain attacks, or anything else. The unifying thread is the *method* — same crate layout, same documentation template, same reproducibility discipline — not any particular subsystem.

## Per-crate layout

```txt
crates/<cve-id>/
├── Cargo.toml      # declares the crate, pulls deps from the workspace
├── README.md       # the empty template — the owner fills it in
├── src/main.rs     # entry point; calls common::banner
├── tests/          # integration tests, if any
└── refs/notes.md   # the owner's freeform notes
```

`artifacts/` is created on demand by `just collect <cve>` (or by the owner) to hold runtime evidence captured during reproduction. It is never tracked by git.

`scripts/new-cve.sh` (or `just new <cve-id>`) creates this layout. It refuses to overwrite an existing crate.

## The README template

Every CVE's `README.md` follows the same fixed structure, with these section headings and **nothing else** at scaffold time:

- `## Summary`
- `## Category`
- `## Affected`
- `## Root Cause`
- `## Reproduction`
- `## References`
- `## Notes`

**The owner fills these in.** Claude Code does not. The template is deliberately empty so that there is no anchoring effect from a pre-written summary, and so that the act of writing each section is part of how the owner learns the bug.

What goes where:

- **Summary**: one paragraph in the owner's own words. Not copy-pasted from CVE databases.
- **Category**: a short tag — kernel LPE, userspace UAF, SQL injection, deserialization, etc.
- **Affected**: versions, distributions, configurations, kernel features, library versions. Specific enough that a future reader can build the same environment.
- **Root Cause**: the owner's mental model of why the bug exists. Code references with line numbers and upstream patch links.
- **Reproduction**: step-by-step, cross-referencing `just` recipes (`just run cve-XXXX-XXXXX`, etc.). Should be runnable from a clean clone.
- **References**: disclosure timeline, CVE record, patch commits, public PoCs, writeups, related CVEs. Links only — no summaries.
- **Notes**: anything else that doesn't fit. VM-specific quirks, kernel symbol offsets, dmesg signatures, dead ends, things the owner tried that didn't work.

## Reproducibility — record everything

The whole point of this repo is that someone (often the future owner) should be able to come back in a year and re-run the reproduction. That requires:

- **Pinned toolchain.** `rust-toolchain.toml` pins the Rust channel. Every crate builds with the same compiler unless it overrides explicitly.
- **Recorded affected versions.** Distribution, kernel version, library version, package SHA — captured in the `Affected` section of the crate README.
- **Recorded VM image.** When a VM image is used, its ISO SHA256 and any post-install changes (snapshot point, kernel cmdline, disabled mitigations) are recorded in the crate README's `Notes` section. Generic VM hygiene lives in `docs/environment.md`; per-CVE specifics live in the crate.
- **Recorded binaries.** When a vulnerable binary is checked in or downloaded, its SHA256 and source URL are recorded.
- **Linked upstream commits.** Patch commits and CVE records are linked from `References`.
- **Captured runtime artifacts.** `dmesg`, `uname -a`, crash logs, and any other runtime evidence go into `crates/<cve>/artifacts/` with a UTC timestamp. The directory is created on demand and is not tracked by git. `just collect <cve>` automates the common case (`dmesg` + `uname -a`).

If a piece of state matters for reproduction and isn't in version control or captured locally under `artifacts/`, it isn't recorded. Re-record it.

## Public PoCs vs. private research

Vulnerabilities reproduced from **public disclosures** are reproduced openly and credited:

- The original researcher and writeup are linked in `References`.
- If the reproduction is materially derived from a public PoC, that PoC is cited. Any code adapted from it carries a comment naming the source.
- All such CVEs are publicly disclosed and patched (or in the process of being patched). This repo does not attempt to host unpatched, undisclosed vulnerabilities.

Vulnerabilities the owner discovers themselves (or via private collaboration) are **documented in the crate but not published** until disclosure is complete. A crate may exist locally with `Affected`, `Root Cause`, etc. filled in while the public reference list stays empty — that's a deliberate signal that disclosure is in flight.

## Style and discipline

- Match existing code style. Run `just check` (rustfmt + clippy with `-D warnings`) before declaring work done.
- Keep commits focused and reference CVE ids when relevant: `cve-2026-31431: scaffold crate`.
- Don't speculatively add recipes, dependencies, or files that aren't needed yet.
- Don't add CI, GitHub Actions, or release automation unless it's explicitly part of the work.
- Shared helpers go in `crates/common` only once a pattern has appeared in **at least two** CVE crates. Premature abstraction is the enemy.
