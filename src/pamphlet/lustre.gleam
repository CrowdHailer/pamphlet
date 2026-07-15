//// Render djot documents to lustre elements.
////
//// The rendering follows `jot.document_to_html` as closely as possible —
//// the same function names, the same case order, the same footnote
//// bookkeeping — so the two targets stay easy to compare. Where jot appends
//// to an HTML string, this module appends `Element`s to a tree.
////
//// Like the markup renderer in `pamphlet/djot`, the special forms are
//// resolved in the continuation monad: each resolver takes what was written
//// in the source and returns a `Cont(t, a)`. A pure lookup is `continuation.return`;
//// an effectful one can do whatever the answer type `t` allows before
//// calling the continuation — or never call it at all. Raw blocks and raw
//// inlines produce lustre elements directly, so the `Renderer(msg, t)` is
//// also polymorphic in the host application's message type.

import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import jot.{
  type Container, type Destination, type Document, type Inline, type ListLayout,
  BlockQuote, BulletList, Code, Codeblock, Delete, Div, Emphasis, Footnote,
  Heading, Image, Insert, Linebreak, Link, LowerAlphaOrdinal, Mark, MathDisplay,
  MathInline, NonBreakingSpace, NumericOrdinal, OrderedList, Paragraph, RawBlock,
  Reference, Span, Strong, Subscript, Superscript, Symbol, Text, ThematicBreak,
  Tight, UpperAlphaOrdinal, Url,
}
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html
import midas/continuation.{type Continuation as K}

/// How the special forms of a document are rendered to lustre elements.
///
/// `resolve_url` and `resolve_symbol` are lookups from what was written in
/// the source to what should appear in the output, as in the markup
/// renderer. Raw blocks (```` ```=html ````) and raw inlines
/// (`` `…`{=html} ``) are payloads addressed directly to the output, so
/// their resolvers continue with `Element`s; `msg` is the message type of
/// those elements, and of everything the render produces.
///
/// Each resolver returns a `Cont(t, a)`: a function that receives the rest
/// of the render as a continuation. `t` is the answer type of the whole
/// render — a resolver may perform effects before continuing, or finish the
/// render itself by returning a `t` without calling the continuation.
///
/// Start from `default()` and override individual forms with a record
/// update.
pub type Renderer(msg, t) {
  Renderer(
    resolve_url: fn(String) -> K(t, String),
    resolve_raw_block: fn(String) -> K(t, Element(msg)),
    resolve_raw_inline: fn(String) -> K(t, Element(msg)),
    resolve_symbol: fn(String) -> K(t, String),
  )
}

/// A renderer that matches `jot.document_to_html` as closely as lustre
/// allows.
///
/// URLs pass through untouched and symbols render as written inside jot's
/// `<span class="symbol">`. Raw content cannot be spliced into a lustre
/// tree without a wrapper element, so raw blocks render inside a `<div>`
/// and raw inlines inside a `<span>`, both via
/// `element.unsafe_raw_html` — as with `jot.document_to_html`, the content
/// is not escaped, so override these for untrusted documents.
pub fn default() -> Renderer(msg, t) {
  Renderer(
    resolve_url: continuation.return,
    resolve_raw_block: fn(content) {
      continuation.return(element.unsafe_raw_html("", "div", [], content))
    },
    resolve_raw_inline: fn(content) {
      continuation.return(element.unsafe_raw_html("", "span", [], content))
    },
    resolve_symbol: continuation.return,
  )
}

/// Render a document to a lustre element.
/// Special forms are resolved through the given renderer.
///
/// The document's containers (and the footnote section, when the document
/// uses footnotes) are returned as an `element.fragment`.
///
/// The result is a `Cont(t, Element(msg))`: apply it to a final
/// continuation to run the render. A pure renderer runs at any answer
/// type — `to_lustre(document, default())(fn(element) { element })` — while
/// with `t = Result(Element(msg), e)` a resolver can halt the render by
/// returning an `Error` instead of continuing, and the final continuation
/// is `Ok`.
pub fn to_lustre(
  document: Document,
  renderer: Renderer(msg, t),
) -> K(t, Element(msg)) {
  let refs =
    RenderRefs(
      renderer: renderer,
      urls: document.references,
      reference_attributes: document.reference_attributes,
      footnotes: document.footnotes,
    )
  use generated_lustre <- continuation.then(containers_to_lustre(
    document.content,
    refs,
    GeneratedLustre([], []),
  ))

  // only create the footnotes section if it is needed
  case generated_lustre.used_footnotes {
    [] ->
      continuation.return(
        element.fragment(list.reverse(generated_lustre.elements)),
      )
    used_footnotes -> {
      use lustre_with_footnotes <- continuation.then(create_footnotes(
        refs,
        list.reverse(used_footnotes),
        GeneratedLustre([], used_footnotes),
      ))

      let footnotes_section =
        html.section([attribute.role("doc-endnotes")], [
          html.hr([]),
          html.ol([], list.reverse(lustre_with_footnotes.elements)),
        ])

      continuation.return(
        element.fragment(
          list.reverse([footnotes_section, ..generated_lustre.elements]),
        ),
      )
    }
  }
}

