//// Builders for rendering back to djot.

import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import jot
import midas/continuation.{type Continuation as K}

pub type Renderer(t) {
  Renderer(resolve_url: fn(String) -> K(t, String))
}

pub fn default() -> Renderer(t) {
  Renderer(resolve_url: continuation.return)
}

/// Render a document to djot flavoured markup.
/// Special forms are resolved through the given renderer.
pub fn to_markup(
  document: jot.Document,
  renderer: Renderer(t),
) -> K(t, String) {
  containers_to_markup(document.content, renderer)
}

fn containers_to_markup(
  containers: List(jot.Container),
  renderer: Renderer(t),
) -> K(t, String) {
  use containers <- continuation.then(
    continuation.each(containers, container_to_markup(_, renderer)),
  )
  containers |> string.join("\n") |> continuation.return()
}

fn container_to_markup(
  container: jot.Container,
  renderer: Renderer(t),
) -> K(t, String) {
  case container {
    jot.ThematicBreak -> continuation.return(thematic_break())
    jot.Paragraph(attributes:, content:) -> {
      use inlines <- continuation.then(inlines_to_markup(content, renderer))
      continuation.return(paragraph(attributes, inlines))
    }
    jot.Heading(attributes:, level:, content:) -> {
      use inlines <- continuation.then(inlines_to_markup(content, renderer))
      continuation.return(heading(attributes, level, inlines))
    }
    jot.Codeblock(attributes:, language:, content:) ->
      continuation.return(codeblock(attributes, language, content))
    jot.RawBlock(content:) -> continuation.return(raw_block(content))
    jot.BulletList(layout:, style:, items:) -> {
      use items <- continuation.then(
        continuation.each(items, containers_to_markup(_, renderer)),
      )
      continuation.return(bullet_list(items, layout, style))
    }
    jot.OrderedList(layout:, punctuation:, ordinal:, start:, items:) -> {
      use items <- continuation.then(
        continuation.each(items, containers_to_markup(_, renderer)),
      )
      continuation.return(ordered_list(
        items,
        layout,
        punctuation,
        ordinal,
        start,
      ))
    }
    jot.BlockQuote(attributes:, items:) -> {
      use items <- continuation.then(containers_to_markup(items, renderer))
      continuation.return(block_quote(attributes, items))
    }
    jot.Div(class:, attributes:, items:) -> {
      use items <- continuation.then(containers_to_markup(items, renderer))
      continuation.return(div(class, attributes, items))
    }
  }
}

fn inlines_to_markup(
  inlines: List(jot.Inline),
  renderer: Renderer(t),
) -> K(t, String) {
  use inlines <- continuation.then(
    continuation.each(inlines, inline_to_markup(_, renderer)),
  )
  continuation.return(string.join(inlines, ""))
}

fn inline_to_markup(inline: jot.Inline, renderer: Renderer(t)) -> K(t, String) {
  let Renderer(resolve_url:) = renderer
  case inline {
    jot.Linebreak -> continuation.return(linebreak())
    jot.NonBreakingSpace -> continuation.return(non_breaking_space())
    jot.Text(text) -> continuation.return(text)
    jot.Link(attributes:, content:, destination:) -> {
      case destination {
        jot.Reference(reference) -> {
          use inlines <- continuation.then(inlines_to_markup(content, renderer))
          continuation.return(reference_link(attributes, inlines, reference))
        }
        jot.Url(url) -> {
          use url <- continuation.then(resolve_url(url))
          use inlines <- continuation.then(inlines_to_markup(content, renderer))
          continuation.return(link(attributes, inlines, url))
        }
      }
    }
    jot.Image(attributes:, content:, destination:) -> {
      case destination {
        jot.Reference(reference) -> {
          use inlines <- continuation.then(inlines_to_markup(content, renderer))
          continuation.return(reference_image(attributes, inlines, reference))
        }
        jot.Url(url) -> {
          use url <- continuation.then(resolve_url(url))
          use inlines <- continuation.then(inlines_to_markup(content, renderer))
          continuation.return(image(attributes, inlines, url))
        }
      }
    }
    jot.Span(attributes:, content:) -> {
      use inlines <- continuation.then(inlines_to_markup(content, renderer))
      continuation.return(span(attributes, inlines))
    }
    jot.Emphasis(content:) -> {
      use inlines <- continuation.then(inlines_to_markup(content, renderer))
      continuation.return(emphasis(inlines))
    }
    jot.Strong(content:) -> {
      use inlines <- continuation.then(inlines_to_markup(content, renderer))
      continuation.return(strong(inlines))
    }
    jot.Delete(content:) -> {
      use inlines <- continuation.then(inlines_to_markup(content, renderer))
      continuation.return(delete(inlines))
    }
    jot.Insert(content:) -> {
      use inlines <- continuation.then(inlines_to_markup(content, renderer))
      continuation.return(insert(inlines))
    }
    jot.Mark(content:) -> {
      use inlines <- continuation.then(inlines_to_markup(content, renderer))
      continuation.return(mark(inlines))
    }
    jot.Superscript(content:) -> {
      use inlines <- continuation.then(inlines_to_markup(content, renderer))
      continuation.return(superscript(inlines))
    }
    jot.Subscript(content:) -> {
      use inlines <- continuation.then(inlines_to_markup(content, renderer))
      continuation.return(subscript(inlines))
    }
    jot.Footnote(reference:) ->
      continuation.return(footnote_reference(reference))
    jot.Code(content:) -> continuation.return(verbatim(content))
    jot.MathInline(content:) -> continuation.return(math_inline(content))
    jot.MathDisplay(content:) -> continuation.return(math_display(content))
    jot.Symbol(content:) -> continuation.return(symbol(content))
  }
}

