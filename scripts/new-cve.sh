#!/usr/bin/env bash
# new-cve.sh — scaffold a new CVE crate under crates/.
#
# Usage:  ./scripts/new-cve.sh cve-2026-12345
#
# Naming convention: lowercase, hyphenated, exactly cve-YYYY-NNNNN.
# Refuses to overwrite an existing crate.

set -euo pipefail

usage() {
    echo "usage: $0 <cve-id>"
    echo "example: $0 cve-2026-12345"
    exit 2
}

[[ $# -eq 1 ]] || usage

cve="$1"

# Validate naming convention: cve-YYYY-NNNN+ (4+ digits in the suffix).
if ! [[ "$cve" =~ ^cve-[0-9]{4}-[0-9]{4,}$ ]]; then
    echo "error: '$cve' does not match cve-YYYY-NNNN+ (lowercase, hyphenated)"
    exit 1
fi

# UPPERCASE form for the README heading and banner argument.
upper=$(echo "$cve" | tr '[:lower:]' '[:upper:]')

# Resolve repo root from this script's location (scripts/ lives at the root).
script_dir=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$script_dir/.." && pwd)
crate_dir="$root/crates/$cve"

if [[ -e "$crate_dir" ]]; then
    echo "error: $crate_dir already exists; refusing to overwrite"
    exit 1
fi

mkdir -p "$crate_dir/src" "$crate_dir/tests" "$crate_dir/refs"

cat > "$crate_dir/Cargo.toml" <<EOF
[package]
name = "$cve"
version.workspace = true
edition.workspace = true
rust-version.workspace = true
authors.workspace = true
license.workspace = true
repository.workspace = true
publish.workspace = true

[[bin]]
name = "$cve"
path = "src/main.rs"

[dependencies]
common.workspace = true
anyhow.workspace = true
EOF

cat > "$crate_dir/src/main.rs" <<EOF
fn main() {
    common::init("$upper");
}
EOF

# README template: literal contents from CLAUDE.md, with only the heading
# substituted. Section bodies stay empty for the owner to fill in.
cat > "$crate_dir/README.md" <<EOF
# $upper

## Summary

<!-- One paragraph: what the vulnerability is, in your own words. -->

## Category

<!-- e.g. Linux kernel — local privilege escalation -->

## Root Cause

<!-- Your understanding of why the bug exists. -->

## Reproduction

<!-- Your step-by-step. Cross-reference \`just\` recipes. -->

## Tested Platforms

<!-- One row per VM you've reproduced this on. \`just collect\` writes uname/dmesg into artifacts/. -->

| Distribution | Kernel | Arch | Build target | Result | Date |
|---|---|---|---|---|---|
|  |  |  |  |  |  |

## References

<!-- Disclosure, patches, writeups, related CVEs. Links only. -->
EOF

# Placeholder that matches cve-2026-31431's layout.
: > "$crate_dir/refs/notes.md"

echo "created $crate_dir"
echo "next:"
echo "  cargo check --workspace"
echo "  edit crates/$cve/README.md as you learn"