type Footnotes =
  List(#(Int, String))

type GeneratedLustre(msg) {
  GeneratedLustre(elements: List(Element(msg)), used_footnotes: Footnotes)
}

type RenderRefs(msg, t) {
  RenderRefs(
    renderer: Renderer(msg, t),
    urls: Dict(String, String),
    reference_attributes: Dict(String, Dict(String, String)),
    footnotes: Dict(String, List(Container)),
  )
}

fn containers_to_lustre_with_last_paragraph(
  containers: List(Container),
  refs: RenderRefs(msg, t),
  lustre: GeneratedLustre(msg),
  apply: fn(GeneratedLustre(msg)) -> GeneratedLustre(msg),
) -> K(t, GeneratedLustre(msg)) {
  case containers {
    [] -> continuation.return(lustre)
    [container] -> {
      case container {
        Paragraph(attrs, inlines) -> {
          use inner <- continuation.then(inlines_to_lustre(
            GeneratedLustre([], lustre.used_footnotes),
            inlines,
            refs,
            TrimLast,
          ))
          let inner = apply(inner)
          continuation.return(
            wrap_elements(lustre, inner, html.p(attributes_to_lustre(attrs), _)),
          )
        }
        _ -> {
          use lustre <- continuation.then(container_to_lustre(
            lustre,
            container,
            refs,
          ))
          let inner = apply(GeneratedLustre([], lustre.used_footnotes))
          continuation.return(wrap_elements(lustre, inner, html.p([], _)))
        }
      }
    }
    [container, ..rest] -> {
      use lustre <- continuation.then(container_to_lustre(
        lustre,
        container,
        refs,
      ))
      containers_to_lustre_with_last_paragraph(rest, refs, lustre, apply)
    }
  }
}

fn containers_to_lustre(
  containers: List(Container),
  refs: RenderRefs(msg, t),
  lustre: GeneratedLustre(msg),
) -> K(t, GeneratedLustre(msg)) {
  case containers {
    [] -> continuation.return(lustre)
    [container, ..rest] -> {
      use lustre <- continuation.then(container_to_lustre(
        lustre,
        container,
        refs,
      ))
      containers_to_lustre(rest, refs, lustre)
    }
  }
}

fn container_to_lustre(
  lustre: GeneratedLustre(msg),
  container: Container,
  refs: RenderRefs(msg, t),
) -> K(t, GeneratedLustre(msg)) {
  case container {
    ThematicBreak -> continuation.return(lustre |> append_element(html.hr([])))

    Paragraph(attrs, inlines) -> {
      use inner <- continuation.then(inlines_to_lustre(
        GeneratedLustre([], lustre.used_footnotes),
        inlines,
        refs,
        TrimLast,
      ))
      continuation.return(
        wrap_elements(lustre, inner, html.p(attributes_to_lustre(attrs), _)),
      )
    }

    Codeblock(attrs, language, content) -> {
      let code_attrs = case language {
        Some(lang) -> add_attribute(attrs, "class", "language-" <> lang)
        None -> attrs
      }
      continuation.return(
        lustre
        |> append_element(
          html.pre([], [
            html.code(attributes_to_lustre(code_attrs), [
              element.text(content),
            ]),
          ]),
        ),
      )
    }

    Heading(attrs, level, inlines) -> {
      let tag = "h" <> int.to_string(level)
      use inner <- continuation.then(inlines_to_lustre(
        GeneratedLustre([], lustre.used_footnotes),
        inlines,
        refs,
        TrimLast,
      ))
      continuation.return(
        wrap_elements(lustre, inner, element.element(
          tag,
          attributes_to_lustre(attrs),
          _,
        )),
      )
    }

    RawBlock(content) -> {
      use element <- continuation.then(refs.renderer.resolve_raw_block(content))
      continuation.return(lustre |> append_element(element))
    }

    BulletList(layout:, style: _, items:) -> {
      use inner <- continuation.then(list_items_to_lustre(
        GeneratedLustre([], lustre.used_footnotes),
        layout,
        items,
        refs,
      ))
      continuation.return(wrap_elements(lustre, inner, html.ul([], _)))
    }

    OrderedList(layout:, punctuation: _, ordinal:, start:, items:) -> {
      let attrs = case start {
        1 -> dict.new()
        _ -> dict.from_list([#("start", int.to_string(start))])
      }
      let attrs = case ordinal {
        NumericOrdinal -> attrs
        LowerAlphaOrdinal -> dict.insert(attrs, "type", "a")
        UpperAlphaOrdinal -> dict.insert(attrs, "type", "A")
      }
      use inner <- continuation.then(list_items_to_lustre(
        GeneratedLustre([], lustre.used_footnotes),
        layout,
        items,
        refs,
      ))
      continuation.return(
        wrap_elements(lustre, inner, html.ol(attributes_to_lustre(attrs), _)),
      )
    }

    BlockQuote(attrs, items) -> {
      use inner <- continuation.then(containers_to_lustre(
        items,
        refs,
        GeneratedLustre([], lustre.used_footnotes),
      ))
      continuation.return(
        wrap_elements(lustre, inner, html.blockquote(
          attributes_to_lustre(attrs),
          _,
        )),
      )
    }

    Div(class: _, attributes:, items:) -> {
      use inner <- continuation.then(containers_to_lustre(
        items,
        refs,
        GeneratedLustre([], lustre.used_footnotes),
      ))
      continuation.return(
        wrap_elements(lustre, inner, html.div(
          attributes_to_lustre(attributes),
          _,
        )),
      )
    }
  }
}

fn create_footnotes(
  refs: RenderRefs(msg, t),
  used_footnotes: List(#(Int, String)),
  lustre_acc: GeneratedLustre(msg),
) -> K(t, GeneratedLustre(msg)) {
  let footnote_to_lustre = fn(
    lustre: GeneratedLustre(msg),
    footnote: String,
    footnote_number: String,
  ) {
    let footnote =
      dict.get(refs.footnotes, footnote)
      |> result.try(fn(footnote) {
        // Even if the footnote is empty, we need to still make sure a backlink is generated
        case list.is_empty(footnote) {
          True -> Error(Nil)
          False -> Ok(footnote)
        }
      })
    case footnote {
      Ok(footnote) ->
        containers_to_lustre_with_last_paragraph(
          footnote,
          refs,
          lustre,
          add_footnote_link(_, footnote_number),
        )
      Error(Nil) -> {
        let inner =
          GeneratedLustre([], lustre.used_footnotes)
          |> add_footnote_link(footnote_number)
        continuation.return(wrap_elements(lustre, inner, html.p([], _)))
      }
    }
  }

  case used_footnotes {
    [] -> continuation.return(lustre_acc)
    [#(footnote_number, footnote), ..other_footnotes] -> {
      let footnote_number = int.to_string(footnote_number)

      use inner <- continuation.then(footnote_to_lustre(
        GeneratedLustre([], lustre_acc.used_footnotes),
        footnote,
        footnote_number,
      ))
      let lustre =
        lustre_acc
        |> wrap_elements(inner, html.li(
          [attribute.id("fn" <> footnote_number)],
          _,
        ))

      let new_used_footnotes =
        list.append(get_new_footnotes(lustre_acc, lustre, []), other_footnotes)
      create_footnotes(refs, new_used_footnotes, lustre)
    }
  }
}

fn add_footnote_link(
  lustre: GeneratedLustre(msg),
  footnote_number: String,
) -> GeneratedLustre(msg) {
  lustre
  |> append_element(
    html.a(
      [
        attribute.href("#fnref" <> footnote_number),
        attribute.role("doc-backlink"),
      ],
      [element.text("↩︎")],
    ),
  )
}

fn get_new_footnotes(
  original_lustre: GeneratedLustre(msg),
  new_lustre: GeneratedLustre(msg),
  acc: List(#(Int, String)),
) -> List(#(Int, String)) {
  case original_lustre.used_footnotes, new_lustre.used_footnotes {
    [original, ..], [new, ..] if original == new -> acc
    _, [new, ..rest] ->
      get_new_footnotes(
        original_lustre,
        GeneratedLustre(..new_lustre, used_footnotes: rest),
        [new, ..acc],
      )
    _, _ -> acc
  }
}

fn append_element(
  original_lustre: GeneratedLustre(msg),
  element: Element(msg),
) -> GeneratedLustre(msg) {
  GeneratedLustre(..original_lustre, elements: [
    element,
    ..original_lustre.elements
  ])
}

/// Where jot opens a tag, generates content, and closes the tag, a lustre
/// tree wraps the content rendered into `inner` in a parent element.
/// The footnotes used while rendering the content carry over.
fn wrap_elements(
  original_lustre: GeneratedLustre(msg),
  inner: GeneratedLustre(msg),
  wrap: fn(List(Element(msg))) -> Element(msg),
) -> GeneratedLustre(msg) {
  GeneratedLustre(
    elements: [wrap(list.reverse(inner.elements)), ..original_lustre.elements],
    used_footnotes: inner.used_footnotes,
  )
}

type Trim {
  NoTrim
  TrimLast
}

fn list_items_to_lustre(
  lustre: GeneratedLustre(msg),
  layout: ListLayout,
  items: List(List(Container)),
  refs: RenderRefs(msg, t),
) -> K(t, GeneratedLustre(msg)) {
  case items {
    [] -> continuation.return(lustre)

    [[Paragraph(_, inlines)], ..rest] if layout == Tight -> {
      use inner <- continuation.then(inlines_to_lustre(
        GeneratedLustre([], lustre.used_footnotes),
        inlines,
        refs,
        TrimLast,
      ))
      lustre
      |> wrap_elements(inner, html.li([], _))
      |> list_items_to_lustre(layout, rest, refs)
    }

    [[Paragraph(_, inlines), nested_list, ..item_rest], ..rest]
      if layout == Tight
    -> {
      use inner <- continuation.then(inlines_to_lustre(
        GeneratedLustre([], lustre.used_footnotes),
        inlines,
        refs,
        TrimLast,
      ))
      use inner <- continuation.then(containers_to_lustre(
        [nested_list, ..item_rest],
        refs,
        inner,
      ))
      lustre
      |> wrap_elements(inner, html.li([], _))
      |> list_items_to_lustre(layout, rest, refs)
    }

    [item, ..rest] -> {
      use inner <- continuation.then(containers_to_lustre(
        item,
        refs,
        GeneratedLustre([], lustre.used_footnotes),
      ))
      lustre
      |> wrap_elements(inner, html.li([], _))
      |> list_items_to_lustre(layout, rest, refs)
    }
  }
}

fn inlines_to_lustre(
  lustre: GeneratedLustre(msg),
  inlines: List(Inline),
  refs: RenderRefs(msg, t),
  trim: Trim,
) -> K(t, GeneratedLustre(msg)) {
  case inlines {
    [] -> continuation.return(lustre)

    // jot has no raw inline variant: `` `…`{=html} `` parses as a Code
    // inline followed by the literal attribute text
    [Code(content), Text("{=html}" <> rest), ..other] -> {
      use element <- continuation.then(refs.renderer.resolve_raw_inline(content))
      let lustre = lustre |> append_element(element)
      case rest {
        "" -> inlines_to_lustre(lustre, other, refs, trim)
        _ -> inlines_to_lustre(lustre, [Text(rest), ..other], refs, trim)
      }
    }

    [inline] if trim == TrimLast -> {
      lustre
      |> inline_to_lustre(inline, refs, trim)
    }

    [inline, ..rest] -> {
      use lustre <- continuation.then(inline_to_lustre(
        lustre,
        inline,
        refs,
        NoTrim,
      ))
      inlines_to_lustre(lustre, rest, refs, trim)
    }
  }
}

fn inline_to_lustre(
  lustre: GeneratedLustre(msg),
  inline: Inline,
  refs: RenderRefs(msg, t),
  trim: Trim,
) -> K(t, GeneratedLustre(msg)) {
  case inline {
    MathInline(latex) -> {
      let latex = "\\(" <> latex <> "\\)"

      continuation.return(
        lustre
        |> append_element(
          html.span([attribute.class("math inline")], [element.text(latex)]),
        ),
      )
    }
    MathDisplay(latex) -> {
      let latex = "\\[" <> latex <> "\\]"

      continuation.return(
        lustre
        |> append_element(
          html.span([attribute.class("math display")], [element.text(latex)]),
        ),
      )
    }
    NonBreakingSpace -> {
      continuation.return(lustre |> append_element(element.text("\u{00A0}")))
    }
    Linebreak -> {
      continuation.return(lustre |> append_element(html.br([])))
    }
    Text(text) -> {
      let text = case trim {
        NoTrim -> text
        TrimLast -> string.trim_end(text)
      }
      // jot appends text to the generated html, so empty text contributes
      // nothing; adding an empty text node would only pad the tree
      case text {
        "" -> continuation.return(lustre)
        text -> continuation.return(append_element(lustre, element.text(text)))
      }
    }
    Strong(inlines) -> {
      use inner <- continuation.then(inlines_to_lustre(
        GeneratedLustre([], lustre.used_footnotes),
        inlines,
        refs,
        trim,
      ))
      continuation.return(wrap_elements(lustre, inner, html.strong([], _)))
    }
    Emphasis(inlines) -> {
      use inner <- continuation.then(inlines_to_lustre(
        GeneratedLustre([], lustre.used_footnotes),
        inlines,
        refs,
        trim,
      ))
      continuation.return(wrap_elements(lustre, inner, html.em([], _)))
    }
    Delete(inlines) -> {
      use inner <- continuation.then(inlines_to_lustre(
        GeneratedLustre([], lustre.used_footnotes),
        inlines,
        refs,
        NoTrim,
      ))
      continuation.return(wrap_elements(lustre, inner, html.del([], _)))
    }
    Insert(inlines) -> {
      use inner <- continuation.then(inlines_to_lustre(
        GeneratedLustre([], lustre.used_footnotes),
        inlines,
        refs,
        NoTrim,
      ))
      continuation.return(wrap_elements(lustre, inner, html.ins([], _)))
    }
    Mark(inlines) -> {
      use inner <- continuation.then(inlines_to_lustre(
        GeneratedLustre([], lustre.used_footnotes),
        inlines,
        refs,
        NoTrim,
      ))
      continuation.return(wrap_elements(lustre, inner, html.mark([], _)))
    }
    Superscript(inlines) -> {
      use inner <- continuation.then(inlines_to_lustre(
        GeneratedLustre([], lustre.used_footnotes),
        inlines,
        refs,
        NoTrim,
      ))
      continuation.return(wrap_elements(lustre, inner, html.sup([], _)))
    }
    Subscript(inlines) -> {
      use inner <- continuation.then(inlines_to_lustre(
        GeneratedLustre([], lustre.used_footnotes),
        inlines,
        refs,
        NoTrim,
      ))
      continuation.return(wrap_elements(lustre, inner, html.sub([], _)))
    }
    Link(attributes, text, destination) -> {
      // Merge: reference attrs <- href <- inline attrs
      let ref_attrs = get_reference_attributes(destination, refs)
      use destination_attrs <- continuation.then(destination_attribute(
        "href",
        destination,
        refs,
      ))
      let attrs =
        ref_attrs
        |> dict.merge(destination_attrs)
        |> dict.merge(attributes)
      use inner <- continuation.then(inlines_to_lustre(
        GeneratedLustre([], lustre.used_footnotes),
        text,
        refs,
        trim,
      ))
      continuation.return(
        wrap_elements(lustre, inner, html.a(attributes_to_lustre(attrs), _)),
      )
    }
    Image(attributes, text, destination) -> {
      // Merge: reference attrs <- src/alt <- inline attrs
      let ref_attrs = get_reference_attributes(destination, refs)
      use destination_attrs <- continuation.then(destination_attribute(
        "src",
        destination,
        refs,
      ))
      let attrs =
        ref_attrs
        |> dict.merge(destination_attrs)
        |> dict.insert("alt", take_inline_text(text, ""))
        |> dict.merge(attributes)
      continuation.return(
        lustre |> append_element(html.img(attributes_to_lustre(attrs))),
      )
    }
    Symbol(content) -> {
      use text <- continuation.then(refs.renderer.resolve_symbol(content))
      continuation.return(
        lustre
        |> append_element(
          html.span([attribute.class("symbol")], [element.text(text)]),
        ),
      )
    }
    Span(attributes, inlines) -> {
      use inner <- continuation.then(inlines_to_lustre(
        GeneratedLustre([], lustre.used_footnotes),
        inlines,
        refs,
        trim,
      ))
      continuation.return(
        wrap_elements(lustre, inner, html.span(
          attributes_to_lustre(attributes),
          _,
        )),
      )
    }
    Code(content) -> {
      continuation.return(
        lustre |> append_element(html.code([], [element.text(content)])),
      )
    }
    Footnote(reference) -> {
      let #(footnote_number, new_used_footnotes) =
        find_footnote_number(
          lustre.used_footnotes,
          reference,
          lustre.used_footnotes,
        )
      let footnote_attrs = [
        attribute.id("fnref" <> footnote_number),
        attribute.href("#fn" <> footnote_number),
        attribute.role("doc-noteref"),
      ]

      let updated_lustre =
        lustre
        |> append_element(
          html.a(footnote_attrs, [
            html.sup([], [element.text(footnote_number)]),
          ]),
        )

      continuation.return(
        GeneratedLustre(..updated_lustre, used_footnotes: new_used_footnotes),
      )
    }
  }
}

fn find_footnote_number(
  footnotes_to_check: Footnotes,
  reference: String,
  used_footnotes: Footnotes,
) -> #(String, Footnotes) {
  case footnotes_to_check {
    [] -> {
      let next_number =
        {
          used_footnotes
          |> list.first()
          |> result.map(fn(f) { f.0 })
          |> result.unwrap(0)
        }
        + 1

      #(int.to_string(next_number), [
        #(next_number, reference),
        ..used_footnotes
      ])
    }
    [#(index, ref), ..] if reference == ref -> {
      #(int.to_string(index), used_footnotes)
    }
    [_, ..rest] -> find_footnote_number(rest, reference, used_footnotes)
  }
}

fn get_reference_attributes(
  destination: Destination,
  refs: RenderRefs(msg, t),
) -> Dict(String, String) {
  case destination {
    Url(_) -> dict.new()
    Reference(id) ->
      dict.get(refs.reference_attributes, id)
      |> result.unwrap(dict.new())
  }
}

fn destination_attribute(
  key: String,
  destination: Destination,
  refs: RenderRefs(msg, t),
) -> K(t, Dict(String, String)) {
  let dict = dict.new()
  case destination {
    Url(url) -> {
      use url <- continuation.then(refs.renderer.resolve_url(url))
      continuation.return(dict.insert(dict, key, url))
    }
    Reference(id) ->
      case dict.get(refs.urls, id) {
        Ok(url) -> {
          use url <- continuation.then(refs.renderer.resolve_url(url))
          continuation.return(dict.insert(dict, key, url))
        }
        _ -> continuation.return(dict)
      }
  }
}

fn attributes_to_lustre(
  attributes: Dict(String, String),
) -> List(Attribute(msg)) {
  attributes
  |> dict.to_list
  |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
  |> list.map(fn(pair) { attribute.attribute(pair.0, pair.1) })
}

fn add_attribute(
  attributes: Dict(String, String),
  key: String,
  value: String,
) -> Dict(String, String) {
  case key {
    "class" ->
      dict.upsert(attributes, key, fn(previous) {
        case previous {
          None -> value
          Some(previous) -> previous <> " " <> value
        }
      })
    _ -> dict.insert(attributes, key, value)
  }
}

fn take_inline_text(inlines: List(Inline), acc: String) -> String {
  case inlines {
    [] -> acc
    [first, ..rest] ->
      case first {
        NonBreakingSpace -> take_inline_text(rest, acc <> " ")
        Text(text)
        | Code(text)
        | MathInline(text)
        | MathDisplay(text)
        | Symbol(text) -> take_inline_text(rest, acc <> text)
        Strong(inlines)
        | Emphasis(inlines)
        | Delete(inlines)
        | Insert(inlines)
        | Mark(inlines)
        | Superscript(inlines)
        | Subscript(inlines) ->
          take_inline_text(list.append(inlines, rest), acc)
        Link(_, nested, _) | Image(_, nested, _) | Span(_, nested) -> {
          let acc = take_inline_text(nested, acc)
          take_inline_text(rest, acc)
        }
        Linebreak | Footnote(_) -> {
          take_inline_text(rest, acc)
        }
      }
  }
}
