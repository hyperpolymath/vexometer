// SPDX-License-Identifier: MPL-2.0
//! vex-verbosity-compressor — information density optimisation for LLM output.
//!
//! Detects the linguistic pathology classes enumerated by the vexometer LPS
//! metric (see `vexometer/docs/METRICS.adoc`): sycophancy density, hedge-word
//! ratio, corporate-speak frequency, unnecessary repetition, and
//! emoji/decoration abuse — plus the padding tics shown in that document's
//! HIGH-LPS example ("Essentially, what you're asking about is basically...").
//!
//! Compression removes only instances whose removal cannot change meaning
//! (sycophantic openers, discourse-adverbial corporate speak, padding
//! fillers). Hedges, repetitions, and emoji are detected and scored but left
//! in place: hedges are meaning-bearing, and naive sentence segmentation or
//! symbol stripping would risk deleting content.

#![forbid(unsafe_code)]

use serde::Serialize;

/// The pathology classes scored by this satellite. The first five mirror the
/// bullet list under LPS in `vexometer/docs/METRICS.adoc`; `Padding` covers
/// the filler tics from that document's HIGH-LPS example, which fall under
/// the LPS definition ("verbal tics, padding") but none of the five bullets.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum PathologyClass {
    Sycophancy,
    Hedge,
    CorporateSpeak,
    Repetition,
    EmojiDecoration,
    Padding,
}

impl PathologyClass {
    /// v0.1 heuristic weights for the LPS proxy. Chosen so that the tics the
    /// protocol singles out (sycophancy) dominate, and meaning-bearing
    /// hedges contribute least. Tunable; any change is visible in tests.
    pub fn weight(self) -> f64 {
        match self {
            PathologyClass::Sycophancy => 3.0,
            PathologyClass::Hedge => 1.0,
            PathologyClass::CorporateSpeak => 2.0,
            PathologyClass::Repetition => 2.5,
            PathologyClass::EmojiDecoration => 1.5,
            PathologyClass::Padding => 2.0,
        }
    }
}

/// One detected pathology instance. `start`/`end` are byte offsets into the
/// analysed text (end exclusive).
#[derive(Debug, Clone, Serialize)]
pub struct Finding {
    pub class: PathologyClass,
    pub excerpt: String,
    pub start: usize,
    pub end: usize,
    /// Whether `compress` will remove this instance.
    pub strippable: bool,
}

/// Result of `analyse`: the findings plus the LPS proxy computation.
#[derive(Debug, Serialize)]
pub struct Analysis {
    pub findings: Vec<Finding>,
    pub word_count: usize,
    pub weighted_sum: f64,
    /// `weighted_sum / word_count` (0.0 for empty input). A *proxy* for the
    /// vexometer LPS metric: the canonical score is computed by the vexometer
    /// Ada core; this mirrors the METRICS.adoc formula
    /// `weighted_sum(pathology_instances) / response_length` with
    /// response_length measured in words.
    pub lps_proxy: f64,
}

/// Result of `compress`.
#[derive(Debug, Serialize)]
pub struct Compressed {
    pub output: String,
    pub removed: Vec<Finding>,
    pub retained: Vec<Finding>,
}

/// A phrase pattern. Strippability is per pattern, not per class: e.g.
/// "at the end of the day" is a removable discourse adverbial, while
/// "leverage" is corporate speak embedded in sentence grammar — removing it
/// would break the sentence, so it is detect-only.
struct Pattern {
    phrase: &'static str,
    class: PathologyClass,
    strippable: bool,
}

const fn strip(phrase: &'static str, class: PathologyClass) -> Pattern {
    Pattern {
        phrase,
        class,
        strippable: true,
    }
}

const fn detect_only(phrase: &'static str, class: PathologyClass) -> Pattern {
    Pattern {
        phrase,
        class,
        strippable: false,
    }
}