// -----------------------------------------------------------
// helpers

fn heading(
  attributes: Dict(String, String),
  level: Int,
  content: String,
) -> String {
  block_attributes(attributes)
  <> string.repeat("#", level)
  <> " "
  <> content
  <> "\n"
}

fn thematic_break() -> String {
  "---"
}

fn linebreak() -> String {
  "\\\n"
}

fn non_breaking_space() -> String {
  "\\ "
}

fn paragraph(attributes: Dict(String, String), content: String) -> String {
  block_attributes(attributes) <> content
}

fn link(
  attributes: Dict(String, String),
  content: String,
  url: String,
) -> String {
  "[" <> content <> "](" <> url <> ")" <> inline_attributes(attributes)
}

fn reference_link(
  attributes: Dict(String, String),
  content: String,
  reference: String,
) -> String {
  "[" <> content <> "][" <> reference <> "]" <> inline_attributes(attributes)
}

fn image(
  attributes: Dict(String, String),
  content: String,
  url: String,
) -> String {
  "![" <> content <> "](" <> url <> ")" <> inline_attributes(attributes)
}

fn reference_image(
  attributes: Dict(String, String),
  content: String,
  reference: String,
) -> String {
  "![" <> content <> "][" <> reference <> "]" <> inline_attributes(attributes)
}

fn span(attributes: Dict(String, String), content: String) -> String {
  "[" <> content <> "]" <> inline_attributes(attributes)
}

fn emphasis(content: String) -> String {
  "_" <> content <> "_"
}

fn strong(content: String) -> String {
  "*" <> content <> "*"
}

fn insert(content: String) -> String {
  "{+" <> content <> "+}"
}

fn delete(content: String) -> String {
  "{-" <> content <> "-}"
}

// called highlighted aswell
fn mark(content: String) -> String {
  "{=" <> content <> "=}"
}

// djot keeps the foot note reference ^
fn footnote_reference(content: String) -> String {
  "[" <> content <> "]"
}

fn superscript(content: String) -> String {
  "^" <> content <> "^"
}

fn subscript(content: String) -> String {
  "~" <> content <> "~"
}

fn symbol(content: String) -> String {
  ":" <> content <> ":"
}

fn verbatim(content: String) -> String {
  let count = max_ticks(<<content:utf8>>, None, 0)
  let wrap = string.repeat("`", count + 1)
  wrap <> content <> wrap
}

fn math_inline(content: String) -> String {
  "$" <> verbatim(content)
}

fn math_display(content: String) -> String {
  "$$" <> verbatim(content)
}

fn codeblock(
  attributes: Dict(String, String),
  language: Option(String),
  content: String,
) -> String {
  let fence = codeblock_fence(content)
  let language = case language {
    Some(language) -> language
    None -> ""
  }

  let content = case string.ends_with(content, "\n") {
    True -> content
    False -> content <> "\n"
  }

  block_attributes(attributes) <> fence <> language <> "\n" <> content <> fence
}

fn raw_block(content: String) -> String {
  let fence = codeblock_fence(content)
  let content = case string.ends_with(content, "\n") {
    True -> content
    False -> content <> "\n"
  }

  fence <> "=html\n" <> content <> fence
}

fn codeblock_fence(content: String) -> String {
  let ticks = int.max(3, max_ticks(<<content:utf8>>, None, 0) + 1)
  string.repeat("`", ticks)
}

fn block_quote(attributes: Dict(String, String), content: String) -> String {
  block_attributes(attributes)
  <> {
    content
    |> string.split("\n")
    |> list.map(fn(line) {
      case line {
        "" -> ">"
        line -> "> " <> line
      }
    })
    |> string.join("\n")
  }
}

fn div(
  class: Option(String),
  attributes: Dict(String, String),
  content: String,
) -> String {
  let attributes = case class {
    Some(class) -> remove_class(attributes, class)
    None -> attributes
  }

  let opening = case class {
    Some(class) -> "::: " <> class
    None -> ":::"
  }

  block_attributes(attributes) <> opening <> "\n" <> content <> "\n:::"
}

fn block_attributes(attributes: Dict(String, String)) -> String {
  case attributes_to_string(attributes) {
    "" -> ""
    attributes -> attributes <> "\n"
  }
}

fn inline_attributes(attributes: Dict(String, String)) -> String {
  attributes_to_string(attributes)
}

