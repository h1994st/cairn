# justfile — top-level entry points for cairn.
#
# Run `just` (no args) to see all recipes.

default-target := "aarch64-unknown-linux-musl"

# List all recipes.
default:
    @just --list

# Interactively install Brewfile + rustup + pinned toolchain + cross, then check container runtime.
bootstrap:
    #!/usr/bin/env bash
    set -euo pipefail

    have() { command -v "$1" >/dev/null 2>&1; }
    step() { printf "\n==> %s\n" "$1"; }
    ask() {
        # Read the y/N answer from the controlling terminal so this works
        # even if just has redirected stdin.
        local reply
        read -r -p "$1 [y/N] " reply </dev/tty
        [[ "$reply" =~ ^[Yy]$ ]]
    }

    # 1. Homebrew-managed host dependencies.
    step "Installing Brewfile dependencies"
    brew bundle install

    # 2. rustup. Homebrew's rust formula does NOT honor rust-toolchain.toml,
    # so the pinned toolchain has to come from the official installer.
    step "Checking rustup"
    if have rustup; then
        rustup --version
    else
        echo "rustup is not installed."
        if ask "Install rustup now via the official installer?"; then
            # --default-toolchain none — rust-toolchain.toml will install the
            # right channel and targets on the next cargo invocation, so we
            # don't waste a download on whatever rustup defaults to.
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain none
        else
            echo "Skipping rustup. Install it manually before re-running bootstrap."
        fi
    fi

    # Make ~/.cargo/bin visible to the rest of this script so a freshly
    # installed cargo/rustup is usable for the steps below.
    if [[ -d "$HOME/.cargo/bin" && ":$PATH:" != *":$HOME/.cargo/bin:"* ]]; then
        export PATH="$HOME/.cargo/bin:$PATH"
    fi

    # 3. Pinned toolchain (channel + targets) from rust-toolchain.toml.
    step "Installing the pinned toolchain (rust-toolchain.toml)"
    if have rustup; then
        # `rustup show` in the repo root materialises whatever rust-toolchain.toml
        # asks for. This may take a while on the first run.
        rustup show
    else
        echo "rustup unavailable; skipping toolchain install."
    fi

    # 4. cross.
    step "Checking cross"
    if have cross; then
        cross --version 2>&1 | head -n1
    elif have cargo; then
        echo "cross is not installed."
        if ask "Install via 'cargo install cross --git https://github.com/cross-rs/cross'?"; then
            cargo install cross --git https://github.com/cross-rs/cross
        else
            echo "Skipping cross."
        fi
    else
        echo "cargo is unavailable, so cross cannot be installed. Install rustup first."
    fi

    # 5. Container runtime — required by cross, but we can't install it for the
    # user (the choice between Docker Desktop / Colima / OrbStack is theirs).
    step "Checking container runtime"
    if   have docker  && docker  info >/dev/null 2>&1; then echo "docker:  ok"
    elif have podman  && podman  info >/dev/null 2>&1; then echo "podman:  ok"
    elif have nerdctl && nerdctl info >/dev/null 2>&1; then echo "nerdctl: ok"
    else
        echo "No working container runtime detected. cross will fail until one is set up."
        echo "Pick one and install it manually:"
        echo "  - Docker Desktop  https://www.docker.com/products/docker-desktop/"
        echo "  - Colima          brew install colima && colima start"
        echo "  - OrbStack        https://orbstack.dev/"
    fi

    step "Done"
    echo "Run 'just doctor' to verify the final state."

