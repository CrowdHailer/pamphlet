//// Render djot documents to lustre elements.
////
//// The rendering follows `jot.document_to_html` as closely as possible —
//// the same function names, the same case order, the same footnote
//// bookkeeping — so the two targets stay easy to compare. Where jot appends
//// to an HTML string, this module appends `Element`s to a tree.

import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
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

/// Source attributes, or merged attributes for resolved links and images.
pub type Attributes =
  Dict(String, String)

/// Presentation policy for every document node and generated structural element.
/// Start from `default()` and override individual fields with a record update.
///
/// `resolve_*` callbacks look up URLs and symbols; `render_*` callbacks construct
/// complete elements. Parents receive already-rendered children in source order.
/// Pamphlet owns traversal, whitespace rules, references, and footnote numbering.
/// Links/images receive merged attributes including resolved href/src and alt.
/// Image alt text is flattened from source inlines, not rendered as child nodes.
///
/// Each callback returns a continuation. Children run before their parent;
/// returning without continuing halts subsequent work, but cannot undo children.
/// Dropping a parent's children also does not undo their effects or footnotes.
///
/// Tight-list paragraphs use `render_tight_paragraph`, which returns a list of
/// elements (by default the children) to avoid adding a wrapper or fragment.
/// Footnote reference/backlink/item callbacks receive the assigned
/// number as a string; preserve the default IDs/links when changing their HTML.
/// Raw and code callbacks receive unescaped source. Math callbacks receive LaTeX
/// without output delimiters. `render_symbol` receives the resolved symbol.
pub type Renderer(msg, t) {
  Renderer(
    resolve_url: fn(String) -> K(t, String),
    resolve_symbol: fn(String) -> K(t, String),
    render_document: fn(List(Element(msg))) -> K(t, Element(msg)),
    render_thematic_break: fn() -> K(t, Element(msg)),
    render_paragraph: fn(Attributes, List(Element(msg))) -> K(t, Element(msg)),
    render_tight_paragraph: fn(Attributes, List(Element(msg))) ->
      K(t, List(Element(msg))),
    render_heading: fn(Attributes, Int, List(Element(msg))) ->
      K(t, Element(msg)),
    render_code_block: fn(Attributes, Option(String), String) ->
      K(t, Element(msg)),
    render_raw_block: fn(String) -> K(t, Element(msg)),
    render_raw_inline: fn(String) -> K(t, Element(msg)),
    render_bullet_list: fn(ListLayout, jot.BulletStyle, List(Element(msg))) ->
      K(t, Element(msg)),
    render_ordered_list: fn(
      ListLayout,
      jot.OrdinalPunctuation,
      jot.OrdinalStyle,
      Int,
      List(Element(msg)),
    ) -> K(t, Element(msg)),
    render_list_item: fn(List(Element(msg))) -> K(t, Element(msg)),
    render_block_quote: fn(Attributes, List(Element(msg))) -> K(t, Element(msg)),
    render_div: fn(Option(String), Attributes, List(Element(msg))) ->
      K(t, Element(msg)),
    render_text: fn(String) -> K(t, Element(msg)),
    render_linebreak: fn() -> K(t, Element(msg)),
    render_non_breaking_space: fn() -> K(t, Element(msg)),
    render_strong: fn(List(Element(msg))) -> K(t, Element(msg)),
    render_emphasis: fn(List(Element(msg))) -> K(t, Element(msg)),
    render_delete: fn(List(Element(msg))) -> K(t, Element(msg)),
    render_insert: fn(List(Element(msg))) -> K(t, Element(msg)),
    render_mark: fn(List(Element(msg))) -> K(t, Element(msg)),
    render_superscript: fn(List(Element(msg))) -> K(t, Element(msg)),
    render_subscript: fn(List(Element(msg))) -> K(t, Element(msg)),
    render_link: fn(Attributes, List(Element(msg))) -> K(t, Element(msg)),
    render_image: fn(Attributes) -> K(t, Element(msg)),
    render_span: fn(Attributes, List(Element(msg))) -> K(t, Element(msg)),
    render_code: fn(String) -> K(t, Element(msg)),
    render_math_inline: fn(String) -> K(t, Element(msg)),
    render_math_display: fn(String) -> K(t, Element(msg)),
    render_symbol: fn(String) -> K(t, Element(msg)),
    render_footnote_reference: fn(String, String) -> K(t, Element(msg)),
    render_footnote_backlink: fn(String) -> K(t, Element(msg)),
    render_footnote_item: fn(String, List(Element(msg))) -> K(t, Element(msg)),
    render_footnotes: fn(List(Element(msg))) -> K(t, Element(msg)),
  )
}

