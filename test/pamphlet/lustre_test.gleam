import birdie
import jot
import lustre/element
import lustre/element/html
import midas/continuation
import pamphlet/lustre

fn snap(source: String, title: String) {
  source
  |> jot.parse()
  |> lustre.to_lustre(lustre.default())
  |> fn(m) { m(fn(x) { x }) }
  |> element.to_readable_string()
  |> birdie.snap(title)
}

fn snap_with(
  source: String,
  renderer: lustre.Renderer(msg, element.Element(msg)),
  title: String,
) {
  source
  |> jot.parse()
  |> lustre.to_lustre(renderer)
  |> fn(m) { m(fn(x) { x }) }
  |> element.to_readable_string()
  |> birdie.snap(title)
}

// block tests

pub fn lustre_thematic_break_test() {
  "---"
  |> snap("lustre_thematic_break")
}

pub fn lustre_paragraph_test() {
  "Wash first"
  |> snap("lustre_paragraph")
}

pub fn lustre_paragraph_attributes_test() {
  "{.wide}
Wash first"
  |> snap("lustre_paragraph_attributes")
}

pub fn lustre_heading_test() {
  "## Laundry"
  |> snap("lustre_heading")
}

pub fn lustre_heading_levels_test() {
  "# One

### Three

###### Six"
  |> snap("lustre_heading_levels")
}