# Report versions of relevant tools and warn about missing ones.
doctor:
    #!/usr/bin/env bash
    set -u
    have() { command -v "$1" >/dev/null 2>&1; }
    line() { printf "%-10s %s\n" "$1" "$2"; }

    if have just;   then line "just"   "$(just --version)";                    else line "just"   "(missing)"; fi
    if have cargo;  then line "cargo"  "$(cargo --version)";                   else line "cargo"  "(missing — install rustup)"; fi
    if have rustc;  then line "rustc"  "$(rustc --version)";                   else line "rustc"  "(missing — install rustup)"; fi
    if have cross;  then line "cross"  "$(cross --version 2>&1 | head -n1)";   else line "cross"  "(missing — cargo install cross --git https://github.com/cross-rs/cross)"; fi
    # `utmctl version` only works when UTM.app is running and has been granted
    # Automation permission. Fall back to reporting the path so an unprivileged
    # or background shell still gets a useful signal.
    if have utmctl; then
        v=$(utmctl version 2>/dev/null | head -n1)
        if [[ -n "$v" ]]; then line "utmctl" "$v"; else line "utmctl" "$(command -v utmctl) (start UTM.app + grant Automation for full version output)"; fi
    else
        line "utmctl" "(not on PATH — UTM optional)"
    fi

    echo
    echo "Container runtime (needed by cross):"
    if   have docker  && docker  info >/dev/null 2>&1; then echo "  docker:  ok"
    elif have podman  && podman  info >/dev/null 2>&1; then echo "  podman:  ok"
    elif have nerdctl && nerdctl info >/dev/null 2>&1; then echo "  nerdctl: ok"
    else echo "  WARNING: no container runtime detected. cross will fail."
    fi

# Scaffold a new CVE crate. Usage: just new cve-2026-12345
new cve:
    ./scripts/new-cve.sh {{cve}}

# Show cross-build targets configured for the project.
targets:
    @echo "default-target: {{default-target}}"
    @echo
    @echo "available targets (rust-toolchain.toml):"
    @awk '/^targets *= *\[/{flag=1; next} /^\]/{flag=0} flag {gsub(/[",]/, ""); gsub(/^[[:space:]]+/, ""); if ($0!="") print "  - " $0}' rust-toolchain.toml

# Cross-build a single CVE crate (release profile).
build cve target=default-target:
    cross build --release --package {{cve}} --target {{target}}

# Cross-build the entire workspace.
build-all target=default-target:
    cross build --release --workspace --target {{target}}

# Cross-build a single CVE crate (release profile).
debug-build cve target=default-target:
    cross build --profile exploit --package {{cve}} --target {{target}}

# Cross-build the entire workspace.
debug-build-all target=default-target:
    cross build --profile exploit --workspace --target {{target}}

# cargo test for one crate (host-only; cross is not used here).
test cve:
    cargo test --package {{cve}}

# Cross-build, then scp the resulting binary to $VM_HOST:/tmp/.
deploy cve target=default-target: (build cve target)
    #!/usr/bin/env bash
    set -euo pipefail
    : "${VM_HOST:?VM_HOST is not set; export VM_HOST=user@vm}"
    bin="target/{{target}}/release/{{cve}}"
    test -f "$bin" || { echo "binary not found: $bin"; exit 1; }
    scp "$bin" "$VM_HOST:/tmp/"

# Deploy, then ssh in and execute the binary.
run cve target=default-target: (deploy cve target)
    #!/usr/bin/env bash
    set -euo pipefail
    : "${VM_HOST:?VM_HOST is not set; export VM_HOST=user@vm}"
    ssh "$VM_HOST" "/tmp/{{cve}}"

# Pull dmesg and uname -a from the VM into crates/<cve>/artifacts/ (UTC-stamped).
collect cve:
    #!/usr/bin/env bash
    set -euo pipefail
    : "${VM_HOST:?VM_HOST is not set; export VM_HOST=user@vm}"
    dest="crates/{{cve}}/artifacts"
    mkdir -p "$dest"
    ts=$(date -u +%Y%m%dT%H%M%SZ)
    ssh "$VM_HOST" "uname -a"   > "$dest/uname-$ts.log"
    ssh "$VM_HOST" "sudo dmesg" > "$dest/dmesg-$ts.log"
    echo "wrote $dest/uname-$ts.log and $dest/dmesg-$ts.log"

# fmt --check + clippy with warnings as errors. Run before declaring work done.
check:
    cargo fmt --all -- --check
    cargo clippy --workspace --all-targets -- -D warnings

# Format the workspace.
fmt:
    cargo fmt --all

# cargo clean + remove the targets/ staging area.
clean:
    cargo clean
    rm -rf targets/
