//! Re-exports of items most CVE crates will want.
//!
//! `use common::prelude::*;` at the top of `main.rs` is the intended pattern.

pub use crate::init;

pub use anyhow::{anyhow, bail, Context, Result};
pub use tracing::{debug, error, info, trace, warn};