/// A renderer that matches `jot.document_to_html` as closely as lustre
/// allows.
///
/// URLs pass through untouched and symbols render as written inside jot's
/// `<span class="symbol">`. Raw blocks and raw inlines are escaped text inside
/// `<div>` elements. Override their render callbacks to interpret raw content.
/// All callbacks construct their own complete element; defaults do not dispatch
/// through other callbacks (e.g. a default link does not call `render_text`).
pub fn default() -> Renderer(msg, t) {
  Renderer(
    resolve_url: continuation.return,
    resolve_symbol: continuation.return,
    render_document: fn(children) {
      continuation.return(element.fragment(children))
    },
    render_thematic_break: fn() { continuation.return(html.hr([])) },
    render_paragraph: container("p"),
    render_tight_paragraph: fn(_, children) { continuation.return(children) },
    render_heading: fn(attrs, level, children) {
      tag("h" <> int.to_string(level), attrs, children)
    },
    render_raw_block: fn(content) {
      continuation.return(html.div([], [html.text(content)]))
    },
    render_raw_inline: fn(content) {
      continuation.return(html.div([], [html.text(content)]))
    },
    render_code_block: fn(attrs, language, content) {
      let code_attrs = case language {
        Some(lang) -> add_attribute(attrs, "class", "language-" <> lang)
        None -> attrs
      }
      continuation.return(
        html.pre([], [
          html.code(attributes_to_lustre(code_attrs), [element.text(content)]),
        ]),
      )
    },
    render_bullet_list: fn(_, _, children) { tag("ul", dict.new(), children) },
    render_ordered_list: fn(_, _, ordinal, start, children) {
      let attrs = case start {
        1 -> dict.new()
        _ -> dict.from_list([#("start", int.to_string(start))])
      }
      let attrs = case ordinal {
        NumericOrdinal -> attrs
        LowerAlphaOrdinal -> dict.insert(attrs, "type", "a")
        UpperAlphaOrdinal -> dict.insert(attrs, "type", "A")
      }
      tag("ol", attrs, children)
    },
    render_list_item: tag("li", dict.new(), _),
    render_block_quote: container("blockquote"),
    render_div: fn(_, attrs, children) { tag("div", attrs, children) },
    render_text: fn(text) { continuation.return(element.text(text)) },
    render_linebreak: fn() { continuation.return(html.br([])) },
    render_non_breaking_space: fn() {
      continuation.return(element.text("\u{00A0}"))
    },
    render_strong: tag("strong", dict.new(), _),
    render_emphasis: tag("em", dict.new(), _),
    render_delete: tag("del", dict.new(), _),
    render_insert: tag("ins", dict.new(), _),
    render_mark: tag("mark", dict.new(), _),
    render_superscript: tag("sup", dict.new(), _),
    render_subscript: tag("sub", dict.new(), _),
    render_link: container("a"),
    render_image: fn(attrs) {
      continuation.return(html.img(attributes_to_lustre(attrs)))
    },
    render_span: container("span"),
    render_code: fn(content) {
      continuation.return(html.code([], [element.text(content)]))
    },
    render_math_inline: fn(latex) {
      continuation.return(
        html.span([attribute.class("math inline")], [
          element.text("\\(" <> latex <> "\\)"),
        ]),
      )
    },
    render_math_display: fn(latex) {
      continuation.return(
        html.span([attribute.class("math display")], [
          element.text("\\[" <> latex <> "\\]"),
        ]),
      )
    },
    render_symbol: fn(text) {
      continuation.return(
        html.span([attribute.class("symbol")], [element.text(text)]),
      )
    },
    render_footnote_reference: fn(_, number) {
      continuation.return(
        html.a(
          [
            attribute.id("fnref" <> number),
            attribute.href("#fn" <> number),
            attribute.role("doc-noteref"),
          ],
          [html.sup([], [element.text(number)])],
        ),
      )
    },
    render_footnote_backlink: fn(number) {
      continuation.return(
        html.a(
          [
            attribute.href("#fnref" <> number),
            attribute.role("doc-backlink"),
          ],
          [element.text("↩︎")],
        ),
      )
    },
    render_footnote_item: fn(number, children) {
      continuation.return(html.li([attribute.id("fn" <> number)], children))
    },
    render_footnotes: fn(children) {
      continuation.return(
        html.section([attribute.role("doc-endnotes")], [
          html.hr([]),
          html.ol([], children),
        ]),
      )
    },
  )
}

fn tag(
  name: String,
  attrs: Attributes,
  children: List(Element(msg)),
) -> K(t, Element(msg)) {
  continuation.return(element.element(
    name,
    attributes_to_lustre(attrs),
    children,
  ))
}

fn container(
  name: String,
) -> fn(Attributes, List(Element(msg))) -> K(t, Element(msg)) {
  fn(attrs, children) { tag(name, attrs, children) }
}

/// Render a document to a lustre element using the given resolution and
/// presentation callbacks.
///
/// The document's containers (and the footnote section, when used) are passed
/// to `render_document`, which returns an `element.fragment` by default.
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
    [] -> renderer.render_document(list.reverse(generated_lustre.elements))
    used_footnotes -> {
      use lustre_with_footnotes <- continuation.then(create_footnotes(
        refs,
        list.reverse(used_footnotes),
        GeneratedLustre([], used_footnotes),
      ))

      use footnotes_section <- continuation.then(
        renderer.render_footnotes(list.reverse(lustre_with_footnotes.elements)),
      )
      renderer.render_document(
        list.reverse([footnotes_section, ..generated_lustre.elements]),
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
  apply: fn(GeneratedLustre(msg)) -> K(t, GeneratedLustre(msg)),
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
          use inner <- continuation.then(apply(inner))
          wrap_elements(lustre, inner, refs.renderer.render_paragraph(attrs, _))
        }
        _ -> {
          use lustre <- continuation.then(container_to_lustre(
            lustre,
            container,
            refs,
          ))
          use inner <- continuation.then(
            apply(GeneratedLustre([], lustre.used_footnotes)),
          )
          wrap_elements(lustre, inner, refs.renderer.render_paragraph(
            dict.new(),
            _,
          ))
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
    ThematicBreak ->
      append_rendered(lustre, refs.renderer.render_thematic_break())

    Paragraph(attrs, inlines) -> {
      use inner <- continuation.then(inlines_to_lustre(
        GeneratedLustre([], lustre.used_footnotes),
        inlines,
        refs,
        TrimLast,
      ))
      wrap_elements(lustre, inner, refs.renderer.render_paragraph(attrs, _))
    }

    Codeblock(attrs, language, content) -> {
      use element <- continuation.then(refs.renderer.render_code_block(
        attrs,
        language,
        content,
      ))
      continuation.return(lustre |> append_element(element))
    }

    Heading(attrs, level, inlines) -> {
      use inner <- continuation.then(inlines_to_lustre(
        GeneratedLustre([], lustre.used_footnotes),
        inlines,
        refs,
        TrimLast,
      ))
      wrap_elements(lustre, inner, refs.renderer.render_heading(attrs, level, _))
    }

    RawBlock(content) -> {
      use element <- continuation.then(refs.renderer.render_raw_block(content))
      continuation.return(lustre |> append_element(element))
    }

    BulletList(layout:, style:, items:) -> {
      use inner <- continuation.then(list_items_to_lustre(
        GeneratedLustre([], lustre.used_footnotes),
        layout,
        items,
        refs,
      ))
      wrap_elements(lustre, inner, refs.renderer.render_bullet_list(
        layout,
        style,
        _,
      ))
    }

    OrderedList(layout:, punctuation:, ordinal:, start:, items:) -> {
      use inner <- continuation.then(list_items_to_lustre(
        GeneratedLustre([], lustre.used_footnotes),
        layout,
        items,
        refs,
      ))
      wrap_elements(lustre, inner, refs.renderer.render_ordered_list(
        layout,
        punctuation,
        ordinal,
        start,
        _,
      ))
    }

    BlockQuote(attrs, items) -> {
      use inner <- continuation.then(containers_to_lustre(
        items,
        refs,
        GeneratedLustre([], lustre.used_footnotes),
      ))
      wrap_elements(lustre, inner, refs.renderer.render_block_quote(attrs, _))
    }

    Div(class:, attributes:, items:) -> {
      use inner <- continuation.then(containers_to_lustre(
        items,
        refs,
        GeneratedLustre([], lustre.used_footnotes),
      ))
      wrap_elements(lustre, inner, refs.renderer.render_div(
        class,
        attributes,
        _,
      ))
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
          add_footnote_link(_, footnote_number, refs),
        )
      Error(Nil) -> {
        use inner <- continuation.then(
          GeneratedLustre([], lustre.used_footnotes)
          |> add_footnote_link(footnote_number, refs),
        )
        wrap_elements(lustre, inner, refs.renderer.render_paragraph(
          dict.new(),
          _,
        ))
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
      use lustre <- continuation.then(
        lustre_acc
        |> wrap_elements(inner, refs.renderer.render_footnote_item(
          footnote_number,
          _,
        )),
      )

      let new_used_footnotes =
        list.append(get_new_footnotes(lustre_acc, lustre, []), other_footnotes)
      create_footnotes(refs, new_used_footnotes, lustre)
    }
  }
}

fn add_footnote_link(
  lustre: GeneratedLustre(msg),
  footnote_number: String,
  refs: RenderRefs(msg, t),
) -> K(t, GeneratedLustre(msg)) {
  append_rendered(
    lustre,
    refs.renderer.render_footnote_backlink(footnote_number),
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
  wrap: fn(List(Element(msg))) -> K(t, Element(msg)),
) -> K(t, GeneratedLustre(msg)) {
  use rendered <- continuation.then(wrap(list.reverse(inner.elements)))
  continuation.return(GeneratedLustre(
    elements: [rendered, ..original_lustre.elements],
    used_footnotes: inner.used_footnotes,
  ))
}

fn append_rendered(
  lustre: GeneratedLustre(msg),
  rendered: K(t, Element(msg)),
) -> K(t, GeneratedLustre(msg)) {
  use rendered <- continuation.then(rendered)
  continuation.return(append_element(lustre, rendered))
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

    [[Paragraph(attrs, inlines)], ..rest] if layout == Tight -> {
      use inner <- continuation.then(inlines_to_lustre(
        GeneratedLustre([], lustre.used_footnotes),
        inlines,
        refs,
        TrimLast,
      ))
      use inner <- continuation.then(tight_paragraph(inner, attrs, refs))
      use lustre <- continuation.then(wrap_elements(
        lustre,
        inner,
        refs.renderer.render_list_item,
      ))
      list_items_to_lustre(lustre, layout, rest, refs)
    }

    [[Paragraph(attrs, inlines), nested_list, ..item_rest], ..rest]
      if layout == Tight
    -> {
      use inner <- continuation.then(inlines_to_lustre(
        GeneratedLustre([], lustre.used_footnotes),
        inlines,
        refs,
        TrimLast,
      ))
      use inner <- continuation.then(tight_paragraph(inner, attrs, refs))
      use inner <- continuation.then(containers_to_lustre(
        [nested_list, ..item_rest],
        refs,
        inner,
      ))
      use lustre <- continuation.then(wrap_elements(
        lustre,
        inner,
        refs.renderer.render_list_item,
      ))
      list_items_to_lustre(lustre, layout, rest, refs)
    }

    [item, ..rest] -> {
      use inner <- continuation.then(containers_to_lustre(
        item,
        refs,
        GeneratedLustre([], lustre.used_footnotes),
      ))
      use lustre <- continuation.then(wrap_elements(
        lustre,
        inner,
        refs.renderer.render_list_item,
      ))
      list_items_to_lustre(lustre, layout, rest, refs)
    }
  }
}

fn tight_paragraph(
  inner: GeneratedLustre(msg),
  attrs: Attributes,
  refs: RenderRefs(msg, t),
) -> K(t, GeneratedLustre(msg)) {
  use children <- continuation.then(refs.renderer.render_tight_paragraph(
    attrs,
    list.reverse(inner.elements),
  ))
  continuation.return(
    GeneratedLustre(..inner, elements: list.reverse(children)),
  )
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
      use element <- continuation.then(refs.renderer.render_raw_inline(content))
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
    MathInline(latex) ->
      append_rendered(lustre, refs.renderer.render_math_inline(latex))
    MathDisplay(latex) ->
      append_rendered(lustre, refs.renderer.render_math_display(latex))
    NonBreakingSpace ->
      append_rendered(lustre, refs.renderer.render_non_breaking_space())
    Linebreak -> append_rendered(lustre, refs.renderer.render_linebreak())
    Text(text) -> {
      let text = case trim {
        NoTrim -> text
        TrimLast -> string.trim_end(text)
      }
      // jot appends text to the generated html, so empty text contributes
      // nothing; adding an empty text node would only pad the tree
      case text {
        "" -> continuation.return(lustre)
        text -> append_rendered(lustre, refs.renderer.render_text(text))
      }
    }
    Strong(inlines) -> {
      use inner <- continuation.then(inlines_to_lustre(
        GeneratedLustre([], lustre.used_footnotes),
        inlines,
        refs,
        trim,
      ))
      wrap_elements(lustre, inner, refs.renderer.render_strong)
    }
    Emphasis(inlines) -> {
      use inner <- continuation.then(inlines_to_lustre(
        GeneratedLustre([], lustre.used_footnotes),
        inlines,
        refs,
        trim,
      ))
      wrap_elements(lustre, inner, refs.renderer.render_emphasis)
    }
    Delete(inlines) -> {
      use inner <- continuation.then(inlines_to_lustre(
        GeneratedLustre([], lustre.used_footnotes),
        inlines,
        refs,
        NoTrim,
      ))
      wrap_elements(lustre, inner, refs.renderer.render_delete)
    }
    Insert(inlines) -> {
      use inner <- continuation.then(inlines_to_lustre(
        GeneratedLustre([], lustre.used_footnotes),
        inlines,
        refs,
        NoTrim,
      ))
      wrap_elements(lustre, inner, refs.renderer.render_insert)
    }
    Mark(inlines) -> {
      use inner <- continuation.then(inlines_to_lustre(
        GeneratedLustre([], lustre.used_footnotes),
        inlines,
        refs,
        NoTrim,
      ))
      wrap_elements(lustre, inner, refs.renderer.render_mark)
    }
    Superscript(inlines) -> {
      use inner <- continuation.then(inlines_to_lustre(
        GeneratedLustre([], lustre.used_footnotes),
        inlines,
        refs,
        NoTrim,
      ))
      wrap_elements(lustre, inner, refs.renderer.render_superscript)
    }
    Subscript(inlines) -> {
      use inner <- continuation.then(inlines_to_lustre(
        GeneratedLustre([], lustre.used_footnotes),
        inlines,
        refs,
        NoTrim,
      ))
      wrap_elements(lustre, inner, refs.renderer.render_subscript)
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
      wrap_elements(lustre, inner, refs.renderer.render_link(attrs, _))
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
      append_rendered(lustre, refs.renderer.render_image(attrs))
    }
    Symbol(content) -> {
      use text <- continuation.then(refs.renderer.resolve_symbol(content))
      append_rendered(lustre, refs.renderer.render_symbol(text))
    }
    Span(attributes, inlines) -> {
      use inner <- continuation.then(inlines_to_lustre(
        GeneratedLustre([], lustre.used_footnotes),
        inlines,
        refs,
        trim,
      ))
      wrap_elements(lustre, inner, refs.renderer.render_span(attributes, _))
    }
    Code(content) -> {
      append_rendered(lustre, refs.renderer.render_code(content))
    }
    Footnote(reference) -> {
      let #(footnote_number, new_used_footnotes) =
        find_footnote_number(
          lustre.used_footnotes,
          reference,
          lustre.used_footnotes,
        )
      use updated_lustre <- continuation.then(append_rendered(
        lustre,
        refs.renderer.render_footnote_reference(reference, footnote_number),
      ))

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
