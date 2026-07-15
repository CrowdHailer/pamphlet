import gleam/list
import gleam/string
import splitter

/// Pop frontmatter from a document.
/// 
/// Doesn't check the validity of the frontmatter.
/// User parse_frontmatter to get a list of frontmatter properties
pub fn take_frontmatter(text: String) -> Result(#(String, String), Nil) {
  let fms = splitter.new(["---\n", "---\r\n"])
  let #(nothing, start, rest) = splitter.split(fms, text)
  case nothing != "" || start == "" {
    True -> Error(Nil)
    False -> {
      let #(frontmatter, end, rest) = splitter.split(fms, rest)
      case end {
        "" -> Error(Nil)
        _ -> Ok(#(frontmatter, rest))
      }
    }
  }
}

pub fn parse_frontmatter(text) {
  let lines =
    splitter.new(["\n", "\r\n"])
    |> split_all(text, [])

  list.filter_map(lines, fn(line) {
    case string.split_once(line, ":") {
      Ok(#(key, value)) -> Ok(#(key, string.trim(value)))
      _ -> Error(Nil)
    }
  })
}

fn split_all(splitter, input, acc) {
  case input {
    "" -> list.reverse(acc)
    _ -> {
      let #(pre, _match, post) = splitter.split(splitter, input)
      split_all(splitter, post, [pre, ..acc])
    }
  }
}
