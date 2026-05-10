# Environment

Setup notes for the macOS host and the Linux VMs that most CVE reproductions run against. This document covers **generic** host and VM hygiene only. Per-CVE configuration (kernel modules to load, sysctls, vulnerable package versions, etc.) lives in the corresponding crate's `README.md`.

## Host setup (macOS)

The primary development host is Apple Silicon macOS.

### 1. Homebrew dependencies

Everything Homebrew can manage is declared in `Brewfile`:

```sh
brew bundle install   # or: just bootstrap
```

This installs `just`, `utm` (cask), `coreutils`, `wget`, `git`, `gh`.

### 2. Rust toolchain — install via rustup, not Homebrew

`rust-toolchain.toml` pins the Rust channel and required targets/components. Homebrew's `rust` formula does **not** honor `rust-toolchain.toml`, so install the official rustup-managed toolchain instead:

```sh
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

After installation, `rustup` will pick up `rust-toolchain.toml` automatically when you `cd` into the repo and pull the pinned channel + targets.

### 3. cross-rs/cross

```sh
cargo install cross --git https://github.com/cross-rs/cross
```

`cross` runs builds inside a container so the host doesn't need a Linux toolchain. The default target is set in `Cross.toml` (`x86_64-unknown-linux-musl`).

### 4. Container runtime for `cross`

`cross` requires a working container runtime. **This project is developed with Docker Desktop**, but `cross` works equally well with [Colima](https://github.com/abiosoft/colima) and [OrbStack](https://orbstack.dev/) — pick whichever you prefer. The `Brewfile` does not install one because the choice is yours and we didn't want to force a heavy dependency on every clone.

Whichever you pick, make sure its daemon is running before invoking `cross` or any `just` recipe that calls it (`build`, `build-all`, `deploy`, `run`).

### 5. Verify

```sh
just doctor
```

This prints versions of `just`, `cargo`, `rustc`, `cross`, optionally `utmctl`, and warns if no container runtime is detected.

## UTM VM setup

UTM is the virtualization manager for Linux guests. VMs are managed manually for now — there is no provisioning automation in this repo.

### Apple Silicon: Emulate mode

On Apple Silicon Macs, UTM offers two backends: **Virtualize** (fast, ARM-only) and **Emulate** (slower, but supports x86_64). Most of the kernel CVEs of interest are easier to reproduce against x86_64 distributions, so the default workflow uses **Emulate** + an x86_64 guest. Use Virtualize for ARM-targeted CVEs.

### Generic guest setup (Ubuntu Server LTS as the default)

1. Download an Ubuntu Server LTS x86_64 ISO. **Record the ISO's SHA256** in the crate README's `Notes` section if a specific image is required for a given CVE; otherwise note it once in your local environment notes.
2. Provision the VM:
   - 4 GB RAM
   - 20 GB disk
   - 2 vCPU
3. Complete the install with a default user and OpenSSH selected.
4. **Take a snapshot before running `apt upgrade`.** This becomes the clean baseline you can roll back to between reproductions.
5. Disable AppArmor (most kernel-LPE PoCs assume it is off):

   ```sh
   sudo systemctl disable --now apparmor
   sudo apt purge apparmor   # optional
   ```

6. Add `nokaslr` to the kernel cmdline by editing `/etc/default/grub` (`GRUB_CMDLINE_LINUX_DEFAULT`) and running `sudo update-grub`. Reboot.
7. SSH access:
   - Copy your host pubkey into the guest (`ssh-copy-id user@vm`).
   - On the host, export `VM_HOST=user@vm` (or add to your shell profile).
8. End-to-end pipeline check:

   ```sh
   just run cve-2026-31431
   ```

   This cross-builds, scps the binary into the VM, and runs it. Expected output is the banner from `crates/common`. If you see the banner, the pipeline is working — the actual reproduction work is your job.

### Per-CVE configuration

This document deliberately stops at generic VM hygiene. Anything CVE-specific — which kernel modules to load, which sysctls to set, which packages to downgrade — goes in the corresponding crate's `README.md` (typically the `Affected` and `Reproduction` sections). Don't push that information back here; it will get stale.

## Non-Linux CVEs

Future CVEs may target macOS, Windows, web applications running in Docker, or other environments. This document will gain sections for those as the need arises. For now, treat the Linux+UTM workflow as the reference.
