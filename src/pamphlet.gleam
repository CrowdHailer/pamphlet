import jot
import pamphlet/document

pub fn parse(text: String) -> #(List(#(String, String)), jot.Document) {
  case document.take_frontmatter(text) {
    Ok(#(meta, body)) -> #(document.parse_frontmatter(meta), jot.parse(body))
    Error(Nil) -> #([], jot.parse(text))
  }
}
