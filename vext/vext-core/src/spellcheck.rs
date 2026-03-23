// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//! Spell checking support for vext commit messages
//!
//! Provides optional spell checking for commit messages before sending
//! notifications, helping catch typos in public IRC channels.

#[cfg(feature = "spell-check")]
use hunspell_rs::Hunspell;

#[cfg(feature = "spell-check")]
use anyhow::Result;

/// Spell checker for commit messages
#[cfg(feature = "spell-check")]
pub struct SpellChecker {
    checker: Hunspell,
}

#[cfg(feature = "spell-check")]
impl SpellChecker {
    /// Create a new spell checker with the specified language
    pub fn new(lang: &str) -> Result<Self> {
        let aff_path = format!("/usr/share/hunspell/{}.aff", lang);
        let dic_path = format!("/usr/share/hunspell/{}.dic", lang);

        let checker = Hunspell::new(&aff_path, &dic_path)?;
        Ok(Self { checker })
    }

    /// Check if a word is correctly spelled
    pub fn check_word(&self, word: &str) -> bool {
        self.checker.spell(word)
    }

    /// Get suggestions for a misspelled word
    pub fn suggest(&self, word: &str) -> Vec<String> {
        self.checker.suggest(word)
    }

    /// Check an entire message and return misspelled words
    pub fn check_message(&self, message: &str) -> Vec<String> {
        message
            .split_whitespace()
            .filter(|word| !self.check_word(word))
            .map(|s| s.to_string())
            .collect()
    }
}

#[cfg(not(feature = "spell-check"))]
pub struct SpellChecker;

#[cfg(not(feature = "spell-check"))]
impl SpellChecker {
    pub fn new(_lang: &str) -> anyhow::Result<Self> {
        Err(anyhow::anyhow!("Spell check not enabled. Rebuild with --features spell-check"))
    }

    pub fn check_word(&self, _word: &str) -> bool {
        true
    }

    pub fn suggest(&self, _word: &str) -> Vec<String> {
        vec![]
    }

    pub fn check_message(&self, _message: &str) -> Vec<String> {
        vec![]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    #[cfg(feature = "spell-check")]
    fn test_spell_check() {
        if let Ok(checker) = SpellChecker::new("en_US") {
            assert!(checker.check_word("hello"));
            assert!(!checker.check_word("hellooo"));
        }
    }

    #[test]
    #[cfg(not(feature = "spell-check"))]
    fn test_spell_check_disabled() {
        let result = SpellChecker::new("en_US");
        assert!(result.is_err());
    }
}