fn attributes_to_string(attributes: Dict(String, String)) -> String {
  let classes = case dict.get(attributes, "class") {
    Ok(classes) -> render_classes(classes)
    Error(_) -> []
  }

  let id = case dict.get(attributes, "id") {
    Ok(id) -> ["#" <> id]
    Error(_) -> []
  }

  let other_attributes =
    attributes
    |> dict.delete("class")
    |> dict.delete("id")
    |> dict.to_list
    |> list.map(fn(attribute) {
      case attribute {
        #(key, value) -> key <> "=\"" <> escape_attribute_value(value) <> "\""
      }
    })

  let rendered = list.flatten([classes, id, other_attributes])

  case rendered {
    [] -> ""
    _ -> "{" <> string.join(rendered, " ") <> "}"
  }
}

fn remove_class(
  attributes: Dict(String, String),
  class_to_remove: String,
) -> Dict(String, String) {
  case dict.get(attributes, "class") {
    Error(_) -> attributes
    Ok(classes) -> {
      let remaining =
        classes
        |> string.split(" ")
        |> list.filter(fn(class) { class != "" && class != class_to_remove })
        |> string.join(" ")

      case remaining {
        "" -> dict.delete(attributes, "class")
        _ -> dict.insert(attributes, "class", remaining)
      }
    }
  }
}

fn render_classes(value: String) -> List(String) {
  value
  |> string.split(" ")
  |> list.filter_map(fn(class) {
    case class {
      "" -> Error(Nil)
      class -> Ok("." <> class)
    }
  })
}

fn escape_attribute_value(value: String) -> String {
  value
  |> string.replace("\\", "\\\\")
  |> string.replace("\"", "\\\"")
}

fn ordered_list(
  items: List(String),
  layout: jot.ListLayout,
  punctuation: jot.OrdinalPunctuation,
  ordinal: jot.OrdinalStyle,
  start: Int,
) -> String {
  let separator = case layout {
    jot.Tight -> "\n"
    jot.Loose -> "\n\n"
  }

  render_ordered_list(items, punctuation, ordinal, start)
  |> string.join(separator)
}

fn bullet_list(
  items: List(String),
  layout: jot.ListLayout,
  style: jot.BulletStyle,
) -> String {
  let separator = case layout {
    jot.Tight -> "\n"
    jot.Loose -> "\n\n"
  }

  let marker = case style {
    jot.BulletDash -> "-"
    jot.BulletStar -> "*"
    jot.BulletPlus -> "+"
  }

  items
  |> list.map(fn(item) { marker <> " " <> item })
  |> string.join(separator)
}

fn render_ordered_list(
  items: List(String),
  punctuation: jot.OrdinalPunctuation,
  ordinal: jot.OrdinalStyle,
  start: Int,
) -> List(String) {
  case items {
    [] -> []
    [item, ..rest] -> {
      let line = ordinal_marker(start, punctuation, ordinal) <> " " <> item
      [line, ..render_ordered_list(rest, punctuation, ordinal, start + 1)]
    }
  }
}

fn ordinal_marker(
  number: Int,
  punctuation: jot.OrdinalPunctuation,
  ordinal: jot.OrdinalStyle,
) -> String {
  let value = case ordinal {
    jot.NumericOrdinal -> int.to_string(number)
    jot.LowerAlphaOrdinal -> alpha_ordinal(number)
    jot.UpperAlphaOrdinal -> alpha_ordinal(number) |> string.uppercase
  }

  case punctuation {
    jot.FullStop -> value <> "."
    jot.SingleParen -> value <> ")"
    jot.DoubleParen -> "(" <> value <> ")"
  }
}

fn alpha_ordinal(number: Int) -> String {
  case number <= 0 {
    True -> ""
    False -> {
      let adjusted = number - 1
      let prefix = alpha_ordinal(adjusted / 26)
      prefix <> alpha_digit(adjusted % 26)
    }
  }
}

fn alpha_digit(number: Int) -> String {
  case number {
    0 -> "a"
    1 -> "b"
    2 -> "c"
    3 -> "d"
    4 -> "e"
    5 -> "f"
    6 -> "g"
    7 -> "h"
    8 -> "i"
    9 -> "j"
    10 -> "k"
    11 -> "l"
    12 -> "m"
    13 -> "n"
    14 -> "o"
    15 -> "p"
    16 -> "q"
    17 -> "r"
    18 -> "s"
    19 -> "t"
    20 -> "u"
    21 -> "v"
    22 -> "w"
    23 -> "x"
    24 -> "y"
    _ -> "z"
  }
}

fn max_ticks(rest: BitArray, current: Option(Int), max: Int) -> Int {
  case rest, current {
    <<"`", rest:bits>>, None -> max_ticks(rest, Some(1), max)
    <<"`", rest:bits>>, Some(count) -> max_ticks(rest, Some(count + 1), max)
    <<_, rest:bits>>, None -> max_ticks(rest, None, max)
    <<_, rest:bits>>, Some(count) -> max_ticks(rest, None, int.max(count, max))
    _, None -> max
    _, Some(count) -> int.max(count, max)
  }
}
