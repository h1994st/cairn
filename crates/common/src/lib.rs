//! Shared utilities for cairn CVE crates.
//!
//! Intentionally small. Every CVE binary should start with a single
//! [`init`] call — it installs the tracing subscriber and emits a
//! banner identifying the run. Submodules are stubs that grow as
//! patterns emerge across CVEs; they should never contain
//! vulnerability-specific logic.

pub mod prelude;

use tracing::info;
use tracing_subscriber::EnvFilter;

/// Install the tracing subscriber (filter from `RUST_LOG`, defaulting
/// to `info`) and emit a startup banner identifying the binary and the
/// environment it runs in. Cross-platform: compiles on Linux, macOS,
/// and Windows. Safe to call more than once — extra calls are no-ops.
pub fn init(name: &str) {
    init_tracing();
    log_banner(name);
}

fn init_tracing() {
    let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));
    let _ = tracing_subscriber::fmt()
        .with_env_filter(filter)
        .with_target(false)
        .try_init();
}

fn log_banner(name: &str) {
    info!(
        name,
        os = std::env::consts::OS,
        arch = std::env::consts::ARCH,
        host = %hostname(),
        pid = std::process::id(),
        "starting"
    );

    #[cfg(unix)]
    {
        // SAFETY: getuid/geteuid are async-signal-safe and always succeed.
        let uid = unsafe { libc::getuid() };
        let euid = unsafe { libc::geteuid() };
        info!(uid, euid, "identity");
    }

    #[cfg(windows)]
    {
        let user = std::env::var("USERNAME").unwrap_or_else(|_| "?".into());
        info!(%user, "identity");
    }
}

#[cfg(unix)]
fn hostname() -> String {
    let mut buf = [0u8; 256];
    // SAFETY: gethostname writes at most buf.len() bytes into buf and
    // null-terminates on success.
    let rc = unsafe { libc::gethostname(buf.as_mut_ptr().cast(), buf.len()) };
    if rc != 0 {
        return "?".into();
    }
    let len = buf.iter().position(|&b| b == 0).unwrap_or(buf.len());
    String::from_utf8_lossy(&buf[..len]).into_owned()
}

#[cfg(windows)]
fn hostname() -> String {
    std::env::var("COMPUTERNAME").unwrap_or_else(|_| "?".into())
}