const PATTERNS: &[Pattern] = &[
    // Sycophancy density — the tics METRICS.adoc names ("Great question!",
    // "Excellent point!") and their common variants.
    strip("that's a great question", PathologyClass::Sycophancy),
    strip("that is a great question", PathologyClass::Sycophancy),
    strip("what a great question", PathologyClass::Sycophancy),
    strip("great question", PathologyClass::Sycophancy),
    strip("that's an excellent question", PathologyClass::Sycophancy),
    strip("excellent question", PathologyClass::Sycophancy),
    strip("excellent point", PathologyClass::Sycophancy),
    strip("great point", PathologyClass::Sycophancy),
    strip(
        "i'd be happy to help you with that",
        PathologyClass::Sycophancy,
    ),
    strip("i'd be happy to help with that", PathologyClass::Sycophancy),
    strip("i would be happy to help", PathologyClass::Sycophancy),
    strip("i'd be happy to help", PathologyClass::Sycophancy),
    strip("you're absolutely right", PathologyClass::Sycophancy),
    strip("you are absolutely right", PathologyClass::Sycophancy),
    strip("thanks for asking", PathologyClass::Sycophancy),
    // Hedge word ratio — meaning-bearing, so detect-only.
    detect_only("perhaps", PathologyClass::Hedge),
    detect_only("maybe", PathologyClass::Hedge),
    detect_only("possibly", PathologyClass::Hedge),
    detect_only("arguably", PathologyClass::Hedge),
    detect_only("it's possible that", PathologyClass::Hedge),
    detect_only("it is possible that", PathologyClass::Hedge),
    detect_only("it could be argued", PathologyClass::Hedge),
    detect_only("it seems", PathologyClass::Hedge),
    // Corporate speak frequency — strippable only where discourse-adverbial.
    strip("at the end of the day", PathologyClass::CorporateSpeak),
    strip("when all is said and done", PathologyClass::CorporateSpeak),
    strip("moving forward", PathologyClass::CorporateSpeak),
    strip("going forward", PathologyClass::CorporateSpeak),
    strip("needless to say", PathologyClass::CorporateSpeak),
    strip(
        "it goes without saying that",
        PathologyClass::CorporateSpeak,
    ),
    detect_only("leverage", PathologyClass::CorporateSpeak),
    detect_only("synergy", PathologyClass::CorporateSpeak),
    detect_only("circle back", PathologyClass::CorporateSpeak),
    detect_only("touch base", PathologyClass::CorporateSpeak),
    detect_only("low-hanging fruit", PathologyClass::CorporateSpeak),
    // Padding — the "Essentially, ... basically ..." tics; semantically null.
    strip("essentially", PathologyClass::Padding),
    strip("basically", PathologyClass::Padding),
    strip("fundamentally speaking", PathologyClass::Padding),
    strip("simply put", PathologyClass::Padding),
    strip("in essence", PathologyClass::Padding),
    strip("at its core", PathologyClass::Padding),
    strip("it's worth noting that", PathologyClass::Padding),
    strip("it is worth noting that", PathologyClass::Padding),
    strip("it's important to note that", PathologyClass::Padding),
    strip("it is important to note that", PathologyClass::Padding),
    strip("as you may know", PathologyClass::Padding),
    strip("to be perfectly honest", PathologyClass::Padding),
];

/// Detect all pathology instances in `text`. Findings are sorted by start
/// offset and never overlap (at equal starts, the longest match wins — so
/// "that's a great question" beats the embedded "great question").
pub fn detect(text: &str) -> Vec<Finding> {
    let mut candidates: Vec<Finding> = Vec::new();
    for pattern in PATTERNS {
        collect_phrase_matches(text, pattern, &mut candidates);
    }
    collect_repetitions(text, &mut candidates);
    collect_emoji_runs(text, &mut candidates);

    // Longest-first at equal start, then earliest-first; drop overlaps.
    candidates.sort_by(|a, b| a.start.cmp(&b.start).then(b.end.cmp(&a.end)));
    let mut accepted: Vec<Finding> = Vec::new();
    for finding in candidates {
        if accepted.last().is_none_or(|prev| finding.start >= prev.end) {
            accepted.push(finding);
        }
    }
    accepted
}

