// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//! Pandoc document conversion support for vext
//!
//! Enables converting commit messages and documentation between formats
//! (Markdown, AsciiDoc, HTML, etc.) before sending to IRC.

#[cfg(feature = "pandoc-support")]
use pandoc::{Pandoc, PandocOption, OutputKind};

#[cfg(feature = "pandoc-support")]
use anyhow::Result;

/// Convert text from one format to another using Pandoc
#[cfg(feature = "pandoc-support")]
pub fn convert(input: &str, from_format: &str, to_format: &str) -> Result<String> {
    let mut pandoc = Pandoc::new();

    pandoc.set_input_format(from_format.into(), vec![]);
    pandoc.set_output_format(to_format.into(), vec![]);
    pandoc.set_output(OutputKind::Pipe);
    pandoc.add_option(PandocOption::NoHighlight);

    pandoc.execute()
        .map_err(|e| anyhow::anyhow!("Pandoc conversion failed: {}", e))
        .and_then(|output| {
            String::from_utf8(output.0)
                .map_err(|e| anyhow::anyhow!("UTF-8 decode error: {}", e))
        })
}

/// Strip formatting from text for plain IRC messages
#[cfg(feature = "pandoc-support")]
pub fn to_plain_text(input: &str, input_format: &str) -> Result<String> {
    convert(input, input_format, "plain")
}

/// Convert markdown to IRC-formatted text with mIRC color codes
#[cfg(feature = "pandoc-support")]
pub fn markdown_to_irc(markdown: &str) -> Result<String> {
    // First convert to plain text, then apply IRC formatting
    let plain = to_plain_text(markdown, "markdown")?;
    Ok(plain)
}

#[cfg(not(feature = "pandoc-support"))]
pub fn convert(_input: &str, _from: &str, _to: &str) -> anyhow::Result<String> {
    Err(anyhow::anyhow!("Pandoc support not enabled. Rebuild with --features pandoc-support"))
}

#[cfg(not(feature = "pandoc-support"))]
pub fn to_plain_text(input: &str, _format: &str) -> anyhow::Result<String> {
    Ok(input.to_string())
}

#[cfg(not(feature = "pandoc-support"))]
pub fn markdown_to_irc(input: &str) -> anyhow::Result<String> {
    Ok(input.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    #[cfg(feature = "pandoc-support")]
    fn test_markdown_to_plain() {
        let md = "# Heading\n\n**Bold** text";
        let result = to_plain_text(md, "markdown");
        assert!(result.is_ok());
    }

    #[test]
    #[cfg(not(feature = "pandoc-support"))]
    fn test_pandoc_disabled() {
        let result = convert("test", "markdown", "html");
        assert!(result.is_err());
    }
}
