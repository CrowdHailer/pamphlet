# Pamphlet


[![Package Version](https://img.shields.io/hexpm/v/pamphlet)](https://hex.pm/packages/pamphlet)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/pamphlet/)

Render djot documents with custom elements and url schemes.

Rendering often needs knowledge the document does not have: asset fingerprints, CDN hosts, syntax grammars, application components, or build-time reports.
Pamphlet exposes those decisions as [continuations](https://crowdhailer.me/2026-07-15/abstracting-effects-with-continuations/).

## Targets

Pamphlet supports rendering back to djot/markdown, useful for `llm.txt` and `.md` pages and lustre for web pages and web apps.

## Front matter

Defines pages with frontmatter deliminated by `---`.
Currently parses frontmatter to string key and value list.

## Rendering

All these examples use symbol but the renderer also provides hooks for urls and raw blocks.
Building on continuations we can make custom renderers with their own control logic.

The **Lustre renderer** exposes `render_*` callbacks for every document node,
including list items and generated footnotes. `resolve_url` and
`resolve_symbol` perform lookups; rendering callbacks construct elements from
resolved values and already-rendered children. Pamphlet owns traversal and
footnote bookkeeping. Start from `lustre.default()` and override the fields you
need.

### Pure renderer

This renderer always succeeds and transforms thumbs down to thumbs up.

```gleam
import pamphlet
import pamphlet/djot

pub fn cheerful_symbol_render(text: String) -> String {
  let renderer =
    djot.Renderer(..djot.default(), resolve_symbol: fn(name) {
      fn(callback) {
        case name {
          "-1" -> ":+1:"
          name -> ":" <> name <> ":"
        }
        |> callback
      }
    })

  let #(_frontmatter, doc) = pamphlet.parse(text)
  djot.to_markup(doc, renderer)(fn(x) { x })
}

pub fn cheerful_render_test() {
  let out =
    ":-1: and :+1:"
    |> cheerful_symbol_render()
  assert ":+1: and :+1:" == out
}
```

### Aborting renderer

This renderer will halt if anyone uses the turd symbol.

```gleam
import pamphlet
import pamphlet/djot

pub fn check_turd_symbol_render(text: String) -> Result(String, Nil) {
  let renderer =
    djot.Renderer(..djot.default(), resolve_symbol: fn(name) {
      fn(callback) {
        case name {
          "turd" -> Error(Nil)
          name -> callback(":" <> name <> ":")
        }
      }
    })

  let #(_frontmatter, doc) = pamphlet.parse(text)
  djot.to_markup(doc, renderer)(Ok)
}

pub fn check_render_test() {
  let out =
    ":-1: and :+1:"
    |> check_turd_symbol_render()
  assert Ok(":-1: and :+1:") == out

  let out =
    ":turd: and :+1:"
    |> check_turd_symbol_render()
  assert Error(Nil) == out
}
```

### Stateful renderer

This renderer collects the set of all symbols used.

```gleam
import gleam/set
import pamphlet
import pamphlet/djot

pub fn list_symbols_render(text) {
  let renderer =
    djot.Renderer(..djot.default(), resolve_symbol: fn(name) {
      fn(callback) {
        let #(page, acc) = callback(":" <> name <> ":")
        #(page, set.insert(acc, name))
      }
    })

  let #(_frontmatter, doc) = pamphlet.parse(text)
  djot.to_markup(doc, renderer)(fn(page) { #(page, set.new()) })
}

pub fn list_symbols_render_test() {
  let #(page, symbols) =
    ":-1: and :+1:"
    |> list_symbols_render()
  assert ":-1: and :+1:" == page
  assert set.from_list(["-1", "+1"]) == symbols
}
```

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```