/// Compute the full analysis (findings + LPS proxy) for `text`.
pub fn analyse(text: &str) -> Analysis {
    let findings = detect(text);
    let word_count = text.split_whitespace().count();
    let weighted_sum: f64 = findings.iter().map(|f| f.class.weight()).sum();
    let lps_proxy = if word_count == 0 {
        0.0
    } else {
        weighted_sum / word_count as f64
    };
    Analysis {
        findings,
        word_count,
        weighted_sum,
        lps_proxy,
    }
}

/// Remove every strippable finding from `text`, consuming any punctuation and
/// whitespace immediately after each removed span and repairing the seam each
/// removal leaves behind. Text away from removed spans is preserved
/// byte-for-byte — indentation, deliberate spacing, and blank lines survive.
///
/// Known v0.1 limitation (see ROADMAP): a stripped sentence-initial filler
/// leaves the following word lowercase — no recapitalisation is attempted.
pub fn compress(text: &str) -> Compressed {
    let findings = detect(text);
    let (removed, retained): (Vec<Finding>, Vec<Finding>) =
        findings.into_iter().partition(|f| f.strippable);

    let mut output = text.to_string();
    // Right-to-left so earlier byte offsets stay valid; each removal cleans
    // only its own seam.
    for finding in removed.iter().rev() {
        let after = consume_trailing(&output, finding.end);
        output.replace_range(finding.start..after, "");
        clean_seam(&mut output, finding.start);
    }
    Compressed {
        output,
        removed,
        retained,
    }
}

/// Extend a removed span over any run of `.,!?;:` then any run of spaces/tabs
/// directly after it, so "Great question! The fix:" strips to "The fix:".
fn consume_trailing(text: &str, end: usize) -> usize {
    let bytes = text.as_bytes();
    let mut i = end;
    while i < bytes.len() && matches!(bytes[i], b'.' | b',' | b'!' | b'?' | b';' | b':') {
        i += 1;
    }
    while i < bytes.len() && matches!(bytes[i], b' ' | b'\t') {
        i += 1;
    }
    i
}

/// Repair the two artifacts a span removal can leave at its seam, touching
/// nothing outside the seam's own line: a line left holding only whitespace
/// is deleted outright, and spaces left dangling before a newline (or end of
/// text) are trimmed.
fn clean_seam(output: &mut String, seam: usize) {
    let line_start = output[..seam].rfind('\n').map_or(0, |i| i + 1);
    let line_end = output[seam..].find('\n').map_or(output.len(), |i| seam + i);
    if output[line_start..line_end]
        .chars()
        .all(|c| c == ' ' || c == '\t')
    {
        let delete_end = if line_end < output.len() {
            line_end + 1
        } else {
            line_end
        };
        output.replace_range(line_start..delete_end, "");
        return;
    }
    let bytes = output.as_bytes();
    let at_line_end = seam == output.len() || bytes[seam] == b'\n';
    if at_line_end {
        let mut ws_start = seam;
        while ws_start > line_start && matches!(bytes[ws_start - 1], b' ' | b'\t') {
            ws_start -= 1;
        }
        if ws_start < seam {
            output.replace_range(ws_start..seam, "");
        }
    }
}

/// ASCII-case-insensitive phrase scan with word-boundary checks on both ends,
/// so "great question" never fires inside "questionnaire".
fn collect_phrase_matches(text: &str, pattern: &Pattern, out: &mut Vec<Finding>) {
    let haystack = text.as_bytes();
    let needle = pattern.phrase.as_bytes();
    if needle.is_empty() || haystack.len() < needle.len() {
        return;
    }
    let mut start = 0usize;
    while start + needle.len() <= haystack.len() {
        // Offsets stay on char boundaries: needles are pure ASCII, and a
        // multibyte UTF-8 sequence can never ASCII-case-match an ASCII byte.
        let window = &haystack[start..start + needle.len()];
        if window.eq_ignore_ascii_case(needle)
            && boundary_before(haystack, start)
            && boundary_after(haystack, start + needle.len())
        {
            let end = start + needle.len();
            out.push(Finding {
                class: pattern.class,
                excerpt: text[start..end].to_string(),
                start,
                end,
                strippable: pattern.strippable,
            });
            start = end;
        } else {
            start += 1;
        }
    }
}

