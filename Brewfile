# Brewfile — host dependencies for cairn (macOS)
#
# Run `brew bundle install` from the repo root to install everything below.
#
# Intentionally NOT in this file:
#   - rustup / rustc / cargo: install via the official rustup installer so that
#     rust-toolchain.toml is honored. Homebrew's Rust formula does not respect it.
#   - cross: installed via `cargo install cross --git https://github.com/cross-rs/cross`.
#   - Container runtime for cross (Docker Desktop, Colima, OrbStack, etc.):
#     left to user choice. See README and docs/environment.md for guidance.

# Command runner
brew "just"

# Virtualization for Linux guests
cask "utm"

# Useful auxiliaries
brew "coreutils"     # GNU coreutils, including sha256sum
brew "wget"
brew "git"
brew "gh"
brew "uv"
