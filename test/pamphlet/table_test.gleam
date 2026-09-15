import birdie
import gleam/dict
import gleam/option.{Some}
import gleam/string
import jot
import lustre/element
import lustre/element/html
import midas/continuation
import pamphlet/lustre

fn snap(source, title) {
  lustre.to_lustre(jot.parse(source), lustre.default())(
    element.to_readable_string,
  )
  |> birdie.snap(title)
}

pub fn rows_test() {
  "| a | *b* |\n| | c |" |> snap("lustre_table_rows")
}

pub fn caption_and_attributes_test() {
  "{#inventory .striped}\n| a | b |\n\n^ With a _caption_\n  and another line."
  |> snap("lustre_table_caption_and_attributes")
}

pub fn headers_and_alignments_test() {
  "| none | left | center | right |\n|---|:---|:---:|---:|\n| a | b | c | d |\n| second | header | row | here |\n|:---|---:|:---|:---:|\n| e | f | g | h |"
  |> snap("lustre_table_headers_and_alignments")
}

pub fn empty_table_test() {
  "|--|" |> snap("lustre_empty_table")
}

pub fn pipes_and_code_test() {
  "| just two \\| `|` | cells in this table |"
  |> snap("lustre_table_pipes_and_code")
}

pub fn continuations_and_footnotes_test() {
  let renderer =
    lustre.Renderer(..lustre.default(), resolve_url: fn(url) {
      continuation.return("/resolved" <> url)
    })
  let document =
    jot.parse(
      "| [guide](/guide) | :warning: [^details] |\n\n^ [caption](/caption)\n\n[^details]: More detail.",
    )
  lustre.to_lustre(document, renderer)(element.to_readable_string)
  |> birdie.snap("lustre_table_continuations_and_footnotes")
}

pub fn custom_table_parts_receive_metadata_test() {
  let attrs = dict.from_list([#("id", "source")])
  let renderer =
    lustre.Renderer(
      ..lustre.default(),
      render_table: fn(received, children) {
        assert received == attrs
        continuation.return(html.section([], children))
      },
      render_table_caption: fn(children) {
        continuation.return(html.h2([], children))
      },
      render_table_row: fn(header, children) {
        assert header
        continuation.return(html.div([], children))
      },
      render_table_cell: fn(header, alignment, children) {
        assert header
        assert alignment == Some(jot.AlignRight)
        continuation.return(html.span([], children))
      },
    )
  let document =
    jot.Document(..jot.parse(""), content: [
      jot.Table(attrs, Some([jot.Text("caption")]), [
        jot.TableRow(True, [
          jot.TableCell(Some(jot.AlignRight), [jot.Strong([jot.Text("cell")])]),
        ]),
      ]),
    ])
  assert string.contains(
    lustre.to_lustre(document, renderer)(element.to_string),
    "<section><h2>caption</h2><div><span><strong>cell</strong></span></div></section>",
  )
}