fn boundary_before(bytes: &[u8], start: usize) -> bool {
    start == 0 || !bytes[start - 1].is_ascii_alphanumeric()
}

fn boundary_after(bytes: &[u8], end: usize) -> bool {
    end == bytes.len() || !bytes[end].is_ascii_alphanumeric()
}

/// Flag the second and later occurrences of a normalized sentence (>= 3
/// words) as `Repetition`. Detect-only: naive sentence segmentation makes
/// destructive removal unsafe.
fn collect_repetitions(text: &str, out: &mut Vec<Finding>) {
    let mut seen: Vec<String> = Vec::new();
    for (start, end) in sentence_spans(text) {
        let sentence = &text[start..end];
        let normalized = sentence
            .split_whitespace()
            .map(|w| w.to_ascii_lowercase())
            .collect::<Vec<_>>()
            .join(" ");
        if normalized.split(' ').count() < 3 {
            continue;
        }
        if seen.contains(&normalized) {
            out.push(Finding {
                class: PathologyClass::Repetition,
                excerpt: sentence.trim().to_string(),
                start,
                end,
                strippable: false,
            });
        } else {
            seen.push(normalized);
        }
    }
}

/// Byte spans of sentence-ish segments: split after `.`, `!`, `?`, or a
/// newline. Good enough for duplicate detection; not a real segmenter.
fn sentence_spans(text: &str) -> Vec<(usize, usize)> {
    let mut spans = Vec::new();
    let mut start = 0usize;
    for (i, ch) in text.char_indices() {
        if matches!(ch, '.' | '!' | '?' | '\n') {
            let end = i + ch.len_utf8();
            if text[start..end].trim().is_empty() {
                start = end;
            } else {
                spans.push((start, end));
                start = end;
            }
        }
    }
    if !text[start..].trim().is_empty() {
        spans.push((start, text.len()));
    }
    spans
}

/// Flag each run of consecutive emoji/decoration codepoints (spaces between
/// them included) as one `EmojiDecoration` finding. Detect-only.
fn collect_emoji_runs(text: &str, out: &mut Vec<Finding>) {
    let mut run_start: Option<usize> = None;
    let mut run_end = 0usize;
    for (i, ch) in text.char_indices() {
        if is_decoration(ch) {
            if run_start.is_none() {
                run_start = Some(i);
            }
            run_end = i + ch.len_utf8();
        } else if !(ch == ' ' && run_start.is_some()) {
            if let Some(s) = run_start.take() {
                push_emoji_finding(text, s, run_end, out);
            }
        }
    }
    if let Some(s) = run_start {
        push_emoji_finding(text, s, run_end, out);
    }
}

fn push_emoji_finding(text: &str, start: usize, end: usize, out: &mut Vec<Finding>) {
    out.push(Finding {
        class: PathologyClass::EmojiDecoration,
        excerpt: text[start..end].to_string(),
        start,
        end,
        strippable: false,
    });
}

fn is_decoration(ch: char) -> bool {
    matches!(u32::from(ch),
        0x1F300..=0x1FAFF   // pictographs, emoticons, symbols
        | 0x2600..=0x27BF   // misc symbols, dingbats
        | 0x2190..=0x21FF   // arrows used as decoration
        | 0x2B00..=0x2BFF   // stars, more arrows
        | 0xFE0F            // variation selector-16
        | 0x200D            // zero-width joiner
    )
}