pub fn lustre_codeblock_test() {
  "```
wash()
```"
  |> snap("lustre_codeblock")
}

pub fn lustre_codeblock_language_test() {
  "```gleam
pub fn wash() { Nil }
```"
  |> snap("lustre_codeblock_language")
}

pub fn lustre_raw_block_test() {
  "```=html
<marquee>Spotless</marquee>
```"
  |> snap("lustre_raw_block")
}

pub fn lustre_table_rows_test() {
  "| a | *b* |
| | c |"
  |> snap("lustre_table_rows")
}

pub fn lustre_table_caption_and_attributes_test() {
  "{#inventory .striped}
| a | b |

^ With a _caption_
  and another line."
  |> snap("lustre_table_caption_and_attributes")
}

pub fn lustre_table_headers_and_alignments_test() {
  "| none | left | center | right |
|---|:---|:---:|---:|
| a | b | c | d |
| second | header | row | here |
|:---|---:|:---|:---:|
| e | f | g | h |"
  |> snap("lustre_table_headers_and_alignments")
}

pub fn lustre_empty_table_test() {
  "|--|"
  |> snap("lustre_empty_table")
}

pub fn lustre_table_pipes_and_code_test() {
  "| just two \\| `|` | cells in this table |"
  |> snap("lustre_table_pipes_and_code")
}

pub fn lustre_table_continuations_and_footnotes_test() {
  let renderer =
    lustre.Renderer(..lustre.default(), resolve_url: fn(url) {
      continuation.return("/resolved" <> url)
    })

  "| [guide](/guide) | :warning: [^details] |

^ [caption](/caption)

[^details]: More detail."
  |> snap_with(renderer, "lustre_table_continuations_and_footnotes")
}

pub fn lustre_bullet_list_test() {
  "- Wash
- Dry"
  |> snap("lustre_bullet_list")
}

pub fn lustre_bullet_list_loose_test() {
  "- Loose

- List"
  |> snap("lustre_bullet_list_loose")
}

pub fn lustre_bullet_list_nested_test() {
  "- Wash

  - Soak
  - Scrub

- Dry"
  |> snap("lustre_bullet_list_nested")
}

pub fn lustre_ordered_list_test() {
  "1. Wash
2. Dry"
  |> snap("lustre_ordered_list")
}

pub fn lustre_ordered_list_start_test() {
  "3. Wash
4. Dry"
  |> snap("lustre_ordered_list_start")
}

pub fn lustre_ordered_list_ordinals_test() {
  "a. Wash
b. Dry

A. Fold
B. Put away"
  |> snap("lustre_ordered_list_ordinals")
}

pub fn lustre_block_quote_test() {
  "> # Laundry
>
> Wash first"
  |> snap("lustre_block_quote")
}

pub fn lustre_div_test() {
  ":::
Wash first
:::"
  |> snap("lustre_div")
}

pub fn lustre_div_class_test() {
  "::: laundry
Wash first
:::"
  |> snap("lustre_div_class")
}

// inline tests

pub fn lustre_linebreak_test() {
  "one\\
two"
  |> snap("lustre_linebreak")
}

pub fn lustre_non_breaking_space_test() {
  "one\\ two"
  |> snap("lustre_non_breaking_space")
}

pub fn lustre_url_link_test() {
  "[Spotless](https://spotless.run)"
  |> snap("lustre_url_link")
}

pub fn lustre_reference_link_test() {
  "[Spotless][site]

[site]: https://spotless.run"
  |> snap("lustre_reference_link")
}

pub fn lustre_reference_link_attributes_test() {
  "[Spotless][site]

{title=\"The Spotless site\"}
[site]: https://spotless.run"
  |> snap("lustre_reference_link_attributes")
}

pub fn lustre_reference_link_missing_test() {
  "[Spotless][site]"
  |> snap("lustre_reference_link_missing")
}

pub fn lustre_image_test() {
  "![Spotless](https://spotless.run/logo.png)"
  |> snap("lustre_image")
}

pub fn lustre_image_alt_text_test() {
  "![The *Spotless* logo](https://spotless.run/logo.png)"
  |> snap("lustre_image_alt_text")
}

pub fn lustre_reference_image_test() {
  "![Spotless][logo]

[logo]: https://spotless.run/logo.png"
  |> snap("lustre_reference_image")
}

pub fn lustre_span_test() {
  "[fancy]{.fancy}"
  |> snap("lustre_span")
}

pub fn lustre_emphasis_test() {
  "_one_"
  |> snap("lustre_emphasis")
}

pub fn lustre_strong_test() {
  "*one*"
  |> snap("lustre_strong")
}

pub fn lustre_delete_test() {
  "{-old-}"
  |> snap("lustre_delete")
}

pub fn lustre_insert_test() {
  "{+new+}"
  |> snap("lustre_insert")
}

pub fn lustre_mark_test() {
  "stains are {=marked=} for treatment"
  |> snap("lustre_mark")
}

pub fn lustre_superscript_test() {
  "^tm^"
  |> snap("lustre_superscript")
}

pub fn lustre_subscript_test() {
  "~one~"
  |> snap("lustre_subscript")
}

pub fn lustre_code_test() {
  "`wash()`"
  |> snap("lustre_code")
}

pub fn lustre_math_inline_test() {
  "$`e=mc^2`"
  |> snap("lustre_math_inline")
}

pub fn lustre_math_display_test() {
  "$$`e=mc^2`"
  |> snap("lustre_math_display")
}

pub fn lustre_symbol_test() {
  "My reaction is :+1:."
  |> snap("lustre_symbol")
}

pub fn lustre_raw_inline_test() {
  "before `<b>bold</b>`{=html} after"
  |> snap("lustre_raw_inline")
}

pub fn lustre_raw_inline_at_end_test() {
  "before `<hr>`{=html}"
  |> snap("lustre_raw_inline_at_end")
}

// footnote tests

pub fn lustre_footnote_test() {
  "Wash first.[^why]

[^why]: Because stains set."
  |> snap("lustre_footnote")
}

pub fn lustre_footnote_repeated_test() {
  "Wash first.[^why] Dry second.[^why]

[^why]: Because stains set."
  |> snap("lustre_footnote_repeated")
}

pub fn lustre_footnote_missing_definition_test() {
  "Wash first.[^ghost]"
  |> snap("lustre_footnote_missing_definition")
}

pub fn lustre_footnote_multiple_test() {
  "Wash first.[^wash] Dry second.[^dry]

[^wash]: Because stains set.

[^dry]: Because mildew."
  |> snap("lustre_footnote_multiple")
}

// renderer configuration tests

pub fn lustre_rewrite_urls_test() {
  let renderer =
    lustre.Renderer(..lustre.default(), resolve_url: fn(url) {
      case url {
        "guide://" <> slug -> continuation.return("/guides/" <> slug <> ".md")
        _ -> continuation.return(url)
      }
    })

  "[the guide](guide://device-login)"
  |> snap_with(renderer, "lustre_rewrite_urls")
}

pub fn lustre_rewrite_urls_applies_to_references_test() {
  // unlike markup output, references resolve to their URL here, so the
  // in-source URL of the definition goes through the resolver
  let renderer =
    lustre.Renderer(..lustre.default(), resolve_url: fn(url) {
      case url {
        "guide://" <> slug -> continuation.return("/guides/" <> slug <> ".md")
        _ -> continuation.return(url)
      }
    })

  "[the guide][guide]

[guide]: guide://device-login"
  |> snap_with(renderer, "lustre_rewrite_urls_applies_to_references")
}

pub fn lustre_rewrite_raw_blocks_test() {
  // render raw html as visible source instead of injecting it
  let renderer =
    lustre.Renderer(..lustre.default(), resolve_raw_block: fn(content) {
      continuation.return(html.pre([], [element.text(content)]))
    })

  "```=html
<marquee>Spotless</marquee>
```"
  |> snap_with(renderer, "lustre_rewrite_raw_blocks")
}

pub fn lustre_rewrite_raw_blocks_drop_test() {
  let renderer =
    lustre.Renderer(..lustre.default(), resolve_raw_block: fn(_content) {
      continuation.return(element.none())
    })

  "before

```=html
<script>alert(1)</script>
```

after"
  |> snap_with(renderer, "lustre_rewrite_raw_blocks_drop")
}

pub fn lustre_rewrite_raw_inlines_test() {
  // escape raw inline html instead of injecting it
  let renderer =
    lustre.Renderer(..lustre.default(), resolve_raw_inline: fn(content) {
      continuation.return(element.text(content))
    })

  "before `<b>bold</b>`{=html} after"
  |> snap_with(renderer, "lustre_rewrite_raw_inlines")
}

pub fn lustre_rewrite_symbols_test() {
  let renderer =
    lustre.Renderer(..lustre.default(), resolve_symbol: fn(name) {
      case name {
        "warning" -> continuation.return("⚠️")
        name -> continuation.return(":" <> name <> ":")
      }
    })

  ":warning: Mind the :gap:"
  |> snap_with(renderer, "lustre_rewrite_symbols")
}

// choosing the answer type: effects and halting

pub fn lustre_pure_renderer_runs_at_any_answer_type_test() {
  // the same Cont value runs with any final continuation
  let document = jot.parse("# Device login")

  assert lustre.to_lustre(document, lustre.default())(Ok)
    == Ok(lustre.to_lustre(document, lustre.default())(fn(x) { x }))
}

pub fn lustre_resolve_urls_can_halt_test() {
  // a resolver that returns without calling the continuation stops the
  // whole render
  let renderer =
    lustre.Renderer(..lustre.default(), resolve_url: fn(url) {
      fn(k) {
        case url {
          "https://" <> _ -> k(url)
          _ -> Error("unexpected internal link: " <> url)
        }
      }
    })

  assert "[app](/app) then [spec](https://oauth.net/2.1/)"
    |> jot.parse()
    |> lustre.to_lustre(renderer)
    |> fn(m) { m(Ok) }
    == Error("unexpected internal link: /app")
}

pub fn lustre_resolve_urls_applies_to_references_test() {
  let renderer =
    lustre.Renderer(..lustre.default(), resolve_url: fn(url) {
      fn(_k) { Error(url) }
    })

  assert "[the guide][guide]

[guide]: guide://device-login"
    |> jot.parse()
    |> lustre.to_lustre(renderer)
    |> fn(m) { m(Ok) }
    == Error("guide://device-login")
}

pub fn lustre_resolve_raw_blocks_can_halt_test() {
  let renderer =
    lustre.Renderer(..lustre.default(), resolve_raw_block: fn(_content) {
      fn(_k) { Error("raw HTML is not allowed here") }
    })

  assert "```=html
<script>alert(1)</script>
```"
    |> jot.parse()
    |> lustre.to_lustre(renderer)
    |> fn(m) { m(Ok) }
    == Error("raw HTML is not allowed here")
}

pub fn lustre_resolve_raw_inlines_can_halt_test() {
  let renderer =
    lustre.Renderer(..lustre.default(), resolve_raw_inline: fn(_content) {
      fn(_k) { Error("raw HTML is not allowed here") }
    })

  assert "before `<b>bold</b>`{=html} after"
    |> jot.parse()
    |> lustre.to_lustre(renderer)
    |> fn(m) { m(Ok) }
    == Error("raw HTML is not allowed here")
}

pub fn lustre_resolve_symbols_can_halt_test() {
  let renderer =
    lustre.Renderer(..lustre.default(), resolve_symbol: fn(name) {
      fn(k) {
        case name {
          "warning" -> k("⚠️")
          name -> Error("unknown symbol: " <> name)
        }
      }
    })

  assert ":warning: mind the :gap:"
    |> jot.parse()
    |> lustre.to_lustre(renderer)
    |> fn(m) { m(Ok) }
    == Error("unknown symbol: gap")
}

pub fn lustre_halting_stops_at_the_first_failure_test() {
  let renderer =
    lustre.Renderer(..lustre.default(), resolve_url: fn(url) {
      fn(_k) { Error(url) }
    })

  assert "[one](/one) [two](/two)"
    |> jot.parse()
    |> lustre.to_lustre(renderer)
    |> fn(m) { m(Ok) }
    == Error("/one")
}
