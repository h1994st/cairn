# cairn

A long-term, single-repository archive of CVE reproductions, written in Rust. Each CVE is a self-contained crate within one Cargo workspace.

## The cairn metaphor

A *cairn* is a stack of stones left by climbers and hikers to mark a route across difficult terrain — each stone is a small contribution that helps the next person find their way. This repository works the same way: every reproduced CVE is one stone added to the trail. Over time the cairn grows, and the route through unfamiliar ground becomes a little easier to follow.

## ⚠️ Disclaimer

> **This repository is for security research and education only.**
>
> The code in this repository reproduces publicly disclosed vulnerabilities for the purpose of understanding how they work. It is intended to be run only on isolated systems that the operator owns or is explicitly authorized to test.
>
> **Do not** run any code from this repository against systems you do not own or have written permission to test. **Do not** run it on shared infrastructure, cloud instances, multi-tenant hosts, or production systems. **Do not** use it to gain unauthorized access to anything.
>
> Unauthorized use of these techniques against systems you do not own is illegal in most jurisdictions and may carry serious civil and criminal penalties. The author of this repository accepts no responsibility for misuse.
>
> All vulnerabilities reproduced here are publicly disclosed and patched (or in the process of being patched). This repository does not contain or seek to contain unpatched, undisclosed vulnerabilities. Reproductions are based on public disclosures and are credited to the original researchers in each crate's README.
>
> By using this repository you acknowledge that you understand the above and agree to use the code responsibly.

## Scope

`cairn` is **not** a Linux-kernel-only project. Any CVE worth understanding deeply is in scope: kernel privilege escalations, userspace memory-corruption bugs, web application vulnerabilities, cryptographic flaws, supply-chain attacks, and so on. The unifying thread is the *method* — every entry follows the same crate structure, the same documentation template, and the same reproducibility discipline — not any particular subsystem.

This is a **personal learning repository**. The owner reproduces each CVE themselves to understand it. Tooling and scaffolding are automated; the analysis is not.

## Repository structure

```txt
cairn/
├── crates/         # one crate per CVE, plus crates/common for shared utilities
├── docs/           # methodology, environment setup, general references
├── scripts/        # new-cve.sh and other plumbing
├── Cargo.toml      # workspace manifest
├── Cross.toml      # cross-compilation config
├── Brewfile        # macOS host dependencies
├── justfile        # one-liner entry points (build, deploy, run, ...)
├── CLAUDE.md       # working agreement for Claude Code sessions
└── README.md
```

For details on how CVE crates are organised and what goes where, see [`docs/methodology.md`](docs/methodology.md). For host and VM setup, see [`docs/environment.md`](docs/environment.md). [`CLAUDE.md`](CLAUDE.md) is the working agreement for Claude Code sessions in this repo and should be read by anyone using AI assistance here.

## Quickstart

1. Install Homebrew dependencies:

   ```sh
   brew bundle install      # or: just bootstrap
   ```

2. Install Rust via rustup (Homebrew's `rust` formula does not honor `rust-toolchain.toml`):

   ```sh
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   ```

3. Install `cross`:

   ```sh
   cargo install cross --git https://github.com/cross-rs/cross
   ```

4. Install a container runtime for `cross`. **This project is developed with Docker Desktop**, but `cross` works equally well with [Colima](https://github.com/abiosoft/colima) or [OrbStack](https://orbstack.dev/) — pick whichever you prefer. None of them is in the `Brewfile` because the choice is yours.
5. Set up a UTM VM following [`docs/environment.md`](docs/environment.md), then export `VM_HOST=user@vm` in your shell.
6. Verify the toolchain and try the first reproduction:

   ```sh
   just doctor
   just run cve-2026-31431   # cross-builds, scps to $VM_HOST, runs the exploit
   ```

`cve-2026-31431` is a working local-privilege-escalation reproduction — running it modifies the page cache of `/usr/bin/su` on the target VM (effects revert on reboot or page eviction). See [`crates/cve-2026-31431/README.md`](crates/cve-2026-31431/README.md) for details on what it does. Crates produced by `just new …` ship only a banner; the reproduction itself is the owner's responsibility for each new CVE.

## Adding a new CVE

```sh
just new cve-YYYY-NNNNN
```

This invokes `scripts/new-cve.sh` to scaffold a fresh crate under `crates/cve-YYYY-NNNNN/` with the standard layout and an empty README template. Then read [`docs/methodology.md`](docs/methodology.md) for what to fill in and how.

## License

Dual-licensed under either of:

- MIT license ([LICENSE-MIT](LICENSE-MIT))
- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE))

at your option.
