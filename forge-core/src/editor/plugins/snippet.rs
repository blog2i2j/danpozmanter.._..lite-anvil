// LSP snippet parser and expander.
//
// Parses the LSP snippet syntax into plain text plus tabstop metadata.
// Supports $0, $1..$N, ${1:default}, ${1|a,b,c|}, and escape sequences.

/// A resolved tabstop with its byte offset range in the expanded plain text.
#[derive(Debug, Clone)]
pub struct Tabstop {
    pub index: u32,
    /// Byte offset of the tabstop start in the expanded text.
    pub start: usize,
    /// Byte offset of the tabstop end in the expanded text.
    pub end: usize,
}

/// Result of expanding a snippet body.
#[derive(Debug)]
pub struct ExpandedSnippet {
    /// Plain text to insert (all snippet syntax removed).
    pub text: String,
    /// Tabstops sorted by index then by position.
    pub tabstops: Vec<Tabstop>,
}

/// Expands an LSP snippet body into plain text and tabstop positions.
pub fn expand(snippet: &str) -> ExpandedSnippet {
    let mut text = String::with_capacity(snippet.len());
    let mut tabstops = Vec::new();
    let bytes = snippet.as_bytes();
    let len = bytes.len();
    let mut i = 0;

    while i < len {
        if bytes[i] == b'\\' && i + 1 < len {
            let next = bytes[i + 1];
            if next == b'$' || next == b'\\' || next == b'}' || next == b'{' {
                text.push(next as char);
                i += 2;
                continue;
            }
        }

        if bytes[i] == b'$' {
            i += 1;
            if i >= len {
                text.push('$');
                break;
            }

            if bytes[i] == b'{' {
                // ${...} form
                i += 1;
                let (index, default_text, consumed) = parse_braced(&bytes[i..]);
                let start = text.len();
                text.push_str(&default_text);
                tabstops.push(Tabstop {
                    index,
                    start,
                    end: text.len(),
                });
                i += consumed;
            } else if bytes[i].is_ascii_digit() {
                // $N form
                let start_idx = i;
                while i < len && bytes[i].is_ascii_digit() {
                    i += 1;
                }
                let index: u32 = std::str::from_utf8(&bytes[start_idx..i])
                    .unwrap_or("0")
                    .parse()
                    .unwrap_or(0);
                let pos = text.len();
                tabstops.push(Tabstop {
                    index,
                    start: pos,
                    end: pos,
                });
            } else {
                text.push('$');
            }
        } else {
            text.push(bytes[i] as char);
            i += 1;
        }
    }

    // Sort: $1, $2, ... $N first, then $0 last.
    tabstops.sort_by_key(|t| if t.index == 0 { u32::MAX } else { t.index });

    ExpandedSnippet { text, tabstops }
}

/// Parses the interior of `${...}` starting after the `{`.
/// Returns `(index, default_text, bytes_consumed_including_closing_brace)`.
fn parse_braced(bytes: &[u8]) -> (u32, String, usize) {
    let len = bytes.len();
    let mut i = 0;

    // Parse the tabstop index.
    let idx_start = i;
    while i < len && bytes[i].is_ascii_digit() {
        i += 1;
    }
    let index: u32 = if i > idx_start {
        std::str::from_utf8(&bytes[idx_start..i])
            .unwrap_or("0")
            .parse()
            .unwrap_or(0)
    } else {
        0
    };

    if i >= len || bytes[i] == b'}' {
        // ${N} with no default
        return (index, String::new(), if i < len { i + 1 } else { i });
    }

    if bytes[i] == b':' {
        // ${N:default}
        i += 1;
        let mut default = String::new();
        let mut depth = 1u32;
        while i < len && depth > 0 {
            if bytes[i] == b'\\' && i + 1 < len {
                let next = bytes[i + 1];
                if next == b'$' || next == b'\\' || next == b'}' || next == b'{' {
                    default.push(next as char);
                    i += 2;
                    continue;
                }
            }
            if bytes[i] == b'{' {
                depth += 1;
            } else if bytes[i] == b'}' {
                depth -= 1;
                if depth == 0 {
                    i += 1;
                    break;
                }
            }
            // Nested $N or ${N:...} inside defaults: expand recursively.
            if bytes[i] == b'$' && i + 1 < len {
                i += 1;
                if i < len && bytes[i] == b'{' {
                    i += 1;
                    let (_, nested_default, consumed) = parse_braced(&bytes[i..]);
                    default.push_str(&nested_default);
                    i += consumed;
                    continue;
                } else if i < len && bytes[i].is_ascii_digit() {
                    // $N inside default — skip the number, emit nothing
                    while i < len && bytes[i].is_ascii_digit() {
                        i += 1;
                    }
                    continue;
                } else {
                    default.push('$');
                }
                continue;
            }
            if depth > 0 {
                default.push(bytes[i] as char);
                i += 1;
            }
        }
        return (index, default, i);
    }

    if bytes[i] == b'|' {
        // ${N|choice1,choice2,...|} — use first choice as default
        i += 1;
        let mut first_choice = String::new();
        while i < len && bytes[i] != b',' && bytes[i] != b'|' {
            if bytes[i] == b'\\' && i + 1 < len {
                first_choice.push(bytes[i + 1] as char);
                i += 2;
            } else {
                first_choice.push(bytes[i] as char);
                i += 1;
            }
        }
        // Skip to closing |}
        while i < len {
            if bytes[i] == b'|' && i + 1 < len && bytes[i + 1] == b'}' {
                i += 2;
                break;
            }
            i += 1;
        }
        return (index, first_choice, i);
    }

    // Unknown syntax — skip to closing brace.
    while i < len && bytes[i] != b'}' {
        i += 1;
    }
    if i < len {
        i += 1;
    }
    (index, String::new(), i)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn plain_text_unchanged() {
        let s = expand("hello world");
        assert_eq!(s.text, "hello world");
        assert!(s.tabstops.is_empty());
    }

    #[test]
    fn simple_tabstops() {
        let s = expand("fn ${1:name}($2) {\n    $0\n}");
        assert_eq!(s.text, "fn name() {\n    \n}");
        assert_eq!(s.tabstops.len(), 3);
        assert_eq!(s.tabstops[0].index, 1);
        assert_eq!(&s.text[s.tabstops[0].start..s.tabstops[0].end], "name");
        assert_eq!(s.tabstops[1].index, 2);
        assert_eq!(s.tabstops[2].index, 0); // $0 sorted last
    }

    #[test]
    fn dollar_number() {
        let s = expand("$1 then $2");
        assert_eq!(s.text, " then ");
        assert_eq!(s.tabstops.len(), 2);
    }

    #[test]
    fn escaped_dollar() {
        let s = expand("cost: \\$100");
        assert_eq!(s.text, "cost: $100");
        assert!(s.tabstops.is_empty());
    }

    #[test]
    fn choice_uses_first() {
        let s = expand("${1|pub,pub(crate),fn|}");
        assert_eq!(s.text, "pub");
        assert_eq!(s.tabstops[0].index, 1);
    }

    #[test]
    fn nested_placeholder() {
        let s = expand("${1:Vec<${2:T}>}");
        assert_eq!(s.text, "Vec<T>");
    }
}
